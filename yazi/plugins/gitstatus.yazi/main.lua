--- @sync entry
local M = {}

local debug_table = function(table)
	for k, v in pairs(table) do
		ya.err(tostring(k) .. " " .. tostring(v))
	end
end

local get_hovered = ya.sync(function(st)
	local h = cx.active.current.hovered
	return tostring(h.url)
end)


local clean_up_all = ya.sync(function(st)
	st.git_roots = {}
	st.git_roots_sub = {}
	st.git_roots_curr = {}
	st.tracked = {}
	st.status = {}
	ya.render()
end)

local get_git_roots = ya.sync(function(st, sub)
	if not st.git_roots then
		st.git_roots = {}
		st.git_roots_sub = {}
	end
	if sub then
		return st.git_roots_sub
	end
	return st.git_roots
end)

local update_git_roots = ya.sync(function(st, git_root, sub)
	if not st.git_roots then
		st.git_roots = {}
	end
	st.git_roots[git_root] = true
	if sub then
		if not st.git_roots_sub then
			st.git_roots_sub = {}
		end
		st.git_roots_sub[git_root] = true
	end
end)

local update_tracked = ya.sync(function(st, git_root, tracked)
	if not st.tracked then
		st.tracked = {}
	end
	for url, type in pairs(tracked) do
		if st.tracked[tostring(url)] == nil or st.tracked[tostring(url)] == "✓" then
			st.tracked[tostring(url)] = type
		end
	end
	Linemode.file_gitstatus = function(self, file)
		local file_tracked = st.tracked[tostring(file.url)]
		if file_tracked == nil then
			return " "
		end
		return file_tracked
	end
	ya.render()
end)

local update_git_roots_curr = ya.sync(function(st, git_roots_curr)
	if not st.git_roots_curr then
		st.git_roots_curr = {}
	end
	for git_root, _ in pairs(git_roots_curr) do
		st.git_roots_curr[git_root] = true
	end
	Linemode.file_gitstatus = function(self, file)
		if st.git_roots_curr[tostring(file.url)] then
			return "󰊢"
		end
		return " "
	end
	ya.render()
end)

local update_status = ya.sync(function(st, git_root, status, dir_status)
	if not st.status then
		st.status = {}
	end
	st.status[git_root] = {
		status = status,
		dir_status = dir_status,
	}
end)

local get_status = ya.sync(function(st, git_root)
	if st.status and st.status[git_root] then
		return st.status[git_root].status, st.status[git_root].dir_status
	end
end)

local parse_git_status = function(git_status_line)
	local type, update_git_root = nil, false
	local status_code = git_status_line:sub(1, 2)
	local status_translations = {
		-- X (index) codes, Y (working tree) codes, translated status
		{ x = "MADRC",  y = " ",   status = "staged" },
		{ x = " MADRC", y = "M",   status = "changed" },
		{ x = " MARC",  y = "D",   status = "deleted" },
		{ x = "D",      y = "DU",  status = "conflict" },
		{ x = "A",      y = "AU",  status = "conflict" },
		{ x = "U",      y = "ADU", status = "conflict" },
		{ x = "?",      y = "?",   status = "untracked" },
		{ x = "!",      y = "!",   status = "ignored" },
		{ x = " MADRC", y = "m",   status = "changed_sub" },
		{ x = " ",      y = "?",   status = "untracked_sub" },
	}
	local status_icon = {
		staged = "*",
		changed = "+",
		deleted = "-",
		conflict = "X",
		untracked = "?",
		ignored = "·",
		changed_sub = "+",
		untracked_sub = "?",
	}

	local x = status_code:sub(1, 1)
	local y = status_code:sub(2, 2)

	for _, rule in ipairs(status_translations) do
		if rule.x:find(x) and rule.y:find(y) then
			if rule.status:find("sub") then
				update_git_root = true
			end
			type = status_icon[rule.status]
			break
		end
	end

	if type == nil then
		ya.err("unknown status: " .. status_code)
		return nil, false, trimed_next
	end

	return type, update_git_root, trimed_next
end

local get_git_status = function(git_root)
	local tracked = {}
	-- check tracked files
	local child, code = Command("git"):args({ "status", "--ignored", "--short" }):cwd(git_root):stdout(Command.PIPED)
			:spawn()
	if not child then
		ya.err("spawn `git` command returns " .. tostring(code))
		ya.err("cwd: " .. git_root)
		return {}, {}
	end

	repeat
		local next, event = child:read_line_with { timeout = 10000 }
		if event == 3 then
			ya.err("timeout")
			break
		elseif event ~= 0 then
			break
		end

		local trimed_next = next:match("^(.*)\n$")
		-- if match "^!! ", it is ignored file
		local type, update_git_root = parse_git_status(trimed_next)
		if update_git_root then
			ya.err("update" .. trimed_next)
		end
		trimed_next = trimed_next:sub(4)
		-- if trimed_next ends with /, it is a directory
		if trimed_next:match("/$") then
			trimed_next = trimed_next:sub(1, -2) -- remove last /
		end
		local url = git_root .. "/" .. trimed_next
		if update_git_root then
			update_git_roots(url, false)
		end
		tracked[url] = type
		::continue::
	until not next

	-- add parent dirs, which is used to see the directory status
	local dir_tracked = {}
	for url, type in pairs(tracked) do
		local base_url = url:match("^(.*/)[^/]*/*$")
		while base_url ~= nil and base_url:find(git_root, 1, true) do
			if tracked[base_url] == nil then
				local base_url_without_slash = base_url:match("^(.*)/$")
				if base_url_without_slash ~= nil and base_url_without_slash == git_root then
					-- git root should not have any status
					break
				end
				if type ~= "·" then
					dir_tracked[base_url_without_slash] = type
				end
			end
			base_url = base_url:match("^(.*/)[^/]*/$")
		end
	end

	return tracked, dir_tracked
end

local get_git_root = function(url)
	local url = url:match("^(.*)/$")
	if url == nil then
		-- root directory
		return 3
	end
	local git_roots = get_git_roots(false)
	if git_roots[url] then
		return url
	end
	local sub_url = url:match("^(.*)/[^/]+/?$")
	while sub_url ~= nil and sub_url:find("/", 1, true) do
		if git_roots[sub_url] then
			return sub_url
		end
		sub_url = sub_url:match("^(.*)/[^/]+/?$")
	end

	-- not found in cache, get git root by git command
	local child, code = Command("git"):args({ "rev-parse", "--show-toplevel" }):cwd(url):stdout(Command.PIPED):spawn()
	if not child then
		ya.err("spawn `git` command returns " .. tostring(code))
		ya.err("cwd: " .. url)
		return 2
	end

	local next, event = child:read_line_with { timeout = 300 }
	if event ~= 0 then
		-- not in git repository
		return 3
	end

	local git_root = next:match("^(.*)\n$")
	update_git_roots(git_root, false)
	return git_root
end

function M:fetch(job)
	-- get subdirectory of git repository
	if #job.files == 0 then
		return 3
	end
	local git_roots_curr = {}
	local ls_flag = false
	for _, file in ipairs(job.files) do
		if file.cha.is_dir then
			local sub_url = tostring(file.url)
			local git_roots = get_git_roots(true)
			if git_roots[sub_url] then
				git_roots_curr[sub_url] = true
				goto continue
			end
		end
		::continue::
	end
	if next(git_roots_curr) ~= nil then
		-- current directory is not in git repository
		ls_flag = true
	end

	local any_url = tostring(job.files[1].url)
	local base_url = any_url:match("^(.*/)[^/]*$")

	local git_root
	if not ls_flag then
		git_root = get_git_root(base_url)
		if git_root == 2 then
			return git_root
		elseif git_root == 3 then
			-- not in git repository
			ls_flag = true
		end
	end

	if ls_flag then
		-- not in git repository
		-- check if subdirectory is in git repository
		local children = {}
		for _, file in ipairs(job.files) do
			if file.cha.is_dir then
				local sub_url = tostring(file.url)
				if git_roots_curr[sub_url] then
					goto continue
				end
				local git_roots = get_git_roots(false)
				if git_roots[sub_url] then
					git_roots_curr[sub_url] = true
					goto continue
				end
				-- use ls -d to check if it is a git repository
				local child, code = Command("ls"):args({ "-d", ".git" }):cwd(sub_url):stdout(Command.PIPED):spawn()
				if not child then
					ya.err("spawn `ls` command returns " .. tostring(code))
					ya.err("cwd: " .. sub_url)
					return 2
				end
				children[sub_url] = child
				::continue::
			end
		end
		for sub_url, child in pairs(children) do
			local sub_next, sub_event = child:read_line_with { timeout = 300 }
			if sub_event == 0 then
				-- subdirectory is in git repository
				update_git_roots(sub_url, true)
				git_roots_curr[sub_url] = true
			end
		end

		update_git_roots_curr(git_roots_curr)

		return 3
	end

	local git_status, dir_git_status = get_status(git_root)
	if git_status == nil then
		git_status, dir_git_status = get_git_status(git_root)
		update_status(git_root, git_status, dir_git_status)
	end

	if dir_git_status == nil then
		ya.err("dir_git_status is nil")
		return 2
	end

	local update_track = {}
	for _, file in ipairs(job.files) do
		local url = tostring(file.url)
		if url ~= nil and url:match(".git$") then
			update_track[url] = " "
			goto continue
		end
		if git_status[url] ~= nil then
			-- exact match
			update_track[url] = git_status[url]
			goto continue
		end
		if dir_git_status[url] ~= nil then
			-- check if it is a directory
			update_track[url] = dir_git_status[url]
			goto continue
		end

		-- check if parent dirs have status
		local sub_url = url:match("^(.*)/[^/]+/?$")
		while sub_url ~= nil and sub_url:find(git_root, 1, true) do
			if git_status[sub_url] ~= nil then
				if git_status[sub_url] ~= nil then
					update_track[url] = git_status[sub_url]
				end
				goto continue
			end
			sub_url = sub_url:match("^(.*)/[^/]+/?$")
		end

		update_track[url] = "✓"
		::continue::
	end

	update_tracked(git_root, update_track)

	return 3
end

function M.entry()
	-- re-evaluate git status
	clean_up_all()
	local hovered = get_hovered()
	local base_url = hovered:match("^(.*/)[^/]*$")
	if base_url == nil then
		ya.err("base_url is nil")
		return
	end
	if base_url == "/" then
		ya.mgr_emit("enter", {})
		ya.mgr_emit("leave", {})
		return
	end
	ya.mgr_emit("leave", {})
	ya.mgr_emit("enter", {})
end

return M

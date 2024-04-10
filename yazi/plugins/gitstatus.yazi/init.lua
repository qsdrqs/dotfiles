local M = {}

local debug_table = function(table)
	for k, v in pairs(table) do
		ya.err(k .. " " .. v)
	end
end

local get_hovered = ya.sync(function(st)
	local h = cx.active.current.hovered
	return tostring(h.url)
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
		st.tracked[tostring(url)] = type
	end
	File.gitstatus = function(self, file)
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
	File.gitstatus = function(self, file)
		if st.git_roots_curr[tostring(file.url)] then
			return "󰊢"
		end
		return " "
	end
	ya.render()
end)

local update_status = ya.sync(function(st, git_root, status)
	if not st.status then
		st.status = {}
	end
	st.status[git_root] = status
end)

local get_status = ya.sync(function(st, git_root)
	if st.status and st.status[git_root] then
		return st.status[git_root]
	end
end)

local get_git_status = function(git_root)
	local tracked = {}
	-- check tracked files
	local child, code = Command("git"):args({"status", "--ignored", "--short"}):cwd(git_root):stdout(Command.PIPED):spawn()
	if not child then
		ya.err("spawn `git` command returns " .. tostring(code))
		return {}
	end

	repeat
		local next, event = child:read_line_with { timeout = 300 }
		if event == 3 then
			ya.err("timeout")
			break
		elseif event ~= 0 then
			break
		end

		local trimed_next = next:match("^(.*)\n$")
		-- if match "^!! ", it is ignored file
		local type = nil
		if trimed_next:match("^!! ") then
			type = "·"
			trimed_next = trimed_next:sub(4)
		elseif trimed_next:match("^%?%? ") then
			type = "?"
			trimed_next = trimed_next:sub(4)
		elseif trimed_next:match("^ M") then
			type = "+"
			trimed_next = trimed_next:sub(4)
		elseif trimed_next:match("^A ") then
			type = "*"
			trimed_next = trimed_next:sub(4)
		elseif trimed_next:match("^ %?") then
			-- subdirectory
			-- TODO:
			type = "?"
			trimed_next = trimed_next:sub(4)
		elseif trimed_next:match("^ m") then
			-- subdirectory
			type = "+"
			trimed_next = trimed_next:sub(4)
		else
			ya.err("unknown status: " .. trimed_next)
			return {}
		end
		-- if trimed_next ends with /, it is a directory
		if trimed_next:match("/$") then
			trimed_next = trimed_next:sub(1, -2)
		end
		local url = git_root .. "/" .. trimed_next
		tracked[url] = type
		::continue::
	until not next

	-- add parent dirs
	for url, type in pairs(tracked) do
		local base_url = url:match("^(.*/)[^/]*/*$")
		while base_url:find(git_root, 1, true) do
			if tracked[base_url] == nil then
				local base_url_without_slash = base_url:match("^(.*)/$")
				if type ~= "·" then
					tracked[base_url_without_slash] = type
				end
			end
			base_url = base_url:match("^(.*/)[^/]*/$")
		end
	end

	return tracked
end

local get_git_root = function(url)
	local git_roots = get_git_roots(false)
	for k, _ in pairs(git_roots) do
		if url:find(k, 1, true) then
			return k
		end
	end
	local child, code = Command("git"):args({"rev-parse", "--show-toplevel"}):cwd(url):stdout(Command.PIPED):spawn()
	if not child then
		ya.err("spawn `git` command returns " .. tostring(code))
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

function M:preload()
	-- get subdirectory of git repository
	if #self.files == 0 then
		return 3
	end
	local git_roots_curr = {}
	for _, file in ipairs(self.files) do
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
		update_git_roots_curr(git_roots_curr)
		return 3
	end

	local any_url = tostring(self.files[1].url)
	local base_url = any_url:match("^(.*/)[^/]*$")

	local git_root = get_git_root(base_url)
	if git_root == 2 then
		return git_root
	end

	if git_root == 3 then
		-- not in git repository
		-- check if subdirectory is in git repository
		for _, file in ipairs(self.files) do
			if file.cha.is_dir then
				local sub_url = tostring(file.url)
				local git_roots = get_git_roots(false)
				if git_roots[sub_url] then
					git_roots_curr[sub_url] = true
					goto continue
				end
				-- use ls -d to check if it is a git repository
				local child, code = Command("ls"):args({"-d", ".git"}):cwd(sub_url):stdout(Command.PIPED):spawn()
				if not child then
					ya.err("spawn `ls` command returns " .. tostring(code))
					return 2
				end

				local sub_next, sub_event = child:read_line_with { timeout = 300 }
				if sub_event == 0 then
					-- subdirectory is in git repository
					update_git_roots(sub_url, true)
					git_roots_curr[sub_url] = true
				end
				::continue::
			end
		end

		update_git_roots_curr(git_roots_curr)

		return 3
	end

	local git_status = get_status(git_root)
	if git_status == nil then
		git_status = get_git_status(git_root)
		update_status(git_root, git_status)
	end

	local update_track = {}
	for _, file in ipairs(self.files) do
		local url = tostring(file.url)
		if url:match(".git$") then
			update_track[url] = " "
			goto continue
		end
		if git_status[url] ~= nil then
			-- exact match
			update_track[url] = git_status[url]
			goto continue
		end

		local sub_url = url:match("^(.*)/[^/]+/?$")
		while sub_url:find(git_root, 1, true) do
			if git_status[sub_url] ~= nil then
				if git_status[sub_url] == "·" then
					update_track[url] = "·"
				else
					update_track[url] = "✓"
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

return M

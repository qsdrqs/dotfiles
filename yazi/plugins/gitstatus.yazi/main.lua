--- @sync entry
local M = {}

local CACHE_TTL = 3 -- seconds

local Cache = { ttl = tonumber(os.getenv("YAZI_GITSTATUS_CACHE_TTL")) or CACHE_TTL }
local Scanner = {}

local function refresh_linemode(st)
	Linemode.file_gitstatus = function(self, file)
		local url = tostring(file.url)
		if st.git_roots_curr then
			local state = st.git_roots_curr[url]
			if state == "clean" then
				return "󰊢:clean"
			elseif state == "dirty" then
				return "󰊢:dirty"
			end
		end
		if st.tracked then
			local file_tracked = st.tracked[url]
			if file_tracked ~= nil then
				return file_tracked
			end
		end
		return " "
	end
	ya.render()
end

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
	refresh_linemode(st)
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
		local key = tostring(url)
		st.tracked[key] = type
	end
end)

local update_git_roots_curr = ya.sync(function(st, git_roots_curr)
	st.git_roots_curr = st.git_roots_curr or {}
	for git_root, state in pairs(git_roots_curr) do
		if state == false then
			st.git_roots_curr[git_root] = nil
		else
			if state ~= "clean" and state ~= "dirty" then
				state = "dirty"
			end
			st.git_roots_curr[git_root] = state
		end
	end
	refresh_linemode(st)
end)

local update_status = ya.sync(function(st, git_root, status, dir_status, state, checked_at)
	if not st.status then
		st.status = {}
	end
	st.status[git_root] = {
		status = status,
		dir_status = dir_status,
		state = state,
		checked_at = checked_at or os.time(),
	}
end)

local get_status = ya.sync(function(st, git_root)
	if st.status then
		return st.status[git_root]
	end
end)

function Cache.peek(root)
	return get_status(root)
end

function Cache.is_fresh(entry, now)
	if not entry or entry.state ~= "clean" then
		return false
	end
	local checked_at = entry.checked_at
	if not checked_at then
		return false
	end
	now = now or os.time()
	return (now - checked_at) <= Cache.ttl
end

function Cache.store(root, status, dir_status, state, now)
	update_status(root, status, dir_status, state, now)
	return get_status(root)
end

local PlaceholderView = {}
PlaceholderView.__index = PlaceholderView

function PlaceholderView.new()
	return setmetatable({
		state_map = {},
		pending = {},
	}, PlaceholderView)
end

function PlaceholderView:add(root, state, mark_pending)
	local icon_state = state or "clean"
	self.state_map[root] = icon_state
	if mark_pending then
		self.pending[root] = true
	else
		self.pending[root] = nil
	end
	update_git_roots_curr({ [root] = icon_state })
end

function PlaceholderView:pending_count()
	return next(self.pending) ~= nil
end

function PlaceholderView:update(root, state)
	if not state then
		return
	end
	self.state_map[root] = state
	self.pending[root] = nil
	update_git_roots_curr({ [root] = state })
end

function PlaceholderView:resolve(resolver, skip_root)
	if not next(self.pending) then
		return
	end
	local updates = {}
	for root, _ in pairs(self.pending) do
		if root ~= skip_root then
			local state = resolver(root)
			if state then
				self.state_map[root] = state
				updates[root] = state
			end
		end
		self.pending[root] = nil
	end
	self.pending = {}
	if next(updates) then
		update_git_roots_curr(updates)
	end
end

function Scanner.parse_line(git_status_line)
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

function Scanner.collect(git_root)
	local tracked = {}
	-- check tracked files
	local child, code = Command("git"):arg({ "status", "--ignored", "--short" }):cwd(git_root):stdout(Command.PIPED)
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
		local type, update_git_root = Scanner.parse_line(trimed_next)
		if update_git_root then
			ya.err("update" .. trimed_next)
		end
		trimed_next = trimed_next:sub(4)
		local renamed_from, renamed_to = trimed_next:match("^(.-)%s+%-%>%s+(.+)$")
		if renamed_from and renamed_to then
			trimed_next = renamed_to
		end
		if trimed_next:sub(1, 1) == '"' and trimed_next:sub(-1) == '"' then
			trimed_next = trimed_next:sub(2, -2)
		end
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

function Scanner.compute_state(git_status, dir_git_status)
	local has_changes = false
	for _, v in pairs(git_status) do
		if v ~= "·" and v ~= " " then
			has_changes = true
			break
		end
	end
	if not has_changes then
		for _, _ in pairs(dir_git_status) do
			has_changes = true
			break
		end
	end

	return has_changes and "dirty" or "clean"
end


local repo_state_for = function(git_root)
	local now = os.time()
	local cached = Cache.peek(git_root)
	if Cache.is_fresh(cached, now) then
		return cached.state, cached.status, cached.dir_status
	end

	local git_status, dir_git_status = Scanner.collect(git_root)
	local state = Scanner.compute_state(git_status, dir_git_status)
	Cache.store(git_root, git_status, dir_git_status, state, now)
	return state, git_status, dir_git_status
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
	local child, code = Command("git"):arg({ "rev-parse", "--show-cdup" }):cwd(url):stdout(Command.PIPED):spawn()
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

	local cdup = (next and next:gsub("\r?\n$", "")) or ""
	local git_root = (cdup == "" and url) or (url .. "/" .. cdup):gsub("/+$","")
	update_git_roots(git_root, false)
	return git_root
end

function M:fetch(job)
	-- get subdirectory of git repository
	if #job.files == 0 then
		return 3
	end
	local view = PlaceholderView.new()

	local function register_repo(path)
		local cached = Cache.peek(path)
		local cached_state = cached and cached.state or nil
		view:add(path, cached_state, cached_state == nil)
		return cached_state
	end

	local function resolve_state(path)
		local state = repo_state_for(path)
		return state
	end

	local ls_flag = false
	for _, file in ipairs(job.files) do
		if file.cha.is_dir then
			local sub_url = tostring(file.url)
			local git_roots = get_git_roots(true)
			if git_roots[sub_url] then
				if not view.state_map[sub_url] then
					register_repo(sub_url)
				end
				goto continue
			end
		end
		::continue::
	end
	if next(view.state_map) ~= nil then
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
				if view.state_map[sub_url] then
					goto continue
				end
				local git_roots = get_git_roots(false)
				if git_roots[sub_url] then
					register_repo(sub_url)
					goto continue
				end
				-- use ls -d to check if it is a git repository
				local child, code = Command("ls"):arg({ "-d", ".git" }):cwd(sub_url):stdout(Command.PIPED):spawn()
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
				register_repo(sub_url)
			end
		end

		view:resolve(resolve_state)

		return 3
	end

	local cached_root = Cache.peek(git_root)
	if cached_root and cached_root.state then
		view:add(git_root, cached_root.state, false)
	else
		view:add(git_root, nil, true)
	end

	local state, git_status, dir_git_status = repo_state_for(git_root)
	if state then
		view:update(git_root, state)
	end

	view:resolve(resolve_state, git_root)

	if not git_status or not dir_git_status then
		ya.err("dir_git_status is nil")
		return 2
	end

	local update_track = {}
	for _, file in ipairs(job.files) do
		local url = tostring(file.url)
		if url ~= nil and url:match("/%.git$") then
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

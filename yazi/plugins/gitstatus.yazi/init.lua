local M = {}

local get_hovered = ya.sync(function(st)
	local h = cx.active.current.hovered
	return tostring(h.url)
end)

local update_tracked = ya.sync(function(st, git_root, tracked)
	if not st.tracked then
		st.tracked = {}
	end
	st.tracked[git_root] = tracked
	File.gitstatus = function(self, file)
		local url = tostring(file.url)
		if url:match(".git$") then
			return " "
		end
		if tracked[url] ~= nil then
			return tracked[url]
		end
		local base_url = url:match("^(.*/)[^/]*$")
		-- if git_root is not a prefix of base_url, it is not in the git repository
		if not base_url:find(git_root, 1, true) then
			return ""
		end
		return "✓"
	end
	ya.render()
end)

local get_tracked = ya.sync(function(st, git_root)
	if st.tracked then
		return st.tracked[git_root]
	end
end)

local get_git_status = function(git_root)
	local tracked = {}
	-- check tracked files
	child, code = Command("git"):args({"status", "--ignored", "--short"}):cwd(git_root):stdout(Command.PIPED):spawn()
	if not child then
		ya.err("spawn `git` command returns " .. tostring(code))
		return 2
	end

	repeat
		next, event = child:read_line_with { timeout = 10000 }
		if event == 3 then
			ya.err("timeout")
			break
		elseif event ~= 0 then
			break
		end

		local trimed_next = next:match("^(.*)\n$")
		-- if match "^!! ", it is ignored file
		local type
		if trimed_next:match("^!! ") then
			type = "·"
			trimed_next = trimed_next:sub(4)
		elseif trimed_next:match("^%?%? ") then
			type = "?"
			trimed_next = trimed_next:sub(4)
		elseif trimed_next:match("^ M") then
			type = "+"
			trimed_next = trimed_next:sub(4)
		else
			ya.err("unknown status: " .. trimed_next)
		end
		-- if trimed_next ends with /, it is a directory
		if trimed_next:match("/$") then
			trimed_next = trimed_next:sub(1, -2)
		end
		local url = git_root .. "/" .. trimed_next
		tracked[url] = type
		::continue::
	until not next
end

function M:preload()
	if #self.files == 0 then
		return 3
	end

	local any_url = tostring(self.files[1].url)
	local base_url = any_url:match("^(.*/)[^/]*$")

	local child, code = Command("git"):args({"rev-parse", "--show-toplevel"}):cwd(base_url):stdout(Command.PIPED):spawn()
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

	local tracked = get_tracked(git_root)
	if tracked ~= nil then
		-- already checked
		return 3
	else
		tracked = get_git_status(git_root)
	end

	local update_track = {}
	for _, file in ipairs(self.files) do
		local url = tostring(file.url)
		if url:match(".git$") then
			update_track[url] = " "
			goto continue
		end
		if tracked[url] ~= nil then
			update_track[url] = tracked[url]
		end
		base_url = url:match("^(.*/)[^/]*$")
		-- if git_root is not a prefix of base_url, it is not in the git repository
		if not base_url:find(git_root, 1, true) then
			update_track[url] = ""
			goto continue
		end
		update_track[url] = "✓"
		::continue::
	end

	update_tracked(git_root, update_track)

	return 3
end

return M

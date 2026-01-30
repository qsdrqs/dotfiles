local M = {}

local get_root_files = ya.sync(function(st)
	return st.root_files
end)

local get_cwd = ya.sync(function(_)
	return cx.active.current.cwd
end)

local get_selected_paths = ya.sync(function(_)
	local selected = {}
	local active = cx.active

	if active.selected then
		for _, url in pairs(active.selected) do
			selected[#selected + 1] = tostring(url)
		end
	end

	if #selected == 0 and active.current.hovered then
		selected[1] = tostring(active.current.hovered.url)
	end

	return selected
end)

function M.setup(st, args)
	if args ~= nil and args.root_files ~= nil then
		st.root_files = args.root_files
	else
		st.root_files = { ".git", ".hg", ".svn" }
	end
end

function string:endswith(suffix)
	return self:sub(-#suffix) == suffix
end

local function find_target_root(cwd, root_files)
	local target = nil

	repeat
		local child, code = Command("ls"):arg({ "-la" }):cwd(cwd):stdout(Command.PIPED):spawn()
		if not child then
			ya.err("spawn `ls` command returns " .. tostring(code))
			ya.err("cwd: " .. cwd)
			return
		end
		repeat
			local line, event = child:read_line_with({ timeout = 300 })
			if line and line:endswith("\n") then
				line = line:sub(1, -2)
			end
			if event == 3 then
				ya.err("timeout")
				goto continue
			elseif event ~= 0 then
				break
			end
			for _, file in ipairs(root_files) do
				if string.endswith(line, file) then
					target = cwd
					goto exit_loop
				end
			end
			::continue::
		until not line
	cwd = cwd:match("^(.*)/[^/]+/?$")
	if not cwd or cwd == "" then
		break
	end
	until not cwd or cwd == ""

	::exit_loop::

	return target
end

function M.entry()
	ya.emit("escape", { visual = true })

	local cwd = tostring(get_cwd())
	local root_files = get_root_files()
	local selected_paths = get_selected_paths()

	if #selected_paths == 0 then
		return
	end

	local target_cwd = find_target_root(cwd, root_files)
	local results = {}

	for _, path in ipairs(selected_paths) do
		local relative = path

		if target_cwd and path:sub(1, #target_cwd) == target_cwd then
			relative = path:sub(#target_cwd + 2)
			if relative == "" then
				relative = "."
			end
		end

		results[#results + 1] = relative
	end

	ya.clipboard(table.concat(results, "\n"))
end

return M

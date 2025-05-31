local M = {}

local get_root_files = ya.sync(function(st)
	return st.root_files
end)

local get_cwd = ya.sync(function(_)
	return cx.active.current.cwd
end)

local get_abs_path = ya.sync(function(_)
	return cx.active.current.hovered.url
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

function M.entry()
	local cwd = tostring(get_cwd())
	local root_files = get_root_files()
	local copy_path = tostring(get_abs_path())
	local target_cwd = nil

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
					target_cwd =cwd
					goto exit
				end
			end
			::continue::
		until not line
	cwd = cwd:match("^(.*)/[^/]+/?$")
	if not cwd or cwd == "" then
		break
	end
	until not cwd or cwd == ""

	::exit::
	if target_cwd then
		copy_path = copy_path:sub(#target_cwd + 2)
	end

	ya.clipboard(copy_path)
end

return M

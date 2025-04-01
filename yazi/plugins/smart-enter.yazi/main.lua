--- @sync entry
local function enterable(dir)
	if ya.target_family() == "windows" or ya.target_os() == "android" then
		return true
	end
	if not dir.cha.is_exec then
		print("not exec")
		return false
	end
	local perms = dir.cha:perm()
	local username = ya.user_name(ya.uid())
	local groupname = ya.group_name(ya.gid())
	if username == "root" then
		return true
	end
	if username == nil or groupname == nil then
		return true
	end
	if dir.cha.uid == ya.uid() then
		if perms:sub(4, 4) ~= "x" and perms:sub(4, 4) ~= "t" then
			ya.notify {
				title = "Permission denied",
				content = "The user " .. username .. " does not have execute permission on " .. tostring(dir.url),
				timeout = 2,
				level = "error"
			}
			return false
		end
		return true
	elseif dir.cha.gid == ya.gid() then
		if perms:sub(7, 7) ~= "x" and perms:sub(7, 7) ~= "t" then
			ya.notify {
				title = "Permission denied",
				content = "The group " .. groupname .. " does not have execute permission on " .. tostring(dir.url),
				timeout = 2,
				level = "error"
			}
			return false
		end
		return true
	else
		if perms:sub(10, 10) ~= "x" and perms:sub(10, 10) ~= "t" then
			ya.notify {
				title = "Permission denied",
				content = "The user " .. username .. " and group " .. groupname .. " does not have execute permission on " .. tostring(dir.url),
				timeout = 2,
				level = "error"
			}
			return false
		end
		return true
	end
end

return {
	entry = function()
		local h = cx.active.current.hovered
		if h.cha.is_dir then
			if enterable(h) then
				ya.manager_emit("enter", {})
			end
		else
			ya.manager_emit("open", {})
		end
	end,
}

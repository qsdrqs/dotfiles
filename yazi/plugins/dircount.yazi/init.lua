local M = {}


local update_dircount = ya.sync(function(st, st_dircount)
	if not st.dircount then
		st.dircount = {}
	end
	for k, v in pairs(st_dircount) do
		st.dircount[k] = v
	end
	File.count = function(self, file)
		return st.dircount[tostring(file.url)]
	end
	ya.render()
end)

local get_dircount = ya.sync(function(st)
	return st.dircount
end)

local get_hovered = ya.sync(function(st)
	local h = cx.active.current.hovered
	return tostring(h.url)
end)

function M:preload()
	local dircount = get_dircount() or {}
	local hovered_url = get_hovered()

	for _, file in ipairs(self.files) do
		if file.cha.is_dir then
			local url = tostring(file.url)
			if dircount[url] and hovered_url ~= url then
				goto continue
			end
			local child, code = Command("ls"):args({ "-A" }):args({ url }):stdout(Command.PIPED):spawn()
			if not child then
				ya.err("spawn `ls` command returns " .. tostring(code))
				return 2
			end

			local i, j = 1, 0
			repeat
				local next, event = child:read_line_with { timeout = 300 }
				if event == 3 then
					goto continue
				elseif event ~= 0 then
					break
				end

				j = j + 1
				i = i + 1
				::continue::
			until not next

			dircount[url] = j
		end
		::continue::
	end

	update_dircount(dircount)

	-- for a, b in pairs(dircount) do
	-- 	local res = tostring(a) .. " " .. tostring(b)
	-- 	ya.err(res)
	-- end

	return 3
end

return M

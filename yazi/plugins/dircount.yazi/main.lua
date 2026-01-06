local M = {}


local update_dircount = ya.sync(function(st, st_dircount)
	if not st.dircount_lock then
		st.dircount_lock = {}
	end
	if not st.dircount then
		st.dircount = {}
	end
	for k, v in pairs(st_dircount) do
		st.dircount[k] = v
	end
	Linemode.file_count = function(self, file)
		if file.is_hovered then
			if st.dircount_lock[tostring(file.url)] then
				st.dircount_lock[tostring(file.url)] = false
			else
				ya.mgr_emit("plugin", { "dircount", tostring(file.url)})
			end
		end
		return st.dircount[tostring(file.url)]
	end
	ui.render()
end)

local update_dircount_table = ya.sync(function(st, st_dircount)
	if not st.dircount then
		st.dircount = {}
	end
	if not st.dircount_lock then
		st.dircount_lock = {}
	end
	for k, v in pairs(st_dircount) do
		st.dircount[k] = v
		st.dircount_lock[k] = true
	end
	ui.render()
end)

local get_dircount = ya.sync(function(st)
	return st.dircount
end)

local get_hovered = ya.sync(function(st)
	local h = cx.active.current.hovered
	return tostring(h.url)
end)

function M:fetch(job)
	local dircount = get_dircount() or {}
	local hovered_url = get_hovered()

	local children = {}
	for _, file in ipairs(job.files) do
		if file.cha.is_dir then
			local url = tostring(file.url)
			if dircount[url] and hovered_url ~= url then
				goto continue
			end
			local child, code = Command("ls"):arg({ "-A" }):arg({ url }):stdout(Command.PIPED):spawn()
			if not child then
				ya.err("spawn `ls` command returns " .. tostring(code))
				return 2
			end
			children[url] = child
		end
		::continue::
	end

	for url, child in pairs(children) do
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

	update_dircount(dircount)

	-- for a, b in pairs(dircount) do
	-- 	local res = tostring(a) .. " " .. tostring(b)
	-- 	ya.err(res)
	-- end

	return 3
end

function M.entry(self, job)
	local args = job.args
	local file_url = args[1]
	if not file_url then
		return
	end
	-- update dircount
	local child, code = Command("ls"):arg({ "-A" }):arg({ file_url }):stdout(Command.PIPED):spawn()
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

	local dircount = {
		[tostring(file_url)] = j
	}
	update_dircount_table(dircount)
end

return M

local M = {}

function M:preload()
	local urls = {}
	for _, file in ipairs(self.files) do
    if file.cha.is_dir then
      urls[#urls + 1] = tostring(file.url)
    end
	end

	local args
	if ya.target_family() == "windows" then
		args = { "-l" }
	else
		args = { "-l" }
	end

	local child, code = Command("ls"):args(args):args(urls):stdout(Command.PIPED):spawn()
	if not child then
		ya.err("spawn `ls` command returns " .. tostring(code))
		return 0
	end

	local files, last = {}, ya.time()
	local flush = function(force)
		if not force and ya.time() - last < 0.1 then
			return
		end
		if next(files) then
			ya.manager_emit("update_files", {}, Folder.CURRENT)
			files, last = {}, ya.time()
		end
	end

	local i, j = 1, 0
	repeat
		local next, event = child:read_line_with { timeout = 300 }
		if event == 3 then
			flush(true)
			goto continue
		elseif event ~= 0 then
			break
		end

		j, files[urls[i]] = j + 1, 100
		flush(false)

		i = i + 1
		::continue::
	until i > #urls

	flush(true)
	return j == #urls and 3 or 2
end

return M

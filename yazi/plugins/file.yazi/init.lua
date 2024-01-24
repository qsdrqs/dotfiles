local M = {}

local function executable(file)
	local permission = file.cha:permissions()
	for i = 1, #permission do
		local c = permission:sub(i, i)
		if c == "x" or c == "s" or c == "S" or c == "t" or c == "T" then
			return true
		end
	end
	return false
end

function M:peek()
	local executable = executable(self.file)
	local output, code
	if executable then
		-- use `readelf -WCa`
		output, code = Command("readelf")
				:args({
					"-WCa",
					tostring(self.file.url),
				})
				:stdout(Command.PIPED)
				:output()
	else
		output, code = Command("file")
				:args({
					"-bL",
					tostring(self.file.url),
				})
				:stdout(Command.PIPED)
				:output()
	end

	local p
	if output then
		if executable then
			p = ui.Paragraph.parse(self.area, output.stdout)
		else
			p = ui.Paragraph.parse(self.area, "----- File Type Classification -----\n" .. output.stdout)
		end
	else
		p = ui.Paragraph(self.area, {
			ui.Line {
				ui.Span("Failed to spawn `file` command, error code: " .. tostring(code)),
			},
		})
	end

	ya.preview_widgets(self, { p:wrap(ui.Paragraph.WRAP) })
end

function M:seek() end

return M

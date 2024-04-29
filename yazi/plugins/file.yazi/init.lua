local M = {}

function M:peek()
	local output, code, readelf_succ = nil, nil, false
	if self.file.cha.is_exec then
		-- use `readelf -WCa`
		output, code = Command("readelf")
				:args({
					"-WCa",
					tostring(self.file.url),
				})
				:stdout(Command.PIPED)
				:output()
		if output.stderr == "" then
			readelf_succ = true
		end
	end
	if not readelf_succ then
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
		if readelf_succ then
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

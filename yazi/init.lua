local link_style = { fg = "cyan" }
local gitstatus_dot = { fg = "white" }
local gitstatus_check = { fg = "green" }
local gitstatus_star = { fg = "green" }
local gitstatus_plus = { fg = "red" }
local gitstatus_minus = { fg = "red" }
local gitstatus_git = { fg = "yellow" }
local gitstatus_question = { fg = "cyan" }

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

function Status:name()
	local h = cx.active.current.hovered
	if h == nil then
		return ui.Span("")
	end

	local linked = ""
	if h.link_to ~= nil then
		linked = " -> " .. tostring(h.link_to)
	end

	local spans = { ui.Span(" ") }

	if ya.target_family() == "unix" then
		local uid = h.cha.uid
		local gid = h.cha.gid
		local user = ya.user_name(uid)
		local group = ya.group_name(gid)
		if group == nil then
			group = gid
		end
		if user == nil then
			user = uid
		end
		spans[#spans + 1] = ui.Span(user .. " " .. group .. " "):style(THEME.status.permissions_r)
	end

	if h.cha.modified ~= nil then
		local modified = os.date("%Y-%m-%d %H:%M:%S", math.floor(h.cha.modified))
		spans[#spans + 1] = ui.Span(modified)
	end
	spans[#spans + 1] = ui.Span(linked):style(link_style)

	return ui.Line(spans)
end

function File:style(file)
	local style = file:style()
	local white_style = false
	if style == nil then
		style = ui.Style()
		white_style = true
	end
	if file.cha.is_link then
		style:fg(link_style.fg)
		white_style = false
	end
	if executable(file) then
		if white_style then
			style:fg("green")
		end
		style:bold()
	end
	if not file:is_hovered() then
		return style
	elseif file:in_preview() then
		return style and style:patch(THEME.manager.preview_hovered) or THEME.manager.preview_hovered
	else
		return style and style:patch(THEME.manager.hovered) or THEME.manager.hovered
	end
end

function File:count(file)
	return nil
end

function File:gitstatus(file)
	return " "
end

function Folder:linemode(area, files)
	local mode = cx.active.conf.linemode
	if mode == "none" then
		return {}
	end

	local lines = {}
	for _, f in ipairs(files) do
		local spans = { ui.Span(" ") }
		if mode == "size" then
			if not f.cha.is_dir then
				local size = f:size()
				spans[#spans + 1] = ui.Span(size and ya.readable_size(size) or "")
			else
				local count = File:count(f)
				spans[#spans + 1] = ui.Span(count and tostring(count) or "")
			end
		elseif mode == "mtime" then
			local time = f.cha.modified
			spans[#spans + 1] = ui.Span(time and os.date("%y-%m-%d %H:%M", time // 1) or "")
		elseif mode == "permissions" then
			spans[#spans + 1] = ui.Span(f.cha:permissions() or "")
		end

		spans[#spans + 1] = ui.Span(" ")

		local gitstatus = File:gitstatus(f)
		if gitstatus then
			if f:is_hovered() then
				spans[#spans + 1] = ui.Span(gitstatus)
			elseif gitstatus == '·' then
				spans[#spans + 1] = ui.Span(gitstatus):style(gitstatus_dot)
			elseif gitstatus == '*' then
				spans[#spans + 1] = ui.Span(gitstatus):style(gitstatus_star)
			elseif gitstatus == '+' then
				spans[#spans + 1] = ui.Span(gitstatus):style(gitstatus_plus)
			elseif gitstatus == '!' then
				spans[#spans + 1] = ui.Span(gitstatus):style(gitstatus_plus)
			elseif gitstatus == '-' then
				spans[#spans + 1] = ui.Span(gitstatus):style(gitstatus_minus)
			elseif gitstatus == '?' then
				spans[#spans + 1] = ui.Span(gitstatus):style(gitstatus_question)
			elseif gitstatus == '✓' then
				spans[#spans + 1] = ui.Span(gitstatus):style(gitstatus_check)
			elseif gitstatus == '󰊢' then
				spans[#spans + 1] = ui.Span(gitstatus):style(gitstatus_git)
			else
				spans[#spans + 1] = ui.Span(gitstatus)
			end
		end

		lines[#lines + 1] = ui.Line(spans)
	end
	return ui.Paragraph(area, lines):align(ui.Paragraph.RIGHT)
end

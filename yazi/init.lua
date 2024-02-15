local link_style = { fg = "cyan" }

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

local function get_style(f)
		local hovered = f:is_hovered()
		if f.cha.is_link then
			if executable(f) then
				if hovered then
					return { fg = link_style.fg, modifier = 65 }
				else
					return { fg = link_style.fg, modifier = 1 }
				end
			else
				if hovered then
					return { fg = link_style.fg, modifier = 64 }
				else
					return link_style
				end
			end
		else
			local style = f:style()
			if executable(f) then
				if style == nil then
					style = ui.Style()
					style:fg("green")
				end
				style:bold()
			end
			if f:is_hovered() then
				if style == nil then
					style = ui.Style()
				end
				if style.reverse ~= nil then
					return style:reverse()
				else
					return THEME.manager.hovered
				end
			end
			return style
		end
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

function Current:render(area)
	self.area = area

	local files = Folder:by_kind(Folder.CURRENT).window
	if #files == 0 then
		return {}
	end

	local items, markers = {}, {}
	for i, f in ipairs(files) do
		local name = Folder:highlighted_name(f)

		-- Highlight hovered file
		local item = ui.ListItem(ui.Line { Folder:icon(f), table.unpack(name) })
		item = item:style(get_style(f))
		items[#items + 1] = item

		-- Yanked/marked/selected files
		local marker = Folder:marker(f)
		if marker ~= 0 then
			markers[#markers + 1] = { i, marker }
		end
	end

	return ya.flat {
		ui.List(area, items),
		Folder:linemode(area, files),
		Folder:markers(area, markers),
	}
end

function Parent:render(area)
	self.area = area

	local folder = Folder:by_kind(Folder.PARENT)
	if not folder then
		return {}
	end

	local items, markers = {}, {}
	for i, f in ipairs(folder.window) do
		-- Highlight hovered file
		local item = ui.ListItem(ui.Line { Folder:icon(f), ui.Span(f.name) })
		item = item:style(get_style(f))
		items[#items + 1] = item

		-- Yanked/marked/selected files
		local marker = Folder:marker(f)
		if marker ~= 0 then
			markers[#markers + 1] = { i, marker }
		end
	end

	return ya.flat {
		ui.List(area, items),
		Folder:markers(area, markers),
	}
end

function Preview:render(area)
	self.area = area

	local folder = Folder:by_kind(Folder.PREVIEW)
	if not folder then
		return {}
	end

	local items, markers = {}, {}
	for i, f in ipairs(folder.window) do
		-- Highlight hovered file
		local item = ui.ListItem(ui.Line { Folder:icon(f), ui.Span(f.name) })
		item = item:style(get_style(f))
		items[#items + 1] = item

		-- Yanked/marked/selected files
		local marker = Folder:marker(f)
		if marker ~= 0 then
			markers[#markers + 1] = { i, marker }
		end
	end

	return ya.flat {
		ui.List(area, items),
		Folder:markers(area, markers),
	}
end

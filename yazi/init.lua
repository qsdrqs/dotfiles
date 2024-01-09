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
		spans[#spans + 1] = ui.Span(user .. " " .. group .. " "):style(THEME.status.permissions_r)
		-- return ui.Span(" " .. user .. " " .. group .. " " .. modified .. linked)
	end

	local modified = os.date("%Y-%m-%d %H:%M:%S", math.floor(h.cha.modified))
	spans[#spans + 1] = ui.Span(modified)
	spans[#spans + 1] = ui.Span(linked):style(THEME.manager.cwd)

	return ui.Line(spans)
end

function Current:render(area)
	self.area = area

	local markers = {}
	local items = {}
	for i, f in ipairs(Folder:by_kind(Folder.CURRENT).window) do
		local name = Folder:highlighted_name(f)

		-- Highlight hovered file
		local item = ui.ListItem(ui.Line { Folder:icon(f), table.unpack(name) })
		if f:is_hovered() then
			item = item:style(THEME.manager.hovered)
		else
			if f.cha.is_symlink then
				item = item:style(THEME.manager.cwd)
			else
				item = item:style(f:style())
			end
		end
		items[#items + 1] = item

		-- Mark yanked/selected files
		local yanked = f:is_yanked()
		if yanked ~= 0 then
			markers[#markers + 1] = { i, yanked }
		elseif f:is_selected() then
			markers[#markers + 1] = { i, 3 }
		end
	end
	return ya.flat { ui.List(area, items), Folder:linemode(area), Folder:markers(area, markers) }
end

local debug_table = function(table)
	for k, v in pairs(table) do
		ya.err(tostring(k) .. " " .. tostring(v))
	end
end

local get_selected = ya.sync(function(st)
	local h = cx.active.selected

	local selected = {}
	for k, v in pairs(h) do
		selected[k] = tostring(v)
	end

	return selected
end)

local get_hovered = ya.sync(function(st)
	local h = cx.active.current.hovered
	return tostring(h.url)
end)

local get_name_from_url = function(url)
	local name = url:match("([^/]+)$")
	return name
end

return {
	entry = function(_, args)
		local is_trash = false
		if args[1] == 'trash' then
			is_trash = true
		end
		ya.manager_emit("escape", { visual = true })
		local content = ''

		local selected_url_table = get_selected()
		if #selected_url_table == 0 then
			-- get hovered url
			local hovered_url = get_hovered()
			selected_url_table = { hovered_url }
		end

		local selected_count = #selected_url_table
		local title
		if selected_count == 1 then
			title = "Delete 1 selected file permanently? (Y/n)"
			if is_trash then
				title = "Move 1 selected file to trash? (Y/n)"
			end
		else
			title = "Delete " .. selected_count .. " selected files permanently? (Y/n)"
			if is_trash then
				title = "Move " .. selected_count .. " selected files to trash? (Y/n)"
			end
		end

		content = ''
		for _, url in ipairs(selected_url_table) do
			content = content .. get_name_from_url(url) .. '\n'
		end
		local confirm_title = "Confirm deletion of:"
		if is_trash then
			confirm_title = "Confirm moving to trash:"
		end
		ya.notify {
			title = confirm_title,
			content = content,
			timeout = 2,
			level = "warn"
		}

		local value, event = ya.input {
			title = title,
			position = { "top-center", y = 2, w = 50, h = 3 },
		}

		local failed_title = "Delete failed"
		if is_trash then
			failed_title = "Move to trash failed"
		end
		if event == 0 then
			ya.notify {
				title = failed_title,
				content = "Unkown error",
				timeout = 1.5,
				level = "error"
			}
			ya.manager_emit("escape", { select = true })
			return
		end
		if event == 3 then
			ya.notify {
				title = failed_title,
				content = "Unkown error, event 3",
				timeout = 1.5,
				level = "error"
			}
			ya.manager_emit("escape", { select = true })
			return
		end
		if event == 2 then
			ya.manager_emit("escape", { select = true })
			return
		end

		local confirm = value:lower()
		if confirm == "y" or confirm == "" then
			if is_trash then
				ya.manager_emit("remove", { force = true, })
			else
				ya.manager_emit("remove", { force = true, permanently = true, })
			end

			content = ''
			for _, url in ipairs(selected_url_table) do
				if is_trash then
					content = content .. "Moved to trash: " .. get_name_from_url(url) .. '\n'
				else
					content = content .. "Deleted: " .. get_name_from_url(url) .. '\n'
				end
			end
			local deleted_title = selected_count .. " files deleted"
			if is_trash then
				deleted_title = selected_count .. " files moved to trash"
			end
			ya.notify {
				title = deleted_title,
				content = content,
				timeout = 1,
				-- level = "info",
			}
			ya.manager_emit("escape", { select = true })
		end

	end,
}

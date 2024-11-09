--- @sync entry
local curr_pos_stack = {}
local cursor_pos = 1
local top_pos = 1

return {
	entry = function(self, args)
		-- follow the link or goto ~/Downloads
		if args[1] == 'jump' then
			local h = cx.active.current.hovered
			curr_pos_stack[cursor_pos] = h.url
			cursor_pos = cursor_pos + 1
			top_pos = cursor_pos

			if args[2] == "interactive" then
				ya.manager_emit("cd", {interactive = true})
				return
			end
			if args[2] == "zoxide" or args[2] == "fzf" then
				ya.manager_emit("plugin", {tostring(args[2])})
				return
			end

			-- if the target is a link, follow the link
			-- if the target is a directory, jump to it
			-- if the target is a file, reveal it
			local jump_target
			local reveal = false
			if args[2] == 'follow' then
				if h.link_to then
					jump_target = h.link_to
					if not h.cha.is_dir then
						reveal = true
					end
				else
					jump_target = args[3]
				end
			else
				jump_target = args[2]
			end

			if not reveal then
				ya.manager_emit("cd", {tostring(jump_target)})
			else
				ya.manager_emit("reveal", {tostring(jump_target)})
			end
		elseif args[1] == 'back' then
			local h = cx.active.current.hovered
			curr_pos_stack[cursor_pos] = h.url

			while cursor_pos > 1 and h.url == curr_pos_stack[cursor_pos - 1] do
				cursor_pos = cursor_pos - 1
			end

			if cursor_pos > 1 then
				ya.manager_emit("reveal", {tostring(curr_pos_stack[cursor_pos - 1])})
				cursor_pos = cursor_pos - 1
			end
		elseif args[1] == 'forward' then
			local h = cx.active.current.hovered
			curr_pos_stack[cursor_pos] = h.url

			while cursor_pos < top_pos and h.url == curr_pos_stack[cursor_pos + 1] do
				cursor_pos = cursor_pos + 1
			end

			if cursor_pos < top_pos then
				ya.manager_emit("reveal", {tostring(curr_pos_stack[cursor_pos + 1])})
				cursor_pos = cursor_pos + 1
			end
		end
	end,
}

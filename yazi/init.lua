local link_style = { fg = "cyan" }
local gitstatus_dot = { fg = "white" }
local gitstatus_check = { fg = "green" }
local gitstatus_star = { fg = "green" }
local gitstatus_plus = { fg = "red" }
local gitstatus_minus = { fg = "red" }
local gitstatus_git = { fg = "yellow" }
local gitstatus_question = { fg = "cyan" }
local gitstatus_conflict = { fg = "magenta" }

-- custom status bar
Status:children_remove(3, Status.LEFT) -- remove "name"
Status:children_add(function()
	local h = cx.active.current.hovered
	if not h then
		return ui.Line {}
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

	if h.cha.mtime ~= nil then
		local mtime = os.date("%Y-%m-%d %H:%M:%S", math.floor(h.cha.mtime))
		spans[#spans + 1] = ui.Span(mtime)
	end
	spans[#spans + 1] = ui.Span(linked):style(link_style)

	return ui.Line(spans)
end, 3000, Status.LEFT)

function Entity:style()
	local file = self._file
	local s = file:style()
	local white_style = false
	if s == nil then
		s = ui.Style()
		white_style = true
	end
	if file.cha.is_link then
		s:fg(link_style.fg)
		white_style = false
	end
	if file.cha.is_exec then
		if white_style then
			s:fg("green")
		end
		s:bold()
	end
	if not file:is_hovered() then
		return s
	elseif file:in_preview() then
		return s and s:patch(THEME.manager.preview_hovered) or THEME.manager.preview_hovered
	else
		return s and s:patch(THEME.manager.hovered) or THEME.manager.hovered
	end
end

function Linemode:file_count(file)
	return nil
end

function Linemode:size()
	local f = self._file
	if not f.cha.is_dir then
		local size = f:size()
		return ui.Line(size and ya.readable_size(size) or "")
	else
		local count = Linemode:file_count(f)
		return ui.Line(count and tostring(count) or "")
	end
end

function Linemode:file_gitstatus(file)
	return " "
end

function Linemode:gitstatus()
	local f = self._file
	local gitstatus = Linemode:file_gitstatus(f)

	local status_color_tbl = {
		['·'] = gitstatus_dot,
		['*'] = gitstatus_star,
		['+'] = gitstatus_plus,
		['!'] = gitstatus_plus,
		['-'] = gitstatus_minus,
		['?'] = gitstatus_question,
		['✓'] = gitstatus_check,
		['X'] = gitstatus_conflict,
		['󰊢'] = gitstatus_git,
	}
	if gitstatus then
		if f:is_hovered() then
			return ui.Line(gitstatus)
		elseif status_color_tbl[gitstatus] then
			return ui.Line(gitstatus):style(status_color_tbl[gitstatus])
		else
			return ui.Line(gitstatus)
		end
	end
end

Linemode:children_add(Linemode.gitstatus, 2000)

require("session"):setup {
	sync_yanked = true,
}

local ok, starship = pcall(require, "starship")
if ok then
	require("starship"):setup {
		config_file = "~/.config/starship-yazi.toml"
	}
end

require("copy-relative-path"):setup {
	root_files = {".git", ".root"}
}

local ok, mime_ext = pcall(require, "mime-ext")
if ok then
	mime_ext:setup {
		with_exts = {
			tex = "text/x-tex",
		},
		fallback_file1 = true,
	}
end

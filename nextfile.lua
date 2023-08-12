local utils = require("mp.utils")
local msg = require("mp.msg")
local settings = {

-- stylua: ignore
	filetypes = {
		"jpg", "jpeg", "png", "tif", "tiff", "gif", "webp", "svg", "bmp",
		"mp3", "wav", "ogm", "flac", "m4a", "wma", "ogg", "opus",
		"mkv", "avi", "mp4", "ogv", "webm", "rmvb", "flv", "wmv", "mpeg", "mpg", "m4v", "3gp",
	},

	--at end of directory jump to start and vice versa
	allow_looping = true,

	--load next file automatically default value
	--recommended to keep as false and cycle with toggle or set with a script message
	--KEY script-message loadnextautomatically [true|false]
	--KEY script-binding toggleauto
	load_next_automatically = true,

	accepted_eof_reasons = {
		["eof"] = true, --The file has ended. This can (but doesn't have to) include incomplete files or broken network connections under circumstances.
		["stop"] = true, --Playback was ended by a command.
		["quit"] = false, --Playback was ended by sending the quit command.
		["error"] = true, --An error happened. In this case, an error field is present with the error string.
		["redirect"] = true, --Happens with playlists and similar. Details see MPV_END_FILE_REASON_REDIRECT in the C API.
		["unknown"] = true, --Unknown. Normally doesn't happen, unless the Lua API is out of sync with the C API.
	},
}

local filetype_lookup = {}
for _, ext in ipairs(settings.filetypes) do
	filetype_lookup[ext] = true
end

local lock = true --to avoid infinite loops
function on_loaded()
	if mp.get_property("filename"):match("^%a%a+:%/%/") then
		return
	end
	pwd = mp.get_property("working-directory")
	relpath = mp.get_property("path")
	path = utils.join_path(pwd, relpath)
	filename = mp.get_property("filename")
	dir = utils.split_path(path)
	lock = true
	mp.set_property_native("pause", false)
end

function on_close(reason)
	local pl_count = mp.get_property_number("playlist-count", 1)
	local pl_pos = mp.get_property_number("playlist-current-pos", 1)
	if pl_count > pl_pos and pl_pos ~= -1 then
		return
	elseif settings.accepted_eof_reasons[reason.reason] and settings.load_next_automatically and lock then
		msg.info("Loading next file in directory")
		mp.command("playlist-clear")
		nexthandler()
	end
end

function toggleauto()
	if not settings.load_next_automatically then
		settings.load_next_automatically = true
		if mp.get_property_number("playlist-count", 0) > 1 then
			mp.osd_message("Playlist will be purged when loading new file")
		else
			mp.osd_message("Loading next when file ends")
		end
	else
		settings.load_next_automatically = false
		mp.osd_message("Not loading next when file ends")
	end
end

function show_osd_message(file)
	mp.osd_message("Now playing: " .. file, 3) -- Adjust OSD display time as needed
end

function nexthandler()
	movetofile(true)
end

function prevhandler()
	movetofile(false)
end

function file_filter(filenames)
	local files = {}
	for i = 1, #filenames do
		local file = filenames[i]
		local ext = file:match("%.([^%.]+)$")
		if ext and filetype_lookup[ext:lower()] then
			table.insert(files, file)
		end
	end
	return files
end

function alphanumsort(a, b)
	local function padnum(d)
		local dec, n = string.match(d, "(%.?)0*(.+)")
		return #dec > 0 and ("%.12f"):format(d) or ("%s%03d%s"):format(dec, #n, n)
	end
	return tostring(a):lower():gsub("%.?%d+", padnum) .. ("%3d"):format(#b)
		< tostring(b):lower():gsub("%.?%d+", padnum) .. ("%3d"):format(#a)
end

function movetofile(forward)
	lock = false
	if not pwd or not relpath then
		return
	end

	local files = file_filter(utils.readdir(dir, "files"))
	table.sort(files, alphanumsort)

	local found = false
	local memory = nil
	local lastfile = true
	local firstfile = nil
	for _, file in ipairs(files) do
		if found == true then
			mp.commandv("loadfile", utils.join_path(dir, file), "replace")
			lastfile = false
			show_osd_message(file)
			break
		end
		if file == filename then
			found = true
			if not forward then
				lastfile = false
				if settings.allow_looping and firstfile == nil then
					found = false
				else
					if firstfile == nil then
						break
					end
					mp.commandv("loadfile", utils.join_path(dir, memory), "replace")
					show_osd_message(memory)
					break
				end
			end
		end
		memory = file
		if firstfile == nil then
			firstfile = file
		end
	end
	if lastfile and firstfile and settings.allow_looping then
		mp.commandv("loadfile", utils.join_path(dir, firstfile), "replace")
		show_osd_message(firstfile)
	end
	if not found and memory then
		mp.commandv("loadfile", utils.join_path(dir, memory), "replace")
		show_osd_message(memory)
	end
end

--read settings from a script message
function loadnext(msg, value)
	if msg == "next" then
		nexthandler()
		return
	end
	if msg == "previous" then
		prevhandler()
		return
	end
	if msg == "auto" then
		if value == "toggle" then
			toggleauto()
			return
		end
		toggleauto(value:lower() == "true")
	end
end

mp.register_script_message("nextfile", loadnext)
mp.add_key_binding("SHIFT+PGDWN", "nextfile", nexthandler)
mp.add_key_binding("SHIFT+PGUP", "previousfile", prevhandler)
mp.add_key_binding("CTRL+n", "autonextfiletoggle", toggleauto)
mp.register_event("file-loaded", on_loaded)
mp.register_event("end-file", on_close)

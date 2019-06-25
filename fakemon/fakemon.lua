local defsave = require "defsave.defsave"
local zzlib = require "utils.zzlib"
local flow = require "utils.flow"
local ufile = require "utils.file"
local settings = require "pokedex.settings"
local md5 = require "utils.md5"
local M = {}

local downloading = false
local unpacking = false

-- Supported files
M.abilities = nil
M.evolve = nil
M.exp_grid = nil
M.feats = nil
M.habitat = nil
M.items = nil
M.leveling = nil
M.move_machines = nil
M.moves = nil
M.pokedex_extra = nil
M.pokemon_number = nil
M.pokemon_order = nil
M.pokemon_types = nil
M.pokemon = nil
M.trainer_classes_list = nil
M.trainer_classes = nil

local extra_json_files = {
	abilities = "abilities.json",
	evolve = "evolve.json",
	exp_grid = "exp_grid.json",
	feats = "feats.json",
	habitat = "habitat.json",
	items = "items.json",
	leveling = "leveling.json",
	move_machines = "move_machines.json",
	moves = "moves.json",
	pokedex_extra = "pokedex_extra.json",
	pokemon_number = "pokemon_number.json",
	pokemon_order = "pokemon_order.json",
	pokemon_types = "pokemon_types.json",
	pokemon = "pokemon.json",
	trainer_classes_list = "trainer_classes_list.json",
	trainer_classes = "trainer_classes.json"
}


M.PACKAGE_NAME = nil
M.APP_ROOT = nil
local os_sep = package.config:sub(1, 1)
local resource_path

local function get_checksum(res)
	local m = md5.new()
	m:update(tostring(res))
	return md5.tohex(m:finish())
end

function M.download(url)
	downloading = true
	http.request(url, "GET", function(self, id, res)
		if res.status == 302 then
			local url = string.gsub(res.response, '<html><body>You are being <a href="', "")
			url = string.gsub(url, '">redirected</a>.</body></html>', "")
			M.download(url)
		elseif res.status ~= 200 and res.status ~= 304 then
			return
		else
			local sum = get_checksum(res.response)
			if sum == settings.get("fakemon_md5") and defsave.file_exists(resource_path) then
				print("using downloaded")
				downloading = false
				return
			end
			settings.set("fakemon_md5", sum)

			local file, err = io.open(resource_path, "wb")

			if file then
				file:write(res.response)
				file:close()
				downloading = false
				for repo, branch in string.gmatch(url, "https://codeload.github.com/%w+/(.+)/zip/(.+)") do
					M.PACKAGE_NAME = repo .. "-" .. branch
				end
			else
				local e = "Error while opening file\n" .. err
				print(e)
			end
		end
	end)
end

function M.unpack()
	print("Unpacking started", resource_path)
	
	local file = io.open(resource_path, "rb")
	local input = file:read("*all")
	local output, err = zzlib.unzip_archive(input, M.APP_ROOT)
	print("Unpacking done")
end

local function file_exists(name)
	local f = io.open(name, "r")
	return f ~= nil and io.close(f)
end

function M.is_ready()
	return not downloading and not unpacking
end

function M.load(url)
	M.APP_ROOT = defsave.get_file_path("")
	resource_path = defsave.get_file_path("resource.zip")
	flow.start(function()
		print("DOWNLOAD START")
		M.download(url)
		flow.until_true(function() return not downloading end)
		unpacking = true
		print("DOWNLOAD DONE", M.PACKAGE_NAME)
		if M.PACKAGE_NAME then
			M.unpack()
			for n, file_name in pairs(extra_json_files) do
				local pa = M.APP_ROOT .. M.PACKAGE_NAME .. os_sep .. file_name
				if file_exists(pa) then
					print("File loaded to memory: " .. file_name)
					M[n] = ufile.load_file(pa)
				end
			end
		end
		unpacking = false
	end)
end


return M
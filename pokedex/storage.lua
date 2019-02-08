local defsave = require "defsave.defsave"
local json = require "defsave.json"
local md5 = require "utils.md5"
local utils = require "utils.utils"
local profiles = require "pokedex.profiles"

local M = {}

local storage = {}
local active = {}
local counters = {}

local initialized = false

local function get_id(pokemon)
	local m = md5.new()
	m:update(json.encode(pokemon))
	return md5.tohex(m:finish())
end

local function getKeysSortedByValue(tbl, sortFunction)
	local keys = {}
	for key in pairs(tbl) do
		table.insert(keys, key)
	end

	table.sort(keys, function(a, b)
		return sortFunction(tbl[a], tbl[b])
	end)

	return keys
end

local function party_is_full()
	local counter = 0
	for _, _ in pairs(active) do
		counter = counter + 1
	end
	return counter >= 6
end

function M.list_of_ids_in_storage()
	return getKeysSortedByValue(storage, function(a, b) return a.species.current < b.species.current end)
end

function M.list_of_ids_in_inventory()
	return getKeysSortedByValue(active, function(a, b) return a.species.current < b.species.current end)
end

function M.get_copy(id)
	return utils.deep_copy(storage[id] and storage[id] or active[id])
end

local function get(id)
	return storage[id] and storage[id] or active[id]
end

function M.update_pokemon(pokemon)
	local id = pokemon.id
	if storage[id] then
		storage[id] = pokemon
	elseif active[id] then
		active[id] = pokemon
	end
	M.save()
end

function M.set_pokemon_move_pp(id, move, pp)
	local p = get(id)
	p.moves[move] = pp
	M.save()
	return p.moves[move]
end

function M.set_pokemon_current_hp(id, hp)
	local p = get(id)
	p.hp.current = hp
	M.save()
end

function M.set_pokemon_max_hp(id, hp)
	local p = get(id)
	p.hp.max = hp
	p.hp.edited = true
	M.save()
end

function M.release_pokemon(id)
	storage[id] = nil
	active[id] = nil
	counters.released = next(counters) ~= nil and counters.released + 1 or 1
	profiles.update(profiles.get_active_slot(), counters)
	M.save()
end

function M.add(pokemon)
	for i=#pokemon.moves, 1, -1 do
		if pokemon.moves[i] == "" or pokemon.moves[i] == "None" then
			table.remove(pokemon.moves, i)
		end
	end
	counters.caught = next(counters) ~= nil and counters.caught + 1 or 1
	pokemon.number = counters.caught
	local id = get_id(pokemon)
	pokemon.id = id
	profiles.update(profiles.get_active_slot(), counters)
	if party_is_full() then
		storage[id] = pokemon
	else
		active[id] = pokemon
	end
	M.save()
	profiles.save()
end

function M.save()
	if profiles.get_active_slot() then
		local profile = profiles.get_active_file_name()
		defsave.set(profile, "storage", storage)
		defsave.set(profile, "active", active)
		defsave.set(profile, "counters", counters)
		defsave.save(profile)
	end
end

function M.load(profile)
	local file_name = profile.file_name
	if not defsave.is_loaded(file_name) then
		local loaded = defsave.load(file_name)
	end
	storage = defsave.get(file_name, "storage")
	active = defsave.get(file_name, "active")
	counters = defsave.get(file_name, "counters")
	-- Default counters
	if next(counters) == nil then
		counters = {caught=0, released=0, seen=0}
	end
end

function M.init()
	if not initialized then
		M.load(profiles.get_active())
		initialized = true
	end
end

function M.move_to_storage(id)
	local pokemon = utils.deep_copy(active[id])
	storage[id] = pokemon
	active[id] = nil
	M.save()
end

function M.move_to_inventory(id)
	local index = 0
	for _, _ in pairs(active) do
		index = index + 1
	end
	assert(index < 6, "Your party is full")
	local pokemon = utils.deep_copy(storage[id])
	active[id] = pokemon
	storage[id] = nil
	M.save()
end

return M
local utils = require "utils.utils"
local pokedex = require "pokedex.pokedex"
local natures = require "pokedex.natures"
local storage = require "pokedex.storage"
local movedex = require "pokedex.moves"
local items = require "pokedex.items"
local trainer = require "pokedex.trainer"

local M = {}

local feat_to_skill = {
	Brawny="Athletics",
	Perceptive="Perception",
	Acrobat= "Acrobatics",
	["Quick-Fingered"]="Sleight of Hand",
	Stealthy="Stealth"
}
local resilient = {
	["Resilient (STR)"]= "STR",
	["Resilient (CON)"]= "CON",
	["Resilient (DEX)"]= "DEX",
	["Resilient (INT)"]= "INT",
	["Resilient (WIS)"]= "WIS",
	["Resilient (CHA)"]= "CHA",
}
local feat_to_attribute = {
	["Resilient (STR)"]= "STR",
	["Resilient (CON)"]= "CON",
	["Resilient (DEX)"]= "DEX",
	["Resilient (INT)"]= "INT",
	["Resilient (WIS)"]= "WIS",
	["Resilient (CHA)"]= "CHA",
	["Athlete (STR)"]= "STR",
	["Athlete (DEX)"]="DEX",
	["Quick-Fingered"]= "DEX",
	Stealthy="DEX",
	Brawny="STR",
	Perceptive="WIS",
	Acrobat="DEX"
}

M.GENDERLESS = pokedex.GENDERLESS
M.MALE = pokedex.MALE
M.FEMALE = pokedex.FEMALE

local loyalty_hp = {
	[-3] = {HP=0},
	[-2] = {HP=0},
	[-1] = {HP=0},
	[0] = {HP=0},
	[1] = {HP=0},
	[2] = {HP=5},
	[3] = {HP=10}
}

local function add_tables(T1, T2)
	local copy = utils.shallow_copy(T1)
	for k,v in pairs(T2) do
		if copy[k] then
			copy[k] = copy[k] + v
		end
	end
	return copy
end

function M.get_senses(pkmn)
	return pokedex.get_senses(M.get_current_species(pkmn))
end

local function get_attributes_from_feats(pkmn)
	local m = {STR=0, DEX=0, CON=0, INT=0, WIS=0, CHA=0}
	for _, feat in pairs(M.get_feats(pkmn)) do
		local attr = feat_to_attribute[feat]
		if attr then
			m[attr] = m[attr] + 1
		end
	end
	return m
end

--[[
A Bulbasaur when gaining ASI would get 2 points. If the Bulbasaur eats an Eviolite he gets 4 instead.
A Ivysaur when gaining ASI would get 2 points. If the Ivysaur eats an Eviolite he gets 3 instead.
A Venusaur when gaining ASI would get 2 points. Eating Eviolite have no effect
A Rattata when gaining ASI would get 3 points. If the Rattata eats an Eviolite he gets 4 points.
A RAticate when gaining ASI would get 3 points. Eating Eviolite have no effect
A Kangaskhan when gaining ASI would get 4 points.  Eating Eviolite have no effect--]]
local function ASI_points(pkmn)
	local species = M.get_current_species(pkmn)
	local total = pokedex.get_total_evolution_stages(species)
	local current = pokedex.get_current_evolution_stage(species)
	if M.get_consumed_eviolite(pkmn) then
		return 5 - current
	else
		return 5 - total
	end
end

function M.get_available_ASI(pkmn)
	local available_at_level = pokedex.level_data(M.get_current_level(pkmn)).ASI
	local available_at_caught = pokedex.level_data(M.get_caught_level(pkmn)).ASI
	local ASI_gained = M.get_ASI_point_increase(pkmn)
	return (available_at_level-available_at_caught) * ASI_gained - M.ability_score_points(pkmn) + trainer.get_asi()
end


function M.genderized(pkmn)
	local species = M.get_current_species(pkmn)
	return pokedex.genderized(species)
end

function M.get_gender(pkmn)
	return pkmn.gender
end

function M.set_gender(pkmn, gender)
	pkmn.gender = gender
end

function M.get_ASI_point_increase(pkmn)
	return ASI_points(pkmn)
end

function M.get_attributes(pkmn)
	local base = pokedex.get_base_attributes(M.get_caught_species(pkmn))
	local increased = M.get_increased_attributes(pkmn) or {}
	local added = M.get_added_attributes(pkmn) or {}
	local natures = natures.get_nature_attributes(M.get_nature(pkmn)) or {}
	local feats = get_attributes_from_feats(pkmn)
	local trainer_attributes = trainer.get_attributes()
	return add_tables(add_tables(add_tables(add_tables(add_tables(base, added), natures), increased), feats), trainer_attributes)
end

function M.get_max_attributes(pkmn)
	local m = {STR= 20,DEX= 20,CON= 20,INT= 20,WIS= 20,CHA= 20}
	local n = natures.get_nature_attributes(M.get_nature(pkmn)) or {}

	local t = add_tables(m, n)
	return t
end

function M.get_increased_attributes(pkmn)
	return pkmn.attributes.increased
end

function M.get_experience_for_level(pkmn)
	return pokedex.get_experience_for_level(M.get_current_level(pkmn))
end

function M.set_loyalty(pkmn, loyalty)
	local c =  math.min(math.max(loyalty, -3), 3)
	pkmn.loyalty = c
end

function M.get_held_item(pkmn)
	return pkmn.item
end

function M.set_held_item(pkmn, item)
	pkmn.item = item
end

function M.remove_feat(pkmn, feat)
	for i, name in pairs(M.get_feats(pkmn)) do
		if name == feat then
			if name == "Extra Move" then
				M.remove_move(pkmn, M.get_moves_count(pkmn))
				table.remove(pkmn.feats, i)
				break
			end
			table.remove(pkmn.feats, i)
		end
	end
end

function M.set_consumed_eviolite(pkmn, value)
	pkmn.eviolite = value == true and true or nil
end

function M.get_consumed_eviolite(pkmn, value)
	return pkmn.eviolite or false
end

function M.remove_move(pkmn, index)
	for move, data in pairs(M.get_moves(pkmn)) do
		if index == data.index then
			pkmn.moves[move] = nil
			break
		end
	end
end

function M.reset_abilities(pkmn)
	for i, name in pairs(M.get_abilities(pkmn)) do
		table.remove(pkmn.abilities, i)
	end
	for i, name in pairs(pokedex.get_abilities(M.get_current_species(pkmn))) do
		table.insert(pkmn.abilities, name)
	end
end

function M.remove_ability(pkmn, ability)
	for i, name in pairs(M.get_abilities(pkmn)) do
		if name == ability then
			table.remove(pkmn.abilities, i)
		end
	end
end

function M.get_moves_count(pkmn)
	local c = 0
	for move, data in pairs(M.get_moves(pkmn)) do
		c = c + 1
	end
	return c
end

function M.set_nature(pkmn, nature)
	pkmn.nature = nature
	pkmn.attributes.nature = natures.get_nature_attributes(nature)
end

function M.get_loyalty(pkmn)
	return pkmn.loyalty or 0
end

function M.have_ability(pkmn, ability)
	local count = 0
	for _, f in pairs(M.get_abilities(pkmn)) do
		if f == ability then
			return true
		end
	end
	return false
end

function M.have_feat(pkmn, feat)
	local count = 0
	for _, f in pairs(M.get_feats(pkmn)) do
		if f == feat then
			count = count + 1
		end
	end
	return count > 0, count
end

function M.get_exp(pkmn)
	return pkmn.exp or 0
end

function M.set_exp(pkmn, exp)
	pkmn.exp = exp
end

function M.update_increased_attributes(pkmn, increased)
	local b = M.get_increased_attributes(pkmn)
	local n = add_tables(increased, b)
	pkmn.attributes.increased = n
end

function M.ability_score_points(pkmn)
	local amount = 0
	for _, n in pairs(M.get_increased_attributes(pkmn)) do
		amount = amount + n
	end
	amount = amount + #M.get_feats(pkmn) * 2
	amount = amount - M.get_evolution_points(pkmn)
	
	return amount
end

function M.get_added_attributes(pkmn)
	return {
		STR=pkmn.attributes["STR"] or 0,
		DEX=pkmn.attributes["DEX"] or 0,
		CON=pkmn.attributes["CON"] or 0,
		INT=pkmn.attributes["INT"] or 0,
		WIS=pkmn.attributes["WIS"] or 0,
		CHA=pkmn.attributes["CHA"] or 0
	}

end

function M.set_shiny(pkmn, value)
	pkmn.shiny = value == true and true or nil
end

function M.is_shiny(pkmn)
	return pkmn.shiny
end

function M.set_attribute(pkmn, attribute, value)
	pkmn.attributes[attribute] = value
end

function M.set_increased_attribute(pkmn, attribute, value)
	pkmn.attributes.increased[attribute] = value
end

function M.get_speed_of_type(pkmn)
	local species = M.get_current_species(pkmn)
	local type = pokedex.get_type(species)[1]
	local mobile_feet = 0
	if M.have_feat(pkmn, "Mobile") then
		mobile_feet = 10
	end
	if type == "Flying" then
		local speed = pokedex.get_flying_speed(species) 
		return speed ~= 0 and speed+mobile_feet or speed, "Flying"
	elseif type == "Water" then
		local speed = pokedex.get_swimming_speed(species) 
		return speed ~= 0 and speed+mobile_feet or speed, "Swimming"
	else
		local speed = pokedex.get_walking_speed(species) 
		return speed ~= 0 and speed+mobile_feet or speed, "Walking"
	end
end

function M.get_status_effects(pkmn)
	return pkmn.statuses or {}
end

function M.set_status_effect(pkmn, effect, enabled)
	if pkmn.statuses == nil then
		pkmn.statuses = {}
	end
	if enabled == false then
		enabled = nil
	end
	pkmn.statuses[effect] = enabled
end

function M.get_all_speed(pkmn)
	local species = M.get_current_species(pkmn)
	local mobile_feet = 0
	if M.have_feat(pkmn, "Mobile") then
		mobile_feet = 10
	end
	local w = pokedex.get_walking_speed(species)
	local s = pokedex.get_swimming_speed(species)
	local c = pokedex.get_climbing_speed(species)
	local f = pokedex.get_flying_speed(species)
	local b = pokedex.get_burrow_speed(species)
	return {
		Walking= w ~= 0 and w+mobile_feet or w,
		Swimming=s ~= 0 and s+mobile_feet or s, 
		Flying= f ~= 0 and f+mobile_feet or f,
		Climbing=c ~= 0 and c+mobile_feet or c,
		Burrow=b ~= 0 and b+mobile_feet or b
	}
end

function M.set_current_hp(pkmn, hp)
	pkmn.hp.current = hp
end

function M.get_current_hp(pkmn)
	return pkmn.hp.current
end

function M.set_temp_hp(pkmn, temp_hp)
	pkmn.hp.temp = math.max(0, temp_hp)
end

function M.get_temp_hp(pkmn)
	return pkmn.hp.temp or 0
end

function M.set_max_hp(pkmn, hp)
	pkmn.hp.max = hp
end

function M.set_max_hp_forced(pkmn, forced)
	pkmn.hp.edited = forced
end

function M.get_max_hp_forced(pkmn)
	return pkmn.hp.edited
end


function M.get_max_hp(pkmn)
	return pkmn.hp.max
end

function M.get_defaut_max_hp(pkmn)
	if M.have_ability(pkmn, "Paper Thin") then
		return 1
	end
	local current = M.get_current_species(pkmn)
	local caught = M.get_caught_species(pkmn)
	local at_level = M.get_current_level(pkmn)
	
	if current ~= caught then
		local evolutions = utils.shallow_copy(M.get_evolution_level(pkmn))
		local evolution_hp = 0

		while next(evolutions) ~= nil do
			local from_pkmn = pokedex.get_evolved_from(current)
			at_level = table.remove(evolutions)
			local _, from_level = next(evolutions)
			from_level = from_level or M.get_caught_level(pkmn)
			local hit_dice = pokedex.get_hit_dice(from_pkmn)
			local hit_dice_current = pokedex.get_hit_dice(current)
			local levels_gained = at_level - from_level
			local hp_hit_dice = math.ceil((hit_dice + 1) / 2) * levels_gained
			local hp_evo = at_level * 2
			-- Offset of current hit dice and the new one
			local hp_offset = math.ceil((hit_dice_current + 1) / 2) - math.ceil((hit_dice + 1) / 2)
			evolution_hp = evolution_hp + hp_hit_dice + hp_evo + hp_offset
			current = from_pkmn
		end

		evolutions = M.get_evolution_level(pkmn)
		local hit_dice = pokedex.get_hit_dice(M.get_current_species(pkmn))
		local hit_dice_avg = math.ceil((hit_dice + 1) / 2)
		return pokedex.get_base_hp(caught) + evolution_hp + ((M.get_current_level(pkmn) - evolutions[#evolutions]) * hit_dice_avg)
	else
		local base = pokedex.get_base_hp(current)
		local from_level = M.get_caught_level(pkmn)
		local hit_dice = pokedex.get_hit_dice(current)
		local levels_gained = at_level - from_level
		local hp_hit_dice = math.ceil((hit_dice + 1) / 2) * levels_gained
		return base + hp_hit_dice
	end
end


function M.get_evolution_points(pkmn)
	local current = M.get_current_species(pkmn)
	local caught = M.get_caught_species(pkmn)
	local evolution_points = 0
	
	if current ~= caught then
		local evolutions = utils.deep_copy(M.get_evolution_level(pkmn))

		while next(evolutions) ~= nil do
			table.remove(evolutions)
			current = pokedex.get_evolved_from(current)
			evolution_points = evolution_points + pokedex.evolve_points(current)
		end
	end
	return evolution_points
end

function M.get_total_max_hp(pkmn)
	if M.have_ability(pkmn, "Paper Thin") then
		return 1
	end
	
	local tough_feat = 0
	if M.have_feat(pkmn, "Tough") then
		tough_feat = M.get_current_level(pkmn) * 2
	end
	
	local con = M.get_attributes(pkmn).CON
	local con_mod = math.floor((con - 10) / 2)

	return M.get_max_hp(pkmn) + tough_feat + loyalty_hp[M.get_loyalty(pkmn)].HP + M.get_current_level(pkmn) * con_mod
end

function M.get_current_species(pkmn)
	return pkmn.species.current
end

local function set_species(pkmn, species)
	pkmn.species.current = species
end

function M.get_caught_species(pkmn)
	return pkmn.species.caught
end

function M.get_current_level(pkmn)
	return pkmn.level.current
end

function M.get_caught_level(pkmn)
	return pkmn.level.caught
end

function M.set_move(pkmn, new_move, index)
	local pp = movedex.get_move_pp(new_move)
	for name, move in pairs(M.get_moves(pkmn)) do
		if move.index == index then
			pkmn.moves[name] = nil
			pkmn.moves[new_move] = {pp=pp, index=index}
			return
		end
	end
	pkmn.moves[new_move] = {pp=pp, index=index}
end

function M.get_moves(pkmn, options)
	local append_known_to_all = false
	if options ~= nil then
		append_known_to_all = options.append_known_to_all == true
	end

	if append_known_to_all then
		local ret = {}
		local count = 1
		for k,v in pairs(pkmn.moves) do
			if not movedex.is_move_known_to_all(k) then -- pkmn has this move in its move set, but ALL pkmn know this move. We'll ignore this move for now, and tack it on later so it shows up at the end.
				ret[k] = v
				count = count + 1
			end
		end
		for k,v in pairs(movedex.get_known_to_all_moves()) do
			ret[k] = {pp=movedex.get_move_pp(k), index=count}
			count = count + 1
		end
		return ret
	else
		return pkmn.moves
	end
end

function M.get_nature(pkmn)
	return pkmn.nature
end

function M.get_id(pkmn)
	return pkmn.id
end

function M.get_type(pkmn)
	return pokedex.get_type(M.get_current_species(pkmn))
end

function M.get_STAB_bonus(pkmn)
	return pokedex.level_data(M.get_current_level(pkmn)).STAB
end

function M.get_proficency_bonus(pkmn)
	return pokedex.level_data(M.get_current_level(pkmn)).prof
end

function M.update_abilities(pkmn, abilities)
	pkmn.abilities = abilities
end

function M.update_feats(pkmn, feats)
	pkmn.feats = feats
end

function M.get_feats(pkmn)
	return pkmn.feats or {}
end


function M.add_feat(pkmn, feat)
	table.insert(pkmn.feats, feat)
end

function M.add_ability(pkmn, ability)
	table.insert(pkmn.abilities, ability)
end

function M.get_abilities(pkmn, as_raw)
	local species = M.get_current_species(pkmn)
	local t = {}
	t = pkmn.abilities or pokedex.get_abilities(species) or {}
	if not as_raw and M.have_feat(pkmn, "Hidden Ability") then
		local hidden = pokedex.get_hidden_ability(species)
		local added = false
		for _, h in pairs(t) do
			if h == hidden then
				added = true
			end
		end
		if not added then
			table.insert(t, hidden)
		end
	end
	return t
end

function M.get_skills(pkmn)
	local skills = pokedex.get_skills(M.get_current_species(pkmn)) or {}
	for feat, skill in pairs(feat_to_skill) do
		local added = false
		if M.have_feat(pkmn, feat) then
			for i=#skills, -1, -1 do
				if skill == skills[i] then
					table.remove(skills, i)
					table.insert(skills, skill .. " (e)")
					added = true
				end
			end
			if not added then
				table.insert(skills, skill)
			end
		end
	end

	return skills
end

function M.set_move_pp(pkmn, move, pp)
	pkmn.moves[move].pp = pp
	return pkmn.moves[move].pp
end

function M.get_move_pp(pkmn, move)
	local pkmn_move = pkmn.moves[move]
	if pkmn_move then
		-- If the move somehow became nil (which can happen in corrupted data cases due to issue https://github.com/Jerakin/Pokedex5E/issues/407),
		-- reset it to the move's base pp to avoid exceptions in other places. Ideally the corruption would never happen in the first place, but
		-- some save data is already corrupt.
		local pp = pkmn_move.pp
		if pp == nil then
			M.reset_move_pp(pkmn, move)
			pp = pkmn.moves[move].pp
		end
		return pp
	end
	-- The pkmn doesn't actually "know" this move - likely a "known to all" move. Return pp of the move itself
	return movedex.get_move_pp(move)
end

function M.get_move_pp_max(pkmn, move)
	local move_pp = movedex.get_move_pp(move)
	if type(move_pp) == "string" then
		-- probably move with Unlimited uses, i.e. Struggle
		return move_pp
	else
		local _, pp_extra = M.have_feat(pkmn, "Tireless")
		return movedex.get_move_pp(move) + pp_extra
	end
end

function M.reset(pkmn)
	M.set_current_hp(pkmn, M.get_total_max_hp(pkmn))
	for name, move in pairs(M.get_moves(pkmn)) do
		M.reset_move_pp(pkmn, name)
	end
	pkmn.statuses = {}
end

function M.reset_in_storage(pkmn)
	M.reset(pkmn)
	storage.update_pokemon(pkmn)
end

function M.get_vulnerabilities(pkmn)
	return pokedex.get_vulnerabilities(M.get_current_species(pkmn))
end

function M.get_immunities(pkmn)
	return pokedex.get_immunities(M.get_current_species(pkmn))
end

function M.get_resistances(pkmn)
	return pokedex.get_resistances(M.get_current_species(pkmn))
end

function M.can_decrease_move_pp(pkmn, move)
	local pkmn_move = pkmn.moves[move]
	if pkmn_move ~= nil then
		local move_pp = M.get_move_pp(pkmn, move)
		if type(move_pp) == "string" then
			return false
		end
		return move_pp > 0
	end
	return false
end

function M.decrease_move_pp(pkmn, move)
	if M.can_decrease_move_pp(pkmn, move) then
		local move_pp = M.get_move_pp(pkmn, move)
		local pp = math.max(move_pp - 1, 0)
		pkmn.moves[move].pp = pp
		return pp
	end
	return nil
end

function M.can_increase_move_pp(pkmn, move)
	local pkmn_move = pkmn.moves[move]
	if pkmn_move ~= nil then
		local move_pp = M.get_move_pp(pkmn, move)
		if type(move_pp) == "string" then
			return false
		end
		local max_pp = M.get_move_pp_max(pkmn, move)
		return move_pp < max_pp
	end
	return false
end

function M.increase_move_pp(pkmn, move)
	if M.can_increase_move_pp(pkmn, move) then
		local move_pp = M.get_move_pp(pkmn, move)
		local max_pp = M.get_move_pp_max(pkmn, move)
		local pp = math.min(move_pp + 1, max_pp)
		pkmn.moves[move].pp = pp
		return pp
	end
	return nil
end


function M.reset_move_pp(pkmn, move)
	local pp = M.get_move_pp_max(pkmn, move)
	pkmn.moves[move].pp = pp
end

local function set_evolution_at_level(pkmn, level)
	if type(pkmn.level.evolved) == "number" then
		local old = pkmn.level.evolved
		pkmn.level.evolved = {}
		if old ~= 0 then
			table.insert(pkmn.level.evolved, old)
		end
	end
	
	table.insert(pkmn.level.evolved, level)
end

function M.calculate_addition_hp_from_levels(pkmn, levels_gained)
	local hit_dice = M.get_hit_dice(pkmn)
	local con = M.get_attributes(pkmn).CON
	local con_mod = math.floor((con - 10) / 2)

	local from_hit_dice = math.ceil((hit_dice + 1) / 2) * levels_gained
	local from_con_mod = con_mod * levels_gained
	return from_hit_dice + from_con_mod
end

function M.set_current_level(pkmn, level)
	pkmn.level.current = level
end

function M.add_hp_from_levels(pkmn, from_level)
	if not M.get_max_hp_forced(pkmn) and not M.have_ability(pkmn, "Paper Thin") then
		local hit_dice = M.get_hit_dice(pkmn)
		
		local from_hit_dice = math.ceil((hit_dice + 1) / 2) *  M.get_current_level(pkmn) - from_level
		
		local max = M.get_max_hp(pkmn)
		M.set_max_hp(pkmn, max + from_hit_dice)
		
		-- Also increase current hp
		local c = M.get_current_hp(pkmn)
		M.set_current_hp(pkmn, c + from_hit_dice)
	end
end

function M.evolve(pkmn, to_species)
	local level = M.get_current_level(pkmn)
	if not M.get_max_hp_forced(pkmn) then
		local current = M.get_max_hp(pkmn)
		local gained = level * 2
		M.set_max_hp(pkmn, current + gained)
		
		-- Also increase current hp
		local c = M.get_current_hp(pkmn)
		M.set_current_hp(pkmn, c + gained)
	end
	set_evolution_at_level(pkmn, level)
	set_species(pkmn, to_species)
end


function M.get_saving_throw_modifier(pkmn)
	local prof = M.get_proficency_bonus(pkmn)
	local b = M.get_attributes(pkmn)
	local saving_throws = pokedex.get_saving_throw_proficiencies(M.get_current_species(pkmn)) or {}
	local loyalty = M.get_loyalty(pkmn)
	for _, feat in pairs(M.get_feats(pkmn)) do
		local is_resilient = resilient[feat]
		local got_save = false
		if is_resilient then
			for _, save in pairs(saving_throws) do
				if save == is_resilient then
					got_save = true
				end
			end
			if not got_save then
				table.insert(saving_throws, is_resilient)
			end
		end
	end
	
	local modifiers = {}
	for name, mod in pairs(b) do
		modifiers[name] = math.floor((b[name] - 10) / 2) + loyalty
	end
	for _, st in pairs(saving_throws) do
		modifiers[st] = modifiers[st] + prof
	end

	return modifiers
end

function M.set_nickname(pkmn, nickname)
	local species = M.get_current_species(pkmn)
	if nickname and species:lower() ~= nickname:lower() then
		pkmn.nickname = nickname
	else
		pkmn.nickname = nil
	end
end

function M.get_nickname(pkmn)
	return pkmn.nickname
end

function M.get_AC(pkmn)
	local _, AC_UP = M.have_feat(pkmn, "AC Up")
	return pokedex.get_AC(M.get_current_species(pkmn)) + natures.get_AC(M.get_nature(pkmn)) + AC_UP
end

function M.get_index_number(pkmn)
	return pokedex.get_index_number(M.get_current_species(pkmn))
end

function M.get_hit_dice(pkmn)
	return pokedex.get_hit_dice(M.get_current_species(pkmn))
end

function M.get_exp_worth(pkmn)
	local level = M.get_current_level(pkmn)
	local sr = pokedex.get_SR(M.get_current_species(pkmn))
	return pokedex.get_exp_worth(level, sr)
end

function M.get_catch_rate(pkmn)
	local l = M.get_current_level(pkmn)
	local sr = math.floor(pokedex.get_SR(M.get_current_species(pkmn)))
	local hp = math.floor(M.get_current_hp(pkmn) / 10)
	return 10 + l + sr + hp
end

function M.get_evolution_level(pkmn)
	if type(pkmn.level.evolved) == "number" then
		local old = pkmn.level.evolved
		pkmn.level.evolved = {}
		if old ~= 0 then
			table.insert(pkmn.level.evolved, old)
		end
	end
	return pkmn.level.evolved or {}
end

function M.get_icon(pkmn)
	local species = M.get_current_species(pkmn)
	return pokedex.get_icon(species)
end

function M.get_sprite(pkmn)
	local species = M.get_current_species(pkmn)
	return pokedex.get_sprite(species)
end

local function level_index(level)
	if level >= 17 then
		return "17"
	elseif level >= 10 then
		return "10"
	elseif level >= 5 then
		return "5"
	else
		return "1"
	end
end

local function get_damage_mod_stab(pkmn, move)
	local move_power
	local dice
	local stab_damage
	local floored_mod
	local trainer_stab = 0
	local extra_damage = 0
	local total = M.get_attributes(pkmn)
	local index = level_index(M.get_current_level(pkmn))
	local is_attack = (move.atk == true or move.auto_hit == true) and move.Damage ~= nil

	-- Pick the highest of the moves powers
	if move["Move Power"] then
		for _, mod in pairs(move["Move Power"]) do
			if total[mod] then
				local floored_mod = math.floor((total[mod] - 10) / 2)
				if move_power then
					if floored_mod > move_power then
						move_power = floored_mod
					end
				else
					move_power = floored_mod
				end
			elseif mod == "Any" then
				local max = 0
				for k, v in pairs(total) do
					max = math.max(v, max)
				end
				move_power = math.floor((max - 10) / 2)
			end
		end
	end

	-- Figure out the STAB
	if is_attack then
		trainer_stab = trainer.get_all_levels_STAB()
		for _, t in pairs(M.get_type(pkmn)) do
			trainer_stab = trainer_stab + trainer.get_type_master_STAB(t)
			if move.Type == t then
				stab_damage = M.get_STAB_bonus(pkmn) + trainer.get_STAB(t)
			end
		end
		extra_damage = extra_damage + (stab_damage or 0 + trainer_stab) + trainer.get_damage()
	end

	local move_damage = move.Damage
	if move_damage then
		-- Some moves uses 5x1d4
		local times_prefix = ""
		if move_damage[index].times then
			times_prefix = move_damage[index].times .. "x"
		end

		-- This is the dice representation i.e. "1d6"
		dice = times_prefix .. move_damage[index].amount .. "d" .. move_damage[index].dice_max
		
		-- Add LEVEL to damage if applicable
		extra_damage = extra_damage + (move_damage[index].level and M.get_current_level(pkmn) or 0)

		-- Add move power
		if move_damage[index].move then
			extra_damage = extra_damage + move_power + trainer.get_move()
		end

		-- Combine the different parts into one string
		if extra_damage ~= 0 then
			local symbol = ""
			if extra_damage > 0 then
				symbol = "+"
			end
			dice = dice .. symbol .. extra_damage
		end
	end
	return dice, move_power, stab_damage
end	

function M.get_move_data(pkmn, move_name)
	local move = movedex.get_move_data(move_name)
	local dmg, mod, stab = get_damage_mod_stab(pkmn, move)
	local requires_save = move.Save ~= nil
	local is_attack = (move.atk == true or move.autohit == true) and move.Damage ~= nil

	local move_data = {}
	move_data.damage = dmg
	move_data.stab = stab
	move_data.name = move_name
	move_data.type = move.Type
	move_data.PP = move.PP
	move_data.duration = move.Duration
	move_data.range = move.Range
	move_data.description = move.Description
	move_data.power = move["Move Power"]
	move_data.save = move.Save
	move_data.time = move["Move Time"]
	if is_attack and not move.autohit then
		move_data.AB = mod + M.get_proficency_bonus(pkmn) + trainer.get_attack_roll() + trainer.get_move_type_attack_bonus(move_data.type) + trainer.get_pokemon_type_attack_bonus(M.get_type(pkmn))
	end
	if requires_save then
		move_data.save_dc = 8 + mod + M.get_proficency_bonus(pkmn)
	end

	return move_data
end



local function get_starting_moves(pkmn, number_of_moves)
	-- We get all moves
	local number_of_moves = number_of_moves or 4
	local starting_moves = pokedex.get_starting_moves(M.get_current_species(pkmn))

	-- Shuffle the moves around, we want random moves
	if #starting_moves > number_of_moves then
		starting_moves = utils.shuffle2(starting_moves)
	end

	-- Setup moves
	local moves = {}
	for i=1, number_of_moves do
		if starting_moves[i] then
			local pp = movedex.get_move_pp(starting_moves[i])
			moves[starting_moves[i]] = {pp=pp, index=i}
		end
	end
	return moves
end

function M.new(data)
	local this = {}
	this.species = {}
	this.species.caught = data.species
	this.species.current = data.species

	this.level = {}
	this.level.caught = pokedex.get_minimum_wild_level(this.species.caught)
	this.level.current = this.level.caught
	this.level.evolved = {}

	this.attributes = {STR=0, DEX=0, CON=0, INT=0, WIS=0, CHA=0}
	this.attributes.increased = {STR=0, DEX=0, CON=0, INT=0, WIS=0, CHA=0}

	this.nature = "No Nature"

	this.feats = {}
	this.abilities = pokedex.get_abilities(data.species)

	this.exp = pokedex.get_experience_for_level(this.level.caught-1)

	this.loyalty = 0
	
	local con = M.get_attributes(this).CON
	local con_mod = math.floor((con - 10) / 2)

	this.hp = {}
	this.hp.max = pokedex.get_base_hp(data.species)
	this.hp.current = pokedex.get_base_hp(data.species) + this.level.current * math.floor((M.get_attributes(this).CON - 10) / 2)
	this.hp.edited = false

	this.moves = get_starting_moves(this, data.number_of_moves)
	
	return this
end



return M
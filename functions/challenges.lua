-- New Game+ challenges and the League voucher pool.

POKE_CHALLENGES = {
  { key = 'obedience', name = 'Obedience', text = 'Jokers past slot 3 are debuffed. Each badge unlocks a slot.' },
  { key = 'distortion', name = 'Distortion', text = 'Joker order shuffles after each hand is played.' },
  { key = 'fashion', name = 'Fashion Week', text = 'A random edition is debuffed each ante.' },
  { key = 'daynight', name = 'Day/Night', text = 'Antes alternate: face cards, then number cards are debuffed.' },
  { key = 'seasons', name = 'Seasons', text = 'One suit is debuffed each ante, in rotation.' },
  { key = 'truths', name = 'Truths and Ideals', text = 'Antes alternate: even cards, then odd cards are debuffed.' },
  { key = 'dive', name = 'Dive', text = '1 in 4 cards are drawn face down.' },
  { key = 'snowbound', name = 'Snowbound', text = '-1 hand size, hand or discard, rotating each ante.' },
  { key = 'unown', name = 'Unown', text = 'Card chip values are randomized each ante (1 to 26).' },
  { key = 'rocket', name = 'Rocket Radio', text = 'Shop prices are 50% higher this region.' },
  { key = 'wild', name = 'Wild Area', text = 'Rerolls cost $2 more.' },
  { key = 'weather', name = 'Weather', text = 'Type effectiveness is doubled.' },
  { key = 'inverse', name = 'Inverse', text = 'The type chart is flipped.' },
  { key = 'terastal', name = 'Terastal', text = 'Gym Leaders change type every hand.' },
  { key = 'fog', name = 'Fog', text = "The boss's type is hidden until you select a Blind." },
  { key = 'totem', name = 'Totem Aura', text = 'Boss Blinds are x1.5.' },
  { key = 'dynamax', name = 'Dynamax', text = 'Blinds are x3. Chips and Mult balance after scoring.' },
  { key = 'crowd', name = 'Crowd', text = 'A Medium Blind comes before each Big Blind.' },
}

POKE_CROWD_MULT = 1.25
POKE_TOTEM_MULT = 1.5
POKE_DYNAMAX_MULT = 3
POKE_ROCKET_MARKUP = 1.5
POKE_WILD_REROLL = 2
POKE_OBEDIENCE_BASE = 3
POKE_RARE_VOUCHER_ODDS = 0.09
POKE_GS_VOUCHER_ODDS = 0.01
POKE_LEGENDARY_BASE_RATE = 0.003
POKE_LEGENDARY_GROWTH = 1.5

local SEASONS = { 'Hearts', 'Diamonds', 'Clubs', 'Spades' }
local SNOWBOUND = { 'hand size', 'hand', 'discard' }
local EVEN_RANKS = { [2] = true, [4] = true, [6] = true, [8] = true, [10] = true, [11] = true, [13] = true }
local ODD_RANKS = { [3] = true, [5] = true, [7] = true, [9] = true, [12] = true, [14] = true }

poke_challenge_on = function(key)
  return G.GAME and G.GAME.poke_challenges and G.GAME.poke_challenges[key] or false
end

local function current_ante()
  return (G.GAME.round_resets and G.GAME.round_resets.ante) or 1
end

--- The ante's position inside its region, 1 to 13.
local function within_region()
  return ((math.max(1, current_ante()) - 1) % POKE_LEAGUE_ANTES) + 1
end

--- One draw per ante, kept so that showing a value never rerolls it.
local function ante_roll(name, options)
  local rolls = G.GAME.poke_ante_rolls
  if not rolls or rolls.ante ~= current_ante() then
    rolls = { ante = current_ante() }
    G.GAME.poke_ante_rolls = rolls
  end
  if rolls[name] == nil then
    rolls[name] = pseudorandom_element(options, pseudoseed('pgc_' .. name .. current_ante()))
  end
  return rolls[name]
end

--- Rolls this region's challenge; only Master Ball keeps the earlier ones.
poke_challenge_roll = function(step)
  G.GAME.poke_challenges_seen = G.GAME.poke_challenges_seen or {}
  local seen, pool = G.GAME.poke_challenges_seen, {}
  for _, c in ipairs(POKE_CHALLENGES) do
    if not seen[c.key] then pool[#pool + 1] = c.key end
  end
  if #pool == 0 then
    G.GAME.poke_challenges_seen, seen = {}, {}
    for _, c in ipairs(POKE_CHALLENGES) do pool[#pool + 1] = c.key end
  end
  local pick = pseudorandom_element(pool, pseudoseed('pgc_challenge_' .. step))
  seen[pick] = true
  -- poke_no_negative_slots is set by Master Ball alone.
  local carried = G.GAME.modifiers.poke_no_negative_slots and G.GAME.poke_challenges or nil
  G.GAME.poke_challenges = carried or {}
  G.GAME.poke_challenges[pick] = true
  if pick == 'snowbound' then
    G.GAME.poke_snow_offset = math.floor(pseudorandom(pseudoseed('pgc_snowbound')) * #SNOWBOUND)
  end
  return pick
end

local function season()
  return SEASONS[((within_region() - 1) % #SEASONS) + 1]
end

local function snowbound_kind()
  return SNOWBOUND[((within_region() + (G.GAME.poke_snow_offset or 0)) % #SNOWBOUND) + 1]
end

local function fashion_edition()
  local options = {}
  for _, v in ipairs(G.P_CENTER_POOLS.Edition) do
    if v.key ~= 'e_base' then options[#options + 1] = v.key end
  end
  return ante_roll('fashion', options)
end

local function obedience_limit()
  return POKE_OBEDIENCE_BASE + math.min(8, within_region() - 1)
end

--- The wording for what a challenge is doing this ante, for those that change.
poke_challenge_status = function(key)
  if key == 'obedience' then return obedience_limit() .. ' Joker slots obey you' end
  if key == 'fashion' then
    return localize({ type = 'name_text', set = 'Edition', key = fashion_edition() }) .. ' cards are debuffed'
  end
  if key == 'daynight' then
    return within_region() % 2 == 1 and 'Face cards are debuffed' or 'Number cards are debuffed'
  end
  if key == 'seasons' then return season() .. ' are debuffed' end
  if key == 'truths' then
    return within_region() % 2 == 1 and 'Even cards are debuffed' or 'Odd cards are debuffed'
  end
  if key == 'snowbound' then return '-1 ' .. snowbound_kind() end
end

--- Whether a challenge is debuffing this card right now.
poke_challenge_debuff = function(card)
  if not (G.GAME and G.GAME.poke_challenges and card and card.base) then return false end
  if card.area == G.jokers and G.jokers and poke_challenge_on('obedience') then
    for i, joker in ipairs(G.jokers.cards) do
      if joker == card then
        if i > obedience_limit() then return true end
        break
      end
    end
  end
  if poke_challenge_on('fashion') and card.edition and card.edition[fashion_edition():sub(3)] then
    return true
  end
  if not card.playing_card then return false end
  local ranked = not SMODS.has_no_rank(card)
  local odd_ante = within_region() % 2 == 1
  if poke_challenge_on('daynight') and ranked then
    local id = card.base.id
    if odd_ante then
      if card:is_face(true) then return true end
    elseif id and id >= 2 and id <= 10 then
      return true
    end
  end
  if poke_challenge_on('truths') and ranked then
    if (odd_ante and EVEN_RANKS or ODD_RANKS)[card.base.id] then return true end
  end
  if poke_challenge_on('seasons') and card:is_suit(season(), true) then return true end
  return false
end

--- Type effectiveness under Inverse.
poke_challenge_inverse = function(m)
  if not poke_challenge_on('inverse') then return m end
  return m == 0 and 2 or 1 / m
end

--- Type effectiveness under Weather.
poke_challenge_weather = function(m)
  if not poke_challenge_on('weather') then return m end
  if m > 1 then return m * 2 end
  if m > 0 and m < 1 then return m / 2 end
  return m
end

--- A Gym Leader's type under Terastal, once the fight has started changing it.
poke_terastal_type = function(ante)
  local tera = G.GAME.poke_tera
  return tera and tera.ante == ante and tera.type or nil
end

poke_terastal_cycle = function()
  local ante, pool = current_ante(), {}
  local avoid = poke_terastal_type(ante)
  for _, t in ipairs(POKE_CYCLE_TYPES) do
    if t ~= avoid then pool[#pool + 1] = t end
  end
  G.GAME.poke_tera = { ante = ante, type = pseudorandom_element(pool, pseudoseed('pgc_terastal')) }
end

--- Fog lifts when a Blind of the ante is selected, because that is when matchups start.
poke_fog_hidden = function(entry)
  if not (entry and poke_challenge_on('fog') and entry.role ~= 'champion') then return false end
  return G.GAME.poke_fog_seen ~= current_ante()
end

local function crowd_medium()
  return poke_challenge_on('crowd') and G.GAME.poke_crowd_stage == 'medium'
end
poke_crowd_medium = crowd_medium

local big_base, boss_scaled, line_swapped

local function swap_first_line(key, line)
  local desc = G.localization.descriptions.Blind[key]
  if not (desc and desc.text and desc.text_parsed) then return end
  line_swapped = { key = key, text = desc.text[1], parsed = desc.text_parsed[1] }
  desc.text[1] = line
  desc.text_parsed[1] = loc_parse_string(line)
end

--- Applies blind sizes, rewards and hidden type lines for the ante, undoing the last ante's first.
poke_challenge_blind_sync = function(entry)
  local big = G.P_BLINDS and G.P_BLINDS.bl_big
  if not big then return end
  big_base = big_base or { mult = big.mult, dollars = big.dollars }
  local medium = entry and crowd_medium()
  big.mult = medium and POKE_CROWD_MULT or big_base.mult
  big.dollars = medium and math.ceil((G.P_BLINDS.bl_small.dollars + big_base.dollars) / 2) or big_base.dollars
  big.unskippable = medium or nil

  if boss_scaled then
    G.P_BLINDS[boss_scaled.key].mult = boss_scaled.mult
    boss_scaled = nil
  end
  if line_swapped then
    local desc = G.localization.descriptions.Blind[line_swapped.key]
    if desc then desc.text[1], desc.text_parsed[1] = line_swapped.text, line_swapped.parsed end
    line_swapped = nil
  end
  if not entry then return end

  local key = poke_league_boss_key(current_ante())
  local boss = key and G.P_BLINDS[key]
  if not boss then return end
  if poke_challenge_on('totem') then
    boss_scaled = { key = key, mult = boss.mult }
    boss.mult = boss.mult * POKE_TOTEM_MULT
  end

  local head
  if poke_fog_hidden(entry) then
    head = '{C:inactive}Type hidden'
  elseif poke_challenge_on('terastal') and entry.role == 'gym' then
    head = 'Type changes {C:attention}every hand'
  end
  if head then
    local fx = poke_gym_effect(entry.effect)
    if fx then head = head .. '{C:inactive}: {C:' .. (fx.colour or 'attention') .. '}' .. fx.status end
    swap_first_line(key, head)
  end
end

--- The name the middle column should carry, or nil.
poke_crowd_name = function()
  return crowd_medium() and localize('poke_crowd_medium') or nil
end

--- Mod-level calculate for the challenges.
poke_challenge_calculate = function(context)
  if not G.GAME.poke_challenges then return end

  if context.press_play and poke_challenge_on('distortion') and #G.jokers.cards > 1 then
    G.jokers:unhighlight_all()
    G.jokers:shuffle('pgc_distortion')
  end

  if context.setting_blind then
    G.GAME.poke_round_clean = nil
    if poke_challenge_on('snowbound') then
      local kind = snowbound_kind()
      if kind == 'hand size' then
        G.hand:change_size(-1)
        G.GAME.poke_snow_hand_size = true
      elseif kind == 'hand' then
        if G.GAME.current_round.hands_left > 1 then ease_hands_played(-1) end
      elseif G.GAME.current_round.discards_left > 0 then
        ease_discard(-1)
      end
    end
  end

  if context.end_of_round and not G.GAME.poke_round_clean then
    G.GAME.poke_round_clean = true
    if G.GAME.poke_snow_hand_size then
      G.GAME.poke_snow_hand_size = nil
      G.hand:change_size(1)
    end
    if poke_challenge_on('dive') then
      for _, card in ipairs(G.hand.cards) do
        if card.facing == 'back' then card:flip() end
      end
      for _, card in pairs(G.playing_cards) do card.ability.wheel_flipped = nil end
    end
  end

  if context.stay_flipped and context.to_area == G.hand and poke_challenge_on('dive')
      and pseudorandom('pgc_dive') < 0.25 then
    return { stay_flipped = true }
  end

  if context.final_scoring_step and poke_challenge_on('dynamax') then
    return { balance = true }
  end
end

-- -------------------------------------------------------------- game hooks

local get_blind_amount_ref = get_blind_amount
function get_blind_amount(ante)
  local amount = get_blind_amount_ref(ante)
  return poke_challenge_on('dynamax') and amount * POKE_DYNAMAX_MULT or amount
end

local set_cost_ref = Card.set_cost
function Card:set_cost()
  set_cost_ref(self)
  if poke_challenge_on('rocket') and (self.cost or 0) > 0 then
    self.cost = math.ceil(self.cost * POKE_ROCKET_MARKUP)
  end
end

local reroll_cost_ref = calculate_reroll_cost
function calculate_reroll_cost(skip_increment)
  reroll_cost_ref(skip_increment)
  if poke_challenge_on('wild') and G.GAME.current_round.free_rerolls <= 0 then
    G.GAME.current_round.reroll_cost = G.GAME.current_round.reroll_cost + POKE_WILD_REROLL
  end
end

--- A card's rolled chip value for the ante.
local function unown_chips(card)
  local h = pseudohash('pgc_unown' .. tostring(G.GAME.pseudorandom.seed) .. current_ante() .. card.sort_id)
  return 1 + math.floor(h * 26)
end

local function unown_applies(card)
  return poke_challenge_on('unown') and card.playing_card and card.base and (card.base.nominal or 0) > 0
    and not card.ability.extra_enhancement
    and not SMODS.has_playing_card_property(card, 'replace_base_card')
end

local get_chip_bonus_ref = Card.get_chip_bonus
function Card:get_chip_bonus()
  local chips = get_chip_bonus_ref(self)
  if unown_applies(self) then return chips - self.base.nominal + unown_chips(self) end
  return chips
end

-- The tooltip reads base.nominal directly, so it borrows the rolled value while it builds.
local ability_table_ref = Card.generate_UIBox_ability_table
function Card:generate_UIBox_ability_table(...)
  if not unown_applies(self) then return ability_table_ref(self, ...) end
  local nominal = self.base.nominal
  self.base.nominal = unown_chips(self)
  local ret = ability_table_ref(self, ...)
  self.base.nominal = nominal
  return ret
end

local main_colour_ref = get_blind_main_colour
function get_blind_main_colour(blind)
  if blind == 'Boss' and G.GAME and G.GAME.poke_challenges
      and poke_fog_hidden(poke_league_entry(current_ante())) then
    return G.C.GREY
  end
  return main_colour_ref(blind)
end

local select_blind_ref = G.FUNCS.select_blind
G.FUNCS.select_blind = function(e)
  if poke_challenge_on('fog') then
    G.GAME.poke_fog_seen = current_ante()
    poke_blind_names_sync()
  end
  return select_blind_ref(e)
end

-- A defeated Medium Blind hands its column to the real Big Blind.
local cash_out_ref = G.FUNCS.cash_out
G.FUNCS.cash_out = function(e)
  local states = G.GAME.round_resets.blind_states
  if crowd_medium() and states.Big == 'Defeated' then
    states.Big = 'Upcoming'
    G.GAME.poke_crowd_stage = 'big'
  end
  return cash_out_ref(e)
end

local reset_blinds_ref = reset_blinds
function reset_blinds()
  reset_blinds_ref()
  if not (G.GAME and G.GAME.round_resets and G.GAME.poke_crowd_ante ~= G.GAME.round_resets.ante) then return end
  G.GAME.poke_crowd_ante = G.GAME.round_resets.ante
  local entry = poke_challenge_on('crowd') and poke_league_entry(G.GAME.round_resets.ante)
  G.GAME.poke_crowd_stage = entry and entry.role == 'gym' and 'medium' or nil
end

--- Announces challenges on the Blind screen: all of them on a region's first ante, then what changed.
local function ante_notice()
  if not (G.GAME.poke_challenges and G.GAME.poke_notice_ante ~= current_ante()) then return end
  G.GAME.poke_notice_ante = current_ante()
  local first_ante, offset = within_region() == 1, -1
  for _, c in ipairs(POKE_CHALLENGES) do
    local status = poke_challenge_on(c.key) and poke_challenge_status(c.key)
    if poke_challenge_on(c.key) and (first_ante or status) then
      local line = c.name .. ': ' .. (status or c.text)
      local y = offset
      offset = offset + 0.8
      G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.8, func = function()
        attention_text({ text = line, scale = 0.6, hold = 6, major = G.jokers,
                         backdrop_colour = G.C.PURPLE, align = 'cm', offset = { x = 0, y = y } })
        return true
      end }))
    end
  end
end

local blind_select_ref = create_UIBox_blind_select
function create_UIBox_blind_select(...)
  local ret = blind_select_ref(...)
  ante_notice()
  return ret
end

--- Obedience moves with the row, so its debuffs follow every reorder and every badge.
local obedience_seen
local function obedience_watch()
  local limit = G.GAME and poke_challenge_on('obedience') and obedience_limit() or nil
  if limit == nil and obedience_seen == nil then return end
  if not (G.jokers and G.GAME and G.GAME.blind) then return end
  local changed = limit ~= obedience_seen
  obedience_seen = limit
  for i, joker in ipairs(G.jokers.cards) do
    if joker.poke_slot ~= i then
      joker.poke_slot = i
      changed = changed or limit ~= nil
    end
  end
  if changed then
    for _, joker in ipairs(G.jokers.cards) do SMODS.recalc_debuff(joker) end
  end
end

local game_update_ref = Game.update
function Game:update(dt)
  game_update_ref(self, dt)
  obedience_watch()
end

-- ------------------------------------------------------------- Run Info tab

local function info_row(text, colour, scale)
  return { n = G.UIT.R, config = { align = 'cm', padding = 0.03, maxw = 11 }, nodes = {
    { n = G.UIT.T, config = { text = text, scale = scale, colour = colour, shadow = true } },
  } }
end

poke_challenges_tab = function()
  local rows = {}
  for _, c in ipairs(POKE_CHALLENGES) do
    if poke_challenge_on(c.key) then
      rows[#rows + 1] = info_row(c.name, G.C.GOLD, 0.55)
      rows[#rows + 1] = info_row(c.text, G.C.UI.TEXT_LIGHT, 0.4)
      local status = poke_challenge_status(c.key)
      if status then rows[#rows + 1] = info_row('This ante: ' .. status, G.C.FILTER, 0.4) end
    end
  end
  local names = {}
  for _, name in ipairs(G.handlist) do
    if poke_league_hand_banned(name) then names[#names + 1] = localize(name, 'poker_hands') end
  end
  if #names > 0 then
    rows[#rows + 1] = info_row(localize('poke_banned_hands'), G.C.RED, 0.55)
    rows[#rows + 1] = info_row(table.concat(names, ', '), G.C.UI.TEXT_LIGHT, 0.4)
  end
  return { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR, padding = 0.2, minw = 9, minh = 5 },
           nodes = { { n = G.UIT.C, config = { align = 'cm' }, nodes = rows } } }
end

local create_tabs_ref = create_tabs
function create_tabs(args)
  if args and args.tabs and args.tabs[1] and args.tabs[1].label == localize('b_poker_hands')
      and G.GAME and G.GAME.poke_challenges then
    args.tabs[#args.tabs + 1] = { label = localize('poke_challenges_tab'),
                                  tab_definition_function = poke_challenges_tab }
  end
  return create_tabs_ref(args)
end

-- --------------------------------------------------------- League vouchers

--- Whether the League's own vouchers have taken over the shop.
local function vouchers_exhausted()
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league) then return false end
  for _, key in ipairs(get_current_pool('Voucher')) do
    if key ~= 'UNAVAILABLE' and not (key == 'v_blank' and G.GAME.used_vouchers.v_blank) then
      return false
    end
  end
  return true
end

--- 1% GS Ball, 9% rare, 90% common; an empty tier falls through to the next one that has stock.
local function pick_league_voucher(taken, seed)
  local gs, rare, common = {}, {}, {}
  for _, v in ipairs(G.P_CENTER_POOLS.Voucher) do
    if v.poke_league_voucher and not taken[v.key] and (not v.poke_eligible or v.poke_eligible()) then
      local list = v.poke_gs and gs or v.poke_rare and rare or common
      list[#list + 1] = v.key
    end
  end
  local roll = pseudorandom(pseudoseed(seed .. '_rarity'))
  local order = roll < POKE_GS_VOUCHER_ODDS and { gs, common, rare }
    or roll < POKE_GS_VOUCHER_ODDS + POKE_RARE_VOUCHER_ODDS and { rare, common, gs }
    or { common, rare, gs }
  for _, pool in ipairs(order) do
    if #pool > 0 then return pseudorandom_element(pool, pseudoseed(seed)) end
  end
  return nil
end

--- GS Ball: a shop Joker slot can roll a Legendary Pokemon.
poke_legendary_shop_flags = function(context)
  local rate = G.GAME.poke_legendary_rate
  if not (rate and context.set == 'Joker') then return end
  if pseudorandom(pseudoseed('pgc_legendary' .. current_ante())) >= rate then return end
  local pool = {}
  for _, v in ipairs(G.P_CENTER_POOLS.Joker) do
    if v.rarity == 4 and v.stage and not G.GAME.used_jokers[v.key] and not G.GAME.banned_keys[v.key]
        and SMODS.add_to_pool(v) then
      pool[#pool + 1] = v.key
    end
  end
  if #pool == 0 then return end
  return { shop_create_flags = { key = pseudorandom_element(pool, pseudoseed('pgc_legendary_pick')) } }
end

local next_vouchers_ref = SMODS.get_next_vouchers
SMODS.get_next_vouchers = function(vouchers)
  if not vouchers_exhausted() then return next_vouchers_ref(vouchers) end
  vouchers = vouchers or { spawn = {} }
  local slots = G.GAME.starting_params.vouchers_in_shop + (G.GAME.modifiers.extra_vouchers or 0)
  for i = #vouchers + 1, slots do
    local key = pick_league_voucher(vouchers.spawn, 'pgc_voucher' .. current_ante() .. '_' .. i)
    if not key then break end
    vouchers[#vouchers + 1] = key
    vouchers.spawn[key] = true
  end
  return vouchers
end

local next_voucher_key_ref = get_next_voucher_key
function get_next_voucher_key(from_tag)
  if vouchers_exhausted() then
    local key = pick_league_voucher({}, 'pgc_voucher_tag' .. current_ante())
    if key then return key end
  end
  return next_voucher_key_ref(from_tag)
end

-- Partner Ribbon: copies go straight to the original add_tag, so a copy is never copied.
local add_tag_ref = add_tag
function add_tag(tag)
  local copies = not tag.from_load and G.GAME and G.GAME.poke_tag_copies or 0
  add_tag_ref(tag)
  for _ = 1, copies do
    local copy = Tag(tag.key, false, tag.ability and tag.ability.blind_type)
    if tag.ability and tag.ability.orbital_hand then copy.ability.orbital_hand = tag.ability.orbital_hand end
    add_tag_ref(copy)
  end
end

-- Rare Candy: taken off each Pokemon's evolution timer once per voucher bought.
local level_evo_ref = pokermon.level_evo
pokermon.level_evo = function(self, card, context, forced_key)
  local candy = G.GAME and G.GAME.poke_rare_candy or 0
  local extra = card.ability.extra
  local eaten = card.ability.poke_candy_eaten or 0
  if candy > eaten and type(extra) == 'table' and type(extra.rounds) == 'number' then
    extra.rounds = math.max(1, extra.rounds - (candy - eaten))
    card.ability.poke_candy_eaten = candy
  end
  return level_evo_ref(self, card, context, forced_key)
end

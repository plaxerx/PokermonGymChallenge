-- Type matchup behaviour for the Poke League.

--- The roster entry for an absolute ante, or nil if that generation has none.
poke_league_entry = function(ante)
  local a = math.max(1, ante or 1)
  local within = ((a - 1) % POKE_LEAGUE_ANTES) + 1
  local gen = poke_league_generation(a)
  local region = POKE_LEAGUE_ROSTER[gen]
  if not region then return nil end
  return region.entries[within], gen, within
end

--- Which generation a given ante falls in.
poke_league_generation = function(ante)
  local a = ante or (G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) or 1
  if not poke_league_gen_for_step then return 1 end
  return poke_league_gen_for_step(math.floor((math.max(1, a) - 1) / POKE_LEAGUE_ANTES))
end

-- The Blind key the League demands for a given ante.
poke_league_boss_key = function(ante)
  local entry = poke_league_entry(ante)
  if not entry then return nil end
  return (PGC_BLIND_PREFIX or "bl_pgc_") .. entry.key
end

-- Blind sizes for a League run.
POKE_LEAGUE_TAIL_RATIO = 1.6    -- per-ante growth for antes 9-13
--- 1.9 was set when antes 9-13 were three Blinds each.
POKE_LEAGUE_GEN_MULT   = 10

-- Vanilla's ante 1-8 tables, indexed by G.GAME.modifiers.scaling.
POKE_BLIND_TABLES = {
  [1] = { 300,  800, 2000, 5000, 11000, 20000,  35000,  50000 },
  [2] = { 300,  900, 2600, 8000, 20000, 36000,  60000, 100000 },
  [3] = { 300, 1000, 3200, 9000, 25000, 60000, 110000, 200000 },
}

-- Vanilla rounds to two significant figures; match it so numbers read the same.
local function poke_round_blind(amount)
  if amount <= 0 then return 0 end
  return amount - amount % (10 ^ math.floor(math.log10(amount) - 1))
end

--- Vanilla ante that League ante 118 is played as.
POKE_ENDLESS_FIRST = 14
--- The lift.
POKE_ENDLESS_MULT = 10
POKE_ENDLESS_MULT_UNTIL = 15

poke_league_blind_amount = function(ante)
  local a = ante or 1
  if a < 1 then return 100 end

  if a > POKE_LEAGUE_LAST_ANTE then
    local vanilla = poke_vanilla_blind_amount or get_blind_amount
    local step = a - POKE_LEAGUE_LAST_ANTE + POKE_ENDLESS_FIRST - 1
    local mult = step <= POKE_ENDLESS_MULT_UNTIL and POKE_ENDLESS_MULT or 1
    return (vanilla(step) or 0) * mult
  end
  local gen_step = math.floor((a - 1) / POKE_LEAGUE_ANTES)
  local within = ((a - 1) % POKE_LEAGUE_ANTES) + 1
  local scaling = (G.GAME and G.GAME.modifiers and G.GAME.modifiers.scaling) or 1
  local tbl = POKE_BLIND_TABLES[scaling] or POKE_BLIND_TABLES[1]

  local amount
  if within <= 8 then
    amount = tbl[within]
  else
    amount = tbl[8] * (POKE_LEAGUE_TAIL_RATIO ^ (within - 8))
  end
  amount = amount * (POKE_LEAGUE_GEN_MULT ^ gen_step)
  return poke_round_blind(math.floor(amount))
end

-- Home-generation Pokemon show up more often.
POKE_GEN_TARGET_SHARE  = 0.30   -- share of draws a home generation aims for
POKE_GEN_MAX_PER_JOKER = 0.02   -- no single Joker may exceed this
POKE_GEN_MAX_COPIES    = 15     -- hard ceiling on pool bloat

local poke_gen_copies_cache = nil

--- Copies each generation's Jokers get.
local function poke_gen_copies()
  if poke_gen_copies_cache then return poke_gen_copies_cache end
  local counts, total = {}, 0
  for _, v in pairs((G.P_CENTER_POOLS or {}).Joker or {}) do
    if v.stage and v.gen then
      counts[v.gen] = (counts[v.gen] or 0) + 1
      total = total + 1
    end
  end
  if total == 0 then return {} end
  local out = {}
  for gen, n in pairs(counts) do
    local share = math.min(POKE_GEN_TARGET_SHARE, n * POKE_GEN_MAX_PER_JOKER)
    local k = 1
    if share > n / total then
      k = math.floor(share * (total - n) / (n * (1 - share)) + 0.5)
      k = math.max(1, math.min(POKE_GEN_MAX_COPIES, k))
    end
    out[gen] = k
  end
  poke_gen_copies_cache = out
  return out
end

--- Extra pool entries a Joker gets for being from the generation being played.
poke_gen_extra_copies = function(center)
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league) then return 0 end
  if not center or center.set ~= 'Joker' or not center.stage or not center.gen then return 0 end
  if center.gen ~= poke_league_generation() then return 0 end
  return (poke_gen_copies()[center.gen] or 1) - 1
end

-- Type effectiveness as a multiplier.
local function poke_type_single(card, gym_type)
  local matchup = POKE_GYM_MATCHUPS[gym_type]
  if not matchup or not card then return 1 end

  local function raw()
    for _, t in ipairs(matchup.immune or {}) do
      if pokermon.is_type(card, t) then return 0 end
    end
    for _, t in ipairs(matchup.weak or {}) do
      if pokermon.is_type(card, t) then return 2 end
    end
    for _, t in ipairs(matchup.resist or {}) do
      if pokermon.is_type(card, t) then return 0.5 end
    end
    return 1
  end
  local m = poke_challenge_inverse(raw())

  -- Negative Pokemon ignore type disadvantage under Master Ball.
  local shrugs_off = G.GAME and G.GAME.modifiers
    and G.GAME.modifiers.poke_no_negative_slots
    and card.edition and card.edition.negative
  if shrugs_off and m < 1 then return 1 end
  return m
end

--- Combined multiplier against a Leader's one or two types.
poke_type_multiplier = function(card, gym_type, gym_type2)
  local m = poke_type_single(card, gym_type)
  if gym_type2 then m = m * poke_type_single(card, gym_type2) end
  return poke_challenge_weather(m)
end

-- What type advantage scales: an ALLOWLIST, not a blacklist.

--- Flat score and money values.
POKE_SCALE_FLAT = {
  mult = true, mult1 = true, mult2 = true,
  mult_mod = true, mult_mod2 = true, mult_scaling_mod = true,
  chips = true, chips1 = true, chips2 = true, chips3 = true,
  chip_mod = true, chip_mod1 = true, chip_mod2 = true,
  money = true, money_mod = true, money_mod1 = true, money_mod2 = true,
  money_increase = true, money_earned = true, water_money = true,
  scizor_chips = true,
}

--- Multiplier fields: only the part above 1 is a bonus.
POKE_SCALE_XMULT = {
  Xmult = true, Xmult1 = true, Xmult2 = true, Xmult_mod = true,
  Xmult_mod1 = true, Xmult_mod2 = true,
  Xmult_multi = true, Xmult_multi1 = true, Xmult_multi2 = true,
  x_mult = true, xmult = true, scizor_Xmult = true,
  Xchips = true, Xchips1 = true, Xchips2 = true, Xchips_multi = true,
}

-- Probability denominators scale INVERSELY.
POKE_SCALE_ODDS = { dem = true }

-- Counts of an ACTION rather than a score: retrigger counts and poker-hand levels.
POKE_SCALE_COUNT = { retriggers = true, level_amt = true }

-- Baby Pokemon are the mirror case: their headline number is a PENALTY.
POKE_SCALE_PENALTY = { Xmult_minus = true }

--- Whether a field is scaled at all.
local function poke_scalable(key, is_baby)
  return POKE_SCALE_FLAT[key] or POKE_SCALE_XMULT[key] or POKE_SCALE_ODDS[key]
    or POKE_SCALE_COUNT[key]
    or (is_baby and POKE_SCALE_PENALTY[key])
end

-- Multiplier fields hold two different things.
local function scaled(value, key, factor, is_baby)
  if is_baby and POKE_SCALE_PENALTY[key] and value < 1 then
    local r
    if factor > 1 then
      r = 1 - (1 - value) / factor        -- eased, but never all the way to 1
    else
      r = value * factor                  -- bitten down harder
    end
    r = math.floor(r * 1000 + 0.5) / 1000
    return math.min(0.99, math.max(0.05, r))
  end
  if POKE_SCALE_XMULT[key] then
    if value < 1 then
      -- An increment: scale it whole.
      return math.max(0.01, math.floor(value * factor * 100 + 0.5) / 100)
    end
    if value == 1 then return value end
    local r = 1 + (value - 1) * factor
    r = math.floor(r * 100 + 0.5) / 100
    return math.max(1.01, r)
  end
  if POKE_SCALE_COUNT[key] then
    local r
    if factor >= 1 then
      r = math.floor(value * factor + 0.5)     -- a buff lands exactly: 3 x2 = 6
    else
      r = math.floor(value * factor)           -- a nerf rounds down: 3 x0.5 = 1
    end
    if value >= 1 and r < 1 then r = 1 end
    return math.max(0, r)
  end
  if POKE_SCALE_ODDS[key] then
    -- Inverted.
    if value <= 1 then return value end
    return math.max(1, math.floor(value / factor + 0.5))
  end
  if value == math.floor(value) then
    -- The Flint's rounding.
    local r = math.max(math.floor(value * factor + 0.5), 0)
    if value >= 1 and r < 1 then r = 1 end
    return r
  end
  return math.floor(value * factor * 100 + 0.5) / 100
end

--- A delta records which matchup produced it.

--- Every area that can hold Jokers, not just G.jokers.
local function poke_joker_areas()
  if SMODS and SMODS.get_card_areas then return SMODS.get_card_areas('jokers') end
  return G.jokers and { G.jokers } or {}
end

--- Undo whatever poke_gym_scale_joker applied.
poke_gym_unscale_joker = function(card)
  if not card or not card.ability or type(card.ability.extra) ~= "table" then return end
  local delta = card.ability.poke_gym_delta
  if not delta then return end
  for k, dv in pairs(delta) do
    if type(card.ability.extra[k]) == "number" and type(dv) == "number" then
      card.ability.extra[k] = card.ability.extra[k] - dv
    end
  end
  card.ability.poke_gym_delta = nil
  card.ability.poke_gym_source = nil
end

-- Which of a Joker's numbers are actually SHOWN on the card.
POKE_SHOWN_CACHE = {}

local function poke_probe_vars(center, card)
  local ok, ret = pcall(center.loc_vars, center, {}, card)
  if not ok or type(ret) ~= 'table' or type(ret.vars) ~= 'table' then return nil end
  local out = {}
  for i, v in ipairs(ret.vars) do out[i] = tostring(v) end
  return table.concat(out, '')
end

poke_shown_fields = function(card)
  local center = card and card.config and card.config.center
  local key = center and center.key
  if not key then return nil end
  if POKE_SHOWN_CACHE[key] then return POKE_SHOWN_CACHE[key] end

  local extra = card.ability and card.ability.extra
  local shown = {}
  if type(extra) == 'table' and type(center.loc_vars) == 'function' then
    local base = poke_probe_vars(center, card)
    if base then
      for k, v in pairs(extra) do
        if type(v) == 'number' then
          for _, nudge in ipairs({ 1, 1000037 }) do
            extra[k] = v + nudge
            local moved = poke_probe_vars(center, card)
            extra[k] = v
            if moved and moved ~= base then shown[k] = true break end
          end
        end
      end
    end
  end
  POKE_SHOWN_CACHE[key] = shown
  return shown
end

poke_gym_scale_joker = function(card, factor, source)
  if not card or not card.ability or type(card.ability.extra) ~= "table" then return end
  if card.ability.poke_gym_delta then
    if card.ability.poke_gym_source == source then return end
    poke_gym_unscale_joker(card)
  end
  local center = card.config and card.config.center
  local is_baby = center and center.stage == 'Baby' or false
  local delta = {}
  -- Only numbers the card actually shows.
  local shown = poke_shown_fields(card) or {}
  for k, v in pairs(card.ability.extra) do
    if type(v) == "number" and poke_scalable(k, is_baby) and shown[k] and v ~= 0 then
      local new = scaled(v, k, factor, is_baby)
      if new ~= v then
        delta[k] = new - v
        card.ability.extra[k] = new
      end
    end
  end
  if next(delta) then
    card.ability.poke_gym_delta = delta
    card.ability.poke_gym_source = source
  end
end

-- Champions fight the meta rather than a type: their type rerolls every hand.
POKE_CYCLE_TYPES = {
  'Normal', 'Fire', 'Water', 'Electric', 'Grass', 'Ice', 'Fighting', 'Poison',
  'Ground', 'Flying', 'Psychic', 'Bug', 'Rock', 'Ghost', 'Dragon', 'Dark',
  'Steel', 'Fairy',
}

--- Advance the Champion's type.
poke_champion_cycle = function(reset)
  local function draw(avoid)
    local pool = {}
    for _, t in ipairs(POKE_CYCLE_TYPES) do
      if t ~= avoid then pool[#pool + 1] = t end
    end
    return pseudorandom_element(pool, pseudoseed('poke_champion'))
  end
  if reset or not G.GAME.poke_champ_type then
    G.GAME.poke_champ_type = draw(nil)
  else
    G.GAME.poke_champ_type = G.GAME.poke_champ_next or draw(G.GAME.poke_champ_type)
  end
  G.GAME.poke_champ_next = draw(G.GAME.poke_champ_type)
  return G.GAME.poke_champ_type, G.GAME.poke_champ_next
end

--- The types a Blind is currently fighting with.
poke_gym_active_types = function(center)
  if not center then return nil end
  if center.poke_champion then
    return G.GAME.poke_champ_type, nil
  end
  return center.poke_gym_type, center.poke_gym_type2
end

--- Matchup indicator under each Joker.
local POKE_BADGE_DARK_GREEN = HEX("0e6b2e")
local POKE_BADGE_DARK_RED   = HEX("7c1626")

local function poke_gym_tag_style(mult)
  if mult == 0    then return { label = "X0",        colour = G.C.PURPLE } end
  if mult >= 4    then return { label = "X" .. mult, colour = POKE_BADGE_DARK_GREEN } end
  if mult > 1     then return { label = "X" .. mult, colour = G.C.GREEN } end
  if mult <= 0.25 then return { label = "X" .. mult, colour = POKE_BADGE_DARK_RED } end
  if mult < 1     then return { label = "X" .. mult, colour = G.C.RED } end
  return { label = "-", colour = G.C.GREY }
end

poke_gym_tag_remove = function(card)
  poke_display_clear(card)
end

poke_gym_tag_add = function(card, mult)
  local style = poke_gym_tag_style(mult or 1)
  poke_display_badge(card, style.label, style.colour)
end

--- Bring one Joker in line with the active matchup: scale it, badge it.
poke_gym_apply_joker = function(joker, t1, t2, source)
  if not joker or not joker.ability then return 1 end
  local mult = poke_type_multiplier(joker, t1, t2)
  if mult ~= 0 and mult ~= 1 then
    poke_gym_scale_joker(joker, mult, source)
  else
    -- Neutral and immune change no values.
    poke_gym_unscale_joker(joker)
  end
  poke_gym_tag_add(joker, mult)
  joker.ability.poke_gym_seen = source
  -- Only once the card is past its constructor: recalc_debuff walks the debuff chain.
  if SMODS.recalc_debuff and joker.base then SMODS.recalc_debuff(joker) end
  return mult
end

--- Apply a Leader's matchup across the joker row.
poke_gym_apply = function(gym_type, gym_type2, source)
  local up, down, nulled = 0, 0, 0
  if not (G.jokers and G.jokers.cards) then return up, down, nulled end
  for _, joker in ipairs(G.jokers.cards) do
    local mult = poke_gym_apply_joker(joker, gym_type, gym_type2, source)
    if mult == 0 then nulled = nulled + 1
    elseif mult > 1 then up = up + 1
    elseif mult < 1 then down = down + 1 end
  end
  sendDebugMessage(("Pokermon gym %s%s: %d buffed, %d nerfed, %d nullified")
    :format(tostring(gym_type), gym_type2 and ('/' .. gym_type2) or '',
            up, down, nulled))
  return up, down, nulled
end

--- Take every gym adjustment and indicator back off the row.
poke_gym_clear = function()
  for _, area in ipairs(poke_joker_areas()) do
    for _, joker in ipairs(area.cards or {}) do
      poke_gym_unscale_joker(joker)
      poke_gym_tag_remove(joker)
      if joker.ability then joker.ability.poke_gym_seen = nil end
      if SMODS.recalc_debuff then SMODS.recalc_debuff(joker) end
    end
  end
end

-- The matchup belongs to the ante's BLINDS.

--- The types being fought this ante.
poke_league_ante_types = function(ante)
  local entry = poke_league_entry(ante)
  if not entry then return nil end
  if entry.role == 'champion' then return G.GAME.poke_champ_type, nil end
  local tera = entry.role == 'gym' and poke_challenge_on('terastal') and poke_terastal_type(ante)
  if tera then return tera, nil end
  return entry.gym_type, entry.gym_type2
end

--- Take the matchup off entirely: values to face, badges gone, debuffs re-checked.
poke_gym_teardown = function()
  if not G.GAME then return end
  -- Ownership must drop BEFORE the row is cleared.
  G.GAME.poke_gym_active = nil
  G.GAME.poke_gym_t1, G.GAME.poke_gym_t2 = nil, nil
  poke_gym_clear()
end

--- Bring the joker row in line with the Blind being fought.
poke_gym_sync = function()
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league) then
    if G.GAME and G.GAME.poke_gym_active then poke_gym_teardown() end
    return
  end

  local ante = (G.GAME.round_resets and G.GAME.round_resets.ante) or 1
  local entry = poke_league_entry(ante)
  if entry and entry.role == 'champion' and not G.GAME.poke_champ_type then
    poke_champion_cycle(true)
  end

  local t1, t2 = poke_league_ante_types(ante)
  if not t1 then
    if G.GAME.poke_gym_active then poke_gym_teardown() end
    return
  end

  local source = ante .. ':' .. t1 .. '/' .. tostring(t2)
  if G.GAME.poke_gym_active == source then
    if G.jokers and G.jokers.cards then
      for _, joker in ipairs(G.jokers.cards) do
        -- Unseen: new or rebuilt since the matchup was applied.
        if joker.ability and (joker.ability.poke_gym_seen ~= source
            or not poke_display_has_badge(joker)) then
          poke_gym_apply_joker(joker, t1, t2, source)
        end
      end
    end
    return
  end

  G.GAME.poke_gym_active = source
  G.GAME.poke_gym_t1, G.GAME.poke_gym_t2 = t1, t2
  poke_gym_clear()
  poke_gym_apply(t1, t2, source)
end

--- Force a reapply, for when the types change under a fixed ante.
poke_gym_resync = function()
  G.GAME.poke_gym_active = nil
  poke_gym_sync()
end

--- Re-score one Joker when its own type changed rather than the Leader's.
poke_gym_refresh_joker = function(card)
  if not (G.GAME and G.GAME.poke_gym_active and G.GAME.poke_gym_t1) then return end
  if not (card and card.ability) then return end
  -- Two things have to be true before this card can be touched.
  if not card.base or card.area ~= G.jokers then return end
  poke_gym_unscale_joker(card)
  poke_gym_apply_joker(card, G.GAME.poke_gym_t1, G.GAME.poke_gym_t2,
                       G.GAME.poke_gym_active)
end

--- Brackets can nest - pokermon.backend_evolve calls energize internally.
local poke_gym_mutation_depth = 0

poke_gym_release = function(card)
  poke_gym_mutation_depth = poke_gym_mutation_depth + 1
  if not (G.GAME and G.GAME.poke_gym_active) then return false end
  if not (card and card.ability) then return false end
  poke_gym_unscale_joker(card)
  return true
end

poke_gym_restore = function(card, was_active)
  poke_gym_mutation_depth = math.max(0, poke_gym_mutation_depth - 1)
  if poke_gym_mutation_depth > 0 then return end
  if not was_active then return end
  if not (G.GAME and G.GAME.poke_gym_active) then return end
  if not (card and card.ability) then return end
  poke_gym_apply_joker(card, G.GAME.poke_gym_t1, G.GAME.poke_gym_t2,
                       G.GAME.poke_gym_active)
end

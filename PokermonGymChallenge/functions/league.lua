-- League run flow.

-- How EARLY each generation comes up.
POKE_GEN_WEIGHTS = { [1] = 3, [2] = 2, [3] = 2 }
POKE_GEN_WEIGHT_DEFAULT = 1

-- The full order the nine regions will be played in, drawn once from the seed.
poke_league_gen_sequence = function()
  local cached = G.GAME.poke_gen_sequence
  if cached and #cached >= POKE_LEAGUE_GENS then return cached end

  local order, taken = {}, {}
  for _, gen in ipairs(cached or {}) do
    if POKE_LEAGUE_ROSTER[gen] and not taken[gen] then
      taken[gen] = true
      order[#order + 1] = gen
    end
  end

  local remaining = {}
  for gen = 1, POKE_LEAGUE_GENS do
    if POKE_LEAGUE_ROSTER[gen] and not taken[gen] then remaining[#remaining + 1] = gen end
  end

  while #remaining > 0 do
    local tickets = {}
    for _, gen in ipairs(remaining) do
      for _ = 1, (POKE_GEN_WEIGHTS[gen] or POKE_GEN_WEIGHT_DEFAULT) do
        tickets[#tickets + 1] = gen
      end
    end
    local pick = pseudorandom_element(tickets, pseudoseed('poke_league_gen_' .. #order))
    order[#order + 1] = pick
    for i, gen in ipairs(remaining) do
      if gen == pick then table.remove(remaining, i) break end
    end
  end

  G.GAME.poke_gen_sequence = order
  return order
end

--- The generation played during a given 13-ante step.
poke_league_gen_for_step = function(step)
  step = math.max(0, step or 0)
  local order = poke_league_gen_sequence()
  return order[step + 1] or order[#order] or 1
end

--- Which 13-ante step an ante belongs to.
poke_league_step = function(ante)
  local a = math.max(1, ante or (G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) or 1)
  return math.floor((a - 1) / POKE_LEAGUE_ANTES)
end

--- The label for continuing past a completed generation: New Gen+, ++, +++.
poke_league_next_label = function()
  local step = poke_league_step() + 1
  -- After the ninth region there is no tenth.
  if step >= POKE_LEAGUE_GENS then return localize('b_endless') end
  return 'New Gen' .. string.rep('+', math.max(1, step))
end

-- Carry-over when a generation ends.
local function poke_league_cull(area, keep)
  if not area then return 0 end
  local kept, count = {}, 0
  for _, list in ipairs({ area.highlighted or {}, area.cards }) do
    for _, card in ipairs(list) do
      if count < (keep or 1) and not kept[card] then
        kept[card] = true
        count = count + 1
      end
    end
  end
  local removed = 0
  for i = #area.cards, 1, -1 do
    local card = area.cards[i]
    local eternal = card.ability and card.ability.eternal
    if not kept[card] and not eternal and not card.getting_sliced then
      card.getting_sliced = true
      removed = removed + 1
      G.E_MANAGER:add_event(Event({
        func = function()
          card:start_dissolve({ G.C.PURPLE }, nil, 1.2)
          return true
        end
      }))
    end
  end
  return removed
end

-- Rarities loosen as the League goes on.
POKE_SOUL_RATE_CAP = 10

--- The multiplier on soul-style rates for the generation being played.
poke_soul_rate_mult = function()
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league) then return 1 end
  local step = poke_league_step and poke_league_step() or 0
  return math.min(POKE_SOUL_RATE_CAP, 2 ^ math.max(0, step))
end

-- SMODS reads `soul_rate` straight off the centre when polling.
POKE_SOUL_RATE_KEYS = {
  'c_poke_transformation', 'c_poke_megastone',
  'c_poke_ultraball', 'c_poke_masterball',
}

poke_soul_rate_sync = function()
  if not G.P_CENTERS then return end
  local mult = poke_soul_rate_mult()
  for _, key in ipairs(POKE_SOUL_RATE_KEYS) do
    local center = G.P_CENTERS[key]
    if center and center.soul_rate then
      center.poke_base_soul_rate = center.poke_base_soul_rate or center.soul_rate
      center.soul_rate = math.min(1, center.poke_base_soul_rate * mult)
    end
  end
end

-- Clearing a generation counts as a win.
poke_league_credit_team = function()
  if not (G.jokers and G.jokers.cards and set_joker_win) then return 0 end
  local seeded_ok = SMODS and SMODS.config and SMODS.config.seeded_unlocks
  if (G.GAME.seeded or G.GAME.challenge) and not seeded_ok then return 0 end

  local n = 0
  for _, card in ipairs(G.jokers.cards) do
    if card.config and card.config.center_key and card.ability
        and card.ability.set == 'Joker' then
      n = n + 1
    end
  end
  set_joker_win()
  return n
end

--- Run the transition into a new generation.
poke_league_advance = function(step)
  local gen = poke_league_gen_for_step(step)
  local region = POKE_LEAGUE_ROSTER[gen]
  local credited = poke_league_credit_team()
  local jokers = poke_league_cull(G.jokers, 1 + (G.GAME.poke_daycare or 0))
  G.GAME.poke_daycare = 0
  local consumables = poke_league_cull(G.consumeables)
  local kept, refilled = poke_league_reset_deck()
  local banned = poke_league_ban_hands(step)
  local challenge = poke_challenge_roll(step)

  -- Money is only flagged here.
  G.GAME.poke_gen_money_pending = step

  -- Matchup scaling belongs to the ante that is now behind us.
  if poke_gym_teardown then poke_gym_teardown()
  elseif poke_gym_clear then poke_gym_clear() end

  -- Balatro's own victory screen only ever fires once (see poke_league_check_advance).
  G.E_MANAGER:add_event(Event({
    trigger = 'after',
    delay = 0.6,
    func = function()
      play_sound('win')
      attention_text({
        text = (region and region.region or ('Gen ' .. gen)),
        scale = 1.4, hold = 2,
        major = G.play, backdrop_colour = G.C.PURPLE,
        align = 'cm', offset = { x = 0, y = -1.5 },
      })
      return true
    end
  }))

  sendDebugMessage(('Pokermon League: entering %s (gen %d, step %d) - kept the selected '
    .. 'or leftmost card, culled %d Jokers and %d consumables, credited %d Jokers with the stake, '
    .. 'money capped at %d, kept %d playing cards and dealt %d, banned %s, challenge %s')
    :format(region and region.region or '?', gen, step, jokers, consumables,
            credited, poke_league_money_allowance(step), kept, refilled,
            table.concat(banned, ', '), challenge))
end

-- The deck a new region opens with.
POKE_LEAGUE_DECK_SIZE = 52
POKE_LEAGUE_REFILL_ODDS = { enhancement = 0.25, edition = 0.10, seal = 0.10 }

--- Remember the cards in play and in hand, so the region's last hand survives the reset.
poke_league_record_hand = function()
  if not (G.play and G.hand) then return end
  local ids = {}
  for _, area in ipairs({ G.play, G.hand }) do
    for _, card in ipairs(area.cards) do
      if card.sort_id then ids[#ids + 1] = card.sort_id end
    end
  end
  G.GAME.poke_last_hand_ids = ids
end

--- Keep the last hand played and the cards held beside it, then deal fresh cards up to 52.
poke_league_reset_deck = function()
  if not G.playing_cards then return 0, 0 end
  local keep = {}
  for _, id in ipairs(G.GAME.poke_last_hand_ids or {}) do keep[id] = true end
  G.GAME.poke_last_hand_ids = nil

  local kept = 0
  for i = #G.playing_cards, 1, -1 do
    local card = G.playing_cards[i]
    if keep[card.sort_id] then kept = kept + 1 else card:remove() end
  end

  local suits, ranks = {}, {}
  for _, suit in pairs(SMODS.Suits) do
    if SMODS.add_to_pool(suit, { rank = '' }) then suits[#suits + 1] = suit end
  end
  for _, rank in pairs(SMODS.Ranks) do
    if SMODS.add_to_pool(rank, { suit = '' }) then ranks[#ranks + 1] = rank end
  end
  table.sort(suits, function(a, b) return a.key < b.key end)
  table.sort(ranks, function(a, b) return a.key < b.key end)

  local odds = POKE_LEAGUE_REFILL_ODDS
  local refilled = 0
  -- Negative cards sit on top of the 52.
  local counted = 0
  for _, card in ipairs(G.playing_cards) do
    if not (card.edition and card.edition.negative) then counted = counted + 1 end
  end

  while counted < POKE_LEAGUE_DECK_SIZE do
    local seed = 'pgc_refill' .. G.GAME.round_resets.ante
    local suit = pseudorandom_element(suits, pseudoseed(seed .. 'suit'))
    local rank = pseudorandom_element(ranks, pseudoseed(seed .. 'rank'))
    local center = G.P_CENTERS.c_base
    if pseudorandom(pseudoseed(seed .. 'enh')) < odds.enhancement then
      center = G.P_CENTERS[SMODS.poll_enhancement({ key = seed .. 'enhkey', guaranteed = true })] or center
    end
    local card = create_playing_card({
      front = G.P_CARDS[suit.card_key .. '_' .. rank.card_key], center = center,
    }, G.deck, true, true)
    if pseudorandom(pseudoseed(seed .. 'ed')) < odds.edition then
      card:set_edition(poll_edition(seed .. 'edkey', nil, true, true), true, true)
    end
    if pseudorandom(pseudoseed(seed .. 'seal')) < odds.seal then
      card:set_seal(SMODS.poll_seal({ key = seed .. 'sealkey', guaranteed = true }), true, true)
    end
    refilled = refilled + 1
    counted = counted + 1
  end
  G.deck.config.card_limit = #G.playing_cards
  G.GAME.starting_deck_size = #G.playing_cards
  return kept, refilled
end

--- The banned hand HM Case would return: the most played one.
poke_league_hm_target = function()
  local best, played
  for _, name in ipairs(G.handlist) do
    if poke_league_hand_banned(name) and (not played or G.GAME.hands[name].played > played) then
      best, played = name, G.GAME.hands[name].played
    end
  end
  return best
end

--- Hands the League no longer allows: the run's N most played, N being the New Gen+ count.
poke_league_ban_hands = function(step)
  local ranked = {}
  for i, name in ipairs(G.handlist) do
    local hand = G.GAME.hands[name]
    local returned = G.GAME.poke_hm_hands and G.GAME.poke_hm_hands[name]
    if hand and (hand.played or 0) > 0 and not returned then ranked[#ranked + 1] = { name = name, played = hand.played, order = i } end
  end
  table.sort(ranked, function(a, b)
    if a.played ~= b.played then return a.played > b.played end
    return a.order < b.order
  end)
  local banned, list = {}, {}
  for i = 1, math.min(step or 0, #ranked) do
    banned[ranked[i].name] = true
    list[#list + 1] = ranked[i].name
  end
  G.GAME.poke_banned_hands = banned
  return list
end

--- Whether the League bans a poker hand this region.
poke_league_hand_banned = function(name)
  return G.GAME and G.GAME.poke_banned_hands and G.GAME.poke_banned_hands[name] or false
end

-- How much money a new generation may open with.
POKE_LEAGUE_MONEY_STEP = 25

--- The ceiling for the generation being entered.
poke_league_money_allowance = function(cleared)
  return POKE_LEAGUE_MONEY_STEP * math.max(1, cleared or 1) + (G.GAME.poke_money_cap_bonus or 0)
end

poke_league_money_settle = function()
  if not G.GAME.poke_gen_money_pending then return end
  local cleared = G.GAME.poke_gen_money_pending
  G.GAME.poke_gen_money_pending = nil

  local allowance = poke_league_money_allowance(cleared)
  local over = (G.GAME.dollars or 0) - allowance
  -- ease_dollars carries the animation and the sound.
  if over > 0 then ease_dollars(-over) end
end

--- Fire the transition when the ante crosses into a new generation.
poke_league_check_advance = function()
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league) then return end
  -- Nine regions and no more.
  local step = math.min(POKE_LEAGUE_GENS - 1, poke_league_step())
  local applied = G.GAME.poke_gen_step_applied or 0
  if step > applied then
    G.GAME.poke_gen_step_applied = step
    poke_league_advance(step)
  elseif not G.GAME.poke_gen_step_applied then
    G.GAME.poke_gen_step_applied = step
  end
end

-- The Ante box's label is built ONCE, when the HUD is created.
poke_hud_label_sync = function()
  if not G.GAME then return end
  local league = G.GAME.modifiers and G.GAME.modifiers.poke_league
  local label = (league and poke_league_generation)
    and (localize('poke_hud_gen') .. ' ' .. tostring(poke_league_generation()))
    or localize('k_ante')
  G.GAME.poke_hud_gen_label = label   -- kept for save inspection only
end

poke_hud_round_label = function()
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league) then return nil end
  return localize('poke_hud_trainer')
end

-- Fold the running ante into its position within the generation.
poke_hud_sync_ante = function()
  poke_hud_label_sync()
  if poke_blind_names_sync then poke_blind_names_sync() end
  if not (G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) then return end
  if not (G.GAME.modifiers and G.GAME.modifiers.poke_league) then return end
  local ante = math.max(1, G.GAME.round_resets.ante)
  -- Past the ninth Champion the box counts in vanilla's Endless numbering.
  local within = ante > POKE_LEAGUE_LAST_ANTE
    and (ante - POKE_LEAGUE_LAST_ANTE + POKE_ENDLESS_FIRST - 1)
    or (((ante - 1) % POKE_LEAGUE_ANTES) + 1)
  G.GAME.round_resets.ante_disp = number_format(within)
end

-- Generation-completion pips, shown under the Ante and Round boxes.
POKE_GEN_PIPS = 9

poke_gen_badge_row = function()
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league) then return nil end
  -- SMODS.get_atlas is a plain lookup in G.ASSET_ATLAS - it does NOT prefix.
  local prefix = (SMODS.current_mod and SMODS.current_mod.prefix) or 'pgc'
  local atlas = SMODS.get_atlas and (SMODS.get_atlas(prefix .. '_poke_gen_badges')
                                     or SMODS.get_atlas('poke_gen_badges'))
  if not atlas then return nil end

  -- At texture_scaling 2 the game sets the sprite filter to LINEAR (game.lua:1029).
  if atlas.image and atlas.image.setFilter and not atlas.poke_nearest then
    atlas.image:setFilter('nearest', 'nearest')
    atlas.poke_nearest = true
  end
  -- The pips are built once, when the HUD is.
  local pips, sprites = {}, {}
  for _ = 1, POKE_GEN_PIPS do
    local spr = Sprite(0, 0, 0.26, 0.26, atlas, { x = 0, y = 0 })
    spr.states.hover.can = false
    spr.states.click.can = false
    spr.states.visible = false
    sprites[#sprites + 1] = spr
    pips[#pips + 1] = { n = G.UIT.C, config = { align = 'cm', padding = 0.008 },
                        nodes = { { n = G.UIT.O, config = { object = spr } } } }
  end

  G.FUNCS.poke_gen_pips_update = G.FUNCS.poke_gen_pips_update or function(e)
    local row = e.config.ref_table
    if not row then return end
    local done = math.min(POKE_GEN_PIPS, poke_league_step and poke_league_step() or 0)
    -- The pip wears the Ball of the stake being played.
    local stake = G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake
      and G.P_CENTER_POOLS.Stake[G.GAME.stake or 1]
    local ball = (stake and stake.atlas == row.prefix .. '_pokeball_stakes'
                  and stake.pos and stake.pos.x) or 0
    for i, spr in ipairs(row.sprites) do
      spr.states.visible = done > 0
      local col = i <= done and 1 or 0
      if spr.poke_col ~= col or spr.poke_row ~= ball then
        spr.poke_col, spr.poke_row = col, ball
        spr:set_sprite_pos({ x = col, y = ball })
      end
    end
  end

  return { n = G.UIT.R, nodes = pips,
           config = { align = 'cm', padding = 0.05,
                      func = 'poke_gen_pips_update',
                      ref_table = { sprites = sprites, prefix = prefix } } }
end

-- The victory screen's continue button, with a popup spelling out the trade.
poke_gen_button = function()
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league) then return nil end
  local node = UIBox_button({
    button = 'exit_overlay_menu',
    label = { poke_league_next_label and poke_league_next_label() or localize('b_endless') },
    minw = 6.5, maxw = 5, minh = 1.2, scale = 0.7, shadow = true, colour = G.C.BLUE,
    focus_args = { nav = 'wide', button = 'x', set_button_pip = true },
  })
  -- UIBox_button returns a wrapper whose FIRST child carries `hover = true`.
  local hot = node.nodes and node.nodes[1] or node
  hot.config.h_popup = create_popup_UIBox_tooltip({
    title = poke_league_next_label and poke_league_next_label() or localize('b_endless'),
    text = {
      localize('poke_gen_tip_1'),
      localize('poke_gen_tip_2'),
      localize('poke_gen_tip_2b'),
      localize('poke_gen_tip_3'),
      localize('poke_gen_tip_4'),
      localize('poke_gen_tip_5'),
      localize('poke_gen_tip_6'),
    },
  })
  hot.config.h_popup_config = { align = 'tm', offset = { x = 0, y = -0.1 }, parent = hot }
  return node
end

-- Repair Blind keys saved by an earlier build.
poke_league_migrate_keys = function()
  if not (G.GAME and G.P_BLINDS) then return end

  local renamed = { bl_pgc_g1oak = 'bl_pgc_g1blue' }
  local function remap(key)
    if type(key) ~= 'string' or G.P_BLINDS[key] then return key end
    if renamed[key] and G.P_BLINDS[renamed[key]] then return renamed[key] end
    local suffix = key:match('^bl_poke_(.+)$')
    local moved = suffix and ((PGC_BLIND_PREFIX or 'bl_pgc_') .. suffix)
    if moved and G.P_BLINDS[moved] then return moved end
    return nil                       -- unresolvable; caller decides
  end

  local moved, dropped = 0, 0
  local rr = G.GAME.round_resets
  if rr and rr.blind_choices then
    for slot, key in pairs(rr.blind_choices) do
      local fixed = remap(key)
      if fixed and fixed ~= key then
        rr.blind_choices[slot] = fixed
        moved = moved + 1
      elseif not fixed then
        -- Leave the slot alone rather than nil it out; only the Boss is ours to regenerate.
        dropped = dropped + 1
      end
    end
    -- The Boss is the one the roster owns.
    if not (rr.blind_choices.Boss and G.P_BLINDS[rr.blind_choices.Boss])
        and G.GAME.modifiers and G.GAME.modifiers.poke_league then
      rr.blind_choices.Boss = get_new_boss()
    end
  end

  -- SMODS keeps bosses_used split by Blind type.
  local used = G.GAME.bosses_used
  local tables = {}
  local function add(t) if type(t) == 'table' then tables[#tables + 1] = t end end
  add(G.GAME.perscribed_bosses)
  if type(used) == 'table' and (type(used.boss) == 'table' or type(used.small) == 'table' or type(used.big) == 'table') then
    add(used.boss); add(used.small); add(used.big)
  else
    add(used)
  end
  for _, tbl in ipairs(tables) do
    do
      for k, v in pairs(tbl) do
        local fk = remap(type(k) == 'string' and k or nil)
        if type(k) == 'string' and fk ~= k then tbl[k] = nil; if fk then tbl[fk] = v end end
        local fv = remap(type(v) == 'string' and v or nil)
        if type(v) == 'string' and fv ~= v then tbl[k] = fv end
      end
    end
  end

  if moved > 0 or dropped > 0 then
    sendDebugMessage(('Gym Challenge: migrated %d Blind key(s), dropped %d')
      :format(moved, dropped))
  end
end

-- Whether the next Cash Out will cross into a new generation.
poke_league_transition_pending = function()
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league) then return false end
  local step = poke_league_step()
  return step > 0 and (G.GAME.poke_gen_step_applied or 0) < step
end

-- Relabel the Cash Out button when pressing it will end the region.
POKE_VANILLA_CASH_OUT = nil

poke_cash_out_label_sync = function()
  local dict = G.localization and G.localization.misc and G.localization.misc.dictionary
  if not (dict and dict.b_cash_out) then return end
  POKE_VANILLA_CASH_OUT = POKE_VANILLA_CASH_OUT or dict.b_cash_out
  local pending = poke_league_transition_pending and poke_league_transition_pending()
  dict.b_cash_out = pending and localize('poke_cash_out_warn') or POKE_VANILLA_CASH_OUT
end

-- Hang the transition details on the Cash Out button.
poke_cash_out_popup = function()
  if not (poke_league_transition_pending and poke_league_transition_pending()) then return end
  if not (G.I and G.I.UIBOX) then return end
  for _, box in ipairs(G.I.UIBOX) do
    local node = box.get_UIE_by_ID and box:get_UIE_by_ID('cash_out_button')
    if node and node.config and not node.config.h_popup then
      node.config.h_popup = create_popup_UIBox_tooltip({
        title = localize('poke_cash_out_warn'),
        text = poke_league_transition_lines(),
      })
      node.config.h_popup_config = { align = 'tm', offset = { x = 0, y = -0.1 }, parent = node }
      return true
    end
  end
end

--- The lines shown on the New Gen+ button and on the Cash Out button.
poke_league_transition_lines = function()
  return {
    localize('poke_gen_tip_1'), localize('poke_gen_tip_2'),
    localize('poke_gen_tip_2b'),
    localize('poke_gen_tip_3'), localize('poke_gen_tip_4'),
    localize('poke_gen_tip_4b'), localize('poke_gen_tip_4c'), localize('poke_gen_tip_4d'),
    localize('poke_gen_tip_5'),
  }
end

-- Rename the Small and Big Blinds to the trainers standing between you and the Leader.
POKE_VANILLA_BLIND_NAMES = nil

-- Small and Big Blind CHIPS for the ante, alongside their names.
POKE_VANILLA_BLIND_CHIPS = nil

poke_blind_chips_sync = function(entry)
  local small, big = G.P_BLINDS and G.P_BLINDS.bl_small, G.P_BLINDS and G.P_BLINDS.bl_big
  if not (small and big) then return end

  POKE_VANILLA_BLIND_CHIPS = POKE_VANILLA_BLIND_CHIPS or {
    small = { atlas = small.atlas, pos = small.pos },
    big   = { atlas = big.atlas,   pos = big.pos },
  }

  local col = entry and POKE_TYPE_CHIP_COL and POKE_TYPE_CHIP_COL[entry.gym_type]
  if not col then
    small.atlas, small.pos = POKE_VANILLA_BLIND_CHIPS.small.atlas, POKE_VANILLA_BLIND_CHIPS.small.pos
    big.atlas,   big.pos   = POKE_VANILLA_BLIND_CHIPS.big.atlas,   POKE_VANILLA_BLIND_CHIPS.big.pos
    return
  end

  local prefix = (SMODS.current_mod and SMODS.current_mod.prefix) or 'pgc'
  local atlas = prefix .. '_AtlasTrainerBlinds'
  small.atlas, small.pos = atlas, { x = col, y = 0 }
  big.atlas,   big.pos   = atlas, { x = col, y = 1 }
end

poke_blind_names_sync = function()
  local dict = G.localization and G.localization.misc
    and G.localization.misc.dictionary
  local desc = G.localization and G.localization.descriptions
    and G.localization.descriptions.Blind
  if not (desc and desc.bl_small and desc.bl_big) then return end

  if dict and not POKE_VANILLA_PROMPT then
    POKE_VANILLA_PROMPT = { dict.ph_choose_blind_1, dict.ph_choose_blind_2 }
  end
  if dict and POKE_VANILLA_PROMPT then
    local league = G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league
    dict.ph_choose_blind_1 = league and localize('poke_choose_1') or POKE_VANILLA_PROMPT[1]
    dict.ph_choose_blind_2 = league and localize('poke_choose_2') or POKE_VANILLA_PROMPT[2]
  end

  POKE_VANILLA_BLIND_NAMES = POKE_VANILLA_BLIND_NAMES
    or { small = desc.bl_small.name, big = desc.bl_big.name }

  local league = G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league
  local entry = league and poke_league_entry
    and poke_league_entry(G.GAME.round_resets and G.GAME.round_resets.ante)
  if poke_challenge_blind_sync then poke_challenge_blind_sync(entry) end
  -- Fog hides the type-coloured chips and type-named trainers too.
  if not entry or poke_fog_hidden(entry) then
    desc.bl_small.name = POKE_VANILLA_BLIND_NAMES.small
    desc.bl_big.name   = poke_crowd_name() or POKE_VANILLA_BLIND_NAMES.big
    poke_blind_chips_sync(nil)
    return
  end

  poke_blind_chips_sync(entry)
  local pair = POKE_TRAINER_CLASSES[entry.gym_type]
  local small, big
  if entry.role == 'champion' then
    small, big = POKE_CHAMPION_TRAINERS[1], POKE_CHAMPION_TRAINERS[2]
  elseif entry.role == 'elite' then
    -- keeps the member's own type for the Small, takes a rising rank for the Big.
    local step = ((entry.ante or 9) - 9) % #POKE_ELITE_RANKS + 1
    small = (pair and pair[1]) or POKE_ELITE_RANKS[1]
    big   = POKE_ELITE_RANKS[step]
  else
    small = pair and pair[1] or POKE_VANILLA_BLIND_NAMES.small
    big   = pair and pair[2] or POKE_VANILLA_BLIND_NAMES.big
  end
  desc.bl_small.name = small
  desc.bl_big.name   = poke_crowd_name() or big
end

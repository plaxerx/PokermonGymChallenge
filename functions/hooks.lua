-- Base-game and Pokermon hooks for the Gym Challenge.
local set_edition = Card.set_edition
function Card:set_edition(edition, immediate, silent)
  if (edition and edition == "e_poke_shiny" and not pokermon_config.shiny_playing_cards) and (self.ability.set ~= 'Joker' and self.ability.set ~= 'Edition') then return end
  local ret = set_edition(self, edition, immediate, silent)

  -- Master Ball is a team of six, full stop.
  local caps_jokers = G.GAME and G.GAME.modifiers
    and G.GAME.modifiers.poke_no_negative_slots
  -- Belt and braces: the set check is the real invariant (consumables are 'Tarot'/'Planet'/'Spectral'/'Item', playing cards 'Default'/'Enhanced').
  local is_joker_row = self.ability and self.ability.set == 'Joker'
    and not (self.area and (self.area == G.consumeables or self.area == G.hand))

  if caps_jokers and is_joker_row
      and self.edition and self.edition.negative
      and (self.edition.card_limit or 0) > 0 then
    self.ability.card_limit = (self.ability.card_limit or 0) - self.edition.card_limit
    self.edition.card_limit = 0
  end

  return ret
end
--- League runs also replace the blind curve past ante 8.
poke_vanilla_blind_amount = get_blind_amount
local poke_old_get_blind_amount = poke_vanilla_blind_amount
function get_blind_amount(ante)
  if G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league then
    return poke_league_blind_amount(ante)
  end
  return poke_old_get_blind_amount(ante)
end

-- Blind-select wording is resolved when the screen is BUILT.
local poke_blind_choice_ref = create_UIBox_blind_choice
function create_UIBox_blind_choice(...)
  if poke_blind_names_sync then poke_blind_names_sync() end
  return poke_blind_choice_ref(...)
end

local poke_blind_select_ref = create_UIBox_blind_select
function create_UIBox_blind_select(...)
  if poke_blind_names_sync then poke_blind_names_sync() end
  return poke_blind_select_ref(...)
end

local poke_reset_blinds_ref = reset_blinds
function reset_blinds()
  poke_reset_blinds_ref()
  local states = G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states
  if not states then return end

  local entry = G.GAME.modifiers and G.GAME.modifiers.poke_league
    and poke_league_entry and poke_league_entry(G.GAME.round_resets.ante)

  if entry and (entry.role == 'elite' or entry.role == 'champion') then
    states.Small = 'Hide'
    states.Big = 'Hide'
    G.GAME.blind_on_deck = 'Boss'
  else
    -- Restored on the way back down.
    if states.Small == 'Hide' then states.Small = 'Upcoming' end
    if states.Big == 'Hide' then states.Big = 'Upcoming' end
  end
end

-- The Ball stakes' Ante box counts within the generation.
local poke_ease_ante_ref = ease_ante
function ease_ante(mod)
  poke_ease_ante_ref(mod)
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league) then return end
  G.E_MANAGER:add_event(Event({
    trigger = 'immediate',
    func = function()
      if poke_hud_sync_ante then poke_hud_sync_ante() end
      return true
    end
  }))
end

-- SMODS draws every Blind through get_new_blind; the League owns the Boss slot.
local poke_get_new_blind_ref = SMODS.get_new_blind
SMODS.get_new_blind = function(blind_type)
  if (blind_type or 'boss') == 'boss' and G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league then
    local key = poke_league_boss_key(G.GAME.round_resets and G.GAME.round_resets.ante)
    if key and G.P_BLINDS[key] then
      local used = G.GAME.bosses_used
      if type(used) == 'table' then
        local tbl = type(used.boss) == 'table' and used.boss or used
        tbl[key] = (tbl[key] or 0) + 1
      end
      -- Clear any stale prescription for this ante so it can't fire later.
      if G.GAME.perscribed_bosses then
        G.GAME.perscribed_bosses[G.GAME.round_resets.ante] = nil
      end
      return key
    end
    sendDebugMessage("Pokermon League: no Blind for ante "
      .. tostring(G.GAME.round_resets and G.GAME.round_resets.ante) .. ", falling back")
  end
  return poke_get_new_blind_ref(blind_type)
end

-- On Ball stakes the only eligible Boss Blinds are the League's own.
local poke_add_to_pool_ref = SMODS.add_to_pool
SMODS.add_to_pool = function(prototype_obj, args)
  if G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_only_content
      and prototype_obj and prototype_obj.boss and prototype_obj.key
      and G.P_BLINDS[prototype_obj.key] and not prototype_obj.key:find('^bl_pgc_') then
    return false
  end
  return poke_add_to_pool_ref(prototype_obj, args)
end

-- Great Ball stake: Jokers in the shop cost more.
local card_set_cost_old = Card.set_cost
function Card:set_cost()
  card_set_cost_old(self)
  local bump = G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_joker_cost_up
  if bump and self.ability and self.ability.set == 'Joker' and (self.cost or 0) > 0 then
    self.cost = self.cost + bump
    self.sell_cost_label = self.facing == 'back' and '?' or self.sell_cost
  end
end

-- To support Debris sleeve combo.
local card_set_ability_old = Card.set_ability
function Card:set_ability(center, initial, delay_sprites)
  if G.GAME.modifiers.negative_hazards and self.config.center and self.config.center.key == "m_poke_hazard" and self.ability and self.ability.card_limit then
      self.ability.card_limit = self.ability.card_limit - 1
  end
  -- The final-evolution bonus marker lives on `ability`.
  local keep_final_bonus = self.ability and self.ability.poke_final_bonus
  local ret = card_set_ability_old(self, center, initial, delay_sprites)
  if keep_final_bonus and self.ability and not self.ability.poke_final_bonus then
      self.ability.poke_final_bonus = keep_final_bonus
  end
  if G.GAME.modifiers.negative_hazards and self.config.center and self.config.center.key == "m_poke_hazard" then
      if not self.ability then self.ability = {} end
      self.ability.card_limit = (self.ability.card_limit or 0) + 1
  end
  return ret
end

-- Gym matchup lifecycle hooks.
local poke_cash_out_ref = G.FUNCS.cash_out
G.FUNCS.cash_out = function(e)
  if poke_gym_teardown then poke_gym_teardown() end
  -- The generation crossing happens HERE, on the Cash Out press.
  if poke_league_check_advance then poke_league_check_advance() end
  local ret = poke_cash_out_ref(e)

  -- Settle the new generation's money AFTER vanilla has paid out.
  G.E_MANAGER:add_event(Event({
    trigger = 'immediate',
    func = function()
      if poke_league_money_settle then poke_league_money_settle() end
      return true
    end
  }))
  return ret
end

-- Immunity covers the whole ante, not just the Boss.
function SMODS.current_mod.set_debuff(card)
  if G.GAME and G.GAME.poke_gym_active and G.GAME.poke_gym_t1
      and card.area == G.jokers then
    if poke_type_multiplier(card, G.GAME.poke_gym_t1, G.GAME.poke_gym_t2) == 0 then
      return true
    end
  end
  if poke_challenge_debuff and poke_challenge_debuff(card) then return true end
end

-- Permanent changes made during a live matchup act on FACE values.
local poke_energize_ref = pokermon.energy.energize
pokermon.energy.energize = function(card, etype, evolving, silent, amount, center)
  local live = poke_gym_release and poke_gym_release(card)
  poke_energize_ref(card, etype, evolving, silent, amount, center)
  if poke_gym_restore then poke_gym_restore(card, live) end
end

local poke_backend_evolve_ref = pokermon.backend_evolve
pokermon.backend_evolve = function(card, to_key, energize_amount)
  local live = poke_gym_release and poke_gym_release(card)
  -- The final-evolution hand size travels with the evolution.
  poke_remove_final_h(card)
  poke_backend_evolve_ref(card, to_key, energize_amount)
  poke_apply_final_h(card)
  if poke_gym_restore then poke_gym_restore(card, live) end
end

-- Fully-evolved Pokemon from resource lines grant a little more.
local poke_final_grant = {
  h_size = function(n) if G.hand then G.hand:change_size(n) end end,
  hands = function(n)
    G.GAME.round_resets.hands = G.GAME.round_resets.hands + n
    if n >= 0 then ease_hands_played(n) else pokermon.ease_hands_played(n) end
  end,
  d_size = function(n)
    G.GAME.round_resets.discards = G.GAME.round_resets.discards + n
    ease_discard(n)
  end,
}
poke_final_grant.discards = poke_final_grant.d_size

poke_apply_final_h = function(card)
  if not card or not card.ability or card.ability.poke_final_bonus then return end
  local center = card.config and card.config.center
  local targets = center and POKE_FINAL_BONUS and POKE_FINAL_BONUS[center.key]
  if not targets then return end
  local extra = (center.config and type(center.config.extra) == 'table')
    and center.config.extra or {}
  local paid = nil
  for field, total in pairs(targets) do
    local bonus = math.max(0, total - (tonumber(extra[field]) or 0))
    if bonus > 0 and poke_final_grant[field] then
      poke_final_grant[field](bonus)
      paid = paid or {}
      paid[field] = bonus
    end
  end
  card.ability.poke_final_bonus = paid
end

poke_remove_final_h = function(card)
  if not card or not card.ability or not card.ability.poke_final_bonus then return end
  local paid = card.ability.poke_final_bonus
  card.ability.poke_final_bonus = nil
  for field, bonus in pairs(paid) do
    if poke_final_grant[field] then poke_final_grant[field](-bonus) end
  end
end

local poke_add_to_deck_ref = Card.add_to_deck
function Card:add_to_deck(from_debuff)
  poke_add_to_deck_ref(self, from_debuff)
  poke_apply_final_h(self)
end

local poke_remove_from_deck_ref = Card.remove_from_deck
function Card:remove_from_deck(from_debuff)
  poke_remove_from_deck_ref(self, from_debuff)
  poke_remove_final_h(self)
end

-- Mod-level callbacks. reset_game_globals runs at round evaluation.
function SMODS.current_mod.reset_game_globals(run_start)
  if poke_soul_rate_sync then poke_soul_rate_sync() end
  if poke_hud_sync_ante then poke_hud_sync_ante() end
end

function SMODS.current_mod.calculate(self, context)
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league) then return end

  -- Excluded vouchers carry no weight in SMODS's weighted pools.
  if context.modify_weights and context.pool and POKE_EXCLUDED_VOUCHERS then
    for _, key in ipairs(POKE_EXCLUDED_VOUCHERS) do
      if context.pool[key] then context.pool[key].weight = 0 end
    end
    -- PC Box and Shiny Charm.
    if context.pool.e_negative then context.pool.e_negative.weight = context.pool.e_negative.weight * (G.GAME.poke_negative_mult or 1) end
    if context.pool.e_poke_shiny then context.pool.e_poke_shiny.weight = context.pool.e_poke_shiny.weight * (G.GAME.poke_shiny_mult or 1) end
  end

  if context.create_shop_card then return poke_legendary_shop_flags(context) end

  if context.debuff_hand and poke_league_hand_banned(context.scoring_name) then
    return { debuff = true, debuff_text = localize('poke_hand_banned') }
  end

  if context.before and not context.blueprint then poke_league_record_hand() end

  if context.setting_blind or context.drawing_cards then
    if poke_gym_sync then poke_gym_sync() end
  end

  -- Warn on the score screen.
  if context.round_eval then
    -- Relabels the Cash Out button itself while a press would end the region.
    if poke_cash_out_label_sync then poke_cash_out_label_sync() end

    if poke_league_transition_pending and poke_league_transition_pending() then
      -- The button does not exist yet when round_eval fires.
      G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.5, func = function()
        if poke_cash_out_popup then poke_cash_out_popup() end
        return true
      end }))
      G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.4, func = function()
        -- Anchored to the score screen, not G.play.
        attention_text({
          text = localize('poke_gen_warn'),
          scale = 0.9, hold = 6, major = G.round_eval or G.play,
          backdrop_colour = G.C.PURPLE,
          align = 'cm', offset = { x = 0, y = -2.2 },
        })
        return true
      end }))
    end
  end

  -- Champions reroll their type after every hand.
  if context.after and not context.blueprint and poke_champion_cycle then
    local entry = poke_league_entry(G.GAME.round_resets and G.GAME.round_resets.ante)
    if entry and entry.role == 'champion' then
      poke_champion_cycle(false)
      poke_gym_resync()
    elseif entry and entry.role == 'gym' and poke_challenge_on('terastal')
        and G.GAME.blind and G.GAME.blind.boss then
      poke_terastal_cycle()
      poke_gym_resync()
    end
  end

  return poke_challenge_calculate(context)
end

-- Banned hands are greyed out in Run Info.
local function poke_grey_node(node)
  if type(node) ~= 'table' then return end
  local c = node.config
  if c then
    if node.n == G.UIT.T then c.colour = G.C.UI.TEXT_INACTIVE
    elseif c.colour and c.colour ~= G.C.CLEAR then c.colour = G.C.UI.BACKGROUND_INACTIVE end
    if c.outline_colour then c.outline_colour = G.C.UI.TEXT_INACTIVE end
  end
  for _, child in ipairs(node.nodes or {}) do poke_grey_node(child) end
end

local poke_hand_row_ref = create_UIBox_current_hand_row
function create_UIBox_current_hand_row(handname, simple, in_collection)
  local row = poke_hand_row_ref(handname, simple, in_collection)
  if row and not in_collection and poke_league_hand_banned(handname) then poke_grey_node(row) end
  return row
end

-- Run the save migration once the run exists.
local pgc_start_run = Game.start_run
function Game:start_run(args)
  local ret = pgc_start_run(self, args)
  if poke_league_migrate_keys then poke_league_migrate_keys() end
  return ret
end

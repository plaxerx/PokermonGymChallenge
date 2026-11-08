-- Gym Leader boss effects, framed as Pokemon status conditions.

POKE_GYM_EFFECTS = {}

local function effect(key, def)
  def.key = key
  POKE_GYM_EFFECTS[key] = def
  return def
end

-- ---------------------------------------------------------------- pure data

--- The Wall.
effect('fortress', {
  status = 'Fortress', colour = 'attention', text = { 'Very large Blind' },
  mult = 4,
  disable = function(self, blind)
    blind.chips = blind.chips / 2
    blind.chip_text = number_format(blind.chips)
  end,
})

--- The Plant.
effect('wither', {
  status = 'Wither', colour = 'gym_grass', text = { 'All face cards are debuffed' },
  config = { is_face = 'face' },
})

--- The Psychic.
effect('focus', {
  status = 'Focus', colour = 'blue', text = { 'Must play {C:attention}5{} cards' },
  config = { h_size_ge = 5 },
})

--- The Club / Goad / Head / Window.
for suit, label in pairs({ Clubs = 'Clubs', Spades = 'Spades',
                           Hearts = 'Hearts', Diamonds = 'Diamonds' }) do
  effect('seal_' .. suit:lower(), {
    status = 'Seal', colour = 'attention', text = { 'All {C:attention}' .. label .. '{} cards are debuffed' },
    config = { suit = suit },
  })
end

-- ------------------------------------------------------- one-shot on setting

-- The Manacle.
effect('freeze', {
  status = 'Freeze', colour = 'gym_ice', text = { '{C:attention}-1{} hand size' },
  set_blind = function(self, blind) G.hand:change_size(-1) end,
  defeat    = function(self, blind)
    if not blind.disabled then G.hand:change_size(1) end
  end,
  disable   = function(self, blind) G.hand:change_size(1) end,
})

--- The Water.
effect('drought', {
  status = 'Drought', colour = 'gym_water', text = { 'Start with {C:attention}0{} discards' },
  set_blind = function(self, blind)
    blind.poke_discards_sub = G.GAME.current_round.discards_left
    ease_discard(-blind.poke_discards_sub)
  end,
  disable = function(self, blind)
    ease_discard(blind.poke_discards_sub or 0)
  end,
})

--- The Needle.
effect('constrict', {
  status = 'Constrict', colour = 'red', text = { 'Play only {C:attention}1{} hand' },
  set_blind = function(self, blind)
    blind.poke_hands_sub = G.GAME.round_resets.hands - 1
    ease_hands_played(-blind.poke_hands_sub)
  end,
  disable = function(self, blind)
    ease_hands_played(blind.poke_hands_sub or 0)
  end,
})

-- ------------------------------------------------------------ scoring hooks

--- The Flint.
effect('burn', {
  status = 'Burn', colour = 'gym_fire', text = { 'Base Chips and Mult are {C:attention}halved' },
  modify_hand = function(self, blind, cards, poker_hands, text, mult, hand_chips)
    blind.triggered = true
    return math.max(math.floor(mult * 0.5 + 0.5), 1),
           math.max(math.floor(hand_chips * 0.5 + 0.5), 0), true
  end,
})

--- The Tooth.
effect('poison', {
  status = 'Poison', colour = 'gym_poison', text = { 'Lose {C:money}$1{} per card played' },
  press_play = function(self, blind)
    G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.2, func = function()
      for i = 1, #G.play.cards do
        G.E_MANAGER:add_event(Event({ func = function()
          G.play.cards[i]:juice_up(); return true
        end }))
        ease_dollars(-1)
        delay(0.23)
      end
      return true
    end }))
    blind.triggered = true
    return true
  end,
})

-- The Arm.
effect('weaken', {
  status = 'Weaken', colour = 'gym_fighting', text = { 'Decrease level of played poker hand' },
  debuff_hand = function(self, blind, cards, hand, handname, check)
    blind.triggered = false
    if G.GAME.hands[handname] and G.GAME.hands[handname].level > 1 then
      blind.triggered = true
      if not check then
        level_up_hand(blind.children.animatedSprite, handname, nil, -1)
        blind:wiggle()
      end
    end
  end,
})

-- The Ox.
effect('leech', {
  status = 'Leech', colour = 'money',
  text = { 'Playing {C:attention}#1#{}', 'sets money to {C:money}$0' },
  -- Guarded: Blind descriptions also render in the collection.
  vars = function(blind)
    local most = G.GAME and G.GAME.current_round
      and G.GAME.current_round.most_played_poker_hand
    return { most and localize(most, 'poker_hands') or localize('High Card', 'poker_hands') }
  end,
  debuff_hand = function(self, blind, cards, hand, handname, check)
    blind.triggered = false
    if handname == G.GAME.current_round.most_played_poker_hand then
      blind.triggered = true
      if not check then
        ease_dollars(-G.GAME.dollars, true)
        blind:wiggle()
      end
    end
  end,
})

-- --------------------------------------------------------------- face down

--- Vanilla unflips and clears `wheel_flipped` in `Blind:disable`.
local function flip_cleanup(self, blind)
  for i = 1, #G.hand.cards do
    if G.hand.cards[i].facing == 'back' then G.hand.cards[i]:flip() end
  end
  for _, v in pairs(G.playing_cards) do v.ability.wheel_flipped = nil end
end

--- The House.
effect('sleep', {
  status = 'Sleep', colour = 'inactive', text = { 'First hand is drawn face down' },
  stay_flipped = function(self, blind, area, card)
    return area == G.hand
       and G.GAME.current_round.hands_played == 0
       and G.GAME.current_round.discards_used == 0
  end,
  defeat = flip_cleanup, disable = flip_cleanup,
})

-- The Wheel.
effect('confuse', {
  status = 'Confusion', colour = 'gym_psychic',
  text = { '{C:attention}#1#{} in {C:attention}#2#{} cards drawn face down' },
  vars = function(blind)
    if blind and SMODS.get_probability_vars then
      local n, d = SMODS.get_probability_vars(blind, 1, 7, 'wheel')
      return { n, d }
    end
    return { 1, 7 }
  end,
  stay_flipped = function(self, blind, area, card)
    if area ~= G.hand then return false end
    if SMODS.pseudorandom_probability then
      return SMODS.pseudorandom_probability(blind, pseudoseed('poke_confuse'), 1, 7, 'wheel')
    end
    return pseudorandom('poke_confuse') < 1 / 7
  end,
  defeat = flip_cleanup, disable = flip_cleanup,
})

--- The Mark.
effect('shroud', {
  status = 'Shroud', colour = 'gym_ghost', text = { 'All face cards are drawn face down' },
  stay_flipped = function(self, blind, area, card)
    return area == G.hand and card:is_face(true)
  end,
  defeat = flip_cleanup, disable = flip_cleanup,
})

-- --------------------------------------------------------------- stateful

-- Cerulean Bell.
effect('attract', {
  status = 'Attract', colour = 'pink', text = { 'Forces {C:attention}1{} card to always be selected' },
  drawn_to_hand = function(self, blind)
    local any_forced = nil
    for k, v in ipairs(G.hand.cards) do
      if v.ability.forced_selection then any_forced = true end
    end
    if not any_forced then
      G.hand:unhighlight_all()
      local forced_card = pseudorandom_element(G.hand.cards, pseudoseed('poke_attract'))
      if forced_card then
        forced_card.ability.forced_selection = true
        G.hand:add_to_highlighted(forced_card)
      end
    end
  end,
  -- Vanilla clears on disable only; we also clear on defeat (see file header).
  defeat = function(self, blind)
    for k, v in ipairs(G.playing_cards) do v.ability.forced_selection = nil end
  end,
  disable = function(self, blind)
    for k, v in ipairs(G.playing_cards) do v.ability.forced_selection = nil end
  end,
})

-- Crimson Heart.
effect('paralyse', {
  status = 'Paralysis', colour = 'gym_electric', text = { '{C:attention}1{} random Joker disabled', 'each hand' },
  press_play = function(self, blind)
    if G.jokers.cards[1] then
      blind.triggered = true
      blind.prepped = true
    end
  end,
  drawn_to_hand = function(self, blind)
    if not (blind.prepped and G.jokers.cards[1]) then return end
    local prev_chosen_set = {}
    local fallback_jokers = {}
    local jokers = {}
    for i = 1, #G.jokers.cards do
      if G.jokers.cards[i].ability.poke_paralysed then
        prev_chosen_set[G.jokers.cards[i]] = true
        G.jokers.cards[i].ability.poke_paralysed = nil
        if G.jokers.cards[i].debuff then SMODS.recalc_debuff(G.jokers.cards[i]) end
      end
    end
    for i = 1, #G.jokers.cards do
      if not G.jokers.cards[i].debuff then
        if not prev_chosen_set[G.jokers.cards[i]] then
          jokers[#jokers + 1] = G.jokers.cards[i]
        end
        table.insert(fallback_jokers, G.jokers.cards[i])
      end
    end
    if #jokers == 0 then jokers = fallback_jokers end
    local _card = pseudorandom_element(jokers, pseudoseed('poke_paralyse'))
    if _card then
      _card.ability.poke_paralysed = true
      SMODS.recalc_debuff(_card)
      _card:juice_up()
      blind:wiggle()
    end
  end,
  recalc_debuff = function(self, blind, card, from_blind)
    if card.area == G.jokers and card.ability.poke_paralysed then return true end
    return false
  end,
  defeat = function(self, blind)
    if not G.jokers then return end
    for _, v in ipairs(G.jokers.cards) do
      v.ability.poke_paralysed = nil
      SMODS.recalc_debuff(v)
    end
  end,
  disable = function(self, blind)
    if not G.jokers then return end
    for _, v in ipairs(G.jokers.cards) do
      v.ability.poke_paralysed = nil
      SMODS.recalc_debuff(v)
    end
  end,
})

-- The Hook.
effect('swarm', {
  status = 'Swarm', colour = 'gym_bug', text = { 'Discards {C:attention}2{} random cards', 'per hand played' },
  press_play = function(self, blind)
    G.E_MANAGER:add_event(Event({ func = function()
      local any_selected = nil
      local _cards = {}
      for k, v in ipairs(G.hand.cards) do
        _cards[#_cards + 1] = v
      end
      for i = 1, 2 do
        if G.hand.cards[i] then
          local selected_card, card_key = pseudorandom_element(_cards, pseudoseed('poke_swarm'))
          G.hand:add_to_highlighted(selected_card, true)
          table.remove(_cards, card_key)
          any_selected = true
          play_sound('card1', 1)
        end
      end
      if any_selected then G.FUNCS.discard_cards_from_highlighted(nil, true) end
      return true
    end }))
    blind.triggered = true
    delay(0.7)
    return true
  end,
})

--- Look up the effect a Blind should carry, or nil.
poke_gym_effect = function(key)
  return key and POKE_GYM_EFFECTS[key] or nil
end

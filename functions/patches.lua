-- Changes to Pokermon's own content, applied additively.

local function centre(key)
  return G.P_CENTERS and G.P_CENTERS[key]
end

-- ---------------------------------------------------------------- Suicune
-- Suicune purifies water.
local suicune = centre('j_poke_suicune')
if suicune then
  suicune.config = { extra = { percent = 10 } }
  suicune.loc_vars = function(self, info_queue, center)
    return { vars = { (center.ability.extra and center.ability.extra.percent) or 10 } }
  end
  suicune.calculate = function(self, card, context)
    if context.joker_main and SMODS.get_scoring_parameter then
      local c = SMODS.get_scoring_parameter('chips')
      local m = SMODS.get_scoring_parameter('mult')
      if type(c) == 'number' and type(m) == 'number' then
        local pct = (card.ability.extra and card.ability.extra.percent) or 10
        -- Moving each side p% toward the mean is a transfer of (chips-mult)/2*p.
        local transfer = math.floor((c - m) / 2 * (pct / 100) + 0.5)
        if transfer ~= 0 then
          return { chips = -transfer, mult = transfer, card = card,
                   message = localize('poke_balance'), colour = G.C.PURPLE }
        end
      end
    end
  end
  suicune.attributes = { 'chips', 'mult' }
end

-- --------------------------------------------------------- Mega Mewtwo Y
-- Perkeo, transcribed from vanilla card.lua including the getAmt()-weighted poll.
local mmy = centre('j_poke_mega_mewtwo_y')
if mmy then
  local inner = mmy.calculate
  mmy.calculate = function(self, card, context)
    if context.ending_shop and not context.blueprint and G.consumeables.cards[1] then
      G.E_MANAGER:add_event(Event({ func = function()
        local total, checked, chosen = 0, 0, nil
        for i = 1, #G.consumeables.cards do
          total = total + G.consumeables.cards[i]:getAmt()
        end
        local poll = pseudorandom(pseudoseed('pgc_mega_mewtwo_y')) * total
        for i = 1, #G.consumeables.cards do
          checked = checked + G.consumeables.cards[i]:getAmt()
          if checked >= poll then chosen = G.consumeables.cards[i] break end
        end
        if chosen then
          local copy = copy_card(chosen, nil, nil, nil, true)
          copy.ability.amt = 1
          copy:set_edition({ negative = true }, true)
          copy:add_to_deck()
          G.consumeables:emplace(copy)
        end
        return true
      end }))
      card_eval_status_text(card, 'extra', nil, nil, nil,
                            { message = localize('k_duplicated_ex') })
    end
    return inner and inner(self, card, context)
  end
end

-- ------------------------------------------------------- Pokermon helpers
-- Two of Pokermon's helpers need to know about the League.
if pokermon and pokermon.add_joker_tooltips then
  local inner_tooltip = pokermon.add_joker_tooltips
  pokermon.add_joker_tooltips = function(self, info_queue, center)
    inner_tooltip(self, info_queue, center)
    if not (POKE_FINAL_BONUS and self and POKE_FINAL_BONUS[self.key]) then return end
    local extra = (type(self.config) == 'table' and type(self.config.extra) == 'table')
      and self.config.extra or {}
    local labels = { h_size = 'hand size', hands = 'hands',
                     d_size = 'discards', discards = 'discards' }
    for field, total in pairs(POKE_FINAL_BONUS[self.key]) do
      local bonus = math.max(0, total - (tonumber(extra[field]) or 0))
      if bonus > 0 and labels[field] then
        info_queue[#info_queue + 1] = { set = 'Other', key = 'poke_final_bonus',
                                        vars = { bonus, labels[field] } }
      end
    end
  end
end

if pokermon and pokermon.apply_type_sticker then
  local inner_sticker = pokermon.apply_type_sticker
  pokermon.apply_type_sticker = function(card, sticker_type)
    inner_sticker(card, sticker_type)
    if poke_gym_refresh_joker then poke_gym_refresh_joker(card) end
  end
end

-- Reroll and -1 Ante vouchers are pulled from the shop on a Ball stake run: you battle who you must.
POKE_EXCLUDED_VOUCHERS = {
  'v_reroll_surplus', 'v_reroll_glut',
  'v_directors_cut', 'v_retcon',
  'v_hieroglyph', 'v_petroglyph',
}

for _, key in ipairs(POKE_EXCLUDED_VOUCHERS) do
  local center = G.P_CENTERS and G.P_CENTERS[key]
  if center and not center.poke_pool_gated then
    center.poke_pool_gated = true
    local inner_in_pool = center.in_pool
    center.in_pool = function(self, args)
      if G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league then
        return false
      end
      if type(inner_in_pool) == 'function' then return inner_in_pool(self, args) end
      return true
    end
  end
end

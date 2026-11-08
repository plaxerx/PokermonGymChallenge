-- Recoloured Blanks: repeatable, and only offered once every other voucher is bought.

local function league_voucher(index, def)
  def.atlas = 'AtlasLeagueVouchers'
  def.pos = { x = index, y = 0 }
  def.cost = 10
  def.discovered = true
  def.unlocked = true
  def.poke_league_voucher = true
  -- Offered by the League's own picker, never by the ordinary pool.
  def.in_pool = function() return false end
  return def
end

local function has_sticker(card)
  return card.ability.perishable or card.ability.rental
end

local function sticker_targets()
  local targets = {}
  for _, card in ipairs(G.jokers.highlighted) do
    if has_sticker(card) then targets[#targets + 1] = card end
  end
  if #targets > 0 then return targets end
  for _, card in ipairs(G.jokers.cards) do
    if has_sticker(card) then return { card } end
  end
  return targets
end

local list = {
  league_voucher(0, {
    key = 'energy',
    loc_txt = { name = 'League Energy', text = { '{C:attention}+1{} {C:pink}Energy Limit{} for all', 'Pokemon Jokers' } },
    redeem = function(self, card)
      G.GAME.poke_energy_plus = (G.GAME.poke_energy_plus or 0) + 1
    end,
  }),
  league_voucher(1, {
    key = 'pcbox',
    poke_rare = true,
    loc_txt = { name = 'PC Box', text = { '{C:dark_edition}Negative{} Pokemon are', '{C:attention}50%{} more likely' } },
    redeem = function(self, card)
      G.GAME.poke_negative_mult = (G.GAME.poke_negative_mult or 1) * 1.5
    end,
  }),
  league_voucher(2, {
    key = 'ribbon',
    poke_rare = true,
    loc_txt = { name = 'Partner Ribbon', text = { '{C:attention}+1{} copy of every', '{C:attention}Tag{} you are given' } },
    redeem = function(self, card)
      G.GAME.poke_tag_copies = (G.GAME.poke_tag_copies or 0) + 1
    end,
  }),
  league_voucher(3, {
    key = 'expshare',
    poke_rare = true,
    loc_txt = { name = 'Exp. Share', text = { '{C:attention}+1{} hand size' } },
    redeem = function(self, card)
      G.hand:change_size(1)
    end,
  }),
  league_voucher(4, {
    key = 'hmcase',
    poke_rare = true,
    poke_eligible = function() return poke_league_hm_target() ~= nil end,
    loc_txt = { name = 'HM Case', text = { 'Lifts the ban on {C:attention}#1#{}', 'for the rest of this game' } },
    loc_vars = function(self, info_queue, card)
      local target = G.GAME and G.GAME.poke_banned_hands and poke_league_hm_target()
      return { vars = { target and localize(target, 'poker_hands') or 'your most played banned hand' } }
    end,
    redeem = function(self, card)
      local target = poke_league_hm_target()
      if not target then return end
      G.GAME.poke_hm_hands = G.GAME.poke_hm_hands or {}
      G.GAME.poke_hm_hands[target] = true
      G.GAME.poke_banned_hands[target] = nil
    end,
  }),
  league_voucher(5, {
    key = 'amulet',
    loc_txt = { name = 'Amulet Coin', text = { '{C:money}+$25{} to the', 'region-clear money cap' } },
    redeem = function(self, card)
      G.GAME.poke_money_cap_bonus = (G.GAME.poke_money_cap_bonus or 0) + 25
    end,
  }),
  league_voucher(6, {
    key = 'daycare',
    poke_rare = true,
    loc_txt = { name = 'Day Care', text = { 'Next region clear keeps', '{C:attention}1{} extra Joker', '{C:inactive}(Stacks)' } },
    redeem = function(self, card)
      G.GAME.poke_daycare = (G.GAME.poke_daycare or 0) + 1
    end,
  }),
  league_voucher(7, {
    key = 'shinycharm',
    poke_rare = true,
    loc_txt = { name = 'Shiny Charm', text = { '{C:attention}Shiny{} Pokemon are', '{C:attention}50%{} more likely' } },
    redeem = function(self, card)
      G.GAME.poke_shiny_mult = (G.GAME.poke_shiny_mult or 1) * 1.5
    end,
  }),
  league_voucher(8, {
    key = 'capsule',
    poke_eligible = function()
      for _, card in ipairs(G.jokers.cards) do
        if has_sticker(card) then return true end
      end
      return false
    end,
    loc_txt = { name = 'Ability Capsule', text = { 'Removes {C:attention}Perishable{} and {C:attention}Rental{}',
                                                   'from selected Jokers', '{C:inactive}(Leftmost if none selected)' } },
    redeem = function(self, card)
      for _, joker in ipairs(sticker_targets()) do
        joker.ability.perishable = nil
        joker.ability.perish_tally = nil
        joker:set_rental(nil)
        SMODS.recalc_debuff(joker)
      end
    end,
  }),
  league_voucher(9, {
    key = 'bagpocket',
    poke_rare = true,
    loc_txt = { name = 'Bag Pocket', text = { '{C:attention}+1{} consumable slot' } },
    redeem = function(self, card)
      G.E_MANAGER:add_event(Event({ func = function()
        G.consumeables.config.card_limit = G.consumeables.config.card_limit + 1
        return true
      end }))
    end,
  }),
  league_voucher(10, {
    key = 'rarecandy',
    poke_rare = true,
    loc_txt = { name = 'Rare Candy', text = { 'Pokemon need {C:attention}1{} fewer', 'round to evolve' } },
    redeem = function(self, card)
      G.GAME.poke_rare_candy = (G.GAME.poke_rare_candy or 0) + 1
    end,
  }),
  league_voucher(11, {
    key = 'gsball',
    poke_gs = true,
    loc_txt = { name = 'GS Ball', text = { '{C:legendary}Legendary{} Pokemon can', 'appear in the shop',
                                           '{C:inactive}(Now #1#%, then +50% per GS Ball)' } },
    loc_vars = function(self, info_queue, card)
      local rate = G.GAME and G.GAME.poke_legendary_rate or POKE_LEGENDARY_BASE_RATE
      return { vars = { math.floor(rate * 10000 + 0.5) / 100 } }
    end,
    redeem = function(self, card)
      local rate = G.GAME.poke_legendary_rate
      G.GAME.poke_legendary_rate = rate and rate * POKE_LEGENDARY_GROWTH or POKE_LEGENDARY_BASE_RATE
    end,
  }),
}

return { name = 'League Vouchers', list = list }

-- Gym Badge / Elite Four / Champion Boss Blinds for the Poke League.

--- Types are coloured with the matching Pokemon palette (PGC_TYPE_COLOURS in PokermonGymChallenge.lua.
local function type_tag(t)
  return '{C:gym_' .. string.lower(t) .. '}' .. t
end

local function gym_blind(entry, gen, index)
  local is_champion = entry.role == "champion"
  local fx = poke_gym_effect(entry.effect)

  -- Kept as terse as a vanilla Boss Blind.
  local function with_status(head)
    if not fx then return head end
    return head .. '{C:inactive}: {C:' .. (fx.colour or 'attention') .. '}' .. fx.status
  end

  local text = {}
  if is_champion then
    -- The Champion's type is whatever this hand rolled.
    text[#text + 1] = 'Type changes {C:attention}every hand'
    text[#text + 1] = with_status('{C:edition}#1#')
    text[#text + 1] = '{C:inactive}next{} {C:edition}#2#'
  elseif entry.gym_type2 then
    text[#text + 1] = with_status(type_tag(entry.gym_type)
      .. '{C:inactive}/' .. type_tag(entry.gym_type2))
  else
    text[#text + 1] = with_status(type_tag(entry.gym_type))
  end

  -- Champions already consume #1# and #2#.
  local var_base = is_champion and 2 or 0
  if fx then
    for _, line in ipairs(fx.text or {}) do
      text[#text + 1] = var_base == 0 and line
        or (line:gsub('#(%d+)#', function(n) return '#' .. (tonumber(n) + var_base) .. '#' end))
    end
  end

  local needs_vars = is_champion or (fx and fx.vars)

  return {
    key = entry.key,
    -- Vanilla sets boss_colour on every Blind it defines and SMODS supplies no default.
    boss_colour = HEX(PGC_TYPE_COLOURS[string.lower(entry.gym_type)]
                      or PGC_TYPE_COLOURS.psychic),
    -- The Elite Four pay nothing.
    dollars = is_champion and 8 or (entry.role == "elite" and 0 or 5),
    mult = (fx and fx.mult) or 2,
    boss = { min = 1, max = 80, showdown = is_champion or nil },
    pos = { x = index - 1, y = gen - 1 },
    atlas = "AtlasGymBlinds",
    discovered = true,
    config = (fx and fx.config) or {},
    debuff = (fx and fx.config) or {},
    poke_gym_type = entry.gym_type,
    poke_gym_type2 = entry.gym_type2,
    -- Champions get the shiny sheen; lovely/UI.toml patches Blind:draw for it.
    poke_champion = is_champion or nil,
    loc_txt = { name = entry.leader, text = text },

    loc_vars = needs_vars and function(self)
      local vars = {}
      if is_champion then
        vars[1] = G.GAME.poke_champ_type or "?"
        vars[2] = G.GAME.poke_champ_next or "?"
      end
      if fx and fx.vars then
        for _, v in ipairs(fx.vars(G.GAME.blind) or {}) do vars[#vars + 1] = v end
      end
      return { vars = vars }
    end or nil,

    -- League Blinds never appear in an ordinary run.
    in_pool = function(self)
      return (G.GAME.modifiers and G.GAME.modifiers.poke_league) and true or false
    end,

    -- Lifecycle.
    set_blind = function(self)
      if fx and fx.set_blind then fx.set_blind(fx, G.GAME.blind) end
    end,

    disable = function(self)
      if fx and fx.disable then fx.disable(fx, G.GAME.blind) end
    end,

    defeat = function(self)
      if fx and fx.defeat then fx.defeat(fx, G.GAME.blind) end
    end,

    -- The status effect's own hooks.
    modify_hand = fx and fx.modify_hand and function(self, ...)
      return fx.modify_hand(fx, G.GAME.blind, ...)
    end or nil,

    debuff_hand = fx and fx.debuff_hand and function(self, cards, hand, handname, check)
      return fx.debuff_hand(fx, G.GAME.blind, cards, hand, handname, check)
    end or nil,

    recalc_debuff = fx and fx.recalc_debuff and function(self, card, from_blind)
      return fx.recalc_debuff(fx, G.GAME.blind, card, from_blind)
    end or nil,

    press_play = fx and fx.press_play and function(self)
      return fx.press_play(fx, G.GAME.blind)
    end or nil,

    stay_flipped = fx and fx.stay_flipped and function(self, area, card, from_area)
      return fx.stay_flipped(fx, G.GAME.blind, area, card, from_area)
    end or nil,

    drawn_to_hand = fx and fx.drawn_to_hand and function(self)
      return fx.drawn_to_hand(fx, G.GAME.blind)
    end or nil,
  }
end

local list = {}
for gen = 1, 9 do
  local region = POKE_LEAGUE_ROSTER[gen]
  if region then
    for i, entry in ipairs(region.entries) do
      list[#list + 1] = gym_blind(entry, gen, i)
    end
  end
end

return {
  name = "Gym Blinds",
  list = list,
}

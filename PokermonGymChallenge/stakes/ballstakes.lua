-- Poke Ball stakes

local pokeball = {
    key = 'pokeball',
    unlocked = true,
    unlocked_stake = 'greatball',
    applied_stakes = {},
    above_stake = 'poke_elite',
    prefix_config = { above_stake = { mod = false } },

    modifiers = function()
        G.GAME.modifiers.poke_league = true
        G.GAME.win_ante = 13
        G.GAME.starting_params.joker_slots = 6
        G.GAME.modifiers.poke_only_content = true
    end,

    pos = {x = 0, y = 0},
    sticker_pos = {x = 0, y = 0},
    atlas = 'pokeball_stakes',
    sticker_atlas = 'pokeball_stakes_stickers',
    colour = HEX("ee4b3b"),
}

local greatball = {
    key = 'greatball',
    unlocked_stake = 'ultraball',
    applied_stakes = {'pokeball'},
    above_stake = 'pokeball',

    modifiers = function()
        G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1								-- Green Stake blind sizes for Antes 1-8
        G.GAME.modifiers.poke_joker_cost_up = (G.GAME.modifiers.poke_joker_cost_up or 0) + 1		-- Jokers in the shop cost $1 more (applied in functions/hooks.lua).
    end,

    pos = {x = 1, y = 0},
    sticker_pos = {x = 1, y = 0},
    atlas = 'pokeball_stakes',
    sticker_atlas = 'pokeball_stakes_stickers',
    colour = HEX("4a90e2"),
}

local ultraball = {
    key = 'ultraball',
    unlocked_stake = 'masterball',
    applied_stakes = {'greatball'},
    above_stake = 'greatball',

    modifiers = function()
        G.GAME.starting_params.hands = G.GAME.starting_params.hands - 1
        G.GAME.starting_params.ante_scaling = (G.GAME.starting_params.ante_scaling or 1) * 1.1		-- Ante scaling amplified 10%.
    end,

    pos = {x = 2, y = 0},
    sticker_pos = {x = 2, y = 0},
    atlas = 'pokeball_stakes',
    sticker_atlas = 'pokeball_stakes_stickers',
    colour = HEX("f7c948"),
}

local masterball = {
    key = 'masterball',
    applied_stakes = {'ultraball'},
    above_stake = 'ultraball',

    modifiers = function()
        G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1								-- Purple Stake blind sizes for Antes 1-8
        G.GAME.starting_params.hand_size = G.GAME.starting_params.hand_size - 1
        G.GAME.starting_params.ante_scaling = (G.GAME.starting_params.ante_scaling or 1) * 1.1		-- Ante scaling amplified another 10%.
        G.GAME.modifiers.poke_no_negative_slots = true												-- removes negative +1 joker slot, retooled to be immune to types
    end,

    pos = {x = 3, y = 0},
    sticker_pos = {x = 3, y = 0},
    atlas = 'pokeball_stakes',
    sticker_atlas = 'pokeball_stakes_stickers',
    colour = HEX("a36ad6"),
    shiny = true
}

return {
  name = "Ball Stakes",
  list = {pokeball, greatball, ultraball, masterball}
}

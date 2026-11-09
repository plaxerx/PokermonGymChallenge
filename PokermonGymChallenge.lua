-- Pokermon: Gym Challenge - entry point.

PGC = {}
PGC.mod_dir = '' .. SMODS.current_mod.path

-- Blind keys are prefixed by SMODS with this mod's prefix.
PGC_BLIND_PREFIX = 'bl_pgc_'

-- The Ante box's label, COMPUTED ON READ.
PGC_HUD = setmetatable({}, {
  __index = function(_, k)
    if k ~= 'gen_label' then return nil end
    local league = G.GAME and G.GAME.modifiers and G.GAME.modifiers.poke_league
    if league and poke_league_generation then
      -- The region reads better than its number: a player knows what Kanto is.
      local region = POKE_LEAGUE_ROSTER and POKE_LEAGUE_ROSTER[poke_league_generation()]
      if region and region.region then return region.region end
      return localize('poke_hud_gen') .. ' ' .. tostring(poke_league_generation())
    end
    return localize('k_ante')
  end,
})

-- ---------------------------------------------------------------- data first
assert(SMODS.load_file("functions/leaguedata.lua"))()

-- ------------------------------------------------------------- then behaviour
assert(SMODS.load_file("functions/display.lua"))()
assert(SMODS.load_file("functions/gymeffects.lua"))()
assert(SMODS.load_file("functions/league.lua"))()
assert(SMODS.load_file("functions/typechart.lua"))()

-- ------------------------------------------------------------------- sprites
SMODS.Atlas({ key = "AtlasGymBlinds",  path = "AtlasGymBlinds.png",  px = 34, py = 34 })
--- Small and Big Blind chips, one column per type: row 0 Small, row 1 Big.
SMODS.Atlas({ key = "AtlasTrainerBlinds", path = "AtlasTrainerBlinds.png",
              px = 34, py = 34 })
-- Generation pips: column 0 empty, column 1 earned.
SMODS.Atlas({ key = "poke_gen_badges", path = "poke_gen_badges.png", px = 12, py = 12 })
SMODS.Atlas({ key = "pokeball_stakes", path = "pokeball_stakes.png", px = 29, py = 29 })
SMODS.Atlas({ key = "AtlasLeagueVouchers", path = "AtlasLeagueVouchers.png", px = 71, py = 95 })
-- Stake stickers are CARD sized (71x95), not chip sized.
SMODS.Atlas({ key = "pokeball_stakes_stickers", path = "pokeball_stakes_stickers.png",
              px = 71, py = 95 })

-- One loc colour per mainline type.
PGC_TYPE_COLOURS = {
  normal = "EDEDE0", fire = "F05030", water = "6390F0", electric = "F7D02C",
  grass = "4BC26A", ice = "96D9D6", fighting = "C22E28", poison = "A33EA1",
  ground = "E2BF65", flying = "F0E6C8", psychic = "F95587", bug = "A6B91A",
  rock = "B6A136", ghost = "735797", dragon = "6F35FC", dark = "8B6B55",
  steel = "B7B7CE", fairy = "D685AD",
}
G.E_MANAGER:add_event(Event({
  func = function()
    if G.ARGS and G.ARGS.LOC_COLOURS then
      for t, hex in pairs(PGC_TYPE_COLOURS) do
        G.ARGS.LOC_COLOURS["gym_" .. t] = HEX(hex)
      end
    end
    return true
  end
}))

-- ----------------------------------------------------------------- objects
local function load_directory(dirname, register)
  for _, file in ipairs(NFS.getDirectoryItems(PGC.mod_dir .. dirname)) do
    local result, err = SMODS.load_file(dirname .. "/" .. file)
    if not result then
      sendDebugMessage("Gym Challenge failed to load " .. file .. ": " .. tostring(err))
    else
      local items = result()
      if items and items.list then
        for _, item in ipairs(items.list) do register(item) end
      end
    end
  end
end

load_directory("blinds", SMODS.Blind)
load_directory("stakes", SMODS.Stake)
load_directory("vouchers", SMODS.Voucher)

-- ------------------------------------------------------------------- hooks
-- Everything below hooks the base game or Pokermon.
assert(SMODS.load_file("functions/hooks.lua"))()
assert(SMODS.load_file("functions/challenges.lua"))()

-- Changes to Pokermon's own Jokers, wrapped rather than edited into its source.
assert(SMODS.load_file("functions/patches.lua"))()

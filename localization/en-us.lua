--[[
  Only the strings this mod owns. Pokermon supplies everything else, and
  the two Joker descriptions below deliberately override its versions -
  this mod loads after Pokermon, so these win.
]]
return {
    descriptions = {
        Joker = {
            j_poke_suicune = {
            name = "Suicune",
            text = {
            "Moves {C:chips}Chips{} and {C:mult}Mult{} each",
            "{C:attention}#1#%{} of the way toward",
            "their {C:attention}average{} when scored",
            }
            },
            j_poke_mega_mewtwo_y = {
            name = "Mega Mewtwo Y",
            text = {
            "{C:pink}Energize{} leftmost {C:attention}Joker twice{}",
            "and create a {C:dark_edition}Negative{} copy of",
            "{C:attention}1{} random consumable, at end of {C:attention}shop",
            "{C:pink}+1{} Energy Limit when",
            "{C:attention}Boss Blind{} is defeated",
            "{C:inactive}(Can't {C:pink}Energize{C:inactive} self)",
            }
            },
        },
        Stake = {
            stake_pgc_pokeball = {
            name = "Poke Ball Stake",
            text = {
            "Custom stakes, antes, and boss blinds.",
            "Collect {C:attention}8{} Gym Badges then battle",
            "the {C:attention}Elite Four{} and {C:attention}Champion",
            "Start with {C:attention}6{} Joker slots",
            },
            },
            stake_pgc_greatball = {
            name = "Great Ball Stake",
            text = {
            "Jokers in the shop cost {C:money}$1{} more",
            "Stronger Blind sizes",
            "{s:0.8}Applies all previous {s:0.8,C:attention}Ball{s:0.8} Stakes"
            },
            },
            stake_pgc_ultraball = {
            name = "Ultra Ball Stake",
            text = {
            "{C:blue}-1{} Hand",
            "Stronger ante scaling",
            "{s:0.8}Applies all previous {s:0.8,C:attention}Ball{s:0.8} Stakes"
            },
            },
            stake_pgc_masterball = {
            name = "Master Ball Stake",
            text = {
            "{C:attention}-1{} hand size",
            "{C:dark_edition}Negative{} Jokers retooled",
            "New Game+ challenges carry over",
            "{s:0.8}Applies all previous {s:0.8,C:attention}Ball{s:0.8} Stakes"
            },
            },
        },
        Other = {
            pgc_pokeball_sticker = {
            name = "Poke Ball Sticker",
            text = {
            "Used this {C:attention}Joker{}",
            "to beat the {C:attention}League{} on",
            "{C:attention}Poke Ball Stake{} difficulty",
            },
            },
            pgc_greatball_sticker = {
            name = "Great Ball Sticker",
            text = {
            "Used this {C:attention}Joker{}",
            "to beat the {C:attention}League{} on",
            "{C:attention}Great Ball Stake{} difficulty",
            },
            },
            pgc_ultraball_sticker = {
            name = "Ultra Ball Sticker",
            text = {
            "Used this {C:attention}Joker{}",
            "to beat the {C:attention}League{} on",
            "{C:attention}Ultra Ball Stake{} difficulty",
            },
            },
            pgc_masterball_sticker = {
            name = "Master Ball Sticker",
            text = {
            "Used this {C:attention}Joker{}",
            "to beat the {C:attention}League{} on",
            "{C:attention}Master Ball Stake{} difficulty",
            },
            },
        },
    },
    misc = {
        dictionary = {
            poke_balance = "Balance!",
            poke_hud_gen = "Gen",
            poke_hud_trainer = "Trainer",
            poke_gen_tip_1 = "A fresh region at {C:attention}10X{} Blind size",
            poke_gen_tip_2 = "Keep your {C:attention}selected{} Joker and consumable, or the leftmost",
            poke_gen_tip_2b = "{C:attention}Eternal{} Jokers are always kept",
            poke_gen_tip_3 = "Money is set to {C:money}$25{}",
            poke_gen_tip_4 = "Vouchers and hand levels are kept",
            poke_gen_tip_4b = "Deck resets to {C:attention}52{}: your last hand and held cards stay",
            poke_gen_tip_4c = "Your most played hand is {C:red}banned{}, one more per region",
            poke_gen_tip_4d = "A random {C:attention}Challenge{} takes hold for the region",
            poke_hand_banned = "Banned by the League",
            poke_banned_hands = "Banned Hands",
            poke_challenges_tab = "Challenges",
            poke_crowd_medium = "Medium Blind",
            poke_gen_tip_5 = "Your whole team is credited with the {C:attention}stake{}",
            poke_gen_tip_6 = "{C:inactive}Applied at Cash Out{}",
            poke_gen_warn = "Cash Out ends this generation!",
            poke_cash_out_warn = "Cash Out (Region Ends)",
            poke_choose_1 = "Upcoming",
            poke_choose_2 = "Trainers",
        },
    },
}

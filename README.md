# Pokermon: Gym Challenge

A retooled Balatro experience to complement [Pokermon](https://github.com/InertSteak/Pokermon) by InertSteak. New antes and region-based trainer battles alongside a new Endless mode!

> **Closed alpha, for review and testing.** Expect bugs and unfinished balance. Saves may not carry over between alpha builds.
>
> **All art is currently borrowed placeholder art.** Anything carrying a **PH** mark, along with the trainer and Gym Leader sprites, is temporary and will be replaced before any wider release.

## Requirements

- [Balatro](https://www.playbalatro.com/)
- [Lovely](https://github.com/ethangreen-dev/lovely-injector)
- [Steamodded](https://github.com/Steamodded/smods) `>= 26.829.0`
- [Pokermon](https://github.com/InertSteak/Pokermon) `>= 3.9.1`

## Installation

Download this repository and place its contents in a folder inside your Balatro mods directory:

```
%APPDATA%/Balatro/Mods/PokermonGymChallenge/
```

Then start a run on any of the four **Poké Ball stakes**.

## What it adds

### The League

Four stakes form their own branch alongside vanilla's. Each one adds to the ball below it.

| Stake | Adds |
|---|---|
| Poké Ball | The League itself, 6 Joker slots, Pokémon-only content |
| Great Ball | Jokers cost $1 more, stronger Blind sizes |
| Ultra Ball | -1 Hand, stronger ante scaling |
| Master Ball | -1 hand size, stronger Blind sizes and ante scaling, Negative Jokers give no slot but ignore type disadvantage, New Game+ challenges carry over |

A region is thirteen antes: eight Gyms, the Elite Four, then the Champion. There are nine regions, drawn in an order set by the run's seed. After the ninth, the run hands over to vanilla Endless.

- **Type matchups** apply for the whole ante. Pokémon the Leader is weak to have their values doubled, resisted ones are halved, and immune ones are debuffed.
- **Boss effects** are vanilla Boss Blind effects framed as status conditions: Crimson Heart is Paralysis, The Flint is Burn, The Manacle is Freeze.
- **Small and Big Blinds** are the Gym's trainers. The Elite Four and Champion are fought alone, and Champions change type every hand.
- Reroll and -1 Ante vouchers are removed. You battle who you must.

### New Game+

Clearing a region starts the next one at 10x Blind size, and it costs you:

- You keep your selected Joker and consumable (or the leftmost), plus anything Eternal.
- Money is capped at $25 per region cleared.
- Your deck resets to 52. Your last played hand and the cards held beside it stay, and random cards fill the rest: 25% enhanced, 10% editioned, 10% sealed. Negative cards don't count toward the 52.
- Your most played hand is banned, then your top two in the next region, and so on. Banned hands are greyed out in Run Info and score nothing.
- One random **challenge** takes hold for the region. On Master Ball they stack. See the **Challenges** tab in Run Info.

| Challenge | Effect |
|---|---|
| Obedience | Jokers past slot 3 are debuffed; each badge unlocks one more |
| Distortion | Joker order shuffles after each hand is played |
| Fashion Week | A random edition is debuffed each ante |
| Day/Night | Antes alternate: face cards, then number cards are debuffed |
| Seasons | One suit is debuffed each ante, in rotation |
| Truths and Ideals | Antes alternate: even cards, then odd cards are debuffed |
| Dive | 1 in 4 cards are drawn face down |
| Snowbound | -1 hand size, hand or discard, rotating each ante |
| Unown | Card chip values are randomized each ante, from 1 to 26 |
| Rocket Radio | Shop prices are 50% higher |
| Wild Area | Rerolls cost $2 more |
| Weather | Type effectiveness is doubled |
| Inverse | The type chart is flipped |
| Terastal | Gym Leaders change type every hand |
| Fog | The boss's type is hidden until you select a Blind |
| Totem Aura | Boss Blinds are x1.5 |
| Dynamax | Blinds are x3, and Chips and Mult balance after scoring |
| Crowd | A Medium Blind comes before each Big Blind |

### League vouchers

Once every other voucher is bought, the shop stops offering Blanks and draws from these instead. They can be bought repeatedly.

| Voucher | Odds | Effect |
|---|---|---|
| League Energy | Common | +1 Energy Limit for all Pokémon Jokers |
| Amulet Coin | Common | +$25 to the region-clear money cap |
| Ability Capsule | Common | Removes Perishable and Rental from selected Jokers |
| PC Box | Rare | Negative Pokémon are 50% more likely |
| Shiny Charm | Rare | Shiny Pokémon are 50% more likely |
| Rare Candy | Rare | Pokémon need 1 fewer round to evolve |
| Partner Ribbon | Rare | +1 copy of every Tag you are given |
| Exp. Share | Rare | +1 hand size |
| HM Case | Rare | Lifts the ban on your most played banned hand for the rest of the game |
| Day Care | Rare | Next region clear keeps 1 extra Joker |
| Bag Pocket | Rare | +1 consumable slot |
| GS Ball | Very rare | Legendary Pokémon can appear in the shop at 0.3%, then +50% per GS Ball |

Commons share 90% of the draw, rares 9%, and GS Ball 1%.

## Testing and feedback

Please report bugs and balance notes through [GitHub Issues](https://github.com/plaxerx/PokermonGymChallenge/issues). For a crash, include the crash text, your stake, your region and ante, and the latest log from `%APPDATA%/Balatro/Mods/lovely/log/`.

The New Game+ systems are the newest and least tested part of this build. Feedback on Crowd, Fog, Obedience, the deck reset and how the challenges stack on Master Ball is especially useful.

## Credits

Made by [plaxerx](https://github.com/plaxerx), with development assistance from
[Claude](https://claude.ai).

Built on [Pokermon](https://github.com/InertSteak/Pokermon) by InertSteak, which supplies the Jokers, types and energy system.

Balatro is by LocalThunk. Pokémon is owned by Nintendo, Game Freak and The Pokémon Company. This mod is unofficial and not affiliated with any of them.

-- Pokermon's own under-card display.

POKE_DISPLAY_CHILD = "poke_display_badge"

--- Remove a card's badge, if it has one.
poke_display_clear = function(card)
  if card and card.children and card.children[POKE_DISPLAY_CHILD] then
    card.children[POKE_DISPLAY_CHILD]:remove()
    card.children[POKE_DISPLAY_CHILD] = nil
  end
end

poke_display_badge = function(card, label, colour, opts)
  if not card or not card.children or not label then return end
  poke_display_clear(card)
  opts = opts or {}
  card.children[POKE_DISPLAY_CHILD] = UIBox {
    definition = {
      n = G.UIT.ROOT,
      config = { align = "cm", colour = G.C.CLEAR, padding = 0 },
      nodes = {{
        n = G.UIT.R,
        config = { align = "cm", colour = colour or G.C.GREY, r = 0.08,
                   padding = 0.03, minw = opts.minw or 0.38, emboss = 0.04 },
        nodes = {{
          n = G.UIT.T,
          config = { text = tostring(label), scale = opts.scale or 0.32,
                     colour = opts.text_colour or G.C.WHITE, shadow = true },
        }},
      }},
    },
    config = {
      align = "bm",
      offset = { x = 0, y = opts.offset or -0.24 },
      major = card,
      -- Strong, as vanilla's card buttons: UIBox:drag moves children with a nil dt.
      bond = "Strong",
      parent = card,
    },
  }
end

--- Whether a card currently carries a badge.
poke_display_has_badge = function(card)
  return card and card.children and card.children[POKE_DISPLAY_CHILD] ~= nil
end

--- Clear badges from every Joker.
poke_display_clear_jokers = function()
  if not G.jokers then return end
  for _, joker in ipairs(G.jokers.cards) do
    poke_display_clear(joker)
  end
end

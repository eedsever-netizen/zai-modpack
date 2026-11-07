--[[
  recipes.lua — рецепты трёх уровней паукотрон-рудокопа.
  T1 (стартовый, дешёвый): железо, медь, двигатель внутреннего сгорания, трубы.
  T2 (после red science, steel, automation): в рецепт входят T1, сталь,
       automation-science-pack, assembler-1, engine-unit.
  T3 (после аккумулятора и стационарного аккумулятора): T2, battery,
       accumulator, electric-engine-unit, processing-unit, low-density-structure.
]]
data:extend({
  {
    type = "recipe",
    name = "zai-stm-t1",
    enabled = true,
    energy_required = 30,
    ingredients = {
      { type = "item", name = "iron-plate", amount = 50 },
      { type = "item", name = "copper-plate", amount = 20 },
      { type = "item", name = "iron-gear-wheel", amount = 15 },
      { type = "item", name = "pipe", amount = 8 },
      { type = "item", name = "burner-inserter", amount = 4 },
    },
    results = { { type = "item", name = "zai-stm-t1", amount = 1 } },
    requester_paste_multiplier = 1,
  },
  {
    type = "recipe",
    name = "zai-stm-t2",
    enabled = false,
    energy_required = 60,
    ingredients = {
      { type = "item", name = "zai-stm-t1", amount = 1 },
      { type = "item", name = "steel-plate", amount = 50 },
      { type = "item", name = "automation-science-pack", amount = 10 },
      { type = "item", name = "assembling-machine-1", amount = 2 },
      { type = "item", name = "engine-unit", amount = 8 },
      { type = "item", name = "iron-gear-wheel", amount = 20 },
    },
    results = { { type = "item", name = "zai-stm-t2", amount = 1 } },
    requester_paste_multiplier = 1,
  },
  {
    type = "recipe",
    name = "zai-stm-t3",
    enabled = false,
    energy_required = 120,
    ingredients = {
      { type = "item", name = "zai-stm-t2", amount = 1 },
      { type = "item", name = "battery", amount = 20 },
      { type = "item", name = "accumulator", amount = 4 },
      { type = "item", name = "electric-engine-unit", amount = 8 },
      { type = "item", name = "processing-unit", amount = 10 },
      { type = "item", name = "low-density-structure", amount = 5 },
    },
    results = { { type = "item", name = "zai-stm-t3", amount = 1 } },
    requester_paste_multiplier = 1,
  },
})

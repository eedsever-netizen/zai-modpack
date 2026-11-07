--[[
  techs.lua — 2 технологии (T2 и T3). T1 доступен сразу.
  zai-stm-t2: после автоматизации и стали. unit: 30 × automation-science.
  zai-stm-t3: после zai-stm-t2, battery и стационарного аккумулятора.
              unit: 50 × automation + logistic-science.
]]
data:extend({
  {
    type = "technology",
    name = "zai-stm-t2",
    icon = "__base__/graphics/technology/automobilism.png",
    icon_size = 256,
    unit = {
      count = 30,
      ingredients = { { "automation-science-pack", 1 } },
      time = 20,
    },
    prerequisites = { "automation", "steel-processing" },
    effects = {
      { type = "unlock-recipe", recipe = "zai-stm-t2" },
    },
    order = "z-a",
  },
  {
    type = "technology",
    name = "zai-stm-t3",
    -- ВНИМАНИЕ: в base 2.1.24 опечатка в имени файла — "acumulators" (одна 'c')
    icon = "__base__/graphics/technology/electric-energy-acumulators.png",
    icon_size = 256,
    unit = {
      count = 50,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
      },
      time = 30,
    },
    prerequisites = { "zai-stm-t2", "battery", "electric-energy-accumulators" },
    effects = {
      { type = "unlock-recipe", recipe = "zai-stm-t3" },
    },
    order = "z-b",
  },
})

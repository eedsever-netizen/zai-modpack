--[[
  data.lua — точка входа прототипов мода zai-spidertron-miner.
  Загружает подмодули:
    prototypes/grids.lua     — 3 сетки оборудования
    prototypes/cars.lua      — 3 машины (T1/T2/T3)
    prototypes/items.lua    — предметы машин + selection-tool для разметки
    prototypes/recipes.lua   — рецепты машин
    prototypes/techs.lua     — 2 технологии (T2 и T3; T1 доступен сразу)
    prototypes/shortcuts.lua — shortcut для авто-режима + custom-inputs
]]
local mod = "zai-spidertron-miner"
require("__" .. mod .. "__/prototypes/grids")
require("__" .. mod .. "__/prototypes/cars")
require("__" .. mod .. "__/prototypes/items")
require("__" .. mod .. "__/prototypes/recipes")
require("__" .. mod .. "__/prototypes/techs")
require("__" .. mod .. "__/prototypes/shortcuts")

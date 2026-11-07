--[[
  cars.lua — 3 машины паукотрон-рудокоп.

  T1: доступна на старте. Burner (любое горючее). Тёмно-ржавая обгоревшая
      разбитая машина. Маленькая сетка оборудования.
  T2: технология после красной ленты, стали и автоматизации. Burner
      повышенной эффективности. Старая машина с полувыцветшей синей краской.
  T3: технология после аккумулятора и стационарного аккумулятора.
      В Factorio 2.1 car-прототип не принимает electric energy_source —
      поэтому T3 реализован как burner с почти нулевыми emissions
      (pollution=1), симулируя «электрическую» машину. Воронёная сталь.

  Спрайты: base car.png с tint-множителем для дифференциации уровней.
]]

local util = require("util")

local TINT_T1 = { r = 0.42, g = 0.22, b = 0.12, a = 1.0 } -- тёмно-ржавый
local TINT_T2 = { r = 0.35, g = 0.40, b = 0.55, a = 1.0 } -- полувыцветшая синяя
local TINT_T3 = { r = 0.45, g = 0.50, b = 0.60, a = 1.0 } -- воронёная сталь

local function make_car(tier, opts)
  local base = data.raw["car"]["car"]
  local car = util.table.deepcopy(base)
  car.name = "zai-stm-" .. tier
  car.localised_name = {"entity-name.zai-stm-" .. tier}
  car.localised_description = {"entity-description.zai-stm-" .. tier}
  car.icon = "__base__/graphics/icons/car.png"
  car.icon_size = 64
  car.icons = {
    { icon = "__base__/graphics/icons/car.png", icon_size = 64, tint = opts.tint },
  }
  car.minable = { mining_time = 0.5, result = "zai-stm-" .. tier }
  car.max_health = opts.health
  car.weight = opts.weight
  car.braking_force = opts.braking
  car.friction = opts.friction
  car.effectivity = opts.effectivity
  car.inventory_size = opts.inventory_size
  car.equipment_grid = opts.grid

  -- Энергия: в Factorio 2.1 только energy_source = { type = "burner"|"void" }
  if opts.energy == "burner" then
    if base.energy_source then
      car.energy_source = util.table.deepcopy(base.energy_source)
      if opts.fuel_emissions and car.energy_source then
        car.energy_source.emissions_per_minute = { pollution = opts.fuel_emissions }
      end
    else
      car.energy_source = {
        type = "burner",
        fuel_categories = {"chemical"},
        effectivity = 1,
        fuel_inventory_size = 1,
      }
    end
  end

  -- tint к спрайтам
  local function apply_tint(sprite_set)
    if not sprite_set then return end
    local function tint_layer(layer)
      if not layer then return end
      layer.tint = opts.tint
      if layer.hr_version then layer.hr_version.tint = opts.tint end
      if layer.layers then
        for _, sub in ipairs(layer.layers) do tint_layer(sub) end
      end
    end
    if sprite_set.layers then
      for _, l in ipairs(sprite_set.layers) do tint_layer(l) end
    else
      tint_layer(sprite_set)
    end
  end
  apply_tint(car.animation)
  if car.turret_animation then apply_tint(car.turret_animation) end
  if car.rotated_turret_animation then apply_tint(car.rotated_turret_animation) end

  return car
end

local cars = {
  make_car("t1", {
    tint = TINT_T1, health = 150, weight = 600, braking = 1500,
    friction = 0.018, effectivity = 0.45, inventory_size = 30,
    grid = "zai-stm-grid-t1", energy = "burner", fuel_emissions = 8,
  }),
  make_car("t2", {
    tint = TINT_T2, health = 350, weight = 900, braking = 2800,
    friction = 0.015, effectivity = 0.65, inventory_size = 50,
    grid = "zai-stm-grid-t2", energy = "burner", fuel_emissions = 5,
  }),
  make_car("t3", {
    tint = TINT_T3, health = 600, weight = 1200, braking = 4500,
    friction = 0.012, effectivity = 0.85, inventory_size = 80,
    grid = "zai-stm-grid-t3", energy = "burner", fuel_emissions = 1,
  }),
}

data:extend(cars)

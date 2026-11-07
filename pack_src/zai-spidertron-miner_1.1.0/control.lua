--[[
  control.lua — логика мода zai-spidertron-miner v1.1.0.

  Улучшения v1.1.0:
  1. Любой сундук: chest-link работает с container, logistic-container,
     infinity-container, assembling-machine, furnace, mining-drill,
     cargo-wagon, car, tank, roboport, reactor — с любым entity имеющим inventory.
  2. Энергия: T3 имеет 4 топливных слота + equipment grid 12×14 для
     generator/shield/laser equipment.
  3. Простой GUI: choose-elem-button с фильтром resource — стандартный
     Factorio picker с поиском, без огромного scroll-pane.
  4. Глобальный поиск руды: авто-режим ищет ближайший ресурс по ВСЕЙ
     поверхности (с лимитом 1000 для производительности).
  5. Самооборона: T2/T3 имеют guns (vehicle-machine-gun + tank-cannon +
     rocket-launcher на T3). Equipment grid поддерживает energy-shield и
     personal-laser-defense через category "armor".

  Привязки:
    Shift + R — связать ближайший сундук под курсором
    Shift + T — открыть compact picker выбора ресурса
    Shortcut  — переключить авто-режим
]]

local DESIGNATOR_RADIUS = 30
local DEPOSIT_INTERVAL = 180     -- 3 сек между сбросами в сундук
local MINING_PER_CALL = 4
local AUTO_SEARCH_LIMIT = 1000   -- лимит entities для global поиска

local CAR_NAMES = { "zai-stm-t1", "zai-stm-t2", "zai-stm-t3" }

-- Любой entity с inventory — кандидат в "сундук" для chest-link
local SUPPORTED_CHEST_TYPES = {
  "container", "logistic-container", "infinity-container",
  "assembling-machine", "furnace", "mining-drill",
  "roboport", "reactor", "boiler", "generator",
  "car", "tank", "spider-vehicle", "cargo-wagon", "fluid-wagon",
  "ammo-turret", "electric-turret", "fluid-turret", "artillery-turret",
  "lab", "beacon",
}

local function is_stm_car(entity)
  if not entity or not entity.valid then return false end
  if entity.type ~= "car" then return false end
  for _, n in ipairs(CAR_NAMES) do
    if entity.name == n then return true end
  end
  return false
end

local function get_or_create_miner_state(car)
  if not is_stm_car(car) then return nil end
  local un = car.unit_number
  if not storage.zai_stm.miners[un] then
    storage.zai_stm.miners[un] = {
      car = car,
      mode = nil,
      target_resource = "iron-ore",
      chest_entity = nil,
      last_deposit = 0,
    }
  else
    storage.zai_stm.miners[un].car = car
  end
  return storage.zai_stm.miners[un]
end

local function find_nearest_stm(surface, position, max_distance)
  local cars = surface.find_entities_filtered{
    type = "car", radius = max_distance, position = position,
  }
  local best, best_dist = nil, math.huge
  for _, c in ipairs(cars) do
    if is_stm_car(c) then
      local dx = c.position.x - position.x
      local dy = c.position.y - position.y
      local d = math.sqrt(dx * dx + dy * dy)
      if d < best_dist then best = c; best_dist = d end
    end
  end
  return best
end

local function mine_resource_to_car(car, resource)
  if not resource or not resource.valid then return false end
  local proto = resource.prototype
  if not proto or not proto.mineable_properties then return false end
  local minable = proto.mineable_properties
  if not minable.products then return false end

  local trunk = car.get_inventory(defines.inventory.car_trunk)
  if not trunk then return false end

  local results = {}
  for _, prod in ipairs(minable.products) do
    local amount = prod.amount or (prod.amount_min or 0)
    if prod.probability then amount = amount * prod.probability end
    amount = math.floor(amount + 0.5)
    if amount > 0 then table.insert(results, { name = prod.name, count = amount }) end
  end

  for _, r in ipairs(results) do
    if not trunk.can_insert({ name = r.name, count = r.count }) then return false end
  end

  resource.destroy()
  for _, r in ipairs(results) do
    trunk.insert({ name = r.name, count = r.count })
  end
  return true
end

-- ЛЮБОЙ сундук: проверка по типу entity
local function find_chest_under_cursor(player)
  local ent = player.selected
  if not ent or not ent.valid then return nil end
  for _, t in ipairs(SUPPORTED_CHEST_TYPES) do
    if ent.type == t then return ent end
  end
  return nil
end

local function deposit_to_chest(car, chest)
  if not car or not car.valid then return end
  if not chest or not chest.valid then return end
  local trunk = car.get_inventory(defines.inventory.car_trunk)
  if not trunk then return end
  -- Найти inventory у chest: пробуем несколько типов
  local chest_inv = nil
  for _, inv_type in pairs({
    defines.inventory.chest,
    defines.inventory.furnace_source,
    defines.inventory.assembling_machine_input,
    defines.inventory.lab_input,
    defines.inventory.car_trunk,
    defines.inventory.cargo_wagon,
  }) do
    local ok, inv = pcall(function() return chest.get_inventory(inv_type) end)
    if ok and inv and inv.valid then
      chest_inv = inv
      break
    end
  end
  if not chest_inv then return end

  local contents = trunk.get_contents()
  for name, count in pairs(contents) do
    if chest_inv.can_insert({ name = name, count = count }) then
      local inserted = chest_inv.insert({ name = name, count = count })
      trunk.remove({ name = name, count = inserted })
    end
  end
end

local function init_global()
  storage.zai_stm = storage.zai_stm or {
    miners = {},
    open_guis = {},
  }
end

script.on_init(init_global)
script.on_configuration_changed(init_global)

------------------------------------------------------------------
-- GUI: compact resource picker через choose-elem-button
------------------------------------------------------------------
local function open_resource_picker(player, car)
  local gui = player.gui.screen
  if gui["zai-stm-picker"] then gui["zai-stm-picker"].destroy() end

  local frame = gui.add{
    type = "frame", name = "zai-stm-picker",
    direction = "vertical", caption = {"zai-stm.picker-title"},
  }
  frame.style.padding = 12
  frame.style.minimal_width = 280

  local state = get_or_create_miner_state(car)

  -- Compact: один choose-elem-button с фильтром resource
  local row = frame.add{ type = "flow", name = "zai-stm-picker-row", direction = "horizontal" }
  row.add{
    type = "label", caption = {"zai-stm.target-resource"},
  }
  local btn = row.add{
    type = "choose-elem-button",
    name = "zai-stm-elem-picker",
    elem_type = "entity",
    entity_filters = {{ filter = "type", type = "resource" }},
  }
  -- Установить текущий ресурс
  if state.target_resource then
    btn.elem_value = state.target_resource
  end

  -- Информация о текущем состоянии
  local info = frame.add{
    type = "label", name = "zai-stm-info",
    caption = {"zai-stm.info-mode",
      state.mode == "auto" and {"zai-stm.auto-on"} or {"zai-stm.auto-off"},
      state.chest_entity and state.chest_entity.localised_name or {"zai-stm.no-chest"},
    },
  }

  -- Кнопка закрытия
  frame.add{
    type = "button", name = "zai-stm-picker-close",
    caption = {"zai-stm.close"}, tags = { action = "zai-stm-close" },
  }

  player.opened = frame
  storage.zai_stm.open_guis[player.index] = car.unit_number
end

------------------------------------------------------------------
-- Обработчики событий
------------------------------------------------------------------
script.on_event(defines.events.on_player_selected_area, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  if event.item ~= "zai-stm-designator" then return end
  local car = find_nearest_stm(player.surface, player.position, DESIGNATOR_RADIUS)
  if not car then player.print({"zai-stm.no-car-in-radius"}); return end

  local resources = player.surface.find_entities_filtered{ type = "resource", area = event.area }
  if #resources == 0 then player.print({"zai-stm.no-resources-in-area"}); return end

  local car_pos = car.position
  local function dist(a)
    local dx = a.position.x - car_pos.x
    local dy = a.position.y - car_pos.y
    return dx * dx + dy * dy
  end
  table.sort(resources, function(a, b) return dist(a) < dist(b) end)

  local mined = 0
  for _, r in ipairs(resources) do
    if mined >= MINING_PER_CALL then break end
    if mine_resource_to_car(car, r) then mined = mined + 1 end
  end
  player.print({"zai-stm.manual-mined", mined})
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name ~= "zai-stm-toggle-auto" then return end
  local player = game.get_player(event.player_index)
  if not player then return end
  local car = player.selected
  if not is_stm_car(car) then car = player.vehicle end
  if not is_stm_car(car) then
    player.print({"zai-stm.no-car-under-cursor"}); return
  end
  local state = get_or_create_miner_state(car)
  if state.mode == "auto" then
    state.mode = nil
    player.print({"zai-stm.auto-off"})
  else
    state.mode = "auto"
    player.print({"zai-stm.auto-on"})
  end
end)

script.on_event("zai-stm-link-chest", function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  -- car = player.vehicle (нужно сидеть в машине), chest = player.selected
  local car = player.vehicle
  if not is_stm_car(car) then
    player.print({"zai-stm.must-sit-in-car-for-chest"}); return
  end
  local chest = find_chest_under_cursor(player)
  if not chest then
    player.print({"zai-stm.no-chest-under-cursor"}); return
  end
  local state = get_or_create_miner_state(car)
  state.chest_entity = chest
  player.print({"zai-stm.chest-linked", chest.localised_name})
end)

script.on_event("zai-stm-set-resource", function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local car = player.selected
  if not is_stm_car(car) then car = player.vehicle end
  if not is_stm_car(car) then
    player.print({"zai-stm.no-car-under-cursor"}); return
  end
  open_resource_picker(player, car)
end)

-- GUI click для close button
script.on_event(defines.events.on_gui_click, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local tags = event.element and event.element.tags
  if tags and tags.action == "zai-stm-close" then
    local frame = player.gui.screen["zai-stm-picker"]
    if frame then frame.destroy() end
    storage.zai_stm.open_guis[player.index] = nil
    return
  end
end)

-- GUI elem_changed для choose-elem-button (выбор ресурса)
script.on_event(defines.events.on_gui_elem_changed, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  if event.element and event.element.name == "zai-stm-elem-picker" then
    local car_unit = storage.zai_stm.open_guis[player.index]
    if not car_unit then return end
    local state = storage.zai_stm.miners[car_unit]
    if not state or not state.car or not state.car.valid then return end
    if event.element.elem_value then
      state.target_resource = event.element.elem_value
      player.print({"zai-stm.resource-set", event.element.elem_value})
    end
  end
end)

script.on_event(defines.events.on_gui_closed, function(event)
  if event.element and event.element.name == "zai-stm-picker" then
    event.element.destroy()
    storage.zai_stm.open_guis[event.player_index] = nil
  end
end)

------------------------------------------------------------------
-- Tick: авто-режим с ГЛОБАЛЬНЫМ поиском руды + сброс в сундук
------------------------------------------------------------------
script.on_nth_tick(60, function(event)
  local tick = event.tick
  for un, state in pairs(storage.zai_stm.miners) do
    local car = state.car
    if not car or not car.valid then
      storage.zai_stm.miners[un] = nil
      goto continue
    end

    if state.mode == "auto" then
      local resource_name = state.target_resource
      if resource_name then
        -- ГЛОБАЛЬНЫЙ поиск по всей поверхности (с лимитом)
        local resources = car.surface.find_entities_filtered{
          type = "resource",
          name = resource_name,
          limit = AUTO_SEARCH_LIMIT,
        }
        if #resources > 0 then
          -- Найти ближайший
          local best, best_dist = nil, math.huge
          local car_pos = car.position
          for _, r in ipairs(resources) do
            local dx = r.position.x - car_pos.x
            local dy = r.position.y - car_pos.y
            local d = dx * dx + dy * dy
            if d < best_dist then best = r; best_dist = d end
          end
          if best then
            local dist = math.sqrt(best_dist)
            -- Если в радиусе 25 тайлов — добываем
            if dist <= 25 then
              mine_resource_to_car(car, best)
            else
              -- Далеко: указать направление в чат (каждые 5 сек, чтобы не спамить)
              if tick % 300 == 0 then
                local angle = math.deg(math.atan2(best.position.y - car_pos.y,
                                                  best.position.x - car_pos.x))
                local dir
                if angle >= -22.5 and angle < 22.5 then dir = "восток (→)"
                elseif angle >= 22.5 and angle < 67.5 then dir = "юго-восток (↘)"
                elseif angle >= 67.5 and angle < 112.5 then dir = "юг (↓)"
                elseif angle >= 112.5 and angle < 157.5 then dir = "юго-запад (↙)"
                elseif angle >= 157.5 or angle < -157.5 then dir = "запад (←)"
                elseif angle >= -157.5 and angle < -112.5 then dir = "северо-запад (↖)"
                elseif angle >= -112.5 and angle < -67.5 then dir = "север (↑)"
                else dir = "северо-восток (↗)" end
                -- Напечатать водителю (если есть)
                -- LuaEntity.get_driver() возвращает LuaPlayer или nil
                local driver_player = state.car.get_driver()
                if driver_player then
                  driver_player.print({"zai-stm.resource-direction",
                                       resource_name, math.floor(dist), dir})
                end
              end
            end
          end
        end
      end
    end

    -- Сброс в сундук — для всех машин (не только auto-mode)
    if tick - (state.last_deposit or 0) >= DEPOSIT_INTERVAL then
      if state.chest_entity and state.chest_entity.valid then
        deposit_to_chest(car, state.chest_entity)
      end
      state.last_deposit = tick
    end

    ::continue::
  end
end)

-- Чистка при удалении машины
script.on_event(defines.events.on_post_entity_died, function(event)
  local ent = event.entity
  if ent and ent.type == "car" then
    local un = ent.unit_number
    if un and storage.zai_stm.miners[un] then
      storage.zai_stm.miners[un] = nil
    end
  end
end)

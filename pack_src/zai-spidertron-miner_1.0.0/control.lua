--[[
  control.lua — логика мода zai-spidertron-miner.

  Режимы работы:
    manual  — игрок выделяет рамку предметом zai-stm-designator, ближайший
              zai-stm-* в радиусе 30 тайлов от игрока добывает ресурсы в этой
              области. Один вызов — MINING_PER_CALL ресурсов.
    auto    — toggle через shortcut zai-stm-toggle-auto. Каждую секунду
              машина добывает ближайший ресурс указанного типа в радиусе
              25 тайлов. Целевой ресурс выбирается через Shift+T (GUI).
              Trunk заполняется → сброс в связанный сундук.

  Привязки:
    Shift + R — связать ближайший сундук под курсором как точку сброса
    Shift + T — открыть диалог выбора целевого ресурса
    Shortcut  — переключить авто-режим для машины под курсором (или driven)

  Состояние хранится в storage.zai_stm.miners[unit_number]:
    car = LuaEntity (прямая ссылка, сериализуется Factorio)
    mode = "auto" | nil
    target_resource = string
    chest_entity = LuaEntity (или nil)
    last_deposit = tick

  В Factorio 2.0+ `global` переименован в `storage`. LuaEntity-ссылки в
  storage валидны и сериализуются.
]]

local DESIGNATOR_RADIUS = 30
local AUTO_RADIUS = 25
local AUTO_INTERVAL = 60       -- 1 сек
local DEPOSIT_INTERVAL = 180   -- 3 сек
local MINING_PER_CALL = 4

local CAR_NAMES = { "zai-stm-t1", "zai-stm-t2", "zai-stm-t3" }

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
  -- Звук не вызываем: в base 2.1.24 нет prototype "mining-ore",
  -- вызов несуществующего звука вызывает crash. В будущей версии
  -- можно добавить через data:extend новый sound prototype.
  return true
end

local function find_chest_under_cursor(player)
  local ent = player.selected
  if not ent then return nil end
  if ent.type == "container" or ent.type == "logistic-container" then return ent end
  return nil
end

local function deposit_to_chest(car, chest)
  if not car or not car.valid then return end
  if not chest or not chest.valid then return end
  local trunk = car.get_inventory(defines.inventory.car_trunk)
  if not trunk then return end
  local chest_inv = chest.get_inventory(defines.inventory.chest)
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

local function open_resource_picker(player, car)
  local gui = player.gui.screen
  if gui["zai-stm-picker"] then gui["zai-stm-picker"].destroy() end

  local frame = gui.add{
    type = "frame", name = "zai-stm-picker",
    direction = "vertical", caption = {"zai-stm.picker-title"},
  }
  frame.style.padding = 12

  local surface = car.surface
  local resources_set = {}
  local resources = surface.find_entities_filtered{ type = "resource", limit = 10000 }
  for _, r in ipairs(resources) do resources_set[r.name] = true end

  local default_resources = {
    "iron-ore", "copper-ore", "coal", "stone",
    "uranium-ore", "crude-oil",
  }
  for _, n in ipairs(default_resources) do resources_set[n] = true end

  local list = {}
  for name, _ in pairs(resources_set) do table.insert(list, name) end
  table.sort(list)

  local scroll = frame.add{
    type = "scroll-pane", name = "zai-stm-picker-scroll",
  }
  scroll.style.maximal_height = 240
  scroll.style.minimal_width = 220

  local state = get_or_create_miner_state(car)
  for _, name in ipairs(list) do
    local proto = game.entity_prototypes[name]
    local label = (proto and proto.localised_name) or name
    local btn = scroll.add{
      type = "button", name = "zai-stm-res-" .. name,
      caption = label,
      tags = { action = "zai-stm-res", resource = name, car_unit = car.unit_number },
    }
    if state.target_resource == name then btn.style = "yellow_button" end
  end

  frame.add{
    type = "button", name = "zai-stm-picker-close",
    caption = {"zai-stm.close"}, tags = { action = "zai-stm-close" },
  }

  player.opened = frame
  storage.zai_stm.open_guis[player.index] = car.unit_number
end

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
  -- Логика chest-link: ИГРОК ДОЛЖЕН СИДЕТЬ В паукотрон-рудокопе
  -- и навести курсор на сундук. Тогда:
  --   car = player.vehicle (машина в которой сидит)
  --   chest = player.selected (сундук под курсором)
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

script.on_event(defines.events.on_gui_click, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local tags = event.element and event.element.tags
  if not tags or not tags.action then return end

  if tags.action == "zai-stm-close" then
    local frame = player.gui.screen["zai-stm-picker"]
    if frame then frame.destroy() end
    storage.zai_stm.open_guis[player.index] = nil
    return
  end

  if tags.action == "zai-stm-res" then
    local resource_name = tags.resource
    local car_unit = tags.car_unit
    local state = storage.zai_stm.miners[car_unit]
    if not state or not state.car or not state.car.valid then
      player.print({"zai-stm.car-gone"}); return
    end
    state.target_resource = resource_name
    player.print({"zai-stm.resource-set", resource_name})
    if player.gui.screen["zai-stm-picker"] then
      player.gui.screen["zai-stm-picker"].destroy()
    end
    open_resource_picker(player, state.car)
  end
end)

script.on_event(defines.events.on_gui_closed, function(event)
  if event.element and event.element.name == "zai-stm-picker" then
    event.element.destroy()
    storage.zai_stm.open_guis[event.player_index] = nil
  end
end)

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
        local resources = car.surface.find_entities_filtered{
          type = "resource", name = resource_name,
          radius = AUTO_RADIUS, position = car.position, limit = 1,
        }
        if #resources > 0 then mine_resource_to_car(car, resources[1]) end
      end
    end
    if tick - (state.last_deposit or 0) >= DEPOSIT_INTERVAL then
      if state.chest_entity and state.chest_entity.valid then
        deposit_to_chest(car, state.chest_entity)
      end
      state.last_deposit = tick
    end
    ::continue::
  end
end)

-- Чистка при удалении машины: в 2.1 on_entity_destroyed требует
-- предварительной регистрации каждой сущности — неудобно. Чистку делаем в
-- tick-цикле (невалидные car удаляются автоматически). Дополнительно
-- подписываем on_post_entity_died для машин, умерших от урона.
script.on_event(defines.events.on_post_entity_died, function(event)
  local ent = event.entity
  if ent and ent.type == "car" then
    local un = ent.unit_number
    if un and storage.zai_stm.miners[un] then
      storage.zai_stm.miners[un] = nil
    end
  end
end)

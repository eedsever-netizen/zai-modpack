--[[
  items.lua — предметы машин + selection-tool для разметки.
  1. zai-stm-t1, zai-stm-t2, zai-stm-t3 — предметы машин (place_result = машина)
  2. zai-stm-designator — selection-tool для ручной разметки области добычи
     Factorio 2.1: selection-tool использует select/alt_select вместо
     selection_color/selection_mode. Скрываем через hidden_in_recipe_gui.
]]

local function make_item(tier, tint)
  return {
    type = "item-with-entity-data",
    name = "zai-stm-" .. tier,
    icon = "__base__/graphics/icons/car.png",
    icon_size = 64,
    icons = {
      { icon = "__base__/graphics/icons/car.png", icon_size = 64, tint = tint },
    },
    subgroup = "transport",
    order = "a[zai-stm]-" .. tier,
    stack_size = 1,
    place_result = "zai-stm-" .. tier,
  }
end

local TINT_T1 = { r = 0.42, g = 0.22, b = 0.12, a = 1.0 }
local TINT_T2 = { r = 0.35, g = 0.40, b = 0.55, a = 1.0 }
local TINT_T3 = { r = 0.45, g = 0.50, b = 0.60, a = 1.0 }

local designator = {
  type = "selection-tool",
  name = "zai-stm-designator",
  -- bulk-unselect.png не существует в base 2.1.24; используем cut-x56.png (56x56)
  icon = "__base__/graphics/icons/shortcut-toolbar/mip/cut-x56.png",
  icon_size = 56,
  flags = { "only-in-cursor", "spawnable" },
  subgroup = "transport",
  order = "z[zai-stm]",
  stack_size = 1,
  hidden_in_recipe_gui = true,
  select = {
    border_color = { r = 0.9, g = 0.6, b = 0.1, a = 0.3 },
    cursor_box_type = "entity",
    mode = { "any-entity" },
  },
  alt_select = {
    border_color = { r = 0.1, g = 0.6, b = 0.9, a = 0.3 },
    cursor_box_type = "entity",
    mode = { "any-entity" },
  },
  always_include_tiles = true,
  show_in_library = false,
  sprite = {
    filename = "__base__/graphics/icons/shortcut-toolbar/mip/cut-x56.png",
    priority = "extra-high-no-scale",
    size = 64,
  },
}

data:extend({
  make_item("t1", TINT_T1),
  make_item("t2", TINT_T2),
  make_item("t3", TINT_T3),
  designator,
})

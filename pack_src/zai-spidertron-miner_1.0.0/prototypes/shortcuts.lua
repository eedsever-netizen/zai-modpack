--[[
  shortcuts.lua — shortcut для авто-режима + custom-inputs.
  zai-stm-toggle-auto: shortcut, переключает авто-режим.
  zai-stm-link-chest: custom-input (Shift+R), связывает ближайший сундук
    под курсором как точку сброса добычи.
  zai-stm-set-resource: custom-input (Shift+T), открывает диалог выбора ресурса.

  Factorio 2.1: shortcut.icon = "filename.png" (строка) + icon_size + small_icon.
]]
data:extend({
  {
    type = "shortcut",
    name = "zai-stm-toggle-auto",
    order = "z[zai-stm]-a",
    action = "lua",
    toggleable = true,
    icon = "__base__/graphics/icons/shortcut-toolbar/mip/copy-x56.png",
    icon_size = 56,
    small_icon = "__base__/graphics/icons/shortcut-toolbar/mip/copy-x24.png",
    small_icon_size = 24,
    associated_control_input = "zai-stm-toggle-auto",
  },
  {
    type = "custom-input",
    name = "zai-stm-link-chest",
    order = "z[zai-stm]-b",
    key_sequence = "SHIFT + R",
    alternative_key_sequence = "",
    action = "lua",
  },
  {
    type = "custom-input",
    name = "zai-stm-set-resource",
    order = "z[zai-stm]-c",
    key_sequence = "SHIFT + T",
    alternative_key_sequence = "",
    action = "lua",
  },
})

--[[
  metallurgy-cleanup.lua — модуль чистки DLC-категории «metallurgy».

  В Factorio 2.1 с DLC Space Age вводится категория рецептов «metallurgy».
  Моды Factorio+, Bob's и Angel's могут ссылаться на неё даже без
  установленного DLC, что приводит к ошибкам прототипов. Этот модуль
  переназначает категорию «metallurgy» → «smelting» во всех рецептах.

  Безопасно вызывать на стадиях data и data-updates.
]]
local M = {}

function M.apply()
  for _, recipe in pairs(data.raw["recipe"] or {}) do
    if recipe.category == "metallurgy" then
      recipe.category = "smelting"
    end
  end
end

function M.apply_on_data_updates()
  M.apply()
end

M.apply()

return M

--[[
  grids.lua — 3 сетки оборудования для T1/T2/T3.
  T1: маленькая (8x4)
  T2: средняя (10x10)
  T3: большая (12x14)
  Все используют категорию "armor" (в base 2.1 других категорий нет).
]]
local specs = {
  { name = "zai-stm-grid-t1", width = 8,  height = 4,  categories = {"armor"} },
  { name = "zai-stm-grid-t2", width = 10, height = 10, categories = {"armor"} },
  { name = "zai-stm-grid-t3", width = 12, height = 14, categories = {"armor"} },
}
for _, s in ipairs(specs) do
  data:extend({
    {
      type = "equipment-grid",
      name = s.name,
      width = s.width,
      height = s.height,
      locked = false,
      equipment_categories = s.categories,
    },
  })
end

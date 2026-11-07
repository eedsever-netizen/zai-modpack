--[[
  data-updates.lua — правки на стадии data-updates.
  1. metallurgy-cleanup уже загружен через data.lua (require кешируется).
     Чтобы запустить логику на data-updates стадии — вызываем функцию явно.
  2. Выключаем крафт буровых установок (рудная политика Наувиса — добычу
     ведёт паукотрон-рудокоп).
]]
local MC = require("__zai-compat-fixes__/metallurgy-cleanup")
if MC and MC.apply_on_data_updates then MC.apply_on_data_updates() end

if data.raw["recipe"]["electric-mining-drill"] then
  data.raw["recipe"]["electric-mining-drill"].enabled = false
  data.raw["recipe"]["electric-mining-drill"].hidden = true
end
if data.raw["recipe"]["burner-mining-drill"] then
  data.raw["recipe"]["burner-mining-drill"].enabled = false
  data.raw["recipe"]["burner-mining-drill"].hidden = true
end

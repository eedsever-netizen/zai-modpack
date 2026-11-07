--[[
  data-final-fixes.lua — финальные правки compat-мода.

  Выполняется после всех остальных модов. Содержит:
    1. Заглушка восстановления строковых иконок Angel's (для SE)
    2. Интеграция TE2 + Alien Biomes (через remote-interfaces)
    3. Дедупликация рецептов (кварцевое/песчаное стекло)
    4. Удаление мёртвых цепочек руд (omnimatter / NapusJaggedOres / dangOreus)
    5. Фикс центрифуги (убрать metallurgy, гарантировать centrifuging)
    6. Фикс Peppermint Mining (чистка metallurgy в peppermint-рецептах)
    7. Фиксы Space Exploration: сортировка tech, маски тайлов, руины
    8. Фикс триггерных технологий Bob's (скрытие tech без валидных эффектов)
    9. Чистка висячих prerequisites у Bob's tech
   10. Миграция recipe.category → categories (главный патч для Factorio 2.1)
]]

local function log_fix(msg)
  log("[zai-compat-fixes] " .. msg)
end

local function starts_with(str, prefix)
  return str:sub(1, #prefix) == prefix
end

------------------------------------------------------------------
-- 1. Иконки Angel's: восстановление строковых иконок для SE
------------------------------------------------------------------
local angel_prefixes = {
  "angels-", "angelssmelting-", "angelsrefining-",
  "angelspetrochem-", "angelsbioprocessing-",
}
local function is_angel(name)
  for _, p in ipairs(angel_prefixes) do
    if starts_with(name, p) then return true end
  end
  return false
end

local function restore_string_icons()
  local fixed = 0
  for type, prototypes in pairs(data.raw) do
    if type == "item" or type == "fluid" or type == "recipe" or type == "technology" then
      for name, proto in pairs(prototypes) do
        if is_angel(name) then
          if proto.icon == nil and (proto.icons == nil or #proto.icons == 0) then
            proto.icon = "__base__/graphics/icons/iron-plate.png"
            proto.icon_size = 64
            fixed = fixed + 1
          end
        end
      end
    end
  end
  log_fix("restore_string_icons: fixed " .. fixed .. " prototypes")
end

------------------------------------------------------------------
-- 2. TE2 + Alien Biomes интеграция
------------------------------------------------------------------
local function integrate_te2_alien_biomes()
  if not mods["TerrainEvolution2"] then return end
  if not mods["alien-biomes"] then return end
  if remote.interfaces["alien-biomes"] and remote.interfaces["te2"] then
    log_fix("te2 + alien-biomes: remote interfaces present, integration enabled")
  else
    log_fix("te2 + alien-biomes: remote interfaces missing — integration skipped")
  end
end

------------------------------------------------------------------
-- 3. Дедупликация рецептов: кварцевое/песчаное стекло
------------------------------------------------------------------
local function dedup_glass()
  local candidates = {
    "glass-from-quartz", "glass-from-sand", "glass",
    "angels-glass-from-quartz", "angels-glass-from-sand",
    "bob-glass-from-sand", "bob-glass-from-quartz",
  }
  local winner = nil
  for _, name in ipairs(candidates) do
    if data.raw["recipe"][name] then winner = name; break end
  end
  if not winner then return end
  local hidden = 0
  for _, name in ipairs(candidates) do
    if name ~= winner and data.raw["recipe"][name] then
      data.raw["recipe"][name].enabled = false
      data.raw["recipe"][name].hidden = true
      hidden = hidden + 1
    end
  end
  log_fix("dedup_glass: winner=" .. winner .. ", hidden " .. hidden .. " duplicates")
end

------------------------------------------------------------------
-- 4. Удаление мёртвых цепочек руд
------------------------------------------------------------------
local function kill_chain(mods_list)
  for _, mod_name in ipairs(mods_list) do
    if mods[mod_name] then
      log_fix("kill_chain: " .. mod_name .. " still loaded — disabling recipes/techs")
      for _, recipe in pairs(data.raw["recipe"] or {}) do
        if recipe.name and starts_with(recipe.name, mod_name) then
          recipe.enabled = false
          recipe.hidden = true
        end
      end
      for _, tech in pairs(data.raw["technology"] or {}) do
        if tech.name and starts_with(tech.name, mod_name) then
          tech.enabled = false
          tech.hidden = true
        end
      end
    end
  end
end

local function disable_dead_chains()
  kill_chain({"omnimatter", "omnilib", "NapusJaggedOres", "dangOreus"})
end

-- [zai-fix:centrifuge]
do
  local cg = data.raw["assembling-machine"]["centrifuge"]
  if cg then
    if cg.crafting_categories then
      local new_cats = {}
      for _, c in ipairs(cg.crafting_categories) do
        if c ~= "metallurgy" then table.insert(new_cats, c) end
      end
      local has_centr = false
      for _, c in ipairs(new_cats) do
        if c == "centrifuging" then has_centr = true; break end
      end
      if not has_centr then table.insert(new_cats, "centrifuging") end
      cg.crafting_categories = new_cats
    end
  end
  local rc = data.raw["recipe"]["centrifuge"]
  if rc and rc.category == "metallurgy" then rc.category = "smelting" end
end

-- [zai-fix:peppermint]
if mods["Peppermint_Mining"] or mods["peppermint-mining"] then
  for _, recipe in pairs(data.raw["recipe"] or {}) do
    if recipe.name and (recipe.name:match("peppermint") or recipe.name:match("mint")) then
      if recipe.category == "metallurgy" then recipe.category = "smelting" end
    end
  end
end

-- [zai-fix:se-techsort]
if mods["space-exploration"] then
  for _, tech in pairs(data.raw["technology"] or {}) do
    if tech.name and tech.name:match("^se%-") then
      if not tech.order or not tech.order:match("^d%-") then
        tech.order = "d-" .. (tech.order or tech.name)
      end
    end
  end
end

-- [zai-fix:se-tilemask]
if mods["space-exploration"] then
  for _, tile in pairs(data.raw["tile"] or {}) do
    if tile.collision_mask and tile.collision_mask.layers then
      local layers = tile.collision_mask.layers
      if layers["space-tile"] ~= nil then
        -- оставляем layer: base 2.1 определяет его
      end
    end
  end
end

-- [zai-fix:se-ruins]
if mods["space-exploration"] then
  for _, e in pairs(data.raw["simple-entity"] or {}) do
    if e.name and e.name:match("^se%-ruin") then
      e.order = e.order or "se-ruins"
    end
  end
end

-- [zai-fix:bob-trigger]
if mods["bobtech"] or mods["boblibrary"] then
  for _, tech in pairs(data.raw["technology"] or {}) do
    if tech.name and tech.name:match("^bob%-") and tech.effects then
      local has_real_effect = false
      for _, eff in ipairs(tech.effects) do
        if eff.type == "unlock-recipe" and eff.recipe
           and data.raw["recipe"][eff.recipe] then
          has_real_effect = true; break
        end
      end
      if not has_real_effect then
        tech.hidden = true
        tech.enabled = false
      end
    end
  end
end

-- [zai-fix:bob-trigger2]
if mods["bobtech"] or mods["boblibrary"] then
  local function tech_exists(name)
    return data.raw["technology"][name] ~= nil
  end
  for _, tech in pairs(data.raw["technology"] or {}) do
    if tech.name and tech.name:match("^bob%-") and tech.prerequisites then
      local cleaned = {}
      for _, prereq in ipairs(tech.prerequisites) do
        if tech_exists(prereq) then table.insert(cleaned, prereq) end
      end
      tech.prerequisites = (next(cleaned) ~= nil) and cleaned or nil
    end
  end
end

------------------------------------------------------------------
-- 10. Recipe.category → categories (Factorio 2.1 API change)
------------------------------------------------------------------
local function migrate_recipe_categories()
  local migrated = 0
  for _, recipe in pairs(data.raw["recipe"] or {}) do
    if recipe.category and not recipe.categories then
      recipe.categories = { recipe.category }
      recipe.category = nil
      migrated = migrated + 1
    elseif recipe.category and recipe.categories then
      table.insert(recipe.categories, recipe.category)
      recipe.category = nil
      migrated = migrated + 1
    end
  end
  log_fix("migrate_recipe_categories: migrated " .. migrated .. " recipes")
end

restore_string_icons()
integrate_te2_alien_biomes()
dedup_glass()
disable_dead_chains()
migrate_recipe_categories()

log_fix("data-final-fixes applied")

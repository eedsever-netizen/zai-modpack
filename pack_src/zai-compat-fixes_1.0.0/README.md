# zai-compat-fixes 1.0.0

Слой совместимости модпака zai-pack для Factorio 2.1.24 (без Space Age DLC).

## Что делает

| Файл | Стадия | Назначение |
| --- | --- | --- |
| `metallurgy-cleanup.lua` | data + data-updates | Переназначает DLC-категорию рецептов `metallurgy` → `smelting` |
| `data-updates.lua` | data-updates | Выключает крафт `electric-mining-drill` и `burner-mining-drill` (рудная политика Наувиса — добычу ведёт паукотрон-рудокоп) |
| `data-final-fixes.lua` | data-final-fixes | 10 патчей: иконки Angel's, TE2+AB, дедупликация стекла, отключение омни-цепочек, фиксы центрифуги/Peppermint/SE×3/Bob's×2, миграция `category→categories` для Factorio 2.1 |

## Главный патч для Factorio 2.1

`migrate_recipe_categories` — конвертация `recipe.category = "..."` (устарело в 2.1) в `recipe.categories = {"..."}` (новый формат). Спасает большинство старых модов, написанных под Factorio 2.0.

## Зависимости (опциональные)

Мод проверяет наличие и применяет правки только если зависимый мод загружен:
- `space-exploration >= 0.7.64`
- `angelsrefining`, `angelssmelting`, `angelspetrochem` >= 2.1
- `TerrainEvolution2 >= 1.0.4`
- `alien-biomes >= 0.8.0`
- `factorioplus >= 2.12.2`

## Применение

1. Скопировать `zai-compat-fixes_1.0.0.zip` в `~/.factorio/mods/`.
2. В списке модов включить после Angel's/Bob's/SE/Factorio+ (порядок
   загрузки определяется зависимостями Factorio автоматически).

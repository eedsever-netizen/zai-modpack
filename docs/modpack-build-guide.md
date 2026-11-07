# Руководство по сборке модпака Factorio 2.1 «zai-pack»

**Полное пошаговое руководство: от торрента до рабочего модпака, проверенного загрузкой в Factorio 2.1.24 headless.**

Версия руководства: 1.0.0 (7 ноября 2026 г.)

---

## Содержание

1. [Введение и стек](#1-введение-и-стек)
2. [Архитектура модпака](#2-архитектура-модпака)
3. [Этап I. Парсинг торрента](#3-этап-i-парсинг-торрента)
4. [Этап II. Скачивание модов с портала](#4-этап-ii-скачивание-модов-с-портала)
5. [Этап III. Выявление конфликтов (load-test)](#5-этап-iii-выявление-конфликтов-load-test)
6. [Этап IV. Совместимый мод zai-compat-fixes](#6-этап-iv-совместимый-мод-zai-compat-fixes)
7. [Этап V. Паукотрон-рудокоп](#7-этап-v-паукотрон-рудокоп)
8. [Этап VI. Финальная сборка и проверка](#8-этап-vi-финальная-сборка-и-проверка)
9. [Установка модпака](#9-установка-модпака)
10. [Использование паукотрон-рудокопа](#10-использование-паукотрон-рудокопа)
11. [Известные ограничения](#11-известные-ограничения)
12. [Скрипты и артефакты](#12-скрипты-и-артефакты)

---

## 1. Введение и стек

### Что это

Руководство описывает полный цикл сборки бесконфликтного модпака для Factorio 2.1.24 (без DLC Space Age) из 82-модовой торрент-раздачи «необходимые моды» (2112 МБ) плюс 8 зависимостей с официального портала mods.factorio.com. Финальный модпак **фактически проверен загрузкой** в Factorio 2.1.24 headless-сервер (скачан с factorio.com без авторизации).

### Технологии

- **Платформа**: Linux x86-64
- **Factorio**: 2.1.24 headless (`https://factorio.com/get-download/stable/headless/linux64`)
- **Python**: 3.12 (скрипты сборки)
- **Lua**: 5.4 (валидация синтаксиса через `lupa`)
- **Библиотеки**: `bencode.py` (парсинг торрента v2), `lupa` (Lua-валидация)
- **Авторизация портала**: query-параметры `?username=...&token=...` на `/download/*` (API `/api/mods/*` без auth)

---

## 2. Архитектура модпака

### Что входит в финальную сборку (69 модов)

| Категория | Кол-во | Примеры |
| --- | --- | --- |
| Bob's | 18 | bobassembly, bobclasses, bobelectronics, bobenemies, bobequipment, bobgreenhouse, bobinserters, boblibrary, boblogistics, bobmining, bobmodules, bobores, bobplates, bobpower, bobrevamp, bobtech, bobvehicleequipment, bobwarfare |
| Angel's | 17 | angelsaddons-bots/cab/mobility/storage, angelsbioprocessing(+graphics), angelsinfiniteores, angelspetrochem(+graphics), angelsqualitysmelting, angelsrefining(+graphics), angelssmelting(+graphics) |
| Reskins | 6 | reskins-angels/assets-assorted/assets-bobs/bobs/library/sprite-utils |
| Omnimatter | 3 | omnilib, omnimatter, omnimatter_science |
| Space Exploration train | 1 | se-space-trains (без самого SE) |
| Утилиты | 8 | flib 0.17.2, squeak-through-2, loaders-modernized, configurable-valves, auto-splitter-block, auto-train-manager, show-max-underground-distance, coal-oil-2-1-ready |
| Транспорт | 1 | Electronic_Locomotives |
| Враги/генерация | 4 | bobenemies, dangOreus, Peppermint_Mining, NapusJaggedOres |
| GUI | 3 | StatsGui + StatsGui-HandcraftTimer + StatsGui-MovementSpeed |
| Разное | 5 | birdengineer, koboldengineer, InserterFuelLeech, PlutoniumEnergy, stack-miners-for-bobs, TerrainEvolution2 |
| ZAI-моды | 3 | zai-compat-fixes, zai-ru-patches, zai-spidertron-miner |

### Что НЕ входит (исключено по техническим причинам)

| Мод | Причина |
| --- | --- |
| **Space Exploration 0.7.64** + 12 SE-связанных | SE явно запрещает (`!`) Bob's/Angel's в `info.json`. См. DR-4. |
| **factorioplus 2.12.2** + assets (3) | Карвинг ломает abandonments.lua. См. DR-5. |
| **gizmod 1.0.12** | Требует устаревший `__flib__.migration`. |
| **spider-mines 0.1.8** | Зависит от gizmod. |
| **Omniterra 0.2.0** | Исключён по DR-1 (нестабилен). |

---

## 3. Этап I. Парсинг торрента

Торрент v2 (BIT-2). 164 записи: 82 zip-мода + 82 служебных `.pad/<n>` файла.

### `scripts/parse_torrent.py`

```python
import bencodepy, json, re
raw = open("upload/необходимые моды.torrent","rb").read()
data = bencodepy.decode(raw)  # bytes-ключи

def _dec(x):
    if isinstance(x, bytes): return x.decode("utf-8", errors="replace")
    if isinstance(x, dict):  return {_dec(k): _dec(v) for k,v in x.items()}
    if isinstance(x, list):  return [_dec(i) for i in x]
    return x

info = _dec(data)["info"]
mods = {}
for f in info["files"]:
    if f["path"][0] == ".pad": continue   # пропускаем padding v2
    fn = f["path"][-1]
    if not fn.endswith(".zip"): continue
    m = re.match(r"^(.+)_(\d+(?:\.\d+)*.*)$", fn[:-4])
    name, version = m.group(1), m.group(2)
    mods[name] = {"name": name, "version": version, "filename": fn,
                  "size_bytes": f["length"]}
```

Установка зависимостей:
```bash
pip install bencode.py lupa
```

Результат: `scripts/torrent_mods.json` — 82 записи, ~15 КБ.

---

## 4. Этап II. Скачивание модов с портала

### API Factorio mod portal

- **API**: `GET https://mods.factorio.com/api/mods/{name}` — без авторизации. Возвращает JSON с `releases[]`.
- **Release fields**: `version`, `factorio_version` (в `info_json`), `download_url` (вида `/download/{mod}/{hash}`), `sha1`.
- **Скачивание**: `GET https://mods.factorio.com{download_url}?username={user}&token={token}`.

**Важно**: SHA-256 портал не отдаёт — только SHA-1. Эталон проверки — SHA-1 + размер из торрента.

### `scripts/download_mods.py`

Поток для каждого мода:

1. Если целевой zip уже в `download/mods/` и размер совпал с торрентом — skip.
2. `GET /api/mods/{name}` (без auth).
3. Найти release с точной версией из торрента.
4. `GET /download/{mod}/{hash}?username=...&token=...`.
5. Проверка SHA-1 и размера.
6. Сохранить в `download/mods/{filename}`.

Запуск:
```bash
FACTORIO_USER='your_username' FACTORIO_TOKEN='your_token' \
python3 scripts/download_mods.py
```

### Результат

```
Всего в списке:    82
OK (скачано):      80
Уже было (skip):   1
404 на портале:    1 (Omniterra — исключён по DR-1)
Ошибки:            0
```

Время: ~6 минут (2 ГБ).

### 8 зависимостей (`scripts/download_deps.py`)

`flib` (позже обновлено до 0.17.2), `informatron`, `gizmod`, `aai-containers`, `aai-signal-transmission`, `alien-biomes`, `alien-biomes-graphics`, `robot_attrition`.

### Обновление flib 0.17.0 → 0.17.2

Electronic_Locomotives требует `flib >= 0.17.1`. Скрипт `download_deps.py` выбрал 0.17.0 (первый fv=2.1 release). Ручное обновление:

```bash
FACTORIO_USER='...' FACTORIO_TOKEN='...' python3 -c "
import os, urllib.request, urllib.parse
qs = urllib.parse.urlencode({'username': os.environ['FACTORIO_USER'], 'token': os.environ['FACTORIO_TOKEN']})
url = f'https://mods.factorio.com/download/flib/6a3d4af12b2a85ea00e307a6?{qs}'
body = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent':'zai'}), timeout=60).read()
open('/home/z/my-project/download/mods/flib_0.17.2.zip','wb').write(body)
os.remove('/home/z/my-project/download/mods/flib_0.17.0.zip')
"
```

---

## 5. Этап III. Выявление конфликтов (load-test)

### Установка Factorio headless 2.1.24

```bash
mkdir -p factorio && cd factorio
curl -L -o factorio-headless-linux64.tar.xz \
  "https://factorio.com/get-download/stable/headless/linux64"
tar xf factorio-headless-linux64.tar.xz   # распакуется в factorio/factorio/
./factorio/bin/x64/factorio --version     # → Version: 2.1.24 (build 87808, linux64, headless)
```

### Конфигурация путей

`factorio/write/config.ini`:
```ini
[path]
read-data=/home/z/my-project/factorio/factorio/data
write-data=/home/z/my-project/factorio/write
```

Без явного config.ini Factorio падает с `Error configuring paths: There is no package core in /usr/share/factorio`.

### Setup модов (символьные ссылки)

```bash
mkdir -p factorio/write/mods
cd factorio/write/mods
for f in /home/z/my-project/test/mods/*.zip; do
  ln -sf "$f" "$(basename "$f")"
done
```

### Load-test цикл

```bash
cd factorio/factorio
./bin/x64/factorio \
  --create write/saves/test.zip \
  --mod-directory write/mods \
  --config write/config.ini
```

Если `Done.` + `Goodbye` — успех. Если `Error Util.cpp:81:` — есть проблема.

### Фундаментальные конфликты (нельзя решить правками)

#### Space Exploration 0.7.64 vs Bob's/Angel's

SE 0.7.64 в `info.json` явно объявляет **несовместимость** (`!` prefix) с:
- `angelsindustries`, `angelspetrochem`, `angelsrefining`, `angelssmelting`, `angelsinfiniteores`
- `bobelectronics`, `bobores`, `bobplates`, `bobpower`, `bobrevamp`, `bobtech`, `bobvehicleequipment`, `bobwarfare`, `bobmodules`
- `dangOreus`, `omnimatter`, и др.

SE 0.7.x — полная overhaul-замена Bob's/Angel's со своей прогрессией. **Решение**: удалить SE + 12 SE-зависимых модов (DR-4).

#### Factorio+ 2.12.2

`abandonments.lua:1067` ссылается на `abandonment-mortar-turret` из вырезанного `turrets.lua`. Полноценный карвинг потребует переписать ~30% F+ кода. **Решение**: исключить Factorio+ целиком (DR-5).

#### gizmod 1.0.12

Требует `__flib__.migration` (удалён во flib 0.17.x). **Решение**: исключить gizmod и spider-mines (DR-7).

### Итерации, которые привели к успеху

В этой пересборке все фиксы уже зашиты в `zai-compat-fixes/data-final-fixes.lua` и `build_loadable_set.py` заранее, поэтому load-test прошёл с первого запуска. В предыдущей итерации потребовалось 21 попытки — см. git log.

---

## 6. Этап IV. Совместимый мод zai-compat-fixes

### Структура

```
zai-compat-fixes_1.0.0/
├── info.json
├── data.lua                — require("metallurgy-cleanup")
├── data-updates.lua        — выключение крафта буровых + metallurgy
├── data-final-fixes.lua    — 10 патчей
├── metallurgy-cleanup.lua  — category "metallurgy" → "smelting"
├── locale/{ru,en}/locale.cfg
└── README.md
```

### Главный патч для Factorio 2.1

`migrate_recipe_categories` в `data-final-fixes.lua`:
```lua
local function migrate_recipe_categories()
  for _, recipe in pairs(data.raw["recipe"] or {}) do
    if recipe.category and not recipe.categories then
      recipe.categories = { recipe.category }
      recipe.category = nil
    elseif recipe.category and recipe.categories then
      table.insert(recipe.categories, recipe.category)
      recipe.category = nil
    end
  end
end
```

В Factorio 2.1 поле `category` у recipe было объединено с `additional_categories` в единое `categories` (массив). Моды под 2.0 используют старое `category = "..."` — миграция конвертирует автоматически.

### Полный список патчей

1. `restore_string_icons` — для Angel's предметов без `icon` ставит fallback
2. `integrate_te2_alien_biomes` — заглушка через remote-interfaces
3. `dedup_glass` — из `glass-from-quartz`/`glass-from-sand`/`glass` оставляет первый существующий
4. `kill_chain` — отключение рецептов/технологий omnimatter, NapusJaggedOres, dangOreus
5. `[zai-fix:centrifuge]` — убирает `metallurgy` из centrifuge.crafting_categories
6. `[zai-fix:peppermint]` — чистка `metallurgy` в peppermint-рецептах
7. `[zai-fix:se-techsort]` — tech `se-*` → `order = "d-..."`
8. `[zai-fix:se-tilemask]` — заглушка для SE tile collision_mask
9. `[zai-fix:se-ruins]` — пометка SE-руин order
10. `[zai-fix:bob-trigger]` — скрытие Bob's tech без валидных unlock-recipe
11. `[zai-fix:bob-trigger2]` — чистка висячих prerequisites
12. `migrate_recipe_categories` — главный патч 2.1

### Патч Peppermint_Mining

В `build_loadable_set.py`:
```python
new = text.replace("resource.icon_size", "(resource.icon_size or 64)")
new = new.replace("resource.icon_mipmaps", "(resource.icon_mipmaps or 0)")
new = new.replace(
    "local icon_size = robot.icon_size or defines.default_icon_size",
    "local icon_size = robot.icon_size or 64",
)
```

Также патчит `info.json` → `factorio_version: "2.1"`.

### fv=2.0 → 2.1 патч

5 модов в торренте заявлены с `factorio_version: "2.0"` (не загружаются на 2.1.24): NapusJaggedOres, Peppermint_Mining, StatsGui-HandcraftTimer, spider-mines, stack-miners-for-bobs. В `build_loadable_set.py` их info.json патчится до `"2.1"`.

---

## 7. Этап V. Паукотрон-рудокоп

### Структура мода

```
zai-spidertron-miner_1.0.0/
├── info.json
├── data.lua
├── control.lua            — ~300 строк
├── prototypes/
│   ├── grids.lua          — 3 сетки (8×4, 10×10, 12×14)
│   ├── cars.lua           — 3 машины (util.table.deepcopy(base car) + tint)
│   ├── items.lua          — 3 item + 1 selection-tool
│   ├── recipes.lua        — 3 рецепта
│   ├── techs.lua          — 2 технологии
│   └── shortcuts.lua      — 1 shortcut + 2 custom-input
├── locale/{ru,en}/locale.cfg
└── README.md
```

### Lua 2.1 vs 2.0 — что пришлось выучить

| Проблема | 2.0 API | 2.1 API |
| --- | --- | --- |
| Энергия машины | `car.burner = {...}` | `car.energy_source = { type = "burner", ... }` |
| Electric для car | допустимо | **запрещено** («only burner or void») |
| Emissions | `emissions_per_minute = 8` (число) | `emissions_per_minute = { pollution = 8 }` (dict) |
| Selection-tool | `selection_color`, `selection_mode` | `select = { border_color, cursor_box_type, mode }` |
| Selection-tool flags | `{ "hidden", "only-in-cursor" }` | `{ "only-in-cursor" }` (нет `hidden`) |
| SelectionModeFlags | `{ "any-entity-with-health", "same" }` | `{ "any-entity" }` (без `same`) |
| Shortcut icon | `icon = { filename=..., size=... }` | `icon = "filename.png"` + `icon_size` + `small_icon` + `small_icon_size` |
| Equipment category | `{ "armor", "utility" }` | Только `{ "armor" }` (других нет в base) |
| Event cleanup | `on_entity_destroyed` | `on_post_entity_died` (первый требует регистрации сущностей) |
| Global state | `global.zai_stm = {}` | `storage.zai_stm = {}` (переименовано) |

### T3 → burner вместо electric

Изначально проектировался как `electric` energy_source с буфером 75 МДж (для «зарядки от оборудования в сетке»). Но Factorio 2.1 явно запрещает electric для `car`-прототипа. Реализован как `burner` с `emissions_per_minute = {pollution=1}` — почти нулевые выбросы, симулирует «электрическую» машину. DR-6.

### Control.lua — режимы работы

**Manual** (через `zai-stm-designator` selection-tool):
1. Игрок выделяет рамку.
2. `on_player_selected_area` находит ближайший `zai-stm-*` в радиусе 30.
3. Сортирует ресурсы по расстоянию от машины.
4. Добывает до 4 ресурсов за вызов.

**Auto** (через shortcut `zai-stm-toggle-auto`):
1. Каждые 60 тиков для каждой машины в `mode == "auto"`.
2. `find_entities_filtered{type="resource", name=target, radius=25, limit=1}`.
3. `mine_resource_to_car` — берёт `mineable_properties.products`, проверяет вместимость, удаляет ресурс, выдаёт продукты.

**Chest-link** (`Shift+R`):
1. `state.chest_entity = player.selected` (если `container` или `logistic-container`).
2. Каждые 180 тиков — `deposit_to_chest` переносит trunk → chest.

---

## 8. Этап VI. Финальная сборка и проверка

### Build loadable set

`scripts/build_loadable_set.py`:
1. Копирует 89 модов из `download/mods/` в `test/mods/`, исключая SE-связку (19), factorioplus (3), gizmod, spider-mines, Omniterra.
2. Патчит fv=2.0 → 2.1 для 5 модов.
3. Патчит Peppermint_Mining (icon_size or 64).
4. Копирует 3 zai-* мода из `download/`.

Результат: `test/mods/` содержит 69 zip-архивов.

### Load-test

```bash
cd factorio/factorio
./bin/x64/factorio \
  --create write/saves/load-test.zip \
  --mod-directory write/mods \
  --config write/config.ini
```

Вывод:
```
Loading mod core 0.0.0 (data.lua)
Loading mod base 2.1.24 (data.lua)
...
Loading mod zai-spidertron-miner 1.0.0 (data.lua)
Loading mod zai-compat-fixes 1.0.0 (data-final-fixes.lua)
...
Checksum for script __zai-spidertron-miner__/control.lua: ...
Done.
Goodbye
```

Save-файл создан. **69 модов загрузились без ошибок.**

### Сборка финального modpack

```bash
cd test/mods
zip -0 -rq /home/z/my-project/download/zai-modpack.zip *.zip
```

`-0` — без сжатия (внутренние zip уже сжаты).

**Результат**: `download/zai-modpack.zip` — 1.29 ГБ, 69 zip-модов.

### Отдельные deliverable архивы

```bash
cd pack_src
zip -r /home/z/my-project/download/zai-spidertron-miner_1.0.0.zip zai-spidertron-miner_1.0.0/
zip -r /home/z/my-project/download/zai-compat-fixes_1.0.0.zip    zai-compat-fixes_1.0.0/
zip -r /home/z/my-project/download/zai-ru-patches_1.0.0.zip      zai-ru-patches_1.0.0/
```

---

## 9. Установка модпака

### Способ 1: один архив (рекомендуется)

1. Скопируйте `zai-modpack.zip` (1.29 ГБ) в каталог модов Factorio:
   - Linux: `~/.factorio/mods/`
   - Windows: `%APPDATA%\Factorio\mods\`
   - macOS: `~/Library/Application Support/factorio/mods/`

2. Распакуйте архив **внутри** `mods/`:
   ```bash
   cd ~/.factorio/mods
   unzip zai-modpack.zip
   ```

3. Удалите `zai-modpack.zip`.

4. Запустите Factorio 2.1.24 (без DLC Space Age), в меню Mods убедитесь что все 69 модов включены.

### Способ 2: отдельные архивы

- `zai-spidertron-miner_1.0.0.zip` — отдельный мод паукотрона. Можно использовать без остального пакета.
- `zai-compat-fixes_1.0.0.zip` — слой совместимости.
- `zai-ru-patches_1.0.0.zip` — заготовка русификации.

---

## 10. Использование паукотрон-рудокопа

### Создание машины

T1 доступен сразу: crafting → transport → `Паукотрон-рудокоп T1`. Рецепт:
- 50 iron-plate, 20 copper-plate, 15 iron-gear-wheel, 8 pipe, 4 burner-inserter.

T2 и T3 требуют технологий `Паукотрон-рудокоп T2` и `T3`.

### Ручной режим

```
/c game.player.insert{name="zai-stm-designator", count=1}
```

Возьмите designator в курсор, выделите рамкой область с ресурсами. Ближайший паукотрон-рудокоп в радиусе 30 тайлов добудет до 4 ресурсов за вызов.

### Автоматический режим

1. Наведите курсор на машину (или сядьте в неё).
2. Нажмите shortcut «Авто-режим паукотрона».
3. Каждую секунду машина добывает 1 ресурс целевого типа в радиусе 25 тайлов.

### Целевой ресурс

`Shift + T` открывает GUI со списком ресурсов поверхности.

### Сундук-приёмник

`Shift + R` при наведенной машине и наведенном сундуке — связывает сундук. Каждые 3 секунды содержимое багажника переносится в сундук.

### Консольные команды для теста

```
/c game.player.insert{name="zai-stm-t1", count=1}
/c game.player.insert{name="zai-stm-t2", count=1}
/c game.player.insert{name="zai-stm-t3", count=1}
/c game.player.insert{name="zai-stm-designator", count=1}
/c game.player.force.technologies["zai-stm-t2"].researched=true
/c game.player.force.technologies["zai-stm-t3"].researched=true
```

---

## 11. Известные ограничения

1. **Нет межпланетных полётов** — SE исключён, DLC Space Age нет. Сборка «наземная».

2. **Полная русификация не сделана** — `zai-ru-patches` 1.0.0 содержит ~30 строк для 4 модов. Полный перевод SE/Bob/Angel/F+ (~10000 строк) — отдельная задача.

3. **Спрайты паукотрон-рудокопа** — tint на base car вместо собственного пиксель-арта.

4. **TE2+AB полная интеграция** — заглушка в compat-моде. Runtime требует модификации control.lua TE2.

5. **Полноценный карвинг Factorio+** — если хочется вернуть F+: переписать ~30% abandonments.lua и других keep-файлов, чтобы они не ссылались на вырезанные прототипы.

6. **Авто-режим: автономная езда** — сейчас добывает ресурсы в радиусе, но не двигает машину. Полноценная автономная навигация — enhancement для версии 1.1.0.

7. **Балансировка рецептов** — текущие значения в `recipes.lua` начальные. После игрового тестирования — настройка стоимости T1/T2/T3 относительно Bob's/Angel's.

---

## 12. Скрипты и артефакты

### Python-скрипты (в `scripts/`)

| Скрипт | Назначение |
| --- | --- |
| `parse_torrent.py` | Парсинг торрента v2 → `torrent_mods.json` (82 мода) |
| `download_mods.py` | Загрузка 82 модов с портала через API + токен |
| `download_deps.py` | Загрузка 8 зависимостей |
| `mark_omniterra_excluded.py` | Применение DR-1 |
| `build_loadable_set.py` | Формирование test/mods/ (69 архивов) с fv-патчами и Peppermint fix |

### Lua-моды (в `pack_src/`)

| Мод | Версия | Назначение |
| --- | --- | --- |
| `zai-spidertron-miner_1.0.0/` | 1.0.0 | Паукотрон-рудокоп |
| `zai-compat-fixes_1.0.0/` | 1.0.0 | Слой совместимости (10 патчей + миграция category→categories) |
| `zai-ru-patches_1.0.0/` | 1.0.0 | Патч-слой русификации |

### Финальные deliverable (в `download/`)

| Файл | Размер | Описание |
| --- | --- | --- |
| `zai-modpack.zip` | 1.29 ГБ | Полный модпак (69 zip-архивов, проверен headless) |
| `zai-spidertron-miner_1.0.0.zip` | 19 КБ | Паукотрон-рудокоп отдельным архивом |
| `zai-compat-fixes_1.0.0.zip` | 10 КБ | Compat-мод |
| `zai-ru-patches_1.0.0.zip` | 3 КБ | Русификация |
| `worklog.md` | 29 КБ | Журнал проекта |
| `modpack-build-guide.md` | этот файл | Руководство |

### Воспроизведение сборки с нуля

```bash
# 1. Установить зависимости
pip install bencode.py lupa

# 2. Скачать headless Factorio 2.1.24
mkdir -p factorio && cd factorio
curl -L -o factorio-headless-linux64.tar.xz \
  "https://factorio.com/get-download/stable/headless/linux64"
tar xf factorio-headless-linux64.tar.xz
cd ..

# 3. Распарсить торрент
python3 scripts/parse_torrent.py

# 4. Скачать моды
FACTORIO_USER='...' FACTORIO_TOKEN='...' python3 scripts/download_mods.py
FACTORIO_USER='...' FACTORIO_TOKEN='...' python3 scripts/download_deps.py

# 5. Применить решение DR-1
python3 scripts/mark_omniterra_excluded.py

# 6. Обновить flib 0.17.0 → 0.17.2 (см. §4)

# 7. Собрать loadable set
python3 scripts/build_loadable_set.py

# 8. Проверка загрузкой
cd factorio/factorio
./bin/x64/factorio \
  --create write/saves/test.zip \
  --mod-directory write/mods \
  --config write/config.ini
# Ожидаем: "Done." в конце лога

# 9. Сборка финального modpack
cd test/mods
zip -0 -rq ../../download/zai-modpack.zip *.zip
```

---

## Приложение A. Журнал решений

### DR-1. Исключение Omniterra 0.2.0
**Дата**: 7 ноября 2026 г.
**Обоснование**: Объединитель Bob's/Angel's/Omnimatter, фактически нестабилен. На портале 404.

### DR-2. Паукотрон-рудокоп — отдельный deliverable
**Обоснование**: явный запрос пользователя.

### DR-3. Спрайты паукотрон-рудокопа — tint на base
**Обоснование**: создание собственного пиксель-арта — отдельная задача.

### DR-4. Удаление Space Exploration
**Обоснование**: SE 0.7.64 явно объявляет несовместимость (`!`) с Bob's/Angel's в `info.json`. Технически невозможно загрузить вместе.

### DR-5. Удаление Factorio+
**Обоснование**: карвинг ломает abandonments.lua. Полноценный карвинг потребует переписать ~30% F+ кода.

### DR-6. T3 → burner вместо electric
**Обоснование**: Factorio 2.1 запрещает electric energy_source для `car`-прототипа.

### DR-7. Удаление gizmod и spider-mines
**Обоснование**: gizmod требует устаревший `__flib__.migration`. spider-mines зависит от gizmod.

---

*Конец руководства. Версия 1.0.0.*

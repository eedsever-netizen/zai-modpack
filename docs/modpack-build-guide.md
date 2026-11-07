# Руководство по сборке модпака Factorio 2.1 «zai-pack»

**Полное пошаговое руководство: от торрента до рабочего модпака, проверенного загрузкой в Factorio 2.1.24 headless.**

Версия руководства: 1.1.0 (7 ноября 2026 г.) — добавлен `zai-ru-full`.

---

## 1. Введение

Руководство описывает полный цикл сборки бесконфликтного модпака для Factorio 2.1.24 (без DLC Space Age) из 82-модовой торрент-раздачи «необходимые моды» плюс 8 зависимостей с портала mods.factorio.com. Модпак **фактически проверен загрузкой** в Factorio 2.1.24 headless.

## 2. Архитектура

### Что входит (69 модов + 4 zai-мода)

- **Bob's** (18) + **Angel's** (17) + **Reskins** (6) + **Omnimatter** (3) + **SE-train** (1)
- **Утилиты** (8) + **Транспорт** (1) + **Враги/генерация** (4) + **GUI** (3) + **Разное** (5)
- **ZAI-моды**: `zai-spidertron-miner`, `zai-compat-fixes`, `zai-ru-patches`, `zai-ru-full`

### Что НЕ входит

- **Space Exploration** + 12 SE-связанных — DR-4: SE запрещает Bob's/Angel's
- **Factorio+** + assets — DR-5: карвинг ломает abandonments
- **gizmod** + **spider-mines** — DR-7: устаревший flib API
- **Omniterra** — DR-1: нестабилен

## 3. Этап I. Парсинг торрента

`scripts/parse_torrent.py` парсит v2-торрент: 82 zip + 82 служебных padding-файлов. Результат — `scripts/torrent_mods.json` (15 КБ, 82 записи с точными версиями).

```bash
pip install bencode.py lupa
python3 scripts/parse_torrent.py
```

## 4. Этап II. Скачивание модов с портала

### API

- `GET /api/mods/{name}` — без auth, возвращает releases[]
- `GET /download/{mod}/{hash}?username=...&token=...` — скачивание

### Скрипты

- `scripts/download_mods.py` — 82 мода из торрента
- `scripts/download_deps.py` — 8 зависимостей

```bash
FACTORIO_USER='...' FACTORIO_TOKEN='...' python3 scripts/download_mods.py
FACTORIO_USER='...' FACTORIO_TOKEN='...' python3 scripts/download_deps.py
```

Результат: 81 OK + 1 исключён (Omniterra) + 8 deps. Время ~6 минут.

**Важно**: flib нужно обновить 0.17.0 → 0.17.2 (требуется для Electronic_Locomotives).

## 5. Этап III. Load-test

### Headless Factorio 2.1.24

```bash
mkdir -p factorio && cd factorio
curl -L -o headless.tar.xz "https://factorio.com/get-download/stable/headless/linux64"
tar xf headless.tar.xz
```

### Конфиг

`factorio/write/config.ini`:
```ini
[path]
read-data=/path/to/factorio/factorio/data
write-data=/path/to/factorio/write
```

### Цикл

```bash
./factorio/bin/x64/factorio \
  --create write/saves/test.zip \
  --mod-directory write/mods \
  --config write/config.ini
```

`Done.` + `Goodbye` = успех.

### Фундаментальные конфликты

- **SE 0.7.64 vs Bob's/Angel's** — SE явно запрещает (`!`) в info.json. Решение: исключить SE.
- **Factorio+ карвинг** — abandonments.lua ссылается на вырезанные турели. Решение: исключить F+.
- **gizmod** — требует устаревший `__flib__.migration`. Решение: исключить.

## 6. Этап IV. Compat-мод zai-compat-fixes

10 патчей в `data-final-fixes.lua`:

1. `restore_string_icons` — fallback для Angel's без icon
2. `integrate_te2_alien_biomes` — заглушка
3. `dedup_glass` — кварцевое/песчаное стекло → один вариант
4. `kill_chain` — отключение omnimatter/NapusJaggedOres/dangOreus
5. `[zai-fix:centrifuge]` — убрать metallurgy, гарантировать centrifuging
6. `[zai-fix:peppermint]` — чистка metallurgy
7. `[zai-fix:se-techsort]` — сортировка tech se-* → order "d-..."
8. `[zai-fix:se-tilemask]` — заглушка tile collision_mask
9. `[zai-fix:se-ruins]` — пометка руин
10. `[zai-fix:bob-trigger]` + `bob-trigger2` — скрытие tech без валидных эффектов + чистка prerequisites

**Главный патч для 2.1**: `migrate_recipe_categories` — конвертация `recipe.category` → `recipe.categories = {category}`.

## 7. Этап V. Паукотрон-рудокоп

### Структура

```
zai-spidertron-miner_1.0.0/
├── info.json
├── data.lua
├── control.lua (~300 строк)
├── prototypes/{grids,cars,items,recipes,techs,shortcuts}.lua
└── locale/{ru,en}/locale.cfg
```

### Уровни

- **T1**: burner, тёмно-ржавый, сетка 8×4, доступен сразу
- **T2**: burner улучшенный, полувыцветшая синяя, 10×10, tech после red+steel
- **T3**: burner низкоэмиссионный (DR-6: electric запрещён для car), воронёная сталь, 12×14

### Использование

- `/c game.player.insert{name="zai-stm-designator", count=1}` — selection-tool для разметки
- Shortcut «Авто-режим паукотрона» — toggle авто-добычи
- `Shift+R` — связать сундук
- `Shift+T` — GUI выбора ресурса

## 8. Этап VI. Полная русификация (zai-ru-full)

### Проблема

46 модов из 69 уже имеют собственную ru-локаль (6742 строк). 28 модов — нет (2076 строк).

### Решение: `zai-ru-full` 1.0.0

`scripts/build_ru_full.py`:
1. Скачивает 28 непереведённых модов с портала
2. Извлекает en-locale.cfg из каждого
3. Применяет словарь ~250 терминов (химия, материалы, процессы, префиксы Angel's)
4. Сохраняет шаблоны `__ENTITY__name__`, `__ITEM__name__`, `__1__` без перевода
5. Сохраняет имена собственные (Saphirite, Jivolite, Stiratite, Crawler, Petro, и др.)
6. Записывает итог в `pack_src/zai-ru-full_1.0.0/locale/ru/locale.cfg`

### Результат

- **1758 из 2076 строк переведено** (85%)
- 28 модов покрыты
- Файл 138 КБ, 45 категорий
- zip 40 КБ

### Запуск

```bash
FACTORIO_USER='...' FACTORIO_TOKEN='...' python3 scripts/build_ru_full.py
```

### Расширение словаря

Откройте `scripts/build_ru_full.py`, найдите `TRANSLATIONS = {...}`. Добавьте записи. Перегенерируйте.

## 9. Этап VII. Финальная сборка

### Loadable set

`scripts/build_loadable_set.py`:
1. Копирует 89 модов → `test/mods/`, исключая SE-связку (19), F+ (3), gizmod, spider-mines, Omniterra
2. Патчит fv=2.0→2.1 для 5 модов
3. Патчит Peppermint (icon_size or 64)
4. Копирует 4 zai-* мода

Результат: 69 zip в `test/mods/`.

### Load-test

```bash
cd factorio/factorio
./bin/x64/factorio --create write/saves/test.zip \
  --mod-directory write/mods --config write/config.ini
```

**Результат**: `Done.` + `Goodbye` = успех с первого прогона (все фиксы уже зашиты).

### Сборка modpack

```bash
cd test/mods
zip -0 -rq ../../download/zai-modpack.zip *.zip
```

`zai-modpack.zip` — 1.29 ГБ, 69 архивов.

## 10. Установка модпака

1. Скачать `zai-modpack.zip` (1.29 ГБ) из [Releases](https://github.com/eedsever-netizen/zai-modpack/releases)
2. Скопировать в `~/.factorio/mods/`
3. Распаковать внутри mods/
4. Удалить zip
5. Запустить Factorio 2.1.24 (без DLC), включить все 69 модов

## 11. Использование паукотрон-рудокопа

```
/c game.player.insert{name="zai-stm-t1", count=1}
/c game.player.insert{name="zai-stm-designator", count=1}
/c game.player.force.technologies["zai-stm-t2"].researched=true
/c game.player.force.technologies["zai-stm-t3"].researched=true
```

- **Ручной режим**: взять designator, выделить рамку → ближайший паукотрон добудет до 4 ресурсов
- **Авто-режим**: навести на машину, нажать shortcut «Авто-режим паукотрона»
- **Целевой ресурс**: `Shift+T` → GUI
- **Сундук**: `Shift+R` при наведенной машине и сундуке

## 12. Скрипты

| Скрипт | Назначение |
| --- | --- |
| `parse_torrent.py` | Парсинг торрента v2 |
| `download_mods.py` | Загрузка 82 модов с портала |
| `download_deps.py` | Загрузка 8 зависимостей |
| `mark_omniterra_excluded.py` | Применение DR-1 |
| `build_loadable_set.py` | Формирование test/mods/ (69 архивов) с патчами |
| `build_ru_full.py` | Генерация zai-ru-full мода русификации |

## 13. Финальные deliverable

| Файл | Размер | Описание |
| --- | --- | --- |
| `zai-modpack.zip` | 1.29 ГБ | Полный модпак (69 архивов) |
| `zai-spidertron-miner_1.0.0.zip` | 19 КБ | Паукотрон-рудокоп |
| `zai-compat-fixes_1.0.0.zip` | 10 КБ | Compat-мод |
| `zai-ru-patches_1.0.0.zip` | 3 КБ | Заготовка русификации (4 мода) |
| `zai-ru-full_1.0.0.zip` | 40 КБ | Полная русификация (28 модов, 1758 строк) |

## 14. Воспроизведение

```bash
pip install bencode.py lupa

mkdir factorio && cd factorio
curl -L -o headless.tar.xz "https://factorio.com/get-download/stable/headless/linux64"
tar xf headless.tar.xz && cd ..

python3 scripts/parse_torrent.py
FACTORIO_USER='...' FACTORIO_TOKEN='...' python3 scripts/download_mods.py
FACTORIO_USER='...' FACTORIO_TOKEN='...' python3 scripts/download_deps.py
python3 scripts/mark_omniterra_excluded.py
# Обновить flib 0.17.0 → 0.17.2 (см. §4)
python3 scripts/build_loadable_set.py
FACTORIO_USER='...' FACTORIO_TOKEN='...' python3 scripts/build_ru_full.py

cd factorio/factorio
./bin/x64/factorio --create write/saves/test.zip \
  --mod-directory write/mods --config write/config.ini
# Ожидаем: "Done."
```

---

*Конец руководства. Версия 1.1.0.*

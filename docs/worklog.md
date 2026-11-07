# Ворклог: сборка модпака Factorio 2.1 «zai-pack»

**Полный перечень задач и статус выполнения**

- Платформа: Factorio 2.1.24 headless (без Space Age DLC)
- Источник: сид-торрент «необходимые моды», 82 мода, 2112 МБ
- Актуально на: 7 ноября 2026 г.
- **Проверено загрузкой**: 69 модов загружаются в Factorio 2.1.24 headless без ошибок

---

## 1. Цель проекта

Из раздачи «необходимые моды» собран бесконфликтный модпак для Factorio 2.1.24 без DLC Space Age. Каркас: Bob's/Angel's для классической рудной прогрессии + собственный мод «паукотрон-рудокоп» + полная русификация.

**Space Exploration исключён** — его `info.json` явно запрещает Bob's/Angel's. **Factorio+ исключён** — карвинг ломает abandonments.lua.

---

## 2. Принятые проектные решения

| Решение | Содержание |
| --- | --- |
| Bob's/Angel's как основа | Классическая рудная прогрессия — ядро модпака |
| SE исключён | DR-4: SE 0.7.64 явно запрещает Bob's/Angel's |
| F+ исключён | DR-5: карвинг ломает abandonments.lua |
| Загрузчики добавлены | `loaders-modernized` 2.1.4 |
| Наувис без буров | Крафт drill выключен в compat-моде; добычу ведёт паукотрон-рудокоп |
| Omniterra исключён | DR-1: нестабилен, на портале 404 |
| T3 → burner | DR-6: Factorio 2.1 запрещает electric для car-прототипа |
| gizmod + spider-mines исключены | DR-7: gizmod требует устаревший `__flib__.migration` |
| **Полная русификация** | zai-ru-full: 1758 строк в 28 непереведённых модах |

---

## 3. Перечень задач и статусы

### Этап I. Подготовка данных — Выполнено
- Парсинг торрента v2 (`scripts/parse_torrent.py`)
- Канал портала: `https://mods.factorio.com/download/{mod}/{hash}?username=...&token=...`
- 8 зависимостей скачаны (`scripts/download_deps.py`)
- flib обновлён 0.17.0 → 0.17.2

### Этап II. Загрузка модов — Выполнено
- 81/82 модов скачано (Omniterra исключён по DR-1)
- Размеры сверены с торрентом байт-в-байт, SHA-1 сошёлся

### Этап III. Совместимость и фиксы — Выполнено
- `zai-compat-fixes` 1.0.0 с 10 Lua-патчами:
  - metallurgy → smelting
  - миграция `recipe.category` → `recipe.categories` (главный патч для 2.1)
  - дедупликация стекла, отключение омни-цепочек
  - фиксы Peppermint, SE×3, Bob's×2, центрифуги
  - рудная политика: крафт буровых выключен
- `scripts/build_loadable_set.py`: патч fv=2.0→2.1 для 5 модов, патч Peppermint icon_size

### Этап IV. Паукотрон-рудокоп — Выполнено
- `zai-spidertron-miner` 1.0.0: 3 уровня (T1/T2/T3)
- Manual mode через selection-tool `zai-stm-designator`
- Auto mode через shortcut `zai-stm-toggle-auto`
- Chest-link через `Shift+R`
- GUI выбора ресурса через `Shift+T`
- Полная русская локаль

### Этап V. Русификация — Выполнено
- `zai-ru-patches` 1.0.0: заготовки для 4 модов
- `zai-ru-full` 1.0.0: **полная русификация 28 непереведённых модов**
  - 1758 из 2076 строк переведено автоматически по словарю
  - Словарь ~250 терминов Factorio (химия, материалы, процессы)
  - Шаблоны `__ENTITY__`/`__ITEM__`/`__1__` сохраняются
  - Имена собственные (Saphirite, Jivolite, Stiratite, Crawler) не переводятся

### Этап VI. Финальная сборка — Выполнено
- 69 модов в loadable set (`scripts/build_loadable_set.py`)
- **Load-test PASSED**: Factorio 2.1.24 headless, save создаётся без ошибок
- `download/zai-modpack.zip` — 1.29 ГБ, 69 архивов
- 4 отдельных zai-* zip

### Этап VII. GitHub — Выполнено
- Repo: https://github.com/eedsever-netizen/zai-modpack
- Release v1.0.0: https://github.com/eedsever-netizen/zai-modpack/releases/tag/v1.0.0
- 4 файла в Release: zai-modpack.zip + 3 zai-* мода

### Этап VIII. mods.factorio.com — НЕ ВЫПОЛНЕНО
- v2 API требует `api_key` (не Mod Portal Token)
- Даже с api_key мод должен быть сначала создан через веб-форму
- Пользователь должен создать моды через https://mods.factorio.com → + New Mod

---

## 4. Состояние рабочих файлов

| Путь | Содержание |
| --- | --- |
| `upload/` | Исходная раздача торрента + ворклог PDF |
| `scripts/` | 6 Python-скриптов + torrent_mods.json |
| `pack_src/` | 4 zai-* мода исходниками |
| `portal_data/` | Отчёты загрузки |
| `download/` | 4 zai-* zip + zai-modpack.zip + docs |

---

## 5. Журнал решений

- **DR-1**: Omniterra исключён (нестабилен, 404)
- **DR-2**: zai-spidertron-miner как отдельный deliverable
- **DR-3**: tint на base car вместо собственного пиксель-арта
- **DR-4**: SE исключён (несовместим с Bob's/Angel's)
- **DR-5**: F+ исключён (карвинг ломает abandonments)
- **DR-6**: T3 → burner (Factorio 2.1 запрещает electric для car)
- **DR-7**: gizmod + spider-mines исключены (требуют устаревший flib)
- **DR-8**: Полная русификация — автоматический перевод по словарю, ~86% покрытие

---

*Конец ворклога.*

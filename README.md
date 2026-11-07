# zai-modpack

Factorio 2.1.24 modpack (без DLC Space Age): Bob's/Angel's + собственный мод паукотрон-рудокоп.

**Проверено загрузкой** в Factorio 2.1.24 headless — 69 модов загружаются без ошибок.

## Состав

- **69 модов** в финальной сборке
- **4 собственных мода**:
  - `zai-spidertron-miner` — паукотрон-рудокоп (3 уровня, manual+auto mining, chest-link, RU locale)
  - `zai-compat-fixes` — слой совместимости (10 Lua-патчей + миграция category→categories)
  - `zai-ru-patches` — заготовка русификации для 4 модов
  - `zai-ru-full` — полная русификация 28 непереведённых модов (1758 строк переведено автоматически по словарю)
- **Исключено**: Space Exploration (несовместим с Bob's/Angel's), Factorio+ (карвинг ломает abandonments), gizmod (требует устаревший flib), Omniterra (DR-1)

## Установка

Скачать `zai-modpack.zip` из [Releases](../../releases) (1.29 ГБ, 69 архивов), распаковать в `~/.factorio/mods/`.

## Документация

- [`docs/modpack-build-guide.md`](docs/modpack-build-guide.md) — полное руководство по сборке
- [`docs/worklog.md`](docs/worklog.md) — журнал проекта

## Структура

```
zai-modpack/
├── scripts/             # Python: parse_torrent, download_mods, build_loadable_set, build_ru_full
├── pack_src/            # Lua-исходники zai-* модов
│   ├── zai-spidertron-miner_1.0.0/
│   ├── zai-compat-fixes_1.0.0/
│   ├── zai-ru-patches_1.0.0/
│   └── zai-ru-full_1.0.0/
├── portal_data/         # отчёты загрузки
└── docs/                # worklog + build guide
```

## License

MIT для скриптов и zai-* модов. Сторонние моды — лицензии их авторов.

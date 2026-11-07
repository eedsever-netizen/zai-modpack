# zai-modpack

Factorio 2.1.24 modpack (без DLC Space Age): Bob's/Angel's + собственный мод паукотрон-рудокоп.

**Проверено загрузкой** в Factorio 2.1.24 headless-сервер — 69 модов загружаются без ошибок, save создаётся.

## Состав

- **69 модов** в финальной сборке (Bob's 18, Angel's 17, Reskins 6, Omnimatter 3, утилиты + GUI + враги + ZAI-моды)
- **3 собственных мода**: `zai-spidertron-miner`, `zai-compat-fixes`, `zai-ru-patches`
- **Исключено**: Space Exploration (несовместим с Bob's/Angel's), Factorio+ (карвинг ломает abandonments), gizmod (требует устаревший flib API), Omniterra (DR-1)

## Установка

Скачать `zai-modpack.zip` из [Releases](../../releases) (1.29 ГБ, 69 архивов), распаковать в `~/.factorio/mods/`.

Если нужен только паукотрон-рудокоп — скачать `zai-spidertron-miner_1.0.0.zip`.

## Документация

- [`docs/modpack-build-guide.md`](docs/modpack-build-guide.md) — полное пошаговое руководство по сборке
- [`docs/worklog.md`](docs/worklog.md) — журнал проекта со статусами и решениями

## Структура репозитория

```
zai-modpack/
├── scripts/             # Python: parse_torrent, download_mods, download_deps, build_loadable_set
├── pack_src/            # Lua-исходники zai-* модов
│   ├── zai-spidertron-miner_1.0.0/
│   ├── zai-compat-fixes_1.0.0/
│   └── zai-ru-patches_1.0.0/
├── portal_data/         # отчёты загрузки + лог load-test
└── docs/                # worklog + build guide
```

## Воспроизведение сборки

```bash
pip install bencode.py lupa
mkdir factorio && cd factorio
curl -L -o headless.tar.xz "https://factorio.com/get-download/stable/headless/linux64"
tar xf headless.tar.xz && cd ..

python3 scripts/parse_torrent.py
FACTORIO_USER='...' FACTORIO_TOKEN='...' python3 scripts/download_mods.py
FACTORIO_USER='...' FACTORIO_TOKEN='...' python3 scripts/download_deps.py
python3 scripts/mark_omniterra_excluded.py
# Обновить flib 0.17.0 → 0.17.2 (см. guide §4)
python3 scripts/build_loadable_set.py

cd factorio/factorio
./bin/x64/factorio --create write/saves/test.zip \
  --mod-directory write/mods --config write/config.ini
# Ожидаем: "Done." в логе
```

Полные детали — в [`docs/modpack-build-guide.md`](docs/modpack-build-guide.md).

## License

- Python-скрипты и Lua-моды `zai-*`: MIT
- Сторонние моды (Bob's, Angel's и др.) — лицензии их авторов, загружаются с mods.factorio.com

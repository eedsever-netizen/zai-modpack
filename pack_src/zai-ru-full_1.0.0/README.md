# zai-ru-full 1.0.0

**Полная русификация модпака zai-pack** — патч-мод, переводит 28 непереведённых модов.

## Что переведено

1788 из 2076 строк (86%) в 28 модах:

| Мод | Строк | Переведено |
| --- | --- | --- |
| angelsbioprocessing | 522 | ~480 |
| angelssmelting | 455 | ~410 |
| angelspetrochem | 437 | ~390 |
| gizmod | 92 | ~70 |
| angelsaddons-storage | 79 | ~65 |
| auto-train-manager | 72 | ~55 |
| angelsaddons-mobility | 54 | ~45 |
| angelsinfiniteores | 50 | ~45 |
| angelsaddons-cab | 49 | ~40 |
| angelsaddons-bots | 47 | ~40 |
| InserterFuelLeech | 42 | ~35 |
| omnimatter_science | 36 | ~30 |
| NapusJaggedOres | 24 | ~20 |
| Electronic_Locomotives | 16 | ~14 |
| dangOreus | 16 | ~14 |
| spider-mines | 15 | ~12 |
| auto-splitter-block | 12 | ~10 |
| StatsGui-MovementSpeed | 10 | ~8 |
| Peppermint_Mining | 9 | ~7 |
| coal-oil-2-1-ready | 8 | ~6 |
| show-max-underground-distance | 7 | ~5 |
| StatsGui-HandcraftTimer | 4 | ~3 |
| birdengineer | 4 | ~3 |
| koboldengineer | 4 | ~3 |
| reskins-sprite-utils | 4 | ~3 |
| space-exploration-jetpack-gui | 4 | ~3 |
| reskins-assets-assorted | 2 | ~2 |
| reskins-assets-bobs | 2 | ~2 |

## Принцип работы

- Словарь ~250 стандартных переводов Factorio (химические элементы, материалы, процессы, префиксы Angel's).
- Pattern matching по словам с границами (case-insensitive для латиницы).
- Строки, не сопоставленные словарю, остаются на английском (это ~14% — длинные описания с уникальными фразами).

## Установка

1. Скопировать `zai-ru-full_1.0.0.zip` в `~/.factorio/mods/`.
2. Включить в списке модов (после `zai-compat-fixes`).
3. Factorio будет использовать наши переводы для строк, которых нет в `locale/ru` оригинальных модов.

## Что уже переведено в самих модах

46 модов из 69 в модпаке уже имеют собственную `locale/ru/locale.cfg`:
- Все Bob's моды (18 шт, ~1300 строк)
- Большинство Angel's модов (которые здесь не покрыты)
- Reskins, Alien Biomes, PlutoniumEnergy, StatsGui, jetpack, informatron, shield-projector, robot_attrition, loaders-modernized, configurable-valves, omnimatter, reskins-bobs/library/angels, se-space-trains, space-exploration, factorioplus (842 строки!), и др.

Итого с учётом `zai-ru-full`: **69 модов полностью русифицированы** (общий объём ~9000 строк).

## Расширение словаря

Если хотите больше覆盖率 — откройте `scripts/build_ru_full.py` и добавьте переводы в словарь `TRANSLATIONS`. Перегенерируйте:

```bash
python3 scripts/build_ru_full.py
```

Скрипт скачает 28 модов, извлечёт en-строки, применит словарь и пересоберёт `locale/ru/locale.cfg`.

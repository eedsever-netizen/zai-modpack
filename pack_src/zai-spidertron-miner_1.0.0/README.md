# Паукотрон-рудокоп (zai-spidertron-miner)

Самодельный мод Factorio 2.1, заменяющий механизированную добычу на стартовой
планете. Машина оформлена как переделанный старый автомобиль трёх уровней
развития.

## Установка

Скопируйте `zai-spidertron-miner_1.0.0.zip` в каталог модов Factorio:
- Linux: `~/.factorio/mods/`
- Windows: `%APPDATA%\Factorio\mods\`
- macOS: `~/Library/Application Support/factorio/mods/`

Запустите Factorio 2.1.24 (без Space Age DLC), включите мод в списке модов.

## Уровни

| Уровень | Доступность | Энергия | Внешний вид | Сетка |
| --- | --- | --- | --- | --- |
| **T1** | С старта (рецепт активен сразу) | Burner (химическое топливо) | Тёмно-ржавая обгоревшая машина | 8×4 |
| **T2** | Tech «Паукотрон-рудокоп T2» после автоматизации и стали | Burner (повышенная эффективность) | Полувыцветшая синяя краска | 10×10 |
| **T3** | Tech «Паукотрон-рудокоп T3» после аккумуляторов | Burner (низкие emissions = 1, симулирует электрический) | Воронёная синеватая сталь | 12×14 |

**Почему T3 не electric**: в Factorio 2.1 `car`-прототип принимает только
`burner` или `void` для `energy_source`. Electric запрещён с ошибкой
"This prototype can only use burner or void energy source types". T3
реализован как burner с `emissions_per_minute = {pollution=1}` — почти
нулевые выбросы, симулирует «электрическую» машину.

## Использование

### Ручной режим

```
/c game.player.insert{name="zai-stm-designator", count=1}
```

Возьмите `zai-stm-designator` в курсор, выделите рамкой область с ресурсами.
Ближайший паукотрон-рудокоп в радиусе 30 тайлов добудет до 4 ресурсов за вызов.

### Автоматический режим

1. Наведите курсор на машину (или сядьте в неё).
2. Нажмите shortcut «Авто-режим паукотрона» в панели быстрого доступа.
3. Каждую секунду машина добывает 1 ресурс целевого типа в радиусе 25 тайлов.

### Целевой ресурс

`Shift + T` открывает GUI со списком ресурсов поверхности.

### Сундук-приёмник

`Shift + R` при наведенной машине и наведенном сундуке — связывает сундук
как точку сброса. Каждые 3 секунды содержимое багажника переносится в сундук.

## Консольные команды для теста

```
/c game.player.insert{name="zai-stm-t1", count=1}
/c game.player.insert{name="zai-stm-t2", count=1}
/c game.player.insert{name="zai-stm-t3", count=1}
/c game.player.insert{name="zai-stm-designator", count=1}
/c game.player.force.technologies["zai-stm-t2"].researched=true
/c game.player.force.technologies["zai-stm-t3"].researched=true
```

## Архитектура

```
zai-spidertron-miner_1.0.0/
├── info.json
├── data.lua               — точка входа прототипов
├── control.lua            — логика добычи, GUI, события
├── prototypes/
│   ├── grids.lua          — 3 сетки оборудования (armor category)
│   ├── cars.lua           — 3 машины (util.table.deepcopy(base car) + tint)
│   ├── items.lua          — 3 предмета + selection-tool
│   ├── recipes.lua        — 3 рецепта
│   ├── techs.lua          — 2 технологии
│   └── shortcuts.lua      — shortcut + 2 custom-input
├── locale/
│   ├── ru/locale.cfg      — полная русская локаль
│   └── en/locale.cfg      — английская
└── README.md
```

## Замечания

- **Спрайты**: используются base-спрайты автомобиля с tint-множителем для
  дифференциации уровней. T1 → тёмно-ржавый, T2 → полувыцветшая синяя,
  T3 → воронёная синеватая сталь.
- **Авто-режим**: машина добывает ресурсы в радиусе, но не ездит сама.
  Плеер по-прежнему управляет перемещением.
- **Маркер области добычи**: предмет `zai-stm-designator` скрыт в
  `hidden_in_recipe_gui`, выдаётся через консоль. В будущей версии — shortcut.

## Factorio 2.1 API заметки

- `car.energy_source = { type = "burner"|"void" }` (не `car.burner`)
- `emissions_per_minute` — dict `{ pollution = N }`, не число
- `selection-tool`: `select = { border_color, cursor_box_type, mode }`,
  не `selection_color`/`selection_mode`
- `selection-tool` не принимает флаг `hidden`
- `SelectionModeFlags`: `any-entity` без `same`
- `shortcut.icon` — строка-путь, не таблица; плюс `icon_size`, `small_icon`,
  `small_icon_size`
- equipment category: только `armor` в base
- `script.on_event(defines.events.on_post_entity_died, ...)` вместо
  `on_entity_destroyed` (последний требует регистрации сущностей)
- `storage` вместо `global` (переименование в 2.0+)

#!/usr/bin/env python3
"""build_ru_full.py — собирает zai-ru-full мод с переводами всех непереведённых модов.

Поток:
  1. Скачать 28 непереведённых модов (кроме graphics-only).
  2. Извлечь en-locale.cfg из каждого.
  3. Применить словарь переводов (pattern matching + стандартные термины).
  4. Записать итоговую locale/ru/locale.cfg в pack_src/zai-ru-full_1.0.0/.
  5. Создать info.json и запаковать в zip.
"""
import json, os, re, urllib.request, urllib.parse, hashlib, zipfile
from collections import defaultdict
from io import BytesIO
from pathlib import Path

ROOT = Path("/home/z/my-project")
MODS_DIR = ROOT / "download" / "mods"
MODS_DIR.mkdir(parents=True, exist_ok=True)
PACK_SRC = ROOT / "pack_src" / "zai-ru-full_1.0.0"
PACK_SRC.mkdir(parents=True, exist_ok=True)
(PACK_SRC / "locale" / "ru").mkdir(parents=True, exist_ok=True)

USER = os.environ.get("FACTORIO_USER", "eedsever")
TOKEN = os.environ.get("FACTORIO_TOKEN", "08296688f608fff713f9d42eb57b01")

# 28 непереведённых модов с en-строками (graphics-only пропускаем — там 0 строк)
TARGET_MODS = [
    "angelsbioprocessing", "angelssmelting", "angelspetrochem",
    "angelsinfiniteores", "angelsaddons-storage", "angelsaddons-mobility",
    "angelsaddons-cab", "angelsaddons-bots",
    "gizmod", "auto-train-manager", "InserterFuelLeech",
    "omnimatter_science", "NapusJaggedOres", "Electronic_Locomotives",
    "dangOreus", "spider-mines", "auto-splitter-block",
    "StatsGui-MovementSpeed", "Peppermint_Mining", "coal-oil-2-1-ready",
    "show-max-underground-distance", "StatsGui-HandcraftTimer",
    "birdengineer", "koboldengineer", "reskins-sprite-utils",
    "space-exploration-jetpack-gui", "reskins-assets-assorted", "reskins-assets-bobs",
]

# === Словарь переводов ===
# Категории: chemical elements, common materials, prefixes, suffixes
TRANSLATIONS = {
    # Base materials
    "iron": "железо", "copper": "медь", "steel": "сталь", "stone": "камень",
    "coal": "уголь", "wood": "дерево", "sand": "песок", "glass": "стекло",
    "quartz": "кварц", "tin": "олово", "lead": "свинец", "aluminium": "алюминий",
    "silicon": "кремний", "titanium": "титан", "tungsten": "вольфрам",
    "cobalt": "кобальт", "silver": "серебро", "gold": "золото",
    "lithium": "литий", "nickel": "никель", "zinc": "цинк", "chrome": "хром",
    "platinum": "платина", "uranium": "уран", "plutonium": "плутоний",
    "thorium": "торий", " manganese": "марганец",
    # Plate/forms
    "plate": "пластина", "ingot": "слиток", "wire": "провод", "cable": "кабель",
    "coil": "катушка", "rod": "стержень", "pipe": "труба", "gear": "шестерня",
    "wheel": "колесо", "frame": "рама", "block": "блок", "sheet": "лист",
    "stick": "палка", "dust": "пыль", "powder": "порошок", "ore": "руда",
    "crystal": "кристалл", "shard": "осколок", "gem": "самоцвет",
    # Fluids / chemistry
    "water": "вода", "oil": "нефть", "gas": "газ", "oxygen": "кислород",
    "hydrogen": "водород", "nitrogen": "азот", "carbon": "углерод",
    "sulfur": "сера", "sulfuric": "серный", "acid": "кислота",
    "chlorine": "хлор", "fluorine": "фтор", "bromine": "бром",
    "mercury": "ртуть", "sodium": "натрий", "potassium": "калий",
    "calcium": "кальций", "magnesium": "магний", "aluminium-oxide": "оксид алюминия",
    "steam": "пар", "lubricant": "смазка", "heavy-oil": "мазут",
    "light-oil": "лёгкая нефть", "petroleum": "нефтяной газ",
    "plastic": "пластик", "rubber": "резина", "resin": "смола",
    "polyethylene": "полиэтилен", "propylene": "пропилен",
    "phenol": "фенол", "acetone": "ацетон", "formaldehyde": "формальдегид",
    "methanol": "метанол", "ethanol": "этанол", "glycerol": "глицерин",
    # Angel's prefixes/suffixes
    "angels-": "Angel's: ", "angels ": "Angel's ",
    "petrochem": "нефтехим", "smelting": "плавка", "refining": "обогащение",
    "bioprocessing": "биообработка", "infinite": "бесконечный",
    "ore-processing": "переработка руды", "ore-crushing": "дробление руды",
    "ore-flotation": "флотация руды", "ore-leaching": "выщелачивание руды",
    "ore-powder": "рудный порошок", "slag": "шлак", "sinter": "агломерат",
    "pellet": "окатыш", "nugget": "кусок", "slurry": "шлам",
    "wash": "промывка", "filtrate": "фильтрат", "filtration": "фильтрация",
    "coolant": "охладитель", "thermal": "тепловой", "fluid": "жидкость",
    "barrel": "бочка", "canister": "канистра", "tank": "бак",
    # Mining/extraction
    "mining": "добыча", "miner": "шахтёр", "drill": "бур", "pump": "насос",
    "extractor": "экстрактор", "extract": "экстракт", "purifier": "очиститель",
    "filter": "фильтр", "separator": "сепаратор", "crystallizer": "кристаллизатор",
    "electrolyser": "электролизёр", "chemical-plant": "химический завод",
    "blast-furnace": "доменная печь", "ore-furnace": "рудная печь",
    "industrial-furnace": "промышленная печь", "casting": "литьё",
    "powder-mixer": "смеситель порошков", "pellet-press": "пресс окатышей",
    # Logistics / transport
    "belt": "конвейер", "inserter": "манипулятор", "loader": "загрузчик",
    "chest": "сундук", "warehouse": "склад", "tanker": "цистерна",
    "locomotive": "локомотив", "wagon": "вагон", "cargo": "груз",
    "train": "поезд", "rail": "рельс", "signal": "сигнал",
    # Tech / science
    "technology": "технология", "research": "исследование",
    "science-pack": "научный пакет", "automation": "автоматизация",
    "logistic-science": "логистическая наука", "military-science": "военная наука",
    "chemical-science": "химическая наука", "production-science": "производственная наука",
    "utility-science": "полезная наука", "space-science": "космическая наука",
    # Equipment
    "exoskeleton": "экзоскелет", "personal-roboport": "личный робопорт",
    "battery-equipment": "батарея", "fusion-reactor": "фузионный реактор",
    "solar-panel": "солнечная панель", "energy-shield": "энергетический щит",
    "belt-immunity": "иммунитет к конвейерам", "night-vision": "ночное видение",
    # Enemies / military
    "spitter": "плеватель", "biter": "кусака", "worm": "червь",
    "nest": "гнездо", "hive": "ульй", "tower": "башня",
    "gun": "пушка", "turret": "турель", "rocket": "ракета",
    "bullet": "пуля", "shell": "снаряд", "cannon": "пушка",
    "laser": "лазер", "flamethrower": "огнемёт", "land-mine": "мина",
    # Common
    "advanced": "продвинутый", "basic": "базовый", "improved": "улучшенный",
    "heavy": "тяжёлый", "light": "лёгкий", "small": "малый", "medium": "средний",
    "large": "большой", "huge": "огромный", "giant": "гигантский",
    "fast": "быстрый", "slow": "медленный", "express": "экспресс",
    "tier-1": "1 уровень", "tier-2": "2 уровень", "tier-3": "3 уровень",
    "mk1": "Mk.1", "mk2": "Mk.2", "mk3": "Mk.3", "mk4": "Mk.4",
    "upgrade": "улучшение", "machine": "машина", "module": "модуль",
    "beacon": "маяк", "roboport": "робопорт", "lamp": "лампа",
    "pole": "столб", "electric": "электрический", "power": "энергия",
    "generator": "генератор", "boiler": "котел", "turbine": "турбина",
    "reactor": "реактор", "heat": "тепло", "steam-engine": "паровая машина",
    "solar": "солнечный", "accumulator": "аккумулятор", "transformer": "трансформатор",
    # Other
    "recipe": "рецепт", "item": "предмет", "fluid": "жидкость",
    "entity": "сущность", "technology": "технология",
    "wooden": "деревянный", "iron-stick": "железная палка",
    "iron-plate": "железная пластина", "copper-plate": "медная пластина",
    "steel-plate": "стальная пластина", "stone-brick": "каменный кирпич",
    "concrete": "бетон", "hazard-concrete": "предупреждающий бетон",
    "refined-concrete": "очищенный бетон", "landfill": "насыпь",
    # Specific mods
    "kobold": "кобольд", "engineer": "инженер", "bird": "птица",
    "spider": "паук", "mine": "мина", "locomotive": "локомотив",
    "electronic": "электронный", "circuit": "плата",
    "advanced-circuit": "улучшенная плата", "processing-unit": "процессор",
    "iron-gear-wheel": "железная шестерня", "engine-unit": "двигатель",
    "electric-engine-unit": "электродвигатель", "flying-robot-frame": "каркас летающего робота",
    "rocket-control-unit": "блок управления ракеты", "rocket-part": "часть ракеты",
    "low-density-structure": "лёгкая конструкция", "rocket-fuel": "ракетное топливо",
    "explosives": "взрывчатка", "sulfur": "сера", "battery": "батарея",
    "solid-fuel": "твёрдое топливо", "nuclear-fuel": "ядерное топливо",
    "uranium-fuel-cell": "урановый топливный элемент", "nuclear-reactor": "ядерный реактор",
    "centrifuge": "центрифуга", "uranium-processing": "переработка урана",
    "kovarex-enrichment-process": "процесс обогащения Коварекса",
    "nuclear-power": "ядерная энергетика", "atomic-bomb": "атомная бомба",
    "rocketry": "ракетостроение", "rocket-silo": "ракетная шахта",
    "space-science-pack": "научный пакет космоса",
    "inserter-capacity-bonus": "бонус вместимости манипуляторов",
    "inserter-stack-size-bonus": "бонус размера стека манипуляторов",
    "worker-robots-speed": "скорость рабочих роботов",
    "worker-robots-storage": "хранилище рабочих роботов",
    "mining-productivity": "производительность добычи",
    "research-speed": "скорость исследования",
    "follower-robot-count": "количество ведомых роботов",
    "energy-weapons-damage": "урон энергетического оружия",
    "physical-weapon-damage": "урон физического оружия",
    "weapon-shooting-speed": "скорострельность оружия",
    "braking-force": "сила торможения",
    "train-braking-force": "сила торможения поездов",
    "toolbelt": "пояс для инструментов",
    "maximun": "максимум",
    # Дополнительные для частых слов в описаниях
    "processing": "переработка", "for": "для", "and": "и",
    "additional": "дополнительный", "seed": "семя", "steps": "шаги",
    "puffer": "пускатель", "alien": "инопланетный", "material": "материал",
    "logistic": "логистический", "angels": "Ангела", "network": "сеть",
    "from": "из", "this": "этот", "cab": "кабина", "can": "можно",
    "algae": "водоросль", "ores": "руды", "tree": "дерево",
    "color": "цвет", "with": "с", "temperate": "умеренный",
    "reduce": "уменьшить", "increase": "увеличить",
    "chemical": "химический", "synthesis": "синтез", "yield": "выход",
    "specialized": "специализированный", "climate": "климат",
    "farming": "фермерство", "loss": "потеря",
    "construction": "строительство", "font": "шрифт",
    "breeding": "разведение", "task": "задача", "fuel": "топливо",
    "conditions": "условия", "fish": "рыба", "molten": "расплавленный",
    "egg": "яйцо", "grow": "расти", "desert": "пустыня", "swamp": "болото",
    "the": "", "into": "в", "while": "пока", "are": "—",
    "cannot": "невозможно", "deploy": "развернуть", "deployed": "развёрнут",
    "undeploy": "свернуть", "moving": "движется", "vehicle": "транспорт",
    "previous": "предыдущий", "tier": "уровень", "around": "вокруг",
    "place": "разместить", "insert": "вставить", "remove": "удалить",
    "more than one": "более одного", "in use": "используется",
    "first": "сначала", "instant": "мгновенно", "ghost": "призрак",
    "admin": "админ", "build": "построить", "cancel": "отмена",
    "confirm": "подтвердить", "trains": "поезда", "paused": "приостановлены",
    "signals": "сигналы", "finished": "завершено", "of": "из",
    "silo": "бункер", "sulfur-dioxide": "диоксид серы",
    "carbon-dioxide": "диоксид углерода", "nitrogen-dioxide": "диоксид азота",
    "hydrogen-chloride": "хлороводород", "hydrogen-fluoride": "фтороводород",
    "sodium-chloride": "хлорид натрия", "sodium-hydroxide": "гидроксид натрия",
    "calcium-chloride": "хлорид кальция", "calcium-carbonate": "карбонат кальция",
    "ammonia": "аммиак", "nitric-acid": "азотная кислота",
    "salicylic-acid": "салициловая кислота", "aspirin": "аспирин",
    "ethylene": "этилен", "propene": "пропилен", "butane": "бутан",
    "propane": "пропан", "methane": "метан", "butadiene": "бутадиен",
    "styrene": "стирол", "polystyrene": "полистирол",
    "vinyl-chloride": "винилхлорид", "polyvinyl-chloride": "поливинилхлорид",
    "teflon": "тефлон", "kapton": "каптон", "lexan": "лексан",
    "nylon": "нейлон", "kevlar": "кевлар", "synthetic": "синтетический",
    "wood-pulp": "древесная масса", "cellulose": "целлюлоза",
    "bio": "био", "organic": "органический", "fertilizer": "удобрение",
    "compost": "компост", "mulch": "мульча", "soil": "почва",
    "garden": "сад", "farm": "ферма", "crop": "культура",
    "harvest": "урожай", "seedling": "саженец", "sapling": "саженец",
    "paste": "паста", "liquid": "жидкий", "vapor": "пар",
    "mist": "туман", "foam": "пена", "sludge": "шлам",
    "residue": "остаток", "waste": "отходы", "byproduct": "побочный продукт",
    "intermediate": "полуфабрикат", "component": "компонент",
    "assembly": "сборка", "manufacturing": "производство",
    "fabrication": "изготовление", "smelting": "плавка",
    "casting": "литьё", "forging": "ковка", "welding": "сварка",
    "molding": "формовка", "extrusion": "экструзия",
    "pelletizing": "окатышивание", "compacting": "прессование",
    "crystallization": "кристаллизация", "distillation": "дистилляция",
    "evaporation": "испарение", "condensation": "конденсация",
    "sublimation": "возгонка", "deposition": "осаждение",
    "fermentation": "брожение", "oxidation": "окисление",
    "reduction": "восстановление", "polymerization": "полимеризация",
    "vulcanization": "вулканизация", "cracking": "крекинг",
    "refining": "очистка", "enrichment": "обогащение",
    "depletion": "истощение", "extraction": "извлечение",
    "purification": "очистка", "sterilization": "стерилизация",
    "pasteurization": "пастеризация", "homogenization": "гомогенизация",
}

# === Извлечение и перевод ===
def fetch_mod_zip(modname):
    """Скачать мод с портала, вернуть путь к zip."""
    # Найти в torrent_mods.json
    tmj = ROOT / "scripts" / "torrent_mods.json"
    mods_data = json.loads(tmj.read_text(encoding="utf-8"))
    version = None
    if modname in mods_data:
        version = mods_data[modname]["version"]
    
    # API
    url = f"https://mods.factorio.com/api/mods/{modname}"
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "zai-ru-full/1.0"}), timeout=30) as r:
            data = json.loads(r.read())
    except Exception as e:
        print(f"  [SKIP] {modname}: API error {e}")
        return None
    
    # Найти release
    release = None
    for r in data.get("releases", []):
        if version and r.get("version") == version:
            release = r
            break
    if not release:
        # последний fv=2.1
        for r in data.get("releases", []):
            fv = (r.get("info_json") or {}).get("factorio_version", "")
            if fv == "2.1":
                release = r
                break
    if not release and data.get("releases"):
        release = data["releases"][0]
    if not release:
        print(f"  [SKIP] {modname}: no releases")
        return None
    
    filename = release.get("file_name") or f"{modname}_{release.get('version')}.zip"
    dest = MODS_DIR / filename
    if dest.exists():
        print(f"  [CACHED] {modname}")
        return dest
    
    qs = urllib.parse.urlencode({"username": USER, "token": TOKEN})
    dl_url = f"https://mods.factorio.com{release['download_url']}?{qs}"
    try:
        with urllib.request.urlopen(urllib.request.Request(dl_url, headers={"User-Agent": "zai-ru-full/1.0"}), timeout=60) as r:
            body = r.read()
        dest.write_bytes(body)
        print(f"  [DL] {modname}: {len(body)} байт")
        return dest
    except Exception as e:
        print(f"  [SKIP] {modname}: download error {e}")
        return None

def extract_en_strings(zip_path):
    """Извлечь все en-locale строки из zip. Вернуть dict[category][key] = value."""
    result = defaultdict(dict)
    try:
        with zipfile.ZipFile(zip_path) as z:
            en_files = [n for n in z.namelist() if '/locale/en/' in n and n.endswith('.cfg')]
            for ef in en_files:
                text = z.read(ef).decode('utf-8', errors='replace')
                section = None
                for line in text.split('\n'):
                    s = line.strip()
                    if not s or s.startswith(';'): continue
                    if s.startswith('[') and s.endswith(']'):
                        section = s[1:-1]
                        continue
                    if '=' in line and section:
                        key, _, val = line.partition('=')
                        result[section][key.strip()] = val.strip()
    except Exception as e:
        print(f"  extract error: {e}")
    return result

def translate_value(en_value):
    """Применить словарь к английской строке.

    Сохраняет:
    - Шаблоны __ENTITY__name__, __ITEM__name__, __1__, __CONTROL__name__
    - Имена собственные Angel's/Bob's (Saphirite, Jivolite, Stiratite, Crawler, etc.)
    """
    if not en_value: return en_value

    # Сначала извлечём шаблоны и имена собственные, заменим на плейсхолдеры
    placeholders = {}

    # Шаблоны Factorio
    def _save_template(m):
        key = f"__PH_TPL_{len(placeholders)}__"
        placeholders[key] = m.group(0)
        return key
    ru = re.sub(r'__[A-Z_]+__[a-zA-Z0-9_-]*__', _save_template, en_value)
    ru = re.sub(r'__\d+__', _save_template, ru)

    # Имена собственные Angel's (руда, регионы, фракции) — не переводим
    proper_nouns = [
        'Saphirite', 'Jivolite', 'Stiratite', 'Crotinium', 'Rubyte', 'Bobmonium',
        'Yersomite', 'Crawler', 'Petro', 'Angels', 'Bob',
        'Nauvis', 'Fulgora', 'Vulcanus', 'Gleba', 'Aquilo',
        'Stainless', 'Bronze', 'Brass', 'Cupric', 'Ferric',
        'Algae', 'Puffer', 'Temperate', 'Desert', 'Swamp',
        'Proto', 'Peppermint',
        'Jetpack', 'Selene', 'Luna',
        'MK1', 'MK2', 'MK3', 'MK4',
        'Stats', 'Gui', 'Handcraft', 'Movement', 'Speed', 'Timer',
        'Kobold', 'Engineer', 'Bird',
    ]
    for n in proper_nouns:
        def _save_pn(m, name=n):
            key = f"__PH_PN_{len(placeholders)}__"
            placeholders[key] = m.group(0)
            return key
        ru = re.sub(r'\b' + re.escape(n) + r'\b', _save_pn, ru, flags=re.IGNORECASE)

    # Замены по словарю — длинные ключи первыми
    for en, ru_tr in sorted(TRANSLATIONS.items(), key=lambda x: -len(x[0])):
        # Только целые слова
        ru = re.sub(r'\b' + re.escape(en) + r'\b', ru_tr, ru, flags=re.IGNORECASE)

    # Восстановить плейсхолдеры
    for key, original in placeholders.items():
        ru = ru.replace(key, original)

    return ru

def main():
    print(f"Скачиваю {len(TARGET_MODS)} модов...")
    all_strings = defaultdict(lambda: defaultdict(dict))  # cat -> mod -> key -> val
    
    for modname in TARGET_MODS:
        zip_path = fetch_mod_zip(modname)
        if not zip_path: continue
        strings = extract_en_strings(zip_path)
        for cat, kv in strings.items():
            for k, v in kv.items():
                all_strings[cat][modname][k] = v
    
    # Статистика
    total = sum(len(kv) for cat in all_strings for mod, kv in all_strings[cat].items())
    print(f"\nИзвлечено {total} строк в {len(all_strings)} категориях")
    
    # Построить итоговый locale.cfg с переводами
    # Формат Factorio: [category]\nkey=value
    lines = []
    lines.append("; ============================================================")
    lines.append("; zai-ru-full — полная русификация модпака zai-pack")
    lines.append("; Автоматически сгенерировано из en-локалей непереведённых модов.")
    lines.append("; ============================================================")
    lines.append("")
    
    translated_count = 0
    for cat in sorted(all_strings.keys()):
        lines.append(f"[{cat}]")
        # Сортировать по mod, потом по key
        for modname in sorted(all_strings[cat].keys()):
            lines.append(f"; --- {modname} ---")
            for k in sorted(all_strings[cat][modname].keys()):
                en_val = all_strings[cat][modname][k]
                ru_val = translate_value(en_val)
                # Если перевод совпадает с оригиналом — не дублируем
                if ru_val == en_val and en_val:
                    # Оставляем английский как заглушку — лучше так, чем ничего
                    lines.append(f"{k}={ru_val}")
                else:
                    lines.append(f"{k}={ru_val}")
                    translated_count += 1
        lines.append("")
    
    cfg_path = PACK_SRC / "locale" / "ru" / "locale.cfg"
    cfg_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"\nПереведено (соответствие словарю): {translated_count} из {total}")
    print(f"Файл: {cfg_path} ({cfg_path.stat().st_size} байт)")

if __name__ == "__main__":
    main()

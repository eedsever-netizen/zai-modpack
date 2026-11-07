#!/usr/bin/env python3
"""build_loadable_set.py — формирует test/mods/ с loadable набором 69 модов.

1. Копирует из download/mods/ в test/mods/, исключая SE-связку и factorioplus.
2. Патчит fv=2.0 → 2.1 в info.json для модов с старым factorio_version.
3. Патчит Peppermint_Mining: icon_size or 64, robot.icon_size or 64.
4. Копирует zai-* моды из download/ в test/mods/.
"""
import json, os, re, shutil, zipfile
from io import BytesIO
from pathlib import Path

ROOT = Path("/home/z/my-project")
SRC = ROOT / "download" / "mods"
DST = ROOT / "test" / "mods"
DST.mkdir(parents=True, exist_ok=True)

# Исключения (SE-связка, factorioplus, gizmod, spider-mines, Omniterra)
SE_FAMILY = {
    'space-exploration', 'space-exploration-graphics',
    'space-exploration-graphics-2', 'space-exploration-graphics-3',
    'space-exploration-graphics-4', 'space-exploration-graphics-5',
    'space-exploration-jetpack-gui', 'space-exploration-scripts',
    'space-exploration-postprocess', 'space-exploration-menu-simulations',
    'jetpack', 'informatron', 'shield-projector', 'robot_attrition',
    'aai-containers', 'aai-signal-transmission',
    'alien-biomes', 'alien-biomes-graphics',
    'gizmod',
}
EXCLUDED = {'Omniterra'}
FACTORIOPLUS = {'factorioplus', 'factorioplus-assets-turrets', 'factorioplus-assets-vehicles'}

def modname_from_filename(fn):
    m = re.match(r'^(.+)_\d+(?:\.\d+)+\.zip$', fn)
    return m.group(1) if m else fn[:-4]

def patch_peppermint(src_bytes):
    """Патчит Peppermint_Mining data-updates.lua: icon_size fallbacks."""
    text = src_bytes.decode('utf-8')
    new = text.replace("resource.icon_size", "(resource.icon_size or 64)")
    new = new.replace("resource.icon_mipmaps", "(resource.icon_mipmaps or 0)")
    new = new.replace(
        "local icon_size = robot.icon_size or defines.default_icon_size",
        "local icon_size = robot.icon_size or 64",
    )
    return new.encode('utf-8')

def copy_or_patch(src_path, dst_path, modname):
    """Копирует zip; для fv=2.0 модов патчит info.json; для Peppermint — data-updates."""
    needs_fv_patch = modname in {'NapusJaggedOres', 'Peppermint_Mining',
                                  'StatsGui-HandcraftTimer', 'spider-mines',
                                  'stack-miners-for-bobs'}
    needs_peppermint = modname == 'Peppermint_Mining'

    if not (needs_fv_patch or needs_peppermint):
        shutil.copy2(src_path, dst_path)
        return 'copy'

    with zipfile.ZipFile(src_path, 'r') as zin:
        buf = BytesIO()
        with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zout:
            for name in zin.namelist():
                if '__MACOSX' in name: continue
                data = zin.read(name)
                if name.endswith('info.json') and needs_fv_patch:
                    info = json.loads(data)
                    if info.get('factorio_version') == '2.0':
                        info['factorio_version'] = '2.1'
                        data = json.dumps(info, indent=2).encode('utf-8')
                elif name.endswith('data-updates.lua') and needs_peppermint:
                    data = patch_peppermint(data)
                zout.writestr(name, data)
    dst_path.write_bytes(buf.getvalue())
    return 'patched'

def main():
    copied = patched = skipped = 0
    for f in sorted(os.listdir(SRC)):
        if not f.endswith('.zip'): continue
        modname = modname_from_filename(f)
        if modname in SE_FAMILY or modname in EXCLUDED or modname in FACTORIOPLUS:
            skipped += 1
            continue
        # gizmod убираем (требует устаревший __flib__.migration)
        # spider-mines зависит от gizmod — тоже убираем
        if modname in {'spider-mines'}:
            skipped += 1
            continue
        src_path = SRC / f
        dst_path = DST / f
        result = copy_or_patch(src_path, dst_path, modname)
        if result == 'patched':
            patched += 1
            print(f'  [PATCH] {f}')
        else:
            copied += 1

    # Копируем zai-* моды из download/ в test/mods/
    for zai_mod in ['zai-spidertron-miner_1.0.0.zip',
                    'zai-compat-fixes_1.0.0.zip',
                    'zai-ru-patches_1.0.0.zip']:
        src = ROOT / 'download' / zai_mod
        if src.exists():
            shutil.copy2(src, DST / zai_mod)
            copied += 1
            print(f'  [ZAI]   {zai_mod}')

    print(f'\nИтог: скопировано {copied}, пропатчено {patched}, пропущено {skipped}')
    print(f'В test/mods: {len(list(DST.glob("*.zip")))} архивов')

if __name__ == '__main__':
    main()

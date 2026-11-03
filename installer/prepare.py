"""Prepare an allowlisted Inno payload using the release's pinned dependency ZIP."""
from pathlib import Path, PurePosixPath
import argparse, hashlib, json, zipfile

ROOT = Path(__file__).resolve().parents[1]
HERE = ROOT / 'installer'
EXPECTED_PACKAGE_SHA256 = '53599d9829b673dc2750dd7f8557b9f6ba2cea0fcb44818f98d2ad4b9d2725c3'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--package', type=Path, required=True)
    args = parser.parse_args()
    if digest(args.package.read_bytes()) != EXPECTED_PACKAGE_SHA256:
        raise ValueError('Dependency ZIP differs from the pinned beta release; obtain the matching release ZIP')
    payload = ROOT / '.build' / 'payload'
    files = {}
    prefix = 'install/SpeciesUnknown/'
    with zipfile.ZipFile(args.package) as archive:
        manifest = json.loads(archive.read('MANIFEST.json'))
        assert manifest['variant'] == 'with-UE4SS', 'Use the bundled dependency ZIP'
        for name, metadata in manifest['files'].items():
            if not name.startswith(prefix):
                continue
            relative = PurePosixPath(name[len(prefix):])
            assert not relative.is_absolute() and '..' not in relative.parts
            data = archive.read(name)
            assert len(data) == metadata['bytes'] and digest(data) == metadata['sha256'], name
            files[relative.as_posix()] = data
    # Current repository Lua/native sources take precedence over the release copy.
    for path in (ROOT/'runtime/Scripts').rglob('*.lua'):
        files['Binaries/Win64/ue4ss/Mods/ItemContours/' + path.relative_to(ROOT/'runtime').as_posix()] = path.read_bytes()
    for path in (ROOT/'assets/native').glob('ItemContours.*'):
        files['Content/Paks/LogicMods/' + path.name] = path.read_bytes()
    for name in ['BPModLoaderMod', 'BPML_GenericFunctions']:
        files['Binaries/Win64/ue4ss/Mods/' + name + '/enabled.txt'] = b''
    lines, initializers = [], []
    order = json.loads((HERE/'payload-index.json').read_text())
    assert set(order) == set(files), 'Payload changed: append stable indices deliberately'
    for index, name in enumerate(order):
        data = files[name]
        target = payload / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        relative = name.replace('/', chr(92))
        owned = '/Mods/ItemContours/' in name or name.startswith('Content/Paks/LogicMods/ItemContours.')
        lines.append(f'Source: "{target}"; DestDir: "{{tmp}}"; DestName: "{index}"; Flags: dontcopy')
        initializers.append(f"Paths[{index}] := '{relative}'; Hashes[{index}] := '{digest(data)}'; Owned[{index}] := {str(owned)};")
    (HERE/'count.iss').write_text(f'#define FileCount {len(files)}\n')
    (HERE/'init.iss').write_text('\n'.join(initializers))
    (HERE/'payload.iss').write_text('\n'.join(lines))
    print(f'Prepared {len(files)} verified payload files')

if __name__ == '__main__':
    main()

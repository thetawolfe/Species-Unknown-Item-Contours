# Building

## Runtime tests

Use Python 3 with `lupa` installed from `tests/requirements.txt`, then run:

```text
python tests/test_continuous_runtime.py
python tests/test_renderer_loader.py
```

The engine is mocked; these tests do not render the game.

## Installer

Use Inno Setup 6.7.4 (official signed compiler: https://jrsoftware.org/isdl.php). Download the **with-UE4SS ZIP from this repository's release** as the verified installer input. It contains the exact pinned dependency, not the moving upstream experimental-latest download.

```text
python installer/prepare.py --package path/to/ItemContours-friends-beta-2026-11-02-with-UE4SS.zip
ISCC.exe installer/ItemContours.iss
```

Preparation pins the dependency archive SHA-256 and validates its manifest hashes, uses repository runtime/native files, and generates ignored payload includes and a private build directory. The result is `installer/output/ItemContours-Setup.exe`. The published EXE was tested against synthetic game folders; the compiler is not needed by players. The uninstaller deliberately leaves shared dependencies installed. `installer/payload-index.json` fixes persistent ownership-record indices; never reorder or reuse existing indices in later builds.

## Renderer authoring

UE 5.7.4 was used. Enable the Python/editor scripting plugins in `renderer/UnrealProject/SpeciesUnknown.uproject`. Execute `renderer/author_assets.py` and then `renderer/author_label.py` through UnrealEditor-Cmd's Python commandlet. Scripts create original assets under `/Game/Mods/ItemContours` and a chunk3713 label. Cook Windows with manifests, then stage with Pak and IoStore enabled using Unreal Automation Tool. The project must retain the name **SpeciesUnknown** for correct game mounts. Only the resulting chunk3713 containers are mod payload; do not redistribute other cooked engine chunks.

The three native containers must be rebuilt and shipped as a matching set. Original authoring reused Epic's documented CustomDepth/CustomStencil post-process technique, not third-party paid outline assets. See https://dev.epicgames.com/documentation/en-us/unreal-engine/post-process-materials-in-unreal-engine .

Authoring portability and a fresh renderer rebuild from this checkout have not been rerun; published native containers are the already-tested build. Players never need the editor.

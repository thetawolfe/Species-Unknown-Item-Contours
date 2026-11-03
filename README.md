# Species Unknown — Item Contours

Highlights items through walls in Species Unknown. Outlines start automatically in missions and refresh as items appear or are collected. Press **Alt+7** to toggle them.

## Download and install

**[Download the Windows installer](https://github.com/thetawolfe/Species-Unknown-Item-Contours/releases/download/v0.1.0-beta.1/ItemContours-Setup.exe)** · [All release downloads](https://github.com/thetawolfe/Species-Unknown-Item-Contours/releases/tag/v0.1.0-beta.1)

1. Close the game and run `ItemContours-Setup.exe`.
2. Select your Species Unknown Steam folder. Steam → Properties → Installed Files → Browse shows its location. Either the outer `Species Unknown` folder or inner `SpeciesUnknown` folder works.
3. Click **Install**, then launch the game normally through Steam.

The installer includes the required UE4SS build. Players do **not** need Unreal Editor, Python, or any separate downloads. This beta installer is unsigned, so Windows may show an unknown-publisher message.

| Color | Items |
| --- | --- |
| Red | Weapons |
| Green | Money and hard drives/data disks |
| Yellow | Keycards, black box, and raw material |

Ammo and health stations are excluded. Supported mission worlds are SpaceShip and PolarMap (Storm Rock). Colors, opacity and thickness can be edited in `SpeciesUnknown/Binaries/Win64/ue4ss/Mods/ItemContours/Scripts/ItemContours/config.lua` while the game is closed.

## Existing mods and uninstall

The installer reuses a compatible UE4SS setup, preserves existing mod lists and refuses incompatible loader files. It enables the required Blueprint support. Disable old `ItemHighlighter` or `ContourRenderTest` prototypes before installing; leave other mods alone.

Use Windows Settings → Apps → **Item Contours (Species Unknown)** to uninstall. Original mod files are backed up and restored when safe; edited files and shared UE4SS dependencies are retained. Recovery files stay in the game's `.ItemContoursInstaller` folder. An existing mod's configuration is backed up and replaced on first installer adoption; later reinstalls preserve edited configuration.

## Beta status

Confirmed in Solo: visible contours, automatic activation, room-to-room updates, pickup cleanup and clean map-change shutdown. Red dropped-weapon appearance, Storm Rock raw-material appearance, multiplayer, larger-mission performance and a friend's clean game launch still need verification.

The EXE passed 13 synthetic-folder installation checks covering folder selection, compatible existing setups, reinstalls, original-file restoration, edited-file preservation, rollback, unwritable recovery metadata, invalid folders, prototype conflicts and a running-game guard. Packaging and installer recovery received independent review. These checks do not substitute for a clean native game launch on another computer.

## Source and development

- `runtime/`: shipped Lua mod.
- `assets/native/`: original cooked renderer containers for the game's UE 5.7.4 build.
- `renderer/`: original material/Blueprint authoring scripts and minimal Unreal project configuration.
- `installer/`: Inno Setup installer source and portable payload preparation.
- `tests/`: mocked runtime and renderer-loader regression tests.

Run the two regression scripts after installing `tests/requirements.txt` in your Python environment. See [BUILDING.md](BUILDING.md) to prepare the installer and author renderer assets.

UE4SS dependency: experimental 3.0.1 Beta #0, commit `1ceefac8`; other loader versions are unverified. This is an unofficial mod. See [third-party notices](THIRD-PARTY-NOTICES.md) and the included UE4SS MIT license. No open-source license is currently specified for the project's original files.

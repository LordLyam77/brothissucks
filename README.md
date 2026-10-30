# StandoffCheat

Runtime-resolved IL2CPP cheat for **Standoff 2 (iOS)** — ESP, aimbot, recoil control, overlay menu. No hardcoded offsets; every class/field is resolved at runtime through the IL2CPP reflection API.

## What's inside

| Path | Purpose |
|---|---|
| `src/main.mm` | Constructor bootstrap + background update loop |
| `src/il2cpp_resolver.mm` | IL2CPP symbol binding + lazy class resolution |
| `src/esp.mm` | Boxes / health bars / names / distance / snaplines |
| `src/aimbot.mm` | FOV pick, smoothing, assist radius |
| `src/recoil.mm` | No-recoil |
| `src/menu.mm` | Floating button + toggle/slider panel |
| `src/overlay.mm` | Touch-pass overlay window |
| `build.sh` | Compiles `build/StandoffCheat.dylib` (arm64) on macOS |
| `inject.sh` | Injects dylib into IPA + re-signs + repackages |
| `.github/workflows/build.yml` | CI build on GitHub Actions |

## Build & inject locally (macOS)

```bash
./build.sh                     # → build/StandoffCheat.dylib
./inject.sh game.ipa game-cheat.ipa
```

Requires: Xcode + iOS SDK, [insert_dylib](https://github.com/Tyilo/insert_dylib).

## Build via GitHub Actions (no Mac needed)

1. **Upload the IPA** where Actions can reach it:
   - Create a Release and attach the `.ipa` file (up to 2 GB), or
   - Host it at any direct-download HTTPS URL.
2. Go to **Actions → Build StandoffCheat IPA → Run workflow**.
   - Input `ipa`: `release` (pulls latest `.ipa` release asset) or paste a direct URL.
3. Download the patched **Standoff2-cheat.ipa** artifact and sideload with Sideloadly / AltStore / TrollStore.

> The IPA is treated as a build input — it is downloaded at run time, never stored in this repo (1.6 GB does not belong in git).

## Notes

- Aimbot and ESP only touch camera rotation and rendering — nothing a server-side validator checks (collider/ammo/damage are server-validated).
- Recoil nullification is client-side visual only.
- The dylib binds IL2CPP exports via `dlsym` and resolves classes lazily, so it keeps working across game updates while class names hold.

### Version compat — why old fork builds died on current game

| What | Old (≤0.37.x) | Current (0.38–0.39.2) |
|---|---|---|
| Gameplay class names | readable | still readable (`PlayerController`, `GunController`, `RecoilParameters`, ...) |
| Gameplay field/method names | readable | mostly **obfuscated** — the repo's named-field fallback lists no-op |
| Anticheat detector class names | readable (`InjectionCheatDetector`, `WardenIos`, ...) | **Obfuscated** (`GFADDCAEEDACCHH`-style) inside `Axlebolt.Standoff.Anitcheat` |
| Warden verify bridge | `WardenIos` class | `Axlebolt.Merger.Warden.*` — ns stem survives |
| ESP / aimbot | worked | still work — they use only `Transform`/`Camera` (UnityEngine, unobfuscated) + camera-distance local-player heuristic |
| No-recoil via `RecoilControl` | worked | **broken** — class gone; rewritten to `GunParameters._recoilParameters` → zero `horizontalRange`/`verticalRange` |
| Anticheat neutralizer | named-class patch list | **broken** — rewritten to namespace sweep (`Anitcheat`, `Merger.Warden`) with obfuscation-aware patching |

Current-module changes vs the old fork:

- `src/main.mm` — `NukeAntiCheat()` now walks every class of every image and nukes
  everything whose namespace contains `Anitcheat` or `Axlebolt.Merger.Warden`, keeping
  the old named list unnecessary. `Get*/GetShort/GetFull` (Task-returning Warden
  fetchers) are preserved on purpose — zeroing a `Task<byte[]>` return NREs the AC thread,
  which is itself a detection signal.
- `src/recoil.mm` — rewritten: `Resources.FindObjectsOfTypeAll(GunParameters)` → zero
  `_recoilParameters.horizontalRange` / `.verticalRange` on each config asset.
- `src/il2cpp_resolver.mm` — binds `il2cpp_image_get_class( _count )` for the namespace sweep;
  resolves `GunParameters`.
- Obit: health bars read the old `_hp`-style fields; obfuscation killed those reads, so
  health falls back to 100 (bars show full). Team colors fall back to neutral yellow.
  Restore by deriving new field names from a fresh dump.

### 1.0.x mode — built-in

A major version bump can rename class anchors. This build recovers in three layers, no Mac required:

1. **Loose resolution** — if an exact class name is missing on 1.0.x, the resolver sweeps
   every loaded class and matches by case-insensitive substring (catches suffix renames;
   logged as `r: loose-resolved ...`).
2. **Anticheat sweep is name-independent** — patches by namespace, so renames inside the
   cheat-detector families don't matter (they're obfuscated anyway since 0.38).
3. **Auto-dump** — if core anchors still fail, the dylib writes a full live type-system
   dump (`Documents/so2dump_auto.cs`) on first run: every class, every field, every field
   offset, obfuscated names included. Force a dump any time by setting the user default
   `so2.dump = 1` before launch (dump lands at `Documents/so2dump.cs`).

Derivation workflow on 1.0.x:

```
1. run patched IPA once            → Documents/so2dump_auto.cs
2. paste/supply dump               → diff vs 0.39.2 dump
3. patch name-anchored lists:
     - src/esp.mm        hp/team/alive field-name candidate lists
     - src/recoil.mm     GunParameters._recoilParameters chain (named fields — likely intact)
     - resolver          added class names, if 1.0.x renamed gameplay classes outright
4. rebuild via Actions, run with a throwaway account first
```

### Per-build derivation (do this every game update)

1. Grab the current IPA, unzip, extract `Data/Managed/Metadata/global-metadata.dat` + `Data/Managed/Metadata/libunity.so`-adjacent `libil2cpp.so`.
2. Stock Il2CppDumper can't rebuild Standoff's mangled metadata — use a runtime dumper
   ([esfp0/standoff2-il2cpp-dumper](https://github.com/esfp0/standoff2-il2cpp-dumper))
   or grab pre-dumped `dump.cs` for the matching game version (search "Standoff 2 dumps" — latest known: 0.39.2).
3. Diff against the previous `dump.cs`: what changed in `Axlebolt.Standoff.Anitcheat`,
   `Axlebolt.Merger.Warden`, and the named gameplay classes.
4. Update anything in this repo that name-matched: field candidate lists in `src/esp.mm`
   (hp/team/alive), class list in the resolver. Runtime resolution keeps most of it automatic.
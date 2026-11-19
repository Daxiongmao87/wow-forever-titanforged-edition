# WoW Forever: Titan Forged Edition

Fork of [jaredgei/wow-forever-android](https://github.com/jaredgei/wow-forever-android) that runs WoW Forever on the Unihertz Titan 2 (Dimensity 7300 / Mali-G615 MC2, Android 15, 1440x1440 1:1 screen, QWERTY keyboard with no number/arrow/Tab keys).

`SPEC.md` is the source of truth. Read it before making changes; it labels every claim **measured** / **sourced** / **guess** and lists acceptance criteria per phase. Keep that labeling habit in any docs you write here.

## State

- Fork lives at `Daxiongmao87/wow-forever-titanforged-edition` (private, origin); upstream is remote `upstream`. Work branch: `titan-forged` (main = pristine upstream baseline 83cdbc9).
- `.github/workflows/test-build.yml` builds the debug-signed release APK (`assembleModernRelease`, no keystore needed) on push to `titan-forged` and uploads artifact `wow-forever-titan-apk`. Trigger/watch with `gh run list` / `gh run download`.
- Phase 1 launcher changes are implemented (Mali profile, wrapper-gamenative bundling, built-in-keyboard fix, fork applicationId `app.wowforever.titanforged`, versionName `2.4.6-titan1`). Phase 2 addon not started.
- The `gh` token needed `gh auth refresh -h github.com -s workflow` once to allow pushing `.github/workflows/*` (done Nov 19 2026).
- Phase 1 = Mali GPU profile in the launcher. Phase 2 = in-game addon `TitanForged` (keyboard -> gamepad-UI bindings). Phase 2 depends on the Phase 1 launcher keyboard fix (spec change 8).

## Build

- **Do not build the APK on this Termux phone.** The Android Gradle plugin's `aapt2` is x86-only. APKs build in the fork's `release.yml` GitHub Actions workflow. If heavy builds are needed, use the remote servers (see global AGENTS.md), never on-device Gradle.
- The fork must have its **own `applicationId`** so it installs beside upstream despite a different signing key. Never reuse upstream's.

## Key upstream touchpoints (as of main 83cdbc9)

- `WoWForeverScreen.kt:1202-1219` — `GpuProfile.detect()`; Adreno-only profiles. Mali branch goes here (`GPUInformation.getRenderer()` contains "Mali").
- `XServerScreen.kt:4764-4826` — driver version/wrapper selection, `containerConfig()`.
- `XServerScreen.kt:998-1002, 1058` — physical-keyboard detection; must count built-in non-virtual keyboards (Phase 1 change 8, also gates Phase 2).
- `ContainerUtils.kt:81-83` — GameNative picks `Wrapper-gamenative` + `dxvk-async-1.10.3` for non-Adreno.
- `DXVKHelper.java:21` — forces `DXVK_LOG_LEVEL=none`; debug build overrides to `info` with `DXVK_LOG_PATH` on the game drive (G:).
- `tools/components.sha256` + `assets/bundled_components` — bundle `wrapper-gamenative` here (pin sha256); first-boot CDN download fails without internet.
- UI reference source (read-only): [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) `forever` branch, commit 3d8abb1 (1.60.1 / 70959).

## Addon (Phase 2) conventions

- Bind only via `SetOverrideBinding` on the addon's own frame; **never overwrite Blizzard `GAMEPAD_*` globals** (taints secure code).
- Apply bindings out of combat only; re-apply on `PLAYER_REGEN_ENABLED` and `UPDATE_BINDINGS` (hidden `InputFunctionBindingButton_<key>` buttons are created lazily by Blizzard).
- Ship as a zip installed via the launcher's Add-on button. The `.toc` interface number is **not** `0` (Blizzard tocs ship `## Interface: 0`); get the real value in game: `/dump select(4, GetBuildInfo())`.
- Key map and design rationale: spec "Proposed key map" table; single table in saved variables, editable via `/tfe`.

## Verification

No local tests exist for the game itself. Verification = spec acceptance-criteria checklists run on the Titan 2 device, plus upstream regression: Adreno 740 and 8xx devices must keep selecting their existing profiles unchanged.

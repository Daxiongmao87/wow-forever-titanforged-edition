# WoW Forever: Titan Forged Edition — Spec

Nov 19, 2026 · @Patrick Richardson

## Summary

Titan Forged Edition is a fork of jaredgei/wow-forever-android that runs WoW Forever on the Unihertz Titan 2. It ships in two phases:

1. **Phase 1:** support for the Dimensity 7300 / Mali-G615 MC2 GPU in the launcher, so the game renders on the Titan 2 at all.
2. **Phase 2:** an optional in-game addon that plays the game from the Titan 2 hardware keyboard on top of WoW Forever's gamepad UI, plus one launcher fix so on-screen controls stay hidden.

Every claim is labeled **measured** (checked in code or on the device), **sourced** (from a cited page) or **guess**.

Upstream baseline: tag v2.4.5 (commit aba66f9) and main at 83cdbc9 (2026-11-19). The GPU-selection and driver code is identical between them (measured, git diff).

## Target hardware and upstream baseline

The Titan 2 has a Mali GPU and a keyboard with no number, arrow or Tab keys, and upstream supports Adreno GPUs only.

| Item | Value | Label |
| --- | --- | --- |
| SoC | MediaTek Dimensity 7300 | sourced ([Notebookcheck](https://www.notebookcheck.net/Unihertz-Titan-2.1077514.0.html)) |
| GPU | Mali-G615 MC2 | sourced ([comparisontabl.es](https://comparisontabl.es/smartphones/unihertz-titan-2/)) |
| Display | 4.5 in, 1440 x 1440, 1:1 | sourced ([Unihertz](https://www.unihertz.com/en-de/products/titan-2)) |
| OS | Android 15 | sourced ([comparisontabl.es](https://comparisontabl.es/smartphones/unihertz-titan-2/)) |
| Keyboard top row | Shift, Sym, Back, Recent, Fn, Alt | sourced ([Unihertz keyboard guide](https://www.unihertz.com/blogs/tutorial/guide-to-the-unihertz-titan-2-qwerty-keyboard)) |
| Number / arrow / Tab keys | None physical; Sym and Fn can be reprogrammed as Tab or Ctrl | sourced ([Unihertz key customization](https://www.unihertz.com/en-fr/blogs/tutorial/how-to-customize-programmable-buttons-and-keyboard-keys-on-titan-2)) |
| Fn default | Short press goes Home (leaves the game) | sourced ([Unihertz keyboard guide](https://www.unihertz.com/blogs/tutorial/guide-to-the-unihertz-titan-2-qwerty-keyboard)) |
| Upstream GPU support | Adreno 740 and Adreno 8xx profiles only (`WoWForeverScreen.kt:1202-1219`) | measured |
| Upstream render path | Proton 11 ARM64EC, DXVK 2.4.1, Turnip via adrenotools, bionic Vulkan wrapper | measured (`WoWForeverScreen.kt:1290-1318`) |
| Interface style the app forces | `InputDeviceInterfaceStyle "1"` (gamepad UI) and `GamePadEnable "1"` in Config.wtf | measured (`WoWForeverScreen.kt:1345-1346`) |

## Phase 1: Mali GPU support in the launcher

Phase 1 adds a third GPU profile that runs DXVK on the phone's own Mali Vulkan driver through GameNative's wrapper, instead of the Adreno-only Turnip driver.

### Why it fails today

- Any non-Adreno-8xx device falls through to the Adreno 740 profile and its Turnip driver (`WoWForeverScreen.kt:1204-1208`), measured.
- Turnip only works on Adreno, sourced ([Azahar discussion](https://github.com/azahar-emu/azahar/discussions/1575)), so the game gets no usable Vulkan device on the Titan 2.

### Code changes

1. **Mali detection.** Add a Mali branch to `GpuProfile.detect()`, triggered by `GPUInformation.getRenderer(context)` containing "Mali". That helper already exists and is used the same way at `XServerScreen.kt:4771` and `BionicProgramLauncherComponent.java:267` (measured).
2. **Profile fields.** Extend `GpuProfile` with the container's `graphicsDriver` value. Mali gets `Wrapper-gamenative`, which upstream GameNative picks for non-Adreno GPUs (`ContainerUtils.kt:81-82`, measured). It also gets driver version `System`, which skips adrenotools so the system Vulkan driver loads (`XServerScreen.kt:4782`, measured).
3. **Driver config.** For Mali, `containerConfig()` writes `version=System,bcnEmulation=auto,bcnEmulationType=compute,resourceType=buffer`. Compute BCn decoding is only excluded for Adreno and Xclipse GPUs (`XServerScreen.kt:4826`, measured). Mali lacks BCn texture support on every surveyed driver (sourced, [leegao's DXVK 2.0 driver survey](https://gist.github.com/leegao/aab7d63423bfd43f7328430fe32d225e)). The config shipped on the device adds `bcnEmulationCache=0,transcoder=cpu,quality=high` (measured, titan9–titan19); see Field findings — the BCn layer, not these wrapper knobs, is what makes textures correct.
4. **Environment.** Drop `TU_DEBUG` and the Samsung `FD_DEV_FEATURES` flag for Mali; they only apply to Turnip.
5. **Bundle the wrapper.** `wrapper-gamenative` is downloaded from GameNative's CDN on first boot (`graphics_driver_download.json`), and boot fails without internet (`XServerScreen.kt:4764-4767`), measured. Bundle it in `assets/bundled_components` like the Turnip zips, and pin its sha256 in `tools/components.sha256`.
6. **Resolution.** Mali defaults to the 1280x720 pixel budget. `fitScreenSize()` already reshapes that to 960x960 on the 1:1 screen (measured, by the function's math).
7. **DXVK fallback.** Keep DXVK `2.4.1-wow-aarch64-test` as the first choice. If device creation fails on Mali, switch the Mali profile to `dxvk-async-1.10.3`, which is in this fork's `dxwrapper_download.json` and is upstream GameNative's non-Adreno default (`ContainerUtils.kt:83`), measured. Whether the WoW Forever client accepts DXVK 1.10.x is a guess.
8. **Launcher keyboard fix.** Count a built-in, non-virtual alphabetic keyboard as a physical keyboard. Today only external keyboards count (`XServerScreen.kt:998-1002`, `1058`), measured, so on-screen controls show on the Titan 2. This ships in Phase 1 because it is launcher code and harmless elsewhere.
9. **README.** Add the Titan 2 to the supported-devices table and Mali to Requirements. Give the fork its own applicationId, so it installs beside upstream despite a different signing key.

### Debug build

- `DXVKHelper.setEnvVars()` forces `DXVK_LOG_LEVEL=none` (`DXVKHelper.java:21`), measured. The debug build sets `DXVK_LOG_LEVEL=info` and `DXVK_LOG_PATH` to a folder on the game drive (G:, the install folder), so the user can open the log with a file manager, no adb.
- The DXVK log names any Vulkan feature or extension it rejects at device creation. That answers the main Phase 1 unknown on the first launch.

### Field findings on the Titan 2 (titan8–titan19 builds)

- **`WRAPPER_NO_PATCH_OPCONSTCOMP=1` is mandatory on Mali.** Without it the wrapper's SPIR-V `OPConstantComposite` patch pass native-AVs while patching DXVK's compiled shaders; the guest then aborts on the `vkCreateShaderModule` / `vkCreateComputePipelines` asserts in `loader_thunks.c`. Upstream ships this same escape hatch for the `dxvk-1.11.1-sarek` profile (`XServerScreen.kt:4713`), measured; Bannerlator's Mali report reaches the same conclusion independently (sourced).
- **`WRAPPER_DISABLE_PLACED=1` fixes dynamic-texture corruption.** With it the intro cinematics and launcher UI render pixel-perfect (measured, screen capture).
- **The wrapper's built-in BCn transcoder is unusable on Mali.** Every knob matrix (`bcnEmulation=auto|full`, `bcnEmulationType=cpu|gpu`, `WRAPPER_BCN_ASTC=0|4x4`, cache on/off) produced noisy mosaic textures, and with the BCn layer removed the bootstrapper hangs at "Launching game..." (>20 min, t16/t17). The compute BCn **layer** is required, measured.
- **BCn layer works when actually loaded.** `VK_LAYER_BCN_BCnLayer` (`libbcn_layer.so`, Fcharan build from `The412Banner/WinlatorMali` `app/src/main/assets/graphics_driver/leegao_bcn.tzst`) with `ENABLE_BCN_COMPUTE=1` + `BCN_TRANSCODE_TO_ASTC=1` renders the login scene correctly (measured, titan18 watermark test: every BCn texture watermark-marked, scene geometry and lava/statue textures clean).
- **The loader's implicit-layer scan misses the shipped manifest.** It scans `<rootDir>/usr/etc/vulkan/implicit_layer.d`, which the imagefs does not ship (`I replace: rewrite (openat)` log lines, measured). Fix in code: `VK_ADD_IMPLICIT_LAYER_PATH=<rootDir>/usr/share/vulkan/implicit_layer.d` when the layer is enabled (titan19).
- **`BCN_ADD_WATERMARK=1`** stamps layer-decoded textures — a clean way to distinguish "layer not loaded" (plain noise) from "layer decoded it" (watermark). `BCN_LAYER_LOG_LEVEL=info` produced no visible stderr output (measured, unexplained).
- Container env precedence: `XServerScreen` `envVars.put()` calls override tokens in the launcher's `envVars` string, and `files/imagefs/home/xuser-wow_forever/.container` is rewritten from the GPU profile on every app start — runtime edits of it never survive (measured).

### Acceptance criteria

- [ ] On the Titan 2, Play reaches character select, then the game world, with no driver error. (Login screen now renders correctly, titan19 pending world test.)
- [ ] The world renders without missing or corrupt textures in two starting zones and one city.
- [ ] 30 minutes of questing without a crash or device-lost error.
- [ ] FPS from the in-app performance overlay recorded at 960x960 and at a lower budget (target to be set from these numbers).
- [ ] Adreno 740 and Adreno 8xx devices still select their existing profiles, unchanged.

## Phase 2: Titan 2 keyboard addon (optional)

Phase 2 is an addon, TitanForged, that binds Titan 2 keys to WoW Forever's own gamepad-UI commands. That gives keyboard-only play with no on-screen controls and no mouse. It depends on the Phase 1 launcher keyboard fix (change 8).

### How input reaches the gamepad UI

1. A Titan key press reaches the launcher as an Android key event. 23 keys held at once all registered (measured, on-device test).
2. The launcher maps Android keycodes to X keycodes, with Alt and Shift passed as real modifiers (`Keyboard.java`, `onKeyEvent`), measured.
3. Wine delivers the key to WoW, where a binding fires.
4. Named gamepad commands (`GAMEPADACTIONBUTTON1`-`8`, `GAMEPADLEFTMOD`, `GAMEPADRIGHTMOD`, `OPENRADIAL`, `TOGGLEUIFOCUS`) are ordinary bindings in the `GamepadModeInGameCore` context (`Blizzard_Gamepad/Bindings.xml`, `Blizzard_GamepadActionBars/Bindings.xml`), measured. The addon binds keys to them directly.
5. UI navigation listens on controller key names such as `PADDLEFT` and `PAD1` (`GamepadConstants.lua`), measured. Each routes through a hidden button named `InputFunctionBindingButton_<key>` whose click handler Blizzard swaps per screen (`InputFunctionBinding.lua`), measured. The addon binds a Titan key to click that button, so the key always does what that pad button does on the current screen.

### Proposed key map

The map lives in one table in the addon's saved variables, editable through `/tfe`. Twitch actions sit on bare letters; slow UI actions sit on the left cluster.

| Action | Titan key | Bound to |
| --- | --- | --- |
| Move forward / back | W / S | `MOVEFORWARD` / `MOVEBACKWARD` |
| Turn left / right | A / D | `TURNLEFT` / `TURNRIGHT` |
| Strafe left / right | Q / E | `STRAFELEFT` / `STRAFERIGHT` |
| Jump | Space | `JUMP` |
| Target nearest enemy | Sym, set to Tab in Titan settings | `TARGETNEARESTENEMY` |
| Interact | F | `INTERACTTARGET` |
| Gamepad action bar 1-8 | U I O P J K L M | `GAMEPADACTIONBUTTON1`-`8` |
| Bar layer 2 / layer 3 | Shift / Alt (held) | `GAMEPADLEFTMOD` / `GAMEPADRIGHTMOD` |
| Spare ability or macro | N | user choice |
| UI focus on / off | T | `TOGGLEUIFOCUS` |
| Radial menu | R | `OPENRADIAL` |
| UI left / down / up / right | Z / X / C / V | click `InputFunctionBindingButton_PADDLEFT` / `PADDDOWN` / `PADDUP` / `PADDRIGHT` |
| UI confirm / back | B / G | click `InputFunctionBindingButton_PAD1` / `PAD2` |
| Ctrl modifier | Fn, set to Ctrl in Titan settings | modifier for rare binds |

With Shift and Alt layers, the action bar reaches 24 slots from 8 keys.

### Addon rules

- Apply all bindings out of combat, and re-apply on `PLAYER_REGEN_ENABLED`. Guess: insecure code cannot change bindings in combat.
- The hidden buttons are created lazily, the first time Blizzard binds that pad key (`GetOrCreateInputFunctionBindingButton`, a local function), measured. The addon re-checks for each button on `UPDATE_BINDINGS` and binds it once it exists.
- Never overwrite Blizzard's `GAMEPAD_*` globals; that would taint secure code.
- Own bindings via `SetOverrideBinding` on the addon's own frame, so disabling the addon restores the user's normal binds.

### Packaging

- Ship as a zip the launcher installs through its existing Add-on button (README, Controls section), measured.
- The `.toc` needs WoW Forever's interface number. The Blizzard tocs in the `forever` branch carry `## Interface: 0` (measured), so read the real value in game with `/dump select(4, GetBuildInfo())`.

### Acceptance criteria

- [ ] With the addon on and no controller connected, the on-screen controls stay hidden.
- [ ] Every key in the map triggers its action in the world and in the bags, vendor, quest and talent windows.
- [ ] A full quest loop (accept, travel, kill, loot, turn in, vendor) runs without touching the screen.
- [ ] Bindings survive a /reload and a combat session.
- [ ] Disabling the addon returns the default keybinds.

## Measurements and open unknowns

The keyboard registers 23 keys held at once, so key count limits no layout. Phase 2 still has three open checks.

| Item | Result | Label |
| --- | --- | --- |
| Keys held at once | 23 (W E R S D F Q A Z X C V U I O P J K L M N, Backspace, Enter) | measured, on-device browser test |
| Held-key auto-repeat | Repeated key-down events while held; the launcher expects this (`Keyboard.java`) | measured |
| Keyboard touch surface, stock settings | No events visible to an app | measured, on-device browser test |
| Core binding names in the map | All nine exist in the `forever` branch's `Bindings_Standard.xml` / `Bindings_WoWHack.xml` | measured |

Open checks:

- [ ] Space reaches apps. The rollover log contained no Space events; whether Space was pressed in that run is unconfirmed.
- [ ] Shift and Alt reach apps as modifiers. The log had no Shift or Alt events.
- [ ] Sym and Fn deliver Tab and Ctrl after reprogramming them in Titan settings.
- [ ] DXVK 2.4.1 accepts the Mali driver through `Wrapper-gamenative`. Leegao's survey found Mali drivers report no `nullDescriptor` or `robustBufferAccess2`, which DXVK requires (sourced, [driver survey](https://gist.github.com/leegao/aab7d63423bfd43f7328430fe32d225e), [DXVK driver support](https://github.com/doitsujin/dxvk/wiki/Driver-support)). Whether the wrapper hides that gap is a guess.
- [ ] The game's interface style stays on gamepad while keyboard keys are pressed. The Lua side only switches on the `InputDeviceInterfaceStyle` CVar (`Blizzard_SettingsDefinitions_Shared/Gamepad.lua:285`), measured; the engine side is unseen.

## Risks and fallbacks

The biggest risk is DXVK refusing the Mali driver; every other risk has a known fallback.

| Risk | Fallback | Label |
| --- | --- | --- |
| DXVK 2.4.1 fails device creation on Mali | Switch the Mali profile to `dxvk-async-1.10.3` | guess that it works |
| DXVK 1.10.x also fails, or WoW Forever rejects it | Test `dxvk-1.10.9-sarek` / `dxvk-1.11.1-sarek`, both in `dxwrapper_download.json`; DXVK-Sarek ships a Mali black-screen fix ([GamingOnLinux](https://www.gamingonlinux.com/2026/04/gaming-on-linux-with-an-older-gpu-levels-up-with-dxvk-sarek-v1-12-bringing-major-new-features/page=1/)) | sourced fix, guess for WoW |
| Low FPS on Mali-G615 MC2 (Geekbench Vulkan about 2,500, vs about 9,600 for MC6) | Lower the pixel budget below 960x960; keep the low-settings Config.wtf defaults | sourced scores ([MC2](https://browser.geekbench.com/v6/compute/4342303), [MC6](https://browser.geekbench.com/v6/compute/5458884)), guess for FPS |
| BCn texture conversion causes stutter | Compute conversion with the cache on; accept first-visit stutter | guess |
| Space is held by the system | Bind Jump to another letter, such as H | open check |
| A WoW patch renames or removes the `InputFunctionBindingButton_` buttons | Launcher maps Titan keys to its existing virtual gamepad outputs (`Binding.java`: `GAMEPAD_BUTTON_A`, `GAMEPAD_DPAD_*`), so the game sees a real controller | measured outputs exist; new launcher code |
| Binding changes blocked in combat | Apply out of combat, re-apply on leaving combat | guess on the restriction |
| Fork signed with a different key than upstream | Give the fork its own `applicationId` so it installs beside upstream | measured, README signing note |

## Out of scope and rejected options

- **TitanPad (keyboard surface as a joystick).** It reads the hidden sensor through Shizuku and an accessibility service (sourced, [TitanPad](https://codeberg.org/sztupy/TitanPad)). Stick coverage would cost about 12 keys, the surface sits under the keys being pressed, and gamepad mode already turns on camera-follow (`Blizzard_Gamepad/Core.lua`), measured.
- **KeyboardPort as the Phase 2 base.** It navigates with arrow keys, which the Titan 2 lacks, and its license is All Rights Reserved, so its code can't be forked (sourced, [CurseForge](https://www.curseforge.com/wow/addons/keyboardport)).
- **Open-source Mali drivers (PanVK).** Guess: they need a kernel driver that stock MediaTek firmware doesn't have.
- **Native input diagnostics screen.** Dropped with TitanPad; key events are already measured through the browser test.
- **Building the APK on-device in Termux.** Possible but fragile (guess: the Android Gradle plugin's `aapt2` is x86-only); builds run in the fork's `release.yml` GitHub Actions workflow instead, measured to exist.

## Sources

Code references are to [jaredgei/wow-forever-android](https://github.com/jaredgei/wow-forever-android) at main 83cdbc9 (v2.4.5 = aba66f9), and to the [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) `forever` branch at 1.60.1 (70959), commit 3d8abb1.

- [Notebookcheck: Unihertz Titan 2](https://www.notebookcheck.net/Unihertz-Titan-2.1077514.0.html)
- [comparisontabl.es: Unihertz Titan 2](https://comparisontabl.es/smartphones/unihertz-titan-2/)
- [Unihertz: Titan 2 product page](https://www.unihertz.com/en-de/products/titan-2)
- [Unihertz: Guide to the Titan 2 QWERTY keyboard](https://www.unihertz.com/blogs/tutorial/guide-to-the-unihertz-titan-2-qwerty-keyboard)
- [Unihertz: Customize programmable buttons and keyboard keys](https://www.unihertz.com/en-fr/blogs/tutorial/how-to-customize-programmable-buttons-and-keyboard-keys-on-titan-2)
- [leegao: DXVK 2.0 Vulkan requirements by Android drivers](https://gist.github.com/leegao/aab7d63423bfd43f7328430fe32d225e)
- [DXVK wiki: Driver support](https://github.com/doitsujin/dxvk/wiki/Driver-support)
- [Azahar discussion: Mali driver paths](https://github.com/azahar-emu/azahar/discussions/1575)
- [GamingOnLinux: DXVK-Sarek 1.12](https://www.gamingonlinux.com/2026/04/gaming-on-linux-with-an-older-gpu-levels-up-with-dxvk-sarek-v1-12-bringing-major-new-features/page=1/)
- [Geekbench: Mali-G615 MC2](https://browser.geekbench.com/v6/compute/4342303) · [Geekbench: Mali-G615 MC6](https://browser.geekbench.com/v6/compute/5458884)
- [TitanPad](https://codeberg.org/sztupy/TitanPad)
- [KeyboardPort on CurseForge](https://www.curseforge.com/wow/addons/keyboardport)
- [Blizzard: Explore WoW: Forever with a Gamepad](https://worldofwarcraft.blizzard.com/news/24316974/)

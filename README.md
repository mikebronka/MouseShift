# MouseShift

Bind SHIFT, CTRL or ALT to a mouse button in World of Warcraft.

> **Work in progress.** MouseShift is not released yet. The first version is being tested in combat.

Hold the button under your thumb, press `2`, and the game does whatever you have on `SHIFT-2`. No awkward key stretches, twice as many bindings within reach of your left hand, and no external key remapping software.

<!-- Screenshot: the configuration window. Save as docs/images/config-window.png -->
<!-- ![The MouseShift configuration window](docs/images/config-window.png) -->

## Features

- Turn any extra mouse button into SHIFT, CTRL or ALT. Use one, two or all three.
- Hold two of them together for combinations such as CTRL-SHIFT.
- Assign a button by clicking it. No need to know whether your thumb button is Button 4 or Button 5.
- Works in combat.
- Uses your existing SHIFT, CTRL and ALT bindings. Nothing to rebind.
- Works with the default action bars and with action bar addons.
- No changes to your interface. One small window, opened only when you need it.
- Retail and WoW Forever.

## Installation

### Addon manager

Search for **MouseShift** in the CurseForge app, the Wago app or WowUp.

<!-- Add the CurseForge, Wago and WoWInterface links once the projects are approved. -->

### Manual

1. Download `MouseShift-x.y.z.zip` from the latest [release](https://github.com/mikebronka/MouseShift/releases/latest).
2. Extract it into your AddOns folder:
   - Retail: `World of Warcraft\_retail_\Interface\AddOns\`
   - WoW Forever: the `Interface\AddOns\` folder of your WoW Forever installation
3. You should end up with `Interface\AddOns\MouseShift\MouseShift.toc`.
4. Restart the game and make sure MouseShift is enabled in the AddOns list.

## Usage

1. Type `/mouseshift` to open the configuration window.
2. Click the SHIFT field with the mouse button you want to use as SHIFT.
3. Do the same for CTRL and ALT if you want them.
4. Close the window. Done.

<!-- Screenshot: assigning a button. Save as docs/images/assign-button.png -->
<!-- ![Assigning a mouse button](docs/images/assign-button.png) -->

The left and right mouse buttons cannot be used, because the game needs them for targeting and the camera.

## Limitations

- **Macro conditions.** The game does not see a real SHIFT key, so macros using `[mod:shift]`, `[mod:ctrl]` or `[mod:alt]` will not react to the mouse button. The same applies to action bar paging on a modifier key.
- **Movement keys are not mirrored.** Releasing the mouse button before a movement key would leave your character running.
- **Settings cannot be changed in combat.** The game blocks binding changes from addons during combat. Using MouseShift in combat works normally.

## FAQ

**Is this allowed?**
MouseShift only uses the game's own key binding system. It does not automate anything: one key press is still one action.

**My mouse button already does something in the game.**
MouseShift takes over that button while it is assigned. The configuration window tells you what was bound to it before.

## Reporting problems

Open an [issue](https://github.com/mikebronka/MouseShift/issues/new/choose). Please include the output of `/mouseshift` and any Lua errors.

## License

[MIT](LICENSE) © Mike Bronka

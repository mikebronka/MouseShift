# Changelog

Version numbers: fixes raise the last number (0.1.1), feature releases raise the middle number (0.2.0), and 1.0.0 will be the first stable release.

## 0.2.0

- Any key can now be a modifier, not only a mouse button. This makes MMO mice whose side buttons send keyboard keys (such as the Razer Naga) work with MouseShift.
- New way to assign: click a field, then press the mouse button or key you want. The cursor can be anywhere. Nothing is assigned without clicking the field first, so a stray click cannot change your settings.
- Escape, Enter, movement keys and the real Shift, Ctrl and Alt keys cannot be assigned, so the game stays usable.
- While a field waits, the button or key pressed does not reach the game, so nothing is cast by accident. Left-click or Escape cancels.
- A layer no longer stays on when a mouse button is released while the game window is not focused, for example after Alt-Tab. Out of combat, MouseShift notices the released button and switches the layer off.
- Every layer is switched off after a loading screen, so a key or button released during it cannot leave a layer on.
- The mouse wheel cannot be assigned, because it has no release event.
- The left and right mouse buttons, and any mouse button used for the camera or for turning, can never be assigned or changed, under any name the game uses for them. Saved settings that contain one are removed on login.

## 0.1.0

First release.

- Use any extra mouse button as Shift, Ctrl or Alt.
- Hold two or three assigned buttons together for combined layers such as Ctrl-Shift.
- Assign a button by clicking the field in the settings window with it.
- Mirrors your existing Shift, Ctrl and Alt bindings, including bindings set by action bar addons.
- Works in combat. Settings can be changed out of combat only.
- Movement keys, the left and right mouse buttons and Escape are never taken over.
- Settings window: `/mouseshift`, the addons button next to the minimap, or Options > AddOns > MouseShift.
- Commands: `/mouseshift list`, `/mouseshift reset`, `/mouseshift help`.

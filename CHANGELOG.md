# Changelog

Version numbers: fixes raise the last number (0.1.1), feature releases raise the middle number (0.2.0), and 1.0.0 will be the first stable release.

## 0.2.0

- Any key can now be a modifier, not only a mouse button. Left-click a field in the settings window and press the key. This makes MMO mice whose side buttons send keyboard keys (such as the Razer Naga) work with MouseShift.
- Escape, Enter, movement keys and the real Shift, Ctrl and Alt keys cannot be assigned, so the game stays usable.
- While a field waits for a key, the key does not reach the game, so nothing is cast by accident. Escape cancels.

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

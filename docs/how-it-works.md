# How it works

[Documentation](README.md) › How it works

This page explains what happens inside the game. You do not need it to use MouseShift, but it helps to understand why some things work and others cannot.

## Layers instead of a real Shift key

An addon cannot press the Shift key. What the game does allow is **override keybinds**: temporary keybinds an addon puts on top of yours. They are never saved and disappear when the addon is disabled or the interface is reloaded, so your own keybinds are never changed.

MouseShift uses them to build **layers**:

1. Out of combat, MouseShift reads every keybind you have with Shift: Shift-1, Shift-2, Shift-Q and so on. This list is the Shift layer. The same is done for Ctrl, Alt and their combinations.
2. When you hold the button assigned to Shift, MouseShift puts each of those actions on the plain key: the action of Shift-1 goes on 1, the action of Shift-2 on 2.
3. When you release the button, those temporary keybinds are removed and your normal keys are back.

To the game you pressed 2, but 2 does what Shift-2 does while the button is held.

## Working in combat

In combat the game blocks addons from changing keybinds, to keep fights fair. There is one exception: **secure handlers**, small pieces of code that run in a restricted, sandboxed part of the game. They may switch override keybinds in combat, but only with data prepared beforehand and without the rest of the addon.

MouseShift works like this:

- **Out of combat** it prepares every layer in advance and hands it to a secure handler.
- The assigned mouse button or key is bound to a click on that handler, sent both when you press and when you release it.
- **In combat** only the handler runs. On press it puts the layer on; on release it takes it off. It never decides what to cast. It only changes which keybind your next key press reaches.

If you change keybinds during combat, MouseShift updates its layers as soon as the fight ends.

## Combining modifiers

Each modifier has a number: Shift is 1, Ctrl is 2, Alt is 4. While buttons are held, MouseShift adds up their numbers and switches to that layer:

| Held | Number | Layer |
| --- | --- | --- |
| Shift | 1 | Shift-key |
| Ctrl | 2 | Ctrl-key |
| Shift and Ctrl | 3 | Ctrl-Shift-key |
| Alt | 4 | Alt-key |
| Alt and Shift | 5 | Alt-Shift-key |
| Alt and Ctrl | 6 | Alt-Ctrl-key |
| all three | 7 | Alt-Ctrl-Shift-key |

## Safety rules

- **Never touched:** the left and right mouse buttons, Escape, Enter, Print Screen, the mouse wheel and the real Shift, Ctrl and Alt keys. A mouse button used to turn the camera is refused too.
- **Movement is never mirrored.** If a layer put movement on a key and you released the modifier first, the game would never see the key's release and your character would keep running. Movement and jump keybinds are therefore left out of every layer, and movement keys cannot be modifiers.
- **Nothing by accident.** A field must be clicked before it accepts a button or key, and while it waits, what you press does not reach the game.
- **No stuck layers.** If you release a mouse button while the game window is not focused (Alt-Tab), the game never sees the release. Out of combat MouseShift checks the real state of the button twice a second and switches the layer off when the button is no longer held. It only trusts a button the game has reported as held before, so a mouse the game does not read correctly can never switch your layer off while you hold it. After a loading screen every layer is switched off.

## What is not possible

These limits come from the game, not from MouseShift:

- **Macro conditions.** `[mod:shift]` in a macro checks the real Shift key. MouseShift does not press it, so these conditions do not react. Put the alternative on a Shift keybind instead of inside one macro.
- **Clicks.** Override keybinds work on keys, not on clicks in the interface. Shift-click to link an item, Shift-click casting on raid frames (Clique, Grid2, VuhDo and the game's click bindings) and similar still need the real Shift key.
- **Action bar paging on a modifier.** Bars that switch pages while Shift is held check the real Shift key too.
- **Keyboard keys and Alt-Tab.** The game cannot tell whether a keyboard key is still held, only whether a mouse button is. A keyboard key released while the game is not focused can leave its layer on until you press it again or a loading screen comes.

## The code

MouseShift is open source under the MIT license. The core is in [`Core.lua`](../Core.lua), the settings window in [`Config.lua`](../Config.lua).

Next: [Troubleshooting](troubleshooting.md)

# Troubleshooting

[Documentation](README.md) › Troubleshooting

## Holding the button does nothing

- Check that the button is assigned: `/mouseshift` should show it in the field.
- Check that you have keybinds on that layer. The number next to the field, for example *24 bindings*, shows how many. `/mouseshift list` shows every key.
- Keybinds with Shift are needed for the Shift layer. If you have none, set them in the game's key bindings menu: hold the real Shift and press the key.

## A macro with [mod:shift] does not react

Macro conditions check the real Shift key, which MouseShift does not press. Move the alternative to its own Shift keybind. See [How it works](how-it-works.md#what-is-not-possible).

## Shift-click on raid frames does not work

Click-casting needs the real Shift key. MouseShift works with keys, including mouseover healing. See [Healers](healers.md).

## A key keeps doing its Shift action after I released the button

This can happen when a keyboard key used as a modifier is released while the game window is not focused, for example after Alt-Tab. Press that key once and it is fixed. Mouse buttons are fixed automatically within a second out of combat.

## The window refuses a key or button

| Message | Reason |
| --- | --- |
| *cannot be used as a modifier* | Escape, Enter, Print Screen, the mouse wheel, or the left or right mouse button. These keep the game usable. |
| *is used for movement* | The key moves your character, or the mouse button turns the camera. |
| *Shift, Ctrl and Alt themselves cannot be used* | The real modifier keys cannot be modifiers for themselves. |
| *Settings cannot be changed in combat* | Leave combat first. The game blocks keybind changes from addons in combat. |

## My mouse button did something else before

The window tells you what was bound to the button when you assign it. MouseShift covers that keybind while the button is assigned. Click **Clear** and the old keybind is back.

## My side buttons send numbers or the numpad

See [MMO mice](mmo-mice.md), including the Shift and numpad trap in Windows.

## The left mouse button only turns the camera now

That is how the game works: the left button turns the camera, the right button turns the character. If a right click moves your character to where you clicked, the game's **Click-to-Move** option is on (Options › Controls). MouseShift never changes game options, and it can never take over the left or right mouse button.

## How do I remove everything?

Type `/mouseshift reset`, or click **Clear** on every field. To remove the addon completely, disable or delete it. Your keybinds were never changed, so nothing else needs undoing.

## Still stuck?

Open an [issue on GitHub](https://github.com/mikebronka/MouseShift/issues/new/choose) with the output of `/mouseshift list` and any Lua error, or ask on [Discord](https://discord.gg/cbmqVcNq7).

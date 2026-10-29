# MMO mice

[Documentation](README.md) › MMO mice

MMO mice such as the Razer Naga, Logitech G600 and Corsair Scimitar have a grid of 6 to 12 buttons under the thumb. They are made for games like World of Warcraft, and MouseShift works with them.

## What the side buttons send

Most of these mice do not send mouse buttons from the side grid. They send **keyboard keys**:

- by default, usually the number row: 1, 2, 3 … 0, - and =
- many players switch them to the numpad in the mouse software, so they do not repeat the keyboard's number row

For the game, pressing side button 1 is the same as pressing a key on the keyboard.

## Using a side button as a modifier

MouseShift accepts keys as well as mouse buttons:

1. Type `/mouseshift` and click the **Shift** field.
2. Press the side button you want to use as Shift.
3. Done. Hold that side button and press a key for its Shift keybind.

A side button used as a modifier no longer does its own action while it is assigned. Click **Clear** to give it back.

## Using the side buttons for spells, with a modifier elsewhere

You can also keep all side buttons for spells and put the modifier on a button your thumb does not need:

- the **middle button** (wheel click), pressed with the index or middle finger
- a **top button** of the mouse, if it sends a mouse button

Hold it and press a side button for its Shift keybind. With three modifiers on three such buttons, a 12-button grid gives 48 keybinds without touching the keyboard.

## Shift and the numpad

If your side buttons send the numpad, the **real** Shift key on the keyboard does not combine well with them. This is a Windows rule, not a game or MouseShift problem: with Num Lock on, Shift turns numpad keys into navigation keys.

| Numpad key | With Shift becomes |
| --- | --- |
| 7, 8, 9 | Home, Up, Page Up |
| 4, 5, 6 | Left, nothing, Right |
| 1, 2, 3 | End, Down, Page Down |
| 0, decimal | Insert, Delete |

So Shift with side button 1 reaches the game as End, not Shift-Numpad 1. The arrows are also movement keys by default, so Shift with side button 8 can move your character.

Ways around it:

- **Use Ctrl or Alt with the numpad.** They are not affected.
- **Let MouseShift be your Shift.** Assign Shift to another key or button, for example Caps Lock, Tab or the middle mouse button. MouseShift does not press the real Shift key, so the numpad stays the numpad and Shift-Numpad 1 keybinds work.
- **Switch the side buttons to the number row** in the mouse software, if you do not need the keyboard's number row for something else.

## Without the mouse software

Many players would rather not run the mouse manufacturer's software all the time. Most MMO mice remember their button settings in the mouse itself, so you can set the side buttons once and close the software. From then on, MouseShift does the rest inside the game.

Next: [How it works](how-it-works.md)

# The idea

## A missing option in the game

World of Warcraft lets you put almost anything on a mouse button: spells, macros, movement, the camera, menus. One basic thing is missing: **a modifier**. You cannot tell the game "this mouse button is Shift", or Ctrl, or Alt.

MouseShift adds exactly that option, and nothing else. It is the setting that should have been in the key bindings menu all along. Shift is simply the most common use. The same works for Ctrl and Alt, for any extra mouse button and for any keyboard key.

## The problem it solves

In World of Warcraft the left hand does almost everything: it moves the character and presses most abilities. The keys it reaches comfortably are few, usually the number row from 1 to 5 or 6 and a handful of letters around W, A, S and D.

Modifier keys multiply those keys, because Shift-2 is a different keybind from 2. Reaching them is the hard part:

- Shift, Ctrl and Alt sit under the little finger, the weakest finger of the hand.
- Shift-5 or Ctrl-6 means stretching the hand while still moving the character.
- In a busy fight these stretches cause mistakes, and after long sessions, tired hands.

For years players worked around this with mouse software or tools like AutoHotKey that make a mouse button act as Shift. That works, but it means an extra program next to the game, a different setup for every mouse brand, and sometimes software the player would rather not trust.

## The solution

The thumb rests on the side buttons of the mouse and does nothing most of the time. MouseShift lets it pick the layer:

- hold the thumb button and the keys under the left hand reach their Shift keybinds
- release it and they are back to normal

The left hand keeps the same comfortable keys. The thumb chooses what they do.

## The principles

MouseShift is built around a few rules that do not change between versions:

- **Inside the game only.** No external program, no drivers, no mouse software. It works with any mouse.
- **One press, one action.** MouseShift never automates anything. It only changes which keybind a key press reaches, exactly as holding Shift would. Nothing is cast that you did not press.
- **Your keybinds stay yours.** MouseShift uses the Shift, Ctrl and Alt keybinds you already have. It never changes or saves them. Remove it and everything is as before.
- **Works in combat.** A feature like this is useless if it stops when the fight starts.
- **Hard to break.** The left and right mouse buttons, Escape and movement can never be taken over, and nothing is assigned by accident.
- **Small and quiet.** One small settings window, no changes to your interface, no extra libraries.
- **A companion, not a replacement.** MouseShift fills a gap in the game, not in another addon, so it works next to the addons you already use. See [A companion to your addons](A-Companion-To-Your-Addons).

## What it does not do

Some things depend on the real Shift key being pressed, and an addon cannot press it. Macro conditions such as `[mod:shift]`, Shift-click in the interface and action bar paging on a modifier keep using the real key on the keyboard. The [documentation](https://github.com/mikebronka/MouseShift/blob/main/docs/how-it-works.md#what-is-not-possible) explains why.

Next: [Who it is for](Who-It-Is-For)

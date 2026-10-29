# Why MouseShift

[Documentation](README.md) › Why MouseShift

## The problem

In World of Warcraft your left hand does almost everything: it moves the character and presses most of your abilities. The keys it can reach comfortably are few, usually the number row from 1 to 5 or 6, and a handful of letters around W, A, S and D.

Modifier keys multiply those keys. Shift-2 is a different keybind from 2. But reaching them is the hard part:

- Shift, Ctrl and Alt sit under the little finger, the weakest finger of the hand.
- Shift-5 or Ctrl-6 means stretching the hand while still moving the character.
- In a busy fight these stretches cause mistakes and, after long sessions, tired hands.

Players have worked around this for years with mouse software or tools like AutoHotKey that make a mouse button act as Shift. That works, but it means an extra program running next to the game, a setup that differs for every mouse brand, and in some cases software the player would rather not trust.

## The idea

Your thumb rests on the side buttons of your mouse and does nothing most of the time. What if holding one of those buttons made the game behave as if Shift were held?

- Hold the thumb button, press 2, and the game does what you have on Shift-2.
- Release the button, press 2, and you get your normal 2.

The left hand keeps the same comfortable keys. The thumb picks the layer.

## The principles

MouseShift was built around a few rules:

- **Inside the game only.** No external program, no drivers, no mouse software. Install the addon and it works with any mouse.
- **One press, one action.** MouseShift never automates anything. It only changes which keybind a key press reaches, exactly as if you held Shift yourself. Nothing is cast that you did not press.
- **Your keybinds stay yours.** MouseShift reads the Shift, Ctrl and Alt keybinds you already have. It never changes or saves your keybinds; clear a button and everything is as before.
- **Works in combat.** The feature is useless if it stops when the fight starts, so it is built on the part of the game's interface that is allowed to work in combat.
- **Hard to break.** The left and right mouse buttons, Escape, Enter and movement keys can never be assigned, nothing is assigned by accident, and a layer cannot stay stuck after Alt-Tab or a loading screen.
- **Small and quiet.** One window, opened only when you need it. No changes to your interface, no minimap button, no extra libraries.

## How many keybinds you gain

Say your left hand reaches 12 keys comfortably: 1 to 6, Q, E, R, F, Z and X.

| Modifiers assigned to the mouse | Layers you can reach | Keybinds within reach |
| --- | --- | --- |
| None | plain | 12 |
| Shift | plain, Shift | 24 (double) |
| Shift and Ctrl | plain, Shift, Ctrl | 36 (triple) |
| Shift, Ctrl and Alt | plain, Shift, Ctrl, Alt | 48 (quadruple) |
| Shift, Ctrl and Alt, holding two buttons together | plus Ctrl-Shift, Alt-Shift, Alt-Ctrl, Alt-Ctrl-Shift | up to 96 |

All of them without moving your left hand away from its usual keys. In practice most players use one or two buttons, which already doubles or triples what they can reach.

## Who it is for

- **Healers.** Mouseover healing needs many spells on keys: heals, cooldowns, dispels, utility. MouseShift gives each of them a comfortable key. See [Healers](healers.md).
- **Damage dealers and tanks** with many abilities, defensive cooldowns, interrupts and utility that do not fit on easy keys.
- **Owners of MMO mice** (Razer Naga and similar) who want Shift, Ctrl or Alt on a side button without the mouse software. See [MMO mice](mmo-mice.md).
- **Players who find modifier keys uncomfortable**, for example after long sessions, or because of hand fatigue or limited reach.
- **Anyone who used AutoHotKey or mouse software for this** and would rather have it inside the game.

## A companion to your other addons

MouseShift does one small thing: it puts Shift, Ctrl and Alt under your thumb. Everything else stays with the addons you already use, and MouseShift makes them reach further.

- **Action bars** (the default bars, Bartender, Dominos, ElvUI and others): MouseShift picks up the Shift, Ctrl and Alt keybinds you set there and puts them under your thumb. No bar settings to change.
- **Raid frames and click-casting** (Grid2, VuhDo, Cell, Clique, the game's click bindings): keep healing with clicks as you do now. MouseShift adds layers to your keys, so the spells you cast with keys on mouseover get more room.
- **Keybinding addons** (BindPad, SpellBinding and others): every Shift, Ctrl or Alt keybind they create becomes reachable with the thumb as well.
- **Macros:** your mouseover and other macros work unchanged on every layer.

MouseShift creates no bars, frames or macros of its own and changes none of yours. It only adds layers on top of what you already have, which is why it fits next to almost any setup. The few things it cannot reach, such as Shift-click in the interface, are explained in [How it works](how-it-works.md#what-is-not-possible).

Next: [Getting started](getting-started.md)

# Healers

[Documentation](README.md) › Healers

Healing asks more of the keyboard than any other role. Besides your heals you need cooldowns, dispels, utility, movement abilities and often a few damage spells, and many of them have to be cast on a specific player in the group. MouseShift was made with this in mind.

## Mouseover healing works

The most common way to heal with keys is mouseover: point the cursor at a player's frame and press a key. The spell lands on that player without changing your target.

This works with MouseShift exactly as it works with the real Shift key:

1. Point the cursor at a raid frame.
2. Hold the thumb button and press 2.
3. The spell on Shift-2 lands on the player under the cursor.

Your mouseover macros do not need any change. A typical one looks like this:

```
#showtooltip
/cast [@mouseover,help,nodead][] Flash Heal
```

Put it on 2 and another macro on Shift-2, and the thumb button switches between them.

## Click-casting does not

Click-casting means clicking a raid frame to cast: left-click for one heal, Shift-left-click for another. This is how Clique, the click-casting of raid frame addons such as Grid2 or VuhDo, and the game's own click bindings work.

MouseShift cannot change clicks. Shift-click on a frame still needs the real Shift key. If you heal with click-casting, MouseShift will not add layers to your clicks. It still adds layers to your keys, so you can move some spells from clicks to keys.

The reason is explained in [How it works](how-it-works.md#what-is-not-possible).

## An example layout

With the thumb button as Shift and the next side button as Ctrl, and these keys under the left hand: 1, 2, 3, 4, Q, E, R, F.

| Key | Plain | Shift (thumb) | Ctrl (second button) |
| --- | --- | --- | --- |
| 1 | Fast heal | Big heal | Group heal |
| 2 | Heal over time | Shield | Second heal over time |
| 3 | Dispel | Mass dispel | Purge on enemy |
| 4 | Damage spell | Second damage spell | Interrupt |
| Q | Cooldown on target | Personal defensive | Movement ability |
| E | Group cooldown | Second group cooldown | Battle resurrection |
| R | Resurrect | Mass resurrect | Mount |
| F | Trinket | Second trinket | Healthstone |

24 actions on 8 keys, with the left hand never leaving them. Adapt it to your class: the point is that related spells share a key and the thumb picks the version.

## Tips

- Keep your fastest, most used heal on a plain key. Layers are for the second and third choice, not for spam.
- Put spells you press in a panic, like a personal defensive, on a layer you reach without thinking, usually the thumb.
- If you use the real Shift on the keyboard for anything, such as moving with Shift held, keep that too: MouseShift does not take the real Shift key away.

Next: [MMO mice](mmo-mice.md)

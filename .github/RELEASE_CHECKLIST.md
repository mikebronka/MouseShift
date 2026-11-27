# Release checklist

Go through this list before every release, including small fixes. Most bugs that reach players come from a fix that changed more than it meant to.

## 1. Describe the change

- [ ] Write down in one or two sentences what behaves differently after this change, and for whom.
- [ ] Check the change against popular keybinds and setups. Ask for each: does it still work exactly as before?
  - `Space` (jump) with Shift, Ctrl and Alt
  - `W`, `A`, `S`, `D`, `Q`, `E` and the arrow keys
  - the number row and the numpad (MMO mice)
  - mouse buttons 3, 4 and 5, and the mouse wheel
  - action bar addons (ElvUI, Bartender, Dominos) and unit frame addons
- [ ] If the change blocks or removes anything a player could use before, it needs a strong reason and a note in the changelog.

## 2. Tests

- [ ] Every bug fixed in this release has a test in `tests/run.lua`, and so does every bug fixed before.
- [ ] `lua5.1 tests/run.lua` passes. The Tests workflow runs it on every push and before every release.

## 3. Independent review

- [ ] The diff since the last release (`git diff vX.Y.Z HEAD`) is reviewed by someone who did not write it, against section 1 of this list.
- [ ] Every finding is fixed or answered before the release.

## 4. In-game test, Retail and WoW Forever

Assign Shift to mouse button 5 and Ctrl to mouse button 4, then:

- [ ] `/reload` shows no Lua errors, and the version is right: `/dump C_AddOns.GetAddOnMetadata("MouseShift", "Version")`.
- [ ] Mouse 5 + `1` gives the `Shift-1` keybind, and mouse 5 + mouse 4 + `1` gives `Ctrl-Shift-1`.
- [ ] Mouse 5 + `Space` gives the `Shift-Space` keybind.
- [ ] With a `Ctrl-W` keybind set: walk with `W`, press mouse 4, release `W`. The character stops.
- [ ] The same keys work in combat.
- [ ] Mouseover casting with mouse 5 over the player, party and raid frames gives the Shift keybind.
- [ ] `/mouseshift list` shows the expected keys.
- [ ] The settings window, the minimap button and **Clear** work.
- [ ] Whatever this release changed, tested directly.

## 5. Documentation

- [ ] `CHANGELOG.md` has the new version at the top.
- [ ] `README.md`, `docs/` and `wiki/` match the new behaviour.

## 6. Publish

- [ ] Publish the draft release on GitHub.
- [ ] The Release workflow is green, and the new file appears on CurseForge, Wago and WoWInterface.
- [ ] For the next day or two, watch comments and issues for anything new.

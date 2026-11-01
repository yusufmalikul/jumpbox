# JumpBox

An offline 3D playground game for a 5-year-old. Godot 4.7 + GDScript, Jolt physics,
Compatibility renderer, exported as an Android APK for a low-end Redmi phone.
Personal use: keep it simple, keep development fast.

## Game rules (never break these)

- No losing, no game over, no timers that punish. A fall puts you back at the last checkpoint.
- Big, simple touch controls. No reading needed to play (the child cannot read yet).
- Light on the phone: few nodes, simple materials, no heavy shaders or real-time shadows.
  Only one place is loaded at a time, and a course is built the first time you enter it.
- No internet, no ads, no downloaded assets. Sounds come from `tools/make_sounds.py`.

## Commands

```bash
./tools/check.sh                                # run every test (headless); must say ALL PASS
godot --path . -- --shot=/tmp/shot.png          # play 2 seconds, save a screenshot, quit
./build.sh                                      # signed release APK at build/JumpBox.apk
```

## How to work

- **A passing test is not proof that it looks right.** After any change you can see
  (a new ride, a course, the HUD, the menu), take a screenshot with `--shot` and look at
  it with the Read tool before calling the work done. Check that it is in the frame, not
  clipped, and not hidden inside another block. Tests do not need to be strict
  (fast development matters more), but always look.
- Before each commit, run `./tools/check.sh`. A broken script can make Godot hang, so the
  check kills any test after 90 seconds.
- Use `delta` for anything that moves over time, so the game runs the same on a slow phone.
- Keep tuning numbers (speeds, jump height, sizes) as named `const` values at the top of
  the script, not as numbers buried inside the code.
- Call down, signal up: a parent calls methods on its children; a child tells its parent
  about events with a signal.

## Godot file rules

- Every `.gd` file has a `.gd.uid` file next to it. Commit them together. If you move or
  rename a script outside the editor, move its `.uid` too. Never invent a `uid://` value.
- The park is built from code. Do not hand-edit `.tscn` files unless you must; after a
  hand edit, run `godot --headless --path . --import` and run the scene once.
- Godot 4.5+ APIs may be newer than your training. If you are not sure an API exists
  in 4.7, check with a quick headless script instead of guessing.

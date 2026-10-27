# JumpBox

An offline 3D playground game for little kids, made with Godot 4.7. One big park with
trampolines, slides, swings, a merry-go-round, a block tower and bouncy balls. There is
no way to lose: just play.

Walk through the rainbow portal to reach the **sky course**: easy jumps high above the
clouds, up through 10 numbered checkpoints to a golden trophy. Gaps are short and steps
are low, made for small kids. Fall into the clouds and you come back at your last checkpoint.

[![JumpBox demo video](docs/demo.jpg)](docs/demo.mp4)

▶️ [Watch the demo video](docs/demo.mp4) (55 seconds, played on an Android phone)

## Download

📱 **[Download JumpBox.apk](https://github.com/yusufmalikul/jumpbox/releases/latest/download/JumpBox.apk)** (Android 7 or newer, 64-bit phones)

Open the file on your phone to install it. Android may ask you to allow installs from
your browser or file app, and Play Protect may warn because the app is not from the
Play Store; choose "Install anyway". All versions are on the
[Releases page](https://github.com/yusufmalikul/jumpbox/releases).

## Controls

- Left side of the screen: joystick (it appears where your finger lands)
- Yellow button: jump (hold it to keep jumping, and to bounce higher on trampolines)
- Drag on the right side: turn the camera
- Home button (top left): go back to the start
- Land on a swing seat to sit and swing; press jump to get off
- On the sky course: the big number at the top is your checkpoint; the arrows next to it
  jump to the previous or next checkpoint if a stage is too hard

On a computer: WASD or arrows to move, Space to jump, Q/E to turn the camera.

## Build the APK

Needs Godot 4.7 (`brew install --cask godot`), JDK 17 (`brew install openjdk@17`) and the
Android SDK (`brew install --cask android-commandlinetools`, then
`sdkmanager "platform-tools" "build-tools;36.1.0" "platforms;android-36"` into
`~/Library/Android/sdk`), plus the Godot 4.7 Android export templates.

```bash
./build.sh   # makes build/JumpBox.apk
```

The first build makes a signing key in `~/.android/jumpbox-release.keystore`. Keep it
safe: new versions only install over the old app if they are signed with the same key.

## Sounds

All sound effects and the music are made from math by `tools/make_sounds.py`
(no downloaded audio). Change it, then run `uv run tools/make_sounds.py` to remake
the files in `assets/`. The music button (top right) turns the music on and off.

## Run on the computer

```bash
godot --path .                                  # play
godot --path . -- --shot=/tmp/shot.png          # save a screenshot after 2 seconds and quit
```

## Code

The whole park is built from code in `scripts/main.gd`. `player.gd` is the character and
camera, `obby.gd` the sky course, `touch_ui.gd` the on-screen controls, `rides.gd` the moving parts (swings,
merry-go-round), and `util.gd` small helpers for making blocks.

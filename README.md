# souls

A souls-like for Roblox, built with [Rojo](https://github.com/rojo-rbx/rojo) 7.6.1.

## Getting started

Tools are managed with [Rokit](https://github.com/rojo-rbx/rokit):

```bash
rokit install
wally install
rojo serve
```

Open your place in Studio and connect the Rojo plugin. The game expects **R15** avatars (Game Settings → Avatar).

To build a fresh place file instead: `rojo build -o souls.rbxlx`.

## Checks

```bash
rojo sourcemap default.project.json --include-non-scripts -o sourcemap.json
stylua --check src
selene src
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json --base-luaurc=.luaurc \
	--ignore="Packages/**" --flag:LuauSolverV2=false src
```

`globalTypes.d.luau` (gitignored) comes from
`https://luau-lsp.pages.dev/type-definitions/globalTypes.None.d.luau`.

> If `rojo --version` reports something other than 7.6.1, an older Rojo install is ahead of
> `~/.rokit/bin` on your PATH.

## Architecture

```
src/
  stubs/      Empty PlayerModule + Animate: stops Roblox's default camera, controls and animations loading
  shared/     Signal, Trove, StateMachine, MathUtil, Tags
  server/     LockOnTagger: tags NPC rigs and player characters as lock-on targets
  client/
    init.client.luau        Entry point: owns Input, TargetRegistry, the CharacterSession and the frame loop
    Config/                 All tuning: Bindings, Movement, Camera, Animations, Debug
    Input/                  UserInputService -> per-frame InputFrame + ActionBuffer (roll/jump buffering)
    Targeting/              TargetRegistry (tagged models) and LockOn (acquire, switch, break)
    Camera/                 CameraRig (orbit, collision, zoom, shoulder, lock-on framing) and Occlusion
    Character/
      CharacterSession      Everything for one life of the character; destroyed on respawn
      Rig                   Character references and collision setup
      Motor                 ControllerManager wrapper + override LinearVelocity
      GroundTilt            Visual slope tilt through the Root Motor6D
      Animation             Locomotion blending and one-shot actions
      States/               Idle, Walk, Sprint, Roll, Jump, Fall, Land, Dead
```

### Frame pipeline

There is a single ordered loop, so the camera never fights the character:

1. **Render step** (`BindToRenderStep`, Camera priority):
   1. sample input
   2. lock-on upkeep
   3. camera orientation
   4. state machine (sets motor intents, plays animations)
   5. locomotion blend
   6. camera transform
2. **PreSimulation:**
   1. motor ground/air switching and ground snap
   2. ground tilt (after the Animator has written this frame's pose)

**Single-writer rules:**

- Only physics moves the character: ControllerManager plus the override LinearVelocity. Nothing writes `Root.CFrame`.
- Only `CameraRig` writes `CurrentCamera.CFrame`.
- Camera rotation comes straight from yaw/pitch. Only the focus point is smoothed.

### Movement

- **Motor:** a `ControllerManager` with a `GroundController`, an `AirController` and a floor `ControllerPartSensor`.
  - Our code decides which controller is active, because ControllerManager doesn't switch on its own.
  - Rolls (and later root motion and knockback) drive horizontal velocity through `Motor:SetOverrideVelocity`. While that runs, the active controller keeps handling hover height and gravity.
- **States** return the name of the next state from `Update`.
  - Roll and jump presses are buffered (`Config.Movement.Buffer`), so a press slightly early still counts.
  - Jump has coyote time.
- **Slope tilt is visual only.** The physics root stays upright, and the body leans through the LowerTorso `Root` joint.

### Default controls

| Action | Keyboard & mouse | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Camera | Mouse | Right stick |
| Roll (tap) / Sprint (hold) | Space | B |
| Jump | F | A |
| Lock-on | Middle mouse / Q | R3 |
| Switch target | Mouse wheel (while locked) | Flick right stick |
| Shoulder swap | Tab | L3 |
| Zoom | Mouse wheel | – |
| Free cursor (hold) | Left Alt | – |

Bindings are in `src/client/Config/Bindings.luau`.

### Debugging

In `src/client/Config/Debug.luau`:

- `Enabled` draws the ground sensor, velocity, facing, current state and lock-on target.
- `LogStates` prints state transitions.

Both only take effect in Studio.

## Play-test checklist

- **Default scripts are gone:** no default camera, controls or animations.
- **Standing height:** feet rest on the floor. If they sink or float, adjust `Movement.GroundOffsetAdjust`.
- **Terrain:** ramps up to about 50° work, steeper slopes slide, stairs step up and down, walking off ledges falls.
- **Turning:** turn speed feels right. Tune `Movement.TurnSpeed`, since ControllerManager's units aren't documented.
- **Rolls:**
  - distance and feel
  - chaining with a buffered tap
  - backstep with no input
  - rolling off a ledge keeps momentum
- **Jumping:** coyote jump just after leaving a ledge works, and a fall of 14+ studs plays the hard landing.
- **Respawn:** respawn 3+ times; nothing is duplicated (one `ControllerManager` and one `GroundSensor`).
- **Camera:**
  - corners, low ceilings and tight corridors
  - shoulder swap against a wall
  - occluding walls fade
  - recenters behind you when idle, and on lock-on with no target
- **Lock-on** (place 3+ R15 dummies):
  - acquire and switch with the wheel and the stick flick
  - breaks after losing sight behind a wall for 2 s, at distance, or on the target's death
  - strafing and locked-on directional rolls
- **Tilt:** leans on slopes, and stays upright at ledges, on stairs and in the air.

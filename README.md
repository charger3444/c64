# FIDATI. — Commodore 64 port (Blocco 1)

A native Commodore 64 port of the first world ("Blocco 1: Spazio
Geometrico", levels 1-3) of **FIDATI.**, a rage-platformer originally
built as an HTML5/Canvas game (design & original web build by Carlo
Gerla). This port is written from scratch in 6502 assembly for the
VIC-II/SID/CIA, aiming to reproduce the original's physics and hazard
gameplay while leaning into what the C64 is actually good at:
hardware sprites, a raster-IRQ-driven main loop, a custom multicolor
character set, and SID sound effects.

## What's here

- `src/fidati.s` — entry point, hardware init, IRQ handler, zero page
  layout, `.include`s for the other modules.
- `src/input.s` — joystick (control port 2) reading.
- `src/states.s` — game state machine (title / play / dead / level
  complete / block complete).
- `src/physics.s` — fixed-point movement, jump buffering/coyote time,
  tile collision and resolution.
- `src/level.s` — level loading, fake-floor "crumble" timers, spike
  and flag hazard checks, scoring.
- `src/render.s` — tile/HUD/text drawing, sprite positioning & framing.
- `src/sound.s` — SID sound effects.
- `src/data.s` — auto-generated tile glyphs, sprite frames, level
  grids and PETSCII text tables (see `tools/`).
- `src/c64-fidati.cfg` — `ld65` linker configuration.
- `tools/genart.py`, `tools/gendata.py`, `tools/gentext.py` — the
  generators that produced `src/data.s`. They are build-time helpers
  only; nothing in the shipped game depends on Python.

## Building

Requires the [cc65](https://cc65.github.io/) toolchain (`cl65`).

```
sudo apt-get install cc65   # Debian/Ubuntu
./build.sh                  # -> build/fidati.prg
```

## Running

Load `build/fidati.prg` in your favourite C64 emulator (VICE, etc.)
or transfer it to real hardware. The game boots straight into the
title screen — no `LOAD`/`RUN` typing needed, since the two-byte PRG
header plus a tiny `10 SYS 2061` BASIC line auto-start it.

**Controls: joystick, port 2, only.**
- Left/Right: move
- Fire: jump (tap for a short hop, hold for a full jump; also used
  to confirm on the title/"block complete" screens)

## Design notes / what's native-C64 about this port

- **Physics** run on the same numeric model as the original (16px
  tiles, 320×192 play-field, gravity/acceleration/friction/jump
  constants), just re-expressed as 7-bit fixed point (`pixels * 128`)
  so it's cheap 16-bit integer math on a 6502.
- **Collision** resolves by snapping the player's AABB to the tile
  boundary it hit, rather than the original's sub-pixel stepping loop
  — same end result, no loops needed on the CPU side.
- **Rendering** uses a custom **multicolor character set**: the
  uppercase/graphics ROM font is copied into RAM at boot (so all the
  Italian flavour text/HUD "just works"), then ~9 character slots are
  overwritten with hand-authored tile/spike/flag glyphs. Solid tiles
  and "fake" (crumbling) floors are *visually identical* — exactly
  like the original — because they share the same glyphs and colour.
- The **player** is a 12×21 multicolor hardware sprite (yellow body,
  orange cap, dark outline) with separate left/right/jump frames and
  a 2-frame run cycle.
- The **main loop is a raster IRQ** at the bottom border (line 250)
  that runs the whole simulate+render step once per frame; CIA1's
  own IRQ sources are disabled so the VIC raster is the sole
  interrupt source, and the RESTORE-key/RS232 NMI vector is pointed
  at a no-op stub since the game doesn't use either.
- Flags animate by swapping the pennant's screen character between
  two pre-drawn frames every 20 frames — cheap and very C64.
- SID sound effects use one-shot envelopes with `sustain=0` so a
  single gate trigger produces a natural decaying blip with no
  per-frame scheduling needed.

## Testing caveat

Genuine Commodore KERNAL/BASIC/character ROMs are Cloanto-licensed
and can't be redistributed or fetched here, so in this sandboxed
environment the build was exercised under VICE using the
[MEGA65 Open ROMs](https://github.com/MEGA65/open-roms) project — an
explicitly **work-in-progress**, clean-room replacement KERNAL. Init
(hardware setup, character-ROM copy/patch, sprite pointer
computation) and the raster-IRQ install/chain were all verified
correct via monitor-level breakpoint tracing. However, that
replacement KERNAL's idle loop is not reentrancy-safe against a
custom `$0314` raster-IRQ takeover — the *single most standard*
technique in C64 programming — and crashes intermittently (anywhere
from under a second to 30+ seconds of idle time) regardless of IRQ
strategy (chained vs. fully independent), which CIA1 state is used,
or which Open ROMs build is loaded. A KERNAL-independent, jiffy-clock
polling build of the same game logic ran cleanly for 30+ seconds,
confirming the game code itself is not at fault. On a real C64 (or
any emulator configured with genuine ROMs) this is a non-issue, since
IRQ vector takeover is exactly what real KERNAL implementations are
built to support cleanly.

## Scope

Only Block 1 ("Spazio Geometrico", levels 1-3 — *Fidati del
pavimento*, *La scorciatoia comoda*, *La bandiera è lì. Giuro.*) is
implemented, matching the request. Blinking platforms, hidden
spikes, stalactites, the meta-game (name entry / online leaderboard)
and later blocks from the original all belong to later
worlds/features that weren't part of this port's scope.

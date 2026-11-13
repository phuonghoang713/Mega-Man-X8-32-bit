# Zero's sprites

Drop an Aseprite sprite-sheet export here and the game uses it for Zero
(Options > Character > Zero). With no sheet in this folder, Zero is drawn with
X's sprites recolored red as a placeholder.

Only add art you made yourself or have permission to use.

## Files

| File        | What it is                                                     |
|-------------|----------------------------------------------------------------|
| `zero.json` | Aseprite JSON data (Hash or Array), exported **with Tags**     |
| `zero.png`  | The sheet the JSON points to (`meta.image` is used if present) |
| `zero.cfg`  | Optional tuning: sprite offset, saber hit frames, slash trail  |

In Aseprite: *File > Export Sprite Sheet*. On the *Output* tab, tick
*Output File* (`zero.png`) and *JSON Data* (`zero.json`), and under *Meta*
tick *Tags*. Trimmed and untrimmed sheets both work.

## How frames are read

- Each **tag** becomes an animation with the same name. Frame order follows
  the tag direction (forward, reverse, ping-pong). Speed comes from the
  frames' durations.
- Draw Zero **facing right**, centered horizontally in the canvas. The
  canvas can be any size: the feet are lined up with X's automatically from
  the first frame of `idle`. Fine-tune with `offset` in `zero.cfg`.
- Animations you have not drawn yet borrow the closest drawn one (or `idle`)
  so Zero never disappears. The game log lists them on stage start:
  `Zero sprites: not drawn yet, using a stand-in: ...`

## Animation names

Start with these. Everything else is optional.

| Name         | Used for                                        |
|--------------|-------------------------------------------------|
| `idle`       | Standing (loops). **Required.**                 |
| `walk`       | Running (loops)                                 |
| `jump`       | Going up                                        |
| `fall`       | Coming down                                     |
| `dash`       | Ground dash                                     |
| `slide`      | Sliding down a wall                             |
| `walljump`   | Kicking off a wall                              |
| `damage`     | Getting hit                                     |
| `saber_1`    | Ground combo, hit 1                             |
| `saber_2`    | Ground combo, hit 2                             |
| `saber_3`    | Ground combo, hit 3 (finisher)                  |
| `saber_air`  | Spin slash in the air                           |
| `saber_dash` | Slash while dashing                             |

Other names the game plays (same as X's): `walk_start`, `stop`, `stop_end`,
`turn`, `airdash`, `recover`, `weak`, `crouch`, `beam`, `beam_in`, `victory`,
`talk`, `ride`, `stairs`, `damage_resist`.

## zero.cfg

```ini
[sprite]
offset=Vector2( 0, 0 )          ; extra shift in pixels after auto-alignment

[saber]
procedural_trail=true           ; false if your saber frames draw the slash
hit_frame_saber_1=2             ; frame (from 0) on which each hit lands
```

The saber hit lands on `hit_frame_<animation>`; without it, the default
timing in `ZSaber.gd` is used.

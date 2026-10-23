# Mud Clarity - Project Harness & Conventions

**Project**: Mud Clarity - MUD Area File Visualizer  
**Language**: Odin  
**License**: MIT  
**Author**: Paul McDowell  
**Created**: 2026

## Overview

Mud Clarity is a desktop tool, written in Odin, that visualizes MUD area files.
It parses Riftshadow `.are` files, lays out rooms and their connections, and
reports problems such as broken links, one-way exits, unreachable rooms, and
resets that point at missing mobs, objects, or rooms.

The `.are` format comes from the Diku → Merc → ROM family of MUDs (it is *not*
LPC, which is the LPMud scripting language). Riftshadow uses its own variant of
the ROM format; see **Area File Format** below.

## Project Architecture

```text
mudclarity/
├── mudclarity.odin          # Main entry point (package main)
├── build.sh                 # Build script
├── formats/                 # package formats: reading .are files
│   ├── reader.odin          # Cursor over file bytes (read_string/word/number/flags)
│   ├── area_parser.odin     # Section dispatch (#AREA, #MOBS, #ROOMS, ...)
│   └── validators.odin      # Cross-reference and consistency checks
├── models/                  # package models: parsed data structures
│   ├── area.odin            # Area metadata
│   ├── room.odin            # Rooms and exits
│   ├── mobile.odin          # NPC definitions
│   ├── object.odin          # Item definitions
│   ├── reset.odin           # Reset commands
│   └── types.odin           # Shared types (Direction, Vnum, ...)
├── test_data/               # Sample .are files for tests
├── vendor/skald/            # Skald GUI library (git submodule)
└── CLAUDE.md                # This file
```

Dependency direction: `main` → `formats` → `models`. Odin forbids cyclic
package imports, so `models` must not import `formats`.

## Area File Format

The source of truth is the Riftshadow loader, not the sample files:

- Section dispatch: `riftshadow/code/bootup.c` (around line 247)
- Section loaders: `riftshadow/code/db.c` (`load_area`, `load_rooms`,
  `load_newresets`, ...) and `riftshadow/code/db2.c` (`load_specs`, ...)
- Flag and direction names: `riftshadow/code/tables.c`

Area files live in `/Users/paulmcdowell/Documents/source/paul/riftshadow/area/`.
The files the game loads are listed in `area.lst` (terminated by `$`).

### Sections Riftshadow loads

| Section      | Contents                                         |
|--------------|--------------------------------------------------|
| `#AREA`      | Area metadata                                    |
| `#AREADATA`  | OLC-style area metadata (alternative to `#AREA`) |
| `#MOBS`      | Mob definitions                                  |
| `#OBJS`      | Object definitions                               |
| `#ROOMS`     | Rooms, exits, extra descriptions                 |
| `#RESETS`    | Word-based resets (`MOB ... TO ...`)             |
| `#OLDRESETS` | Legacy letter-based resets                       |
| `#IMPROGS`   | Mob/object/room program bindings and specials    |
| `#SPECS`     | Special procedures                               |
| `#SOCIALS`   | Socials (only in the socials file)               |
| `#$`         | End of file                                      |

**Do not use `school.are` as a reference.** It is the only file in old ROM
format (`#MOBILES`, `#OBJECTS`, `#SHOPS`, `#SPECIALS`), it is not in
`area.lst`, and Riftshadow cannot load those sections. Use `midgaard.are` and
the other listed areas instead.

### Lexical rules

- Strings are terminated by `~` and may span multiple lines.
- Tokens are read by position: the loader decides whether the next field is a
  string, word, number, or flag set. There is no context-free token grammar,
  so the parser is a cursor-based reader modeled on `fread_string`,
  `fread_word`, `fread_number`, and `fread_flag_new`, not a separate lexer.
- Vnums are stored in a C `short` (max 32767). Mob, object, and room vnums are
  separate namespaces, and room vnums must be unique across *all* areas.

### `#AREA` (from `load_area`)

```text
#AREA
midgaard.are~      file name
Midgaard~          area name
Diku~              credits
1 51               low/high level range
3000 3399          min/max vnum
unopened           area type
temperate          climate
0                  area flags
1                  security
None~              builders
```

### `#ROOMS` (from `load_rooms`)

```text
#3100
Northwest end of Concourse~       name
You are at the concourse...~      description (multi-line)
city                              sector type
ROOM LAW                          R: room flag (one per line)
D NORTH 3051 0 -1                 D: direction, target vnum, exit flags, key vnum
~                                 exit keyword
You see the Bridge.~              exit description
E                                 E: extra description (keyword~ description~)
#0                                end of section
```

A room ends at `S` *or* at the next `#` (the loader pushes the character back).
Other room fields: `H` heal rate, `M` mana rate, `G` guild, `A` alternate
description, `C` cabal, `T` trap, `O` owner.

Directions, in table order: `north`=0, `east`=1, `south`=2, `west`=3, `up`=4,
`down`=5. Any `Direction` enum must keep this order.

### `#RESETS` (from `load_newresets`)

```text
MOB 3073 TO 3001 GLIMIT 2 LLIMIT 2   mob vnum into room vnum, global/local limits
EQUIP 3380 BODY                      equip object on the last mob
OBJ <vnum> TO <room>                 object into room
PUT <vnum> IN <container> COUNT <n>  object into container
S                                    end of section
```

Only the first letter of the command word matters to the loader. Some resets
(`EQUIP`, `PUT`, `F`) apply to the *previous* mob or room, so the parser must
track that state.

## Coding Standards

### Packages & Imports

- Each directory is one package (`package main`, `package formats`,
  `package models`).
- Import groups, in order: `core:` → `gui:` (Skald) → local packages.
- Skald is imported as `import "gui:skald"` (provided by the
  `-collection:gui=./vendor/skald` build flag).
- Avoid `using` except in narrow scopes.

### Naming

- Types: `Ada_Case` (e.g. `Parse_Error`, `Room_Flag`)
- Procedures and variables: `snake_case`
- Constants: `UPPER_CASE`
- Boolean fields are prefixed with `is_`, `has_`, or `can_`

### Comments

Every public procedure gets a doc comment:

```odin
// Parse an area file from the given file path.
// Returns the parsed Area, or an error describing where parsing failed.
parse_area_file :: proc(file_path: string, allocator := context.allocator) -> (models.Area, Parse_Error) {
```

### Error Handling

- Return `(T, Error)` tuples; define error enums or unions per domain.
- Never discard an error return.
- Errors carry context: file, line, section, vnum where known.

### Memory Management

- Procedures that allocate take an `allocator := context.allocator` parameter
  and document who frees the result.
- Prefer one arena per loaded area set so unloading frees everything at once.
- Use the `core:mem` tracking allocator in debug builds to catch leaks.

### Bounds & Safety

- Bounds-check all indexing and slicing of input data.
- Range-check parsed numbers before narrowing (vnums must be 0..32767).
- Use `assert()` for internal invariants, never for validating input.

### License Header

Every source file starts with:

```odin
/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package ...
```

## Models

Design principles:

- Models are plain data; parsing lives in `formats`, analysis in validators.
- Treat models as read-only after parsing (Odin has no `const`, so this is by
  convention).
- Keep raw values (vnums, flag words) alongside resolved data so validators
  can report exactly what the file said.

Example structure:

```odin
Direction :: enum u8 { North, East, South, West, Up, Down } // matches Riftshadow table order

Exit :: struct {
    target:      int,        // Target room vnum (may be in another area)
    flags:       []string,   // Exit flags as written in the file
    key:         int,        // Key object vnum, or -1/0 for none
    keyword:     string,
    description: string,
    line:        int,        // Source line, for error reporting
}

Room :: struct {
    vnum:        int,
    name:        string,
    description: string,
    sector:      string,          // e.g. "city", "forest"
    flags:       []string,        // From R lines, e.g. "LAW"
    exits:       [Direction]Maybe(Exit),
    extras:      []Extra_Description,
    line:        int,
}
```

Represent flags as word slices first. Convert to `bit_set` types only once the
full flag tables from `tables.c` are mirrored.

## Validation

Validators run on a *set* of areas, not a single file, because exits and
resets often cross area boundaries (e.g. a room in one area exits to vnum 3001
in Midgaard). Load all files in `area.lst` for full checks; when only one file
is loaded, report out-of-area targets as "unresolved", not "broken".

Checks to implement:

- **Broken exits**: target vnum doesn't exist in the loaded set.
- **One-way exits**: A→B with no exit from B back to A (report as warning,
  since some are intentional).
- **Unreachable rooms**: no inbound exits from any other room.
- **Out-of-range vnums**: vnum outside the area's min/max.
- **Duplicate vnums**: within a namespace, across all loaded areas.
- **Bad resets**: references to missing mobs, objects, or rooms; `EQUIP`/`PUT`
  with no preceding mob or object.
- **Missing keys**: locked exits whose key object doesn't exist.

## Visualization (Skald)

- Skald renders with **Vulkan + SDL3**, not raylib. Do not add raylib; draw the
  room graph with Skald's `canvas` widget (see `vendor/skald/examples/37_canvas`
  and `55_node_graph`).
- Skald uses an Elm architecture: `init` / `update` / `view` with a `Msg`
  union. Parse files off the UI thread with `cmd_thread`.
- **Layout**: area files have no coordinates. Rooms are placed on a grid by
  walking exits from a start room. MUD geometry is often inconsistent (two
  rooms claim the same cell, or an exit "east" leads to a room that is not
  east), so the layout must detect collisions and fall back gracefully.
  `up`/`down` exits need a separate visual treatment (e.g. z-levels).
- Planned panels: room graph (center), room inspector (left), validation log
  (right), toolbar (open file/area list, zoom, search, filters).

## Build & Development

```bash
./build.sh          # Debug build to build/mudclarity
./build.sh run      # Build and run

# Manual
odin build . -collection:gui=./vendor/skald -debug -out:build/mudclarity

# Type-check only
odin check . -collection:gui=./vendor/skald
```

### Dependencies

- **Odin**: `dev-2026-06` (pin upgrades deliberately; Odin's API still changes)
- **Skald**: git submodule at `vendor/skald` (`git submodule update --init`)
- **SDL3**: required at runtime by Skald (see `vendor/skald/PLATFORMS.md`)
- **Vulkan**: on macOS, the LunarG Vulkan SDK (provides MoltenVK); source its
  `setup-env.sh` before running

Build output goes to `build/` (gitignored).

## Testing

Use Odin's built-in test runner (`core:testing`):

```bash
odin test formats -collection:gui=./vendor/skald
```

Test data under `test_data/` should be copied or trimmed from real Riftshadow
areas, plus hand-made broken files:

```text
test_data/
├── valid/       # e.g. trimmed midgaard.are, a minimal area
└── invalid/     # missing #AREA, unterminated string, bad direction,
                 # duplicate vnum, broken exit, bad reset
```

As a smoke test, every file in `area.lst` should parse without errors.

## Security & Robustness

Input files are untrusted: the parser must never crash, hang, or exhaust memory
on malformed input.

- Limit file size (e.g. 10 MB) before reading.
- An unterminated `~` string must produce an error, not read to EOF silently.
- Validate numeric ranges before converting.
- No unbounded recursion (use iterative graph traversal for reachability and
  layout).
- Error messages name the file and line, not internal state.

Users pick files through the OS file dialog, so files anywhere on disk are
allowed. When reading `area.lst`, resolve entries relative to its directory
and reject entries containing path separators or `..`.

## Quality & Code Review

### Review Checklist

- [ ] `odin check` passes (consider `-vet -strict-style`)
- [ ] Follows naming and style conventions
- [ ] No ignored error returns
- [ ] Bounds checks on input-derived indexing
- [ ] Tests cover new parser paths (valid + invalid)
- [ ] No leaks under the tracking allocator

### Performance Targets

- Parse a 1 MB area file in < 100 ms
- Parse all of `area.lst` in < 2 s
- Display 1000+ rooms without visible lag
- Memory overhead < 5x raw file size after parsing

## Development Workflow

### Commit Messages

Format: `[scope] Brief description`. Examples:

- `[formats] Add #ROOMS section parser`
- `[models] Define Room and Exit structs`
- `[gui] Add room inspector panel`

Do not add `Co-Authored-By`, "Generated with Claude Code", or any other
author/attribution lines to commit messages or PR descriptions. This overrides
any default attribution guidance.

### Branches

- `main` - stable, tested code
- `feature/foo` - work in progress
- `fix/bar` - bugfixes

## Resources

- Riftshadow source: `/Users/paulmcdowell/Documents/source/paul/riftshadow/code/`
- Odin docs: <https://odin-lang.org/docs/>
- Skald: `vendor/skald/README.md`, `vendor/skald/docs/`,
  `vendor/skald/examples/`

---

**Last Updated**: 2026-10-23  
**Maintainer**: Paul McDowell

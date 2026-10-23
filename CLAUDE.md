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
│   ├── reader.odin          # Byte cursor porting fread_* (string/word/number/flags)
│   ├── errors.odin          # Parse_Error / Parse_Failure
│   ├── tables.odin          # Item type and direction tables mirrored from Riftshadow
│   ├── area_parser.odin     # Section dispatch, #AREA/#ROOMS/#RESETS/#IMPROGS/#SPECS
│   ├── mobile_parser.odin   # #MOBS
│   ├── object_parser.odin   # #OBJS
│   ├── area_list.odin       # area.lst
│   ├── loaded_area.odin     # Loaded_Area: an area plus the arena it lives in
│   ├── area_set.odin        # Area_Set: every area in an area.lst
│   └── *_test.odin          # Tests (only compiled by `odin test`)
├── validation/              # package validation: checks on a set of areas
│   ├── validate.odin        # validate() entry point
│   ├── world.odin           # Vnum indexes, completeness rule
│   ├── exits.odin           # Exits, doors, keys
│   ├── resets.odin          # Resets, portals, programs, records
│   ├── reachability.odin    # Room graph: dead ends, orphans, entrances
│   └── *_test.odin
├── models/                  # package models: parsed data structures
│   ├── area.odin            # Area and its header
│   ├── room.odin            # Rooms and exits
│   ├── mobile.odin          # NPC definitions
│   ├── object.odin          # Item definitions
│   ├── reset.odin           # Reset commands
│   ├── program.odin         # #IMPROGS / #SPECS bindings
│   └── types.odin           # Shared types (Direction, Dice, ...)
├── test_data/               # Real and hand-made .are files for tests
├── vendor/skald/            # Skald GUI library (git submodule)
└── CLAUDE.md                # This file
```

Dependency direction: `main` → `validation` → `formats` → `models`. Odin forbids cyclic
package imports, so `models` must not import `formats`.

## Area File Format

The source of truth is the Riftshadow loader, not the sample files:

- Section dispatch: `riftshadow/code/bootup.c` (around line 247)
- Section loaders: `riftshadow/code/db.c` (`load_area`, `load_rooms`,
  `load_newresets`, ...) and `riftshadow/code/db2.c` (`load_specs`, ...)
- Flag and direction names: `riftshadow/code/tables.c`

Area files live in `/Users/paulmcdowell/Documents/source/paul/riftshadow/area/`.
The files the game loads are listed in `area.lst` (terminated by `$`). Note:

- `area.lst` uses bare-CR line endings; some area files use CRLF.
- A few files contain Latin-1 bytes, so treat input as bytes, never UTF-8.
- `midgaard.are` is *not* in `area.lst`, but it is in Riftshadow's format and
  is a good reference (it is a test fixture).

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
- Many fields are read as a *letter* followed by a *word*, so the word is the
  rest of the keyword: `ROOM LAW` is `R` + `OOM` + `LAW`, and the object
  keyword `NAMEOFLOC` is compared as `AMEOFLOC`. Only the first letter
  decides the field, which is why `ITEM`, `APPLY` and `MSG` work.
- Room and object field letters are case-insensitive; mob trailer letters
  (`F A C B N L S T Y`) are case-sensitive.
- An object's item type is a case-insensitive *prefix* lookup in `item_table`
  order (`const.c`), and it decides how the five values are read. Unknown
  types read five flag values.
- `#IMPROGS` lines starting with `S` are skipped by the game; they have no
  effect (the parser records them so a validator can flag them).

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

Package `validation/` (`validate(areas, is_complete, allocator)`) checks a
*set* of areas, because exits and resets cross area boundaries. It returns
`[]Diagnostic` sorted by area, line and check. Every rule follows what the
game does; the code each is based on is noted below.

**Completeness rule**: a reference to a vnum that isn't loaded is an Error
when the whole `area.lst` is loaded (`is_complete`) or the vnum is inside a
loaded area's range; otherwise it is Info ("may be in an area that isn't
loaded"). This lets a single area be checked without false alarms.

| Check | Severity | Rule (game code) |
| --- | --- | --- |
| Broken_Exit | Error/Info | Exit to a missing room or negative vnum (`fix_exits`) |
| Mismatched_Return | Warning | A→B, but B's reverse exit leads elsewhere (disabled check in `fix_exits`) |
| One_Way_Exit | Info | A→B and B has no exit back to A in any direction |
| Replaced_Exit | Warning | Second `D` line for a direction; the first is lost (`load_rooms`) |
| Dead_End_Room | Warning | No way out; the game also sets NO_MOB (`fix_exits`) |
| Orphan_Room | Warning | No exit or portal leads in |
| Unreachable_Room | Warning (Info if unopened) | Not reachable from the area's entrances; whole world only |
| Area_Without_Entrance | Warning (Info if unopened) | No exit or portal from another area leads in; whole world only |
| Locked_Door_No_Key | Warning | Locked door with key < 0 (can't be unlocked) or 0 (`act_move.c`) |
| Missing_Key | Error/Info | Door's key object doesn't exist |
| Key_Never_Placed | Warning | Locked door's key exists but no reset places it |
| Door_Reset_No_Exit | Warning | `DOOR` reset where the room has no exit (`reset_room` ignores it) |
| Reset_Missing_Mob/Object/Room | Error/Info | Reset references a missing vnum (`reset_room` skips it) |
| Reset_Without_Mob | Warning | `EQUIP`/`GIVE`/`FOLLOW` with no earlier `MOB` in its room (skipped) |
| Reset_After_Object | Warning | `EQUIP`/`GIVE` after an `OBJ` into a *different* room than the last `MOB`, so it reaches another mob |
| Put_Into_Non_Container | Warning | `PUT` into an object whose item type isn't container |
| Portal_Missing_Target | Error/Info | Placed portal's destination (`value[3]`) is missing; -1 is random (`act_ente.c`) |
| Program_Missing_Target | Error/Info | `#IMPROGS`/`#SPECS` vnum doesn't exist |
| Ignored_Program_Line | Info | `S` line in `#IMPROGS` (`load_improgs` skips it) |
| Duplicate_Vnum | Error | Same vnum defined twice in a namespace (the game won't boot) |
| Vnum_Out_Of_Range | Warning | Record vnum outside its area's range |
| Bad_Area_Header | Warning | Backwards vnum or level range |

Calibration notes from the real data:

- Exits to vnum 0 are **look-only**: Riftshadow's area editor writes all six
  directions, and vnum 0 gives a direction a description without a way
  through (~9,700 of them). They are never reported and don't count as a way
  back.
- Most areas with no entrance are `unopened` on purpose, hence Info there.
- Rooms reached only by programs, recall or staff commands (e.g. midgaard's
  pet shop storage, 3032) are reported as orphans; that's accurate, if
  intended.
- The game has **deliberate mazes** (mismatched and one-way exits by design)
  and **areas reachable only by teleport** (orphan, unreachable or
  entrance-less on purpose). Do not weaken or suppress these checks to make
  them go away: surfacing them is the point, and the user decides in the
  visualizer which are intended. Intended findings are recorded as accepted,
  not removed from the validator.

The room graph's edges are exits to existing rooms plus portals placed by
`OBJ` resets. Self-loops are ignored.

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
./build.sh test     # Vet and run tests (see Testing)
./build/mudclarity path/to/area.lst   # Until the GUI exists: validate the whole world
./build/mudclarity file.are ...       # ...or just these files

# Manual
odin build . -collection:gui=./vendor/skald -debug -out:build/mudclarity

# Type-check only. Vet only our packages: vendor/skald does not pass -vet.
odin check . -collection:gui=./vendor/skald -vet -vet-style -vet-packages:main,formats,models,validation
```

### Dependencies

- **Odin**: `dev-2026-06` (pin upgrades deliberately; Odin's API still changes)
- **Skald**: git submodule at `vendor/skald` (`git submodule update --init`)
- **SDL3**: required at runtime by Skald (see `vendor/skald/PLATFORMS.md`)
- **Vulkan**: on macOS, the LunarG Vulkan SDK (provides MoltenVK); source its
  `setup-env.sh` before running

Build output goes to `build/` (gitignored).

## Testing

```bash
./build.sh test                     # vet our packages, then test formats and validation
RIFTSHADOW_AREA_DIR=/Users/paulmcdowell/Documents/source/paul/riftshadow/area \
    ./build.sh test                 # also parse and validate every area in area.lst

# Run selected tests
odin test formats -define:ODIN_TEST_NAMES=formats.test_room_basic_fields
odin test validation -define:ODIN_TEST_NAMES=validation.test_one_way_exit
```

Tests live next to the code as `<package>/*_test.odin`, so private
procedures are testable. The test runner tracks memory, so leaks fail a test.
Every change needs tests.

**Parser (`formats/`)**

- **Unit tests** (`reader_test`, `area_parser_test`, `mobile_parser_test`,
  `object_parser_test`, `area_list_test`, `area_set_test`, `loading_test`):
  small inline inputs built with `with_header(...)`; error tests check the
  kind *and* line.
- **Golden tests** (`golden_test`): real files in `test_data/valid/` embedded
  with `#load`. Expected counts were checked with `awk`/`grep`, not the parser.
- **Fuzz tests** (`fuzz_test`): every truncation and seeded random mutations
  of a fixture must parse or fail cleanly, never crash or hang.
- **Corpus test** (`corpus_test`): with `RIFTSHADOW_AREA_DIR` set, all of
  `area.lst` must parse within the performance budget.

**Validators (`validation/`)**

- **Per-check tests** (`exits_test`, `resets_test`, `reachability_test`):
  worlds built from helpers (`test_area`, `room`, `exit`, `mob`, `object`,
  `resets`). Each check has a case that triggers it and a near miss that must
  not; use `expect_one`/`expect_none`/`expect_clean`.
- **Golden tests** (`golden_test`): `clean_world.are` must produce nothing;
  midgaard's findings were each verified by hand against the file.
- **Robustness**: validation is deterministic and survives mutated areas.
- **Corpus test**: validates the whole world (< 500 ms) and logs counts.

When real data disagrees with a check, read the game code before changing
the rule, then add a test for the case (e.g. look-only exits, same-room
`OBJ` before `GIVE`).

`test_data/invalid/` holds files the parser must reject (e.g. the legacy ROM
`school.are`). `test_data/` files are Riftshadow areas (MIT licensed), except
the hand-written `clean_world.are`.

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

- [ ] `./build.sh test` passes (vets our packages; tests use `-vet -strict-style`)
- [ ] New or changed checks are calibrated against the corpus
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

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
├── mudclarity.odin          # Entry point (package main): GUI with no arguments, else the CLI
├── build.sh / build.bat     # Build scripts (macOS/Linux, Windows): run tools/build
├── tools/build/             # package build: the build script itself, in Odin
├── .gitattributes           # Line endings pinned per file type; area files untouched
├── app/                     # package app: the GUI (Elm root, screens, loading)
│   ├── app.odin             # run(paths): Skald wiring; debug leak report
│   ├── state.odin           # State, init, show_area; string ownership
│   ├── msg.odin             # Msg union and Effect union
│   ├── update.odin          # step (pure: State, Msg -> State, Effect) and update
│   ├── effects.odin         # Effect -> skald.Command; dialog and drop handlers
│   ├── world.odin           # World: workspace + layouts, marks, labels, room lookup, findings
│   ├── world_map.odin       # The area map's data: nodes, links between areas, positions
│   ├── inspector_data.odin  # Resolve the selected room's exits and findings for the inspector
│   ├── area_inspector_data.odin # The shown area's header, filtered findings and notes
│   ├── filters.odin         # Filters (severities, review states); marking rooms and areas
│   ├── filters_view.odin    # The Filters button and popover
│   ├── area_order.odin      # Area picker labels and order (by name, ignoring "The"/"A"/"An")
│   ├── search.odin          # Room search: the index and ranked matching
│   ├── settings_store.odin  # The settings file at run time; theme_for; save_settings
│   ├── settings_view.odin   # The Settings dialog, button and shortcut
│   ├── keys.odin            # Every keyboard shortcut, in one table; chord_text
│   ├── help_view.odin       # The Help dialog (F1, Ctrl+/, ?), listing the keys
│   ├── search_view.odin     # The search box and its results popover
│   ├── loading.odin         # load_world worker (cmd_thread)
│   ├── view.odin            # Root view; startup paths
│   ├── welcome_view.odin    # Screens, one file each
│   ├── world_view.odin
│   └── *_test.odin
├── components/              # package components: reusable GUI pieces
│   ├── common.odin          # heading, caption, stat, banner (generic over $Msg)
│   ├── text.odin            # display_text (Latin-1 file text), display_user_text (UTF-8 notes)
│   ├── graph_camera.odin    # Cells <-> graph <-> screen; zoom at cursor; fit
│   ├── room_graph.odin      # Room graph: state, Msg, update, view (input)
│   ├── room_graph_paint.odin # Painting rooms, exits and labels on the canvas
│   ├── room_graph_keys.odin # The room graph's keys (arrows follow exits)
│   ├── area_map.odin        # Area map: one circle per area, links between them
│   ├── area_map_paint.odin  # Painting the area map
│   ├── area_map_keys.odin   # The area map's keys (arrows pick the nearest area that way)
│   ├── canvas_gestures.odin # Press, pan and zoom shared by the map canvases
│   ├── room_inspector.odin  # Room inspector panel (generic over $Msg; see GUI structure)
│   ├── area_inspector.odin  # Area inspector panel: facts, findings, notes and a note box
│   ├── inspector_panel.odin # The inspectors' shared frame (panel, section, text width)
│   └── *_test.odin
├── layout/                  # package layout: room grid placement, no GUI code
│   ├── layout.odin          # Layout, Cell, Edge; compute / destroy / room_at
│   ├── place.odin           # Walk exits per component; links; vnum index
│   ├── island.odin          # Grow an island; fit it at the nearest free spot
│   ├── pack.odin            # Pack components side by side
│   ├── edges.odin           # Edges (straight/bent/vertical, two-way) and external exits
│   ├── force.odin           # Force-directed layout for small graphs (the area map)
│   └── *_test.odin
├── cli/                     # package cli: command-line commands
│   ├── cli.odin             # run(args, output) -> exit code; Output; shared helpers
│   ├── commands.odin        # COMMANDS table (also builds the usage text)
│   ├── check.odin           # check and its summary
│   ├── review.odin          # save, accept, flag, reopen
│   ├── records.odin         # note, issue
│   └── *_test.odin
├── workspace/               # package workspace: a loaded world, its findings and review file
│   ├── workspace.odin       # open_area_list / open_area_files / close
│   ├── review.odin          # Merge, finding lookup, review edits, save
│   ├── errors.odin          # Error union and error_message
│   └── *_test.odin
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
├── clarity/                 # package clarity: the .clarity review file
│   ├── document.odin        # Document format (JSON, version 1)
│   ├── io.odin              # Load (with checks) and atomic, sorted save
│   ├── hash.odin            # SHA-256 of area files
│   ├── review.odin          # Finding keys/ids; merge a run with the file
│   ├── edit.odin            # Reviews, issues, notes, refresh
│   └── *_test.odin
├── settings/                # package settings: the user's settings file (no GUI)
│   ├── settings.odin        # Settings, defaults, the names written to the file
│   ├── io.odin              # Path, load (never fails), save (atomic, keeps unknown keys)
│   └── *_test.odin
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
├── testkit/                 # package testkit: helpers imported only by *_test.odin
├── test_data/               # Real and hand-made .are files for tests
├── vendor/skald/            # Skald GUI library (git submodule)
├── .vscode/                 # Tasks, launch (debug) configs, recommended extensions
├── ols.json                 # Odin language server: the `gui` collection
└── CLAUDE.md                # This file
```

Dependency direction:

```text
main ─┬─ cli ─────────────────┐
      └─ app ─┬─ components ──┴─ workspace → clarity → validation → formats → models
              ├─ settings → clarity
              └─ layout → models
```

Odin forbids cyclic package imports, so a package never imports one to its
left (e.g. `models` must not import `formats`, `components` must not import
`app`). `workspace` holds everything the CLI and the GUI share, so neither
reimplements loading, review edits or saving. `layout` has no Skald import,
so it is tested like any other package.

`(planned)` packages don't exist yet; drop the marker when one lands.

## Area File Format

The source of truth is the Riftshadow loader, not the sample files. Paths
below assume Riftshadow is checked out next to this repository, at
`../riftshadow`:

- Section dispatch: `../riftshadow/code/bootup.c` (around line 247)
- Section loaders: `../riftshadow/code/db.c` (`load_area`, `load_rooms`,
  `load_newresets`, ...) and `../riftshadow/code/db2.c` (`load_specs`, ...)
- Flag and direction names: `../riftshadow/code/tables.c`

Area files live in `../riftshadow/area/`.
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

## Review File (`.clarity`)

One `area.clarity` per world, next to `area.lst`: pretty-printed JSON
(version 1) recording the files covered (SHA-256, size, counts), decisions on
findings, the user's issues and notes, and a snapshot of the last saved run.
It is the user's data: never drop entries you don't understand, and refuse
(don't overwrite) a newer `version`.

- **Finding key** = `(file, check, vnum, related_vnum)`, never the line, so
  decisions survive edits. Printed as an id: `mtcim.are:Mismatched_Return:218:219`.
- **States** when merged with a run: `Open` (no decision), `Accepted`
  (intended; hidden by default), `Flagged` (to fix), `Needs_Review` (decided,
  but the file's hash has changed since). A decision whose finding is gone
  is reported as *resolved*.
- **Snapshot** from the last `save`: findings not in it are *new*, entries
  no longer found are *fixed*.
- Names are stored as strings (checks, statuses, kinds `area|room|mob|object`).
  Every list is saved sorted, so an unchanged save is byte-identical and git
  diffs stay small. Saves go to a temp file and are renamed into place.

```bash
mudclarity save   area.lst                       # record files, hashes, snapshot
mudclarity accept area.lst <id> [note]           # intended (e.g. a deliberate maze)
mudclarity flag   area.lst <id> [note]           # confirmed problem
mudclarity reopen area.lst <id>
mudclarity note   area.lst <file> <kind> <vnum> <text>
mudclarity issue  area.lst <file> <kind> <vnum> <title>
```

`check` exits 1 only for parse failures or errors that aren't accepted.

## Settings File

`settings.json` in a `mudclarity` folder in the OS's per-user config
directory (`os.user_config_dir`: `%LOCALAPPDATA%` on Windows,
`~/Library/Application Support` on macOS, `$XDG_CONFIG_HOME` or
`~/.config` on Linux). Pretty-printed JSON with sorted keys:

```json
{
  "filters": {"severities": ["error", "warning", "info"], "states": ["open", "flagged", "needs_review"]},
  "format": "mudclarity-settings",
  "palette": "standard",
  "text_scale": 100,
  "theme": "system",
  "version": 1
}
```

- Choices are written as names, not numbers, so the file reads well and
  survives reordering an enum. `text_scale` is a percentage (75 to 200,
  in steps of 5; anything else is brought into range). The first files
  had a named `text_size` ("small" ... "largest"); it is read as the
  percentage it stood for and dropped on the next save.
- It is untrusted input, and reading it never fails: a missing file gives
  the defaults; an unreadable one (too large, not JSON, wrong format) gives
  the defaults and a warning for a banner, and is kept as
  `settings.json.bak` before the first save replaces it; a bad value
  resets only that setting and is named in the warning.
- Keys this version doesn't know (including inside `filters`) are kept
  when saving: the file is read as a raw JSON object and ours are written
  over it. A file from a newer `version` is read as far as possible and
  never saved over.
- Saves create the folder if needed and go to a temp file renamed into
  place, like `area.clarity`.
- In the GUI, `run` loads the file before the window opens (it is tiny)
  into a heap `Settings_Store` (`app/settings_store.odin`) that lives
  until the window closes; `init` starts from it (`init_with(store)`, so
  tests use stores of their own) and shows its warning in a banner.
  `State.settings` holds the current values. Every change goes through
  `change_settings`, which returns `Apply_Settings`: `command_for`
  restyles the app (`theme_for`) and saves on the GUI thread. A save
  refused because the file is newer stays quiet (the load warning said
  so); other failures show in the error banner.
- The **Settings dialog** (`app/settings_view.odin`) is a modal opened by
  the Settings button (Welcome and World headers) or Ctrl+, (Cmd+, on
  macOS). Changes apply at once, so it has only Close (or Escape). It says
  where the file is. Theme: follow the system, light, dark (with a chosen
  theme, the OS switching light/dark no longer changes it). Text size:
  a slider from 75% to 200% in 5% steps, with clickable marks every 25%
  and the value beside it; dragging only shows the value
  (`text_scale_draft`) and it is applied when the mouse is let go, since
  restyling mid-drag would move the slider under the pointer. Ctrl+= /
  Ctrl+- (Cmd on macOS) step it by 10% anywhere and Ctrl+0 resets it; a
  change refits both canvases. Colours: standard, or colour-blind
  friendly (`colour_blind` in `theme_for`), which replaces the theme's
  danger and warning colours so errors and warnings stay apart with
  protanopia, deuteranopia and tritanopia (picked by simulation; see its
  comment). Info and the selection are unchanged. `theme_for` builds the theme for the settings:
  the chosen or OS theme with the app's type sizes (`app_type`: small and
  body text a step above Skald's 13 and 14 px, since this app is mostly
  reading), then `scaled_theme` (fonts, spacing, radii),
  also when following an OS light/dark switch. The World toolbar is a
  `wrap_row`, so at large sizes it wraps instead of running off.
- Testing the GUI by hand changes the settings file: point
  `XDG_CONFIG_HOME` at a temp folder (Linux) so your own isn't touched.

## Visualization (Skald)

- Skald renders with **Vulkan + SDL3**, not raylib. Do not add raylib; draw the
  room graph with Skald's `canvas` widget (see `vendor/skald/examples/37_canvas`
  and `55_node_graph`).
- Skald uses an Elm architecture: `init` / `update` / `view` with a `Msg`
  union. Parse files off the UI thread with `cmd_thread`.
- `mudclarity` with no arguments opens the GUI; `mudclarity open <area.lst>`
  opens it on a world. Every other invocation is the CLI.
- **Layout**: area files have no coordinates. Rooms are placed on a grid by
  walking exits from a start room. MUD geometry is often inconsistent (two
  rooms claim the same cell, or an exit "east" leads to a room that is not
  east), so the layout must detect collisions and fall back gracefully.
  `up`/`down` exits need a separate visual treatment (e.g. z-levels).
  Layout lives in `layout/`, is computed once per load (never per frame) and
  is iterative, not recursive. Per area: cells are `(x, y, level)`; a room
  whose cell is taken starts an *island* that moves as a block to the
  nearest free spot, so a conflict bends one connection instead of
  cascading; exits that don't line up are `Bent` edges; disconnected
  components are packed apart. On the corpus (~10k rooms, ~15 ms) about 1%
  of rooms are displaced. Exits to vnum 0 are look-only and never edges.
- **Screens**: Welcome (open an `area.lst` or drop files; recent files are planned) and
  World: a header (the world's name, its folder cut short with "…" so
  Close stays in the window, Close), summary counts, a toolbar
  (Rooms/Areas switch, area picker, room search, filters) over the
  inspector (left), room graph or area map with their zoom buttons
  (center) and findings log (right, planned). Review actions (accept,
  flag, reopen, issue) are planned as dialogs.

### GUI structure

- **Components** (`components/`, one package) follow Skald's
  `examples/11_composed`: each has its own `X_State`, `X_Msg`, `x_update` and
  `x_view`, and `app` embeds it with `skald.map_msg`. Components never
  import or call each other.
- **Events go up, data comes down.** A component reports what happened
  (`Finding_Chosen{...}`) instead of changing other components; `app`'s
  `update` decides what follows (select the room, center the graph, show it
  in the inspector). Shared state such as the selection lives in `app` and is
  passed down to the components that show it.
- Small shared widgets (severity badge, section header, key/value row, empty
  state) live in `components/common.odin` and are generic over `$Msg`.
- **`map_msg` and deferred builders don't mix.** `map_msg` builds the
  component's `Ctx` on its own stack, but `scroll` with a zero size (and
  anything built through `sized`) is built later, during rendering, with a
  pointer to that `Ctx`: it crashes. A component that scrolls or uses
  `sized` is generic over the host's `$Msg` instead and takes callbacks for
  its events (the room inspector's `on_follow`). The room graph can use
  `map_msg` because its canvas keeps no `Ctx`.
- A zero-size `scroll` fills only a *flex* parent: wrap it in `flex(1, ...)`.
- **Build a dialog's or popover's content only while it is open.** Skald's
  `dialog(open = false)` discards its content, but the widgets were still
  built, so they still handled input, against `last_rect`s that an
  auto-id may share with a visible widget: a click near the search box
  once chose a text size in the closed Settings dialog. Return
  `dialog(ctx, false, spacer(0), ...)` while closed (it restores focus).
- **Colours that carry meaning** come from the theme: a severity's
  colour only through `components.severity_color` (danger, warning,
  muted text), the selection and accents from `primary`. Never hard-code
  them: the colour-blind palette is a change of theme colours, and the
  legend (#34) reads the same values.
- **Text size.** Fixed widths and heights (panels, popovers, dialogs,
  the picker) are written at the default text size and multiplied by
  `components.ui_scale(ctx.theme)` (body font size ÷ 14, Skald's own
  body size, so with `app_type`'s 15 px the panels are a little wider to
  match), which follows the Text size setting through the theme; canvases get it as
  `text_scale` in their data for labels. A new fixed size must do the
  same, or it won't grow with the text.
- Odin checks a generic proc's body only where it is instantiated, so a
  `$Msg` view's imports count as unused in the `components` test build.
  Do the work that needs other packages (`strings`, `filepath`, ...) in
  small non-generic helpers (see `area_inspector.odin`).
- Components draw into whichever window they're given, so a panel can later
  move into its own window (dispatch on `ctx.window`).
- `update` procs are pure (state and message in, state and command out) and
  get unit tests; views get headless smoke tests where useful (see Skald's
  `skald/table_hover_test.odin` for a GPU-less `Ctx`).
- Keep files short: aim for under ~300 lines and one component per file;
  split a component's painting from its interaction once it grows.

### GUI safety

- Loading and validation run in `cmd_thread` workers. Each load carries a
  generation number so results from a superseded load are dropped (and
  their workspace freed). Workers never assert or panic (that kills the
  process); errors come back as `Msg` variants with heap-allocated text.
- **Memory that crosses threads uses `runtime.heap_allocator()`**: request
  paths, workspaces, error text, and the `cmd_thread` command itself (Skald
  allocates its job there and frees it on the worker). The GUI thread's
  allocator is a tracking allocator in debug builds, so mixing the two is
  reported as leaks and bad frees. `close_workspace` closes under the heap.
- `update` calls `step`, which returns an `Effect` instead of a
  `skald.Command`; `command_for` turns it into one. Tests check effects
  without Skald allocating commands.
- Skald has no startup command, so the first `view` sends `Open_Paths` for
  `mudclarity open <path>`; opening bumps the generation, so it is sent once.
- Closing the window sends `Quit_Requested` (`on_close_request`), which
  frees the workspace before `cmd_quit`.
- A loaded `workspace` owns all its memory and is freed at once on unload.
  `Msg` strings live in the frame arena: clone them before keeping them.
  Debug builds use the tracking allocator.
- Area text is Latin-1 and untrusted; Skald draws UTF-8. Convert and strip
  control characters through one display helper before drawing any file
  text.
- The room graph draws only what is on screen and hit-tests through a
  spatial index, to keep 1000+ rooms smooth. Painting is one pass over the
  area's rooms and edges with nothing precomputed per frame: anything that
  needs more than that (which rooms lead up/down, each room's worst
  finding) is computed once, in `layout` or `World`.

### Area picker

- Entries read `Name (file)` (base name only, so loose files don't show
  their path) and are sorted by name: case-insensitive, a leading "The",
  "A" or "An" ignored (`SORT_ARTICLES`), ties by file name. An area without
  a name is shown and sorted by its file name, `social.are (no name)`.
- Areas keep their positions everywhere; only `World.picker` /
  `picker_labels` are in picker order. The first area shown after loading
  is the first in that order with rooms.

### Room inspector

- Left of the graph, 340 px wide, scrolling: vnum, name, area, sector and
  flags; the description reflowed to the panel (files pre-wrap at 80
  columns); exits with their targets (links; "look only" for vnum 0,
  "missing" in red, "in <area>" for other areas, door state and key);
  the room's findings with their review state; extra description keywords.
- Clicking an exit's target selects that room, switching area if needed,
  and the graph centres on it (`Focus_Room`, applied after the next fit if
  the graph hasn't been fitted yet).
- `app/inspector_data.odin` resolves everything from `World`
  (`rooms_by_vnum`, `room_findings`), so the component only displays data.

### Room graph

- One area and one level at a time. Rooms are boxes outlined by their
  worst finding that the filters show (red error, amber warning, muted info;
  only `validation.ROOM_CHECKS` count), thicker in the accent colour when
  selected; a dot marks a displaced room. Exits: straight corridors, bent
  curves (translucent amber), arrowheads on one-way exits, up/down
  triangles on rooms with exits to other levels, and stubs for exits that
  leave the area.
- Drag empty space to pan, scroll to zoom at the cursor, click a room to
  select it (reported to `app` as `Room_Clicked`); Up/Down change level,
  − and + zoom about the canvas centre (`zoom_buttons`, shared with the
  area map) and Fit refits. Labels appear only when zoomed in enough to
  read. The hint beside the buttons is cut short with "…" (`hint`), so a
  narrow window never makes the canvas wider than it. Labels follow the
  text size; a vnum label shrinks to fit its box if needed.
- **Keyboard** (while the canvas has focus: Tab to it, or click it; a
  ring in the accent colour shows it): arrows follow the selected room's
  west/north/east/south exit, Page Up/Down its up/down exit (or change
  level if it has none), reported as `Exit_Key` for `app` to resolve
  (`follow_exit_key`, across areas too); with nothing selected an arrow
  selects the room nearest the middle. Shift+arrows pan, `+` `-` zoom
  about the centre, `0` fits (`canvas_keys`, shared with the area map),
  Escape deselects (`Room_Deselected`). The list is `ROOM_GRAPH_KEYS`.
- **Click away**: a press on empty space starts a pan; `pan_distance`
  sums its travel, and if it ends under `CLICK_SLOP` (4 px) `app` treats
  it as a click and deselects (#46). A real drag keeps the selection.
- A newly shown area fits itself once the canvas has a size. Skald redraws
  only on events, so a load returns `Redraw_Soon` to get that frame.
- Paint gets theme colours through `Room_Graph_Data.colors` (the painter has
  no `Ctx`); `draw_text` takes the *baseline*, and its `size` is the cap
  height.

### Filters

- The toolbar's Filters popover has a box per severity and per review
  state; Reset goes back to `DEFAULT_FILTERS` (everything but accepted
  findings), and the button reads "Filters (changed)" otherwise. Escape,
  Done or a click elsewhere closes it.
- The filters are a setting (`settings.Filters`, two bit sets; `app`
  aliases it as `Filters`), kept in `State.settings.filters` and so
  remembered between runs. Changing them runs `apply_filters`, which
  re-marks the open world's rooms and areas in place (a pass over the
  findings), and `change_settings`, which saves them; a newly loaded world
  is marked with the filters in use. The room graph,
  the area map and the area inspector's counts all follow it; the room
  inspector still lists every finding of the room, with its state.

### Keyboard

- Everything should work without a mouse (#48). **Every binding is in
  `key_bindings` (`app/keys.odin`)**, which the Help dialog lists by
  where it works. Chords the app registers (`SETTINGS_SHORTCUT`,
  `HELP_SHORTCUTS`, the text size keys) are constants used both to
  register them and in the table, and `keys_test` checks each registered
  chord is listed: add a key to both, or the test fails. `chord_text`
  writes a chord as the platform does (Ctrl, or Cmd on macOS).
- **Help**: F1, Ctrl+/ (Cmd+/), or `?` outside a text box, plus a Help
  button beside Settings. Skald only reports typed text while a text box
  has focus, so `?` is matched as Shift+/ (`HELP_CHARACTER_SHORTCUT`)
  and, when text does arrive, as the character; neither fires while
  typing (`skald.is_typing`). One dialog at a time: opening Help closes
  Settings and the other way round.
- Shortcuts are registered at the top of `view`, before other widgets,
  so they win over widgets built later.
- A component with keys of its own lists them as `Key_Hint`s
  (`ROOM_GRAPH_KEYS`), and `key_bindings` adds them under their scope.

### Room search

- The toolbar's search box finds rooms across the world by vnum (`3001`,
  `#3001`) or name, ignoring case. `World.search_index` (picker order,
  lower-cased display names) is built once per load; `step` searches it
  when the query changes (`set_search`), never `view` (~0.2 ms for the
  whole world). Ranked: the vnum in every area that defines it, then names
  equal to the query, starting with it, and containing it. The best
  `SEARCH_LIMIT` show in a popover with a count of the rest.
- **Keys**: `/` (when not typing) or Ctrl+F (Cmd+F) jump to the box
  (`search_shortcuts`, which focuses it directly; `SEARCH_SHORTCUTS`).
  In the box, Up and Down move a highlight through the results
  (`search_highlight`, reset by a new query) and Enter chooses it; they
  are taken from `keys_pressed` before the text box sees them.
- Choosing a result goes to the room (`go_to_room`, shared with following
  an exit): switch to the room graph and to the room's area, select it,
  centre on it. Escape or the clear button empties the box; a new world
  or Close clears it.
- The popover publishes its rect (`widget_stamp_overlay_rect`), and the
  canvases ignore presses under any open popover (`mouse_over_overlay` in
  `canvas_gestures`), so a click on a result (or a dropdown entry) never
  also lands on the map beneath.

### Area map

- The Rooms/Areas switch in the toolbar (`State.center`) shows the map of
  every area in place of the room graph; the inspector stays. Each area is
  a circle sized by its rooms and outlined by its worst finding that the
  filters show (any check, not just room checks); unopened areas are faint and
  the area the room graph shows has an accent ring. Lines join areas that
  exits or placed portals connect: thicker for more, accent colour when
  portals are the only link, an arrowhead when they go one way only.
- Clicking an area selects it, as picking it does (the ring and picker
  follow); double-clicking opens its room graph (afresh if it's another
  area). Following an exit in the inspector also goes back to the room
  graph.
  The map keeps its camera while hidden; a new world refits it.
- While the map is up, the left panel is the **area inspector** for the
  area shown: file, name, rooms, levels, vnums, type, climate, the
  findings the filters show, credits, builders, an Open rooms button, and the area's notes
  (`kind = "area"`, vnum 0, as `mudclarity note` writes them) with a box
  to add one. Adding edits the review document in `step` and returns
  `Save_Review`; `command_for` saves on the GUI thread (the file is a few
  hundred KB, and the document must not change while a worker writes it)
  and reports failure as `Review_Saved`. Loose files have no review file,
  so the box is replaced by a hint to open the `area.lst`. A draft is
  dropped when another area is shown.
- Notes are UTF-8 typed by the user (or edited by hand), so they are drawn
  through `display_user_text`, not `display_text` (which is for Latin-1).
- **Keyboard** (canvas focused, with the same ring as the room graph):
  arrows select the nearest area that way (`area_in_direction`: within
  45°, else anywhere on that side), sent as `Area_Clicked`, and pan it to
  the middle if it is off screen or at the edge; Enter opens it
  (`Area_Opened`); Shift+arrows, `+` `-` `0` as on the room graph. The
  list is `AREA_MAP_KEYS`.
- `World.area_map` (`app/world_map.odin`) is built once per load; the view
  only fills in the camera and the current area. Positions come from
  `layout.force_layout`, which lays out each connected group on its own and
  packs the groups in rows, so areas without links don't drift away.

## Build & Development

Mud Clarity is developed on Windows, macOS and Linux. `build.sh` (macOS,
Linux) and `build.bat` (Windows) only run `tools/build/build.odin`, which
holds every command and flag; change the build there, never in the
wrappers. The examples use `./build.sh`; on Windows use `build.bat` and
`build\mudclarity.exe`.

```bash
./build.sh          # Debug build to build/mudclarity
./build.sh run [args]   # Build and run (args go to mudclarity)
./build.sh test     # Vet, cross-OS type-check, and run tests (see Testing)
./build.sh debug-tests [name]         # Test binaries for a debugger (see VS Code)
./build.sh help     # The build commands
./build/mudclarity                    # Open the GUI
./build/mudclarity open path/to/area.lst   # Open the GUI on a world
./build/mudclarity path/to/area.lst   # CLI: validate the whole world
./build/mudclarity file.are ...       # ...or just these files
./build/mudclarity help               # Usage, including the review commands below

# Manual
odin build . -collection:gui=./vendor/skald -debug -out:build/mudclarity

# Type-check only. Vet only our packages: vendor/skald does not pass -vet.
odin check . -collection:gui=./vendor/skald -vet -vet-style -vet-packages:main,formats,models,validation,clarity,settings,workspace,cli,layout,components,app
```

`-strict-style` applies to every package compiled, Skald included, so tests
of packages that import Skald (`app`, `components`) use `-vet-style` with
`-vet-packages` instead (see `style_flags` in `tools/build/build.odin`).

`test` also type-checks the program for macOS (arm64, amd64) and Linux
(amd64, arm64) whatever the host, so platform-specific mistakes show up on
any machine. `odin check` can only target Windows from Windows (it needs the
Windows SDK), so Windows is covered when `test` runs there.

### Cross-platform rules

- Paths go through `core:path/filepath` (`join`, `dir`, `base`, `ext`);
  never build them with `/` or `\`. Odin accepts `/` in its own flags.
- File extensions are compared ignoring case (`workspace.is_area_list`,
  `workspace.is_area_file`): `AREA.LST` is common on Windows.
- Executables get `.exe` on Windows (`EXE` in the build tool; `windows`
  overrides in `.vscode/launch.json`).
- No shell-specific logic outside `build.sh`/`build.bat`, which stay thin.
  VS Code tasks pass `args` arrays so each OS's shell quotes them.
- Line endings are pinned in `.gitattributes`: sources LF, `.bat` CRLF, and
  area files (`test_data/`, `*.are`, `*.lst`) are never converted, since
  their bytes and hashes are part of the tests.
- Text from files is bytes, never assumed UTF-8 (see `display_text`).

### Dependencies

- **Odin**: `dev-2026-10` or newer (Odin's API still changes, so report
  breakage on newer releases rather than pinning an old one)
- **Skald**: git submodule at `vendor/skald` (`git submodule update --init`)
- **SDL3** and **Vulkan** at runtime (details: `vendor/skald/PLATFORMS.md`):
  - **Windows**: Visual Studio Build Tools (MSVC + Windows SDK); build from a
    Developer Command Prompt or PowerShell so the linker is found.
    `SDL3.dll` ships with Odin (`vendor\sdl3`) and the build tool copies it
    into `build\`. The Vulkan loader comes with GPU drivers.
  - **macOS**: the LunarG Vulkan SDK (provides MoltenVK); source its
    `setup-env.sh` before running. Odin's SDL3 and STB come prebuilt.
  - **Linux**: SDL3 (e.g. `sdl3` / `libsdl3-dev`) and a Vulkan loader and
    driver from the distro. Odin's STB libraries must be built once per
    Odin install: `$ODIN_ROOT/vendor/stb/src/build_stb.sh` (needs write
    access to the Odin install, so often `sudo`). Skald's docs say this is
    only needed for the fontstash backend and suggest `make`; both are out
    of date: `vendor:stb/image` is always used.

Build output goes to `build/` (gitignored).

### VS Code

Recommended extensions (`.vscode/extensions.json`): OLS (`danielgavin.ols`)
for the language server and CodeLLDB (`vadimcn.vscode-lldb`) for debugging.
Every task calls `build.sh`, or `build.bat` on Windows, so flags are only
ever changed in `tools/build`. Launch configurations use `.exe` paths on
Windows; CodeLLDB works on all three OSes.

- **Build** (Ctrl+Shift+B) is `./build.sh`; **Run Test Task** offers `test`
  (the default), `test (with corpus)` (uses `../riftshadow/area`) and
  `test (one)`, which prompts for `<package>.<test>`. Compiler, vet and
  test failures show up in the Problems panel.
- **Run and Debug** configurations (F5 to debug, Ctrl+F5 to run without the
  debugger): `mudclarity: GUI` (the default), `mudclarity: GUI on the world`,
  `mudclarity: check the world`, `mudclarity: custom arguments` (prompts for
  a command line), `tests: debug a package` and `tests: debug one test`.
- Test binaries for debugging come from `./build.sh debug-tests`. They run
  tests on one thread so breakpoints hit in order. `ODIN_TEST_NAMES` is a
  compile-time setting, so debugging one test rebuilds it on its own.

## Testing

```bash
./build.sh test                     # vet our packages, then run every package's tests
RIFTSHADOW_AREA_DIR=../riftshadow/area \
    ./build.sh test                 # also parse and validate every area in area.lst

# Run one test (<package>.<test>)
./build.sh test formats.test_room_basic_fields
./build.sh test validation.test_one_way_exit
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

**Review file (`clarity/`)**

- Round trip is byte-identical; load errors (bad JSON, format, version,
  names, enum values, duplicate issue ids) are each tested; saves are atomic.
- Merge states, snapshot new/fixed, added/removed/changed files, and edits
  use small worlds from `world_make(...)`.
- Corpus test saves and reloads a review of the whole world in a temp dir.

**Settings (`settings/`)**

- Round trip is byte-identical; missing keys use the defaults; a bad value
  resets only its setting and is named; unreadable files (empty, not JSON,
  wrong root, format or version, too large) give the defaults; unknown
  keys survive a save; newer files are read and refused for saving;
  saving creates the folder; an unreadable file is backed up once;
  `text_scale` is clamped onto steps and a non-number reported; old
  `text_size` names are read as percentages and dropped on save.

Helpers several test suites need (`area_text`, `BASE_ROOMS`, `temp_dir`,
`write_world`, ...) live in `testkit/`; a suite's own helpers stay in its
`helpers_test.odin`.

**CLI (`cli/`)**

- `run_cli(args...)` runs a command line with output captured in string
  builders; tests check exit codes and exact messages, and read the saved
  `area.clarity` back. A refused edit must not write the file.
- Adding a command means adding it to `COMMANDS`; the usage and
  missing-argument messages come from the table.

**GUI (`app/`, `components/`)**

- `step` is tested message by message; effects are checked as values.
  `load_now` runs the real `load_world` worker synchronously on a world from
  `testkit`. State is freed with `finish(s)` (a quit), so the tracking
  allocator catches leaked strings. Workspaces live on the plain heap by
  design, so a leaked workspace is *not* caught by the test runner.
- `inspector_data` (exit targets, other areas, missing and look-only exits,
  findings) and following exits within and across areas (`inspector_test`).
- `room_graph_update`, `room_at_point`, `level_bounds` and the camera maths
  (`graph_camera_test`) are tested without drawing; `World`'s layouts and
  room marks (including accepted findings not marking) in `world_test`.
- `area_map_update`, `area_at_point` and `map_bounds` (`area_map_test`);
  the area map's names, links (exits both ways, portals, look-only and
  same-area exits left out), positions and marks in `world_map_test`.
- Switching between the room graph and the area map, selecting
  (click) and opening (double-click) an area, following an exit from the
  map, and a new world resetting both
  (`center_test`).
- Area notes (`area_notes_test`): the inspector's data, adding a note
  (blank drafts add nothing; the saved file is read back), a draft dropped
  with its area, loose files refused, and a failed save shown.
- Settings in the GUI (`settings_test`): starting from a store and its
  warning, choosing a theme (applied and saved once; the same choice does
  nothing), only a followed system theme tracking the OS, `theme_for`,
  `save_settings` (written, newer file left alone, no store or folder),
  and a failed save shown.
- Text size (`text_scale_test`, `components/common_test`): `scaled_theme`
  (fonts, spacing, radii; pills and colours unchanged), `app_type`,
  `theme_for` and `ui_scale` across the range (and out of it),
  `next_text_scale` at the ends, choosing a size, dragging (shown, then
  applied on release, with both canvases refitted), and an OS light/dark
  switch keeping it.
- Palette (`palette_test`, `components/common_test`): the colour-blind
  colours for light and dark backgrounds (nothing else changed),
  `theme_for` applying them, choosing a palette, and `severity_color`
  following the theme.
- Room keys (`room_keys_test`, `room_graph_test`): arrows following
  exits (staying put without one), up/down changing level, into another
  area and back, Page keys changing level without an exit, Escape and a
  click away deselecting while a drag doesn't, the keys listed in Help,
  `pan_distance`, and `room_nearest_middle` per level; the area map's
  keys listed, and `area_in_direction` (cone, side, nothing that way).
- Keys (`keys_test`): every chord the app registers is in the table,
  every binding has keys and an action and every scope has bindings,
  `chord_text` for the platform, and Help and Settings taking turns.
- Filters (`filters_test`): `shows`, re-marking rooms and areas and the
  inspector's counts as boxes change, Reset, accepted findings shown on
  request, filters kept across a reload, changes with no world open,
  filter changes saved as settings (and no-op changes not), and saved
  filters marking a newly loaded world.
- Room search (`search_test`): ranking (vnum, exact, prefix, contains),
  `#` and spaces, duplicate vnums across areas, the limit and total, blank
  queries, Latin-1 names and picker order in the index, and searching and
  choosing a result in `step` (from the map, out of range, cleared by a
  reload).
- Corpus test (`app/corpus_test`) opens the whole world as the loading
  thread does (< 3 s), times the area map on its own (< 250 ms) and a
  one-letter search over every room (< 10 ms).
- `display_text` is tested on Latin-1, control and C1 bytes, newlines,
  length limits, and every byte value producing valid UTF-8;
  `display_user_text` on UTF-8, invalid and cut-off sequences, controls,
  and every byte pair.
- Check the window itself by running it (see VS Code, or `xdotool` plus
  `import -window <id>` to screenshot only the app's own window).

**Layout (`layout/`)**

- Areas are built in memory with `room(vnum, {.East, 101}, ...)` and
  `area_of(...)`; no parsing. `expect_valid` checks the invariants every
  layout must meet (each room on its own cell, inside its component, no
  overlapping components, edge kinds matching the geometry).
- Seeded random areas and the corpus must stay valid; corpus layout of the
  whole world < 250 ms.

**Workspace (`workspace/`)**

- Worlds are written to a temp dir with `write_world(...)` and opened like
  the CLI does. Each open and edit error kind is tested, including the
  exact message; strings passed to edits must survive the caller freeing
  theirs.
- Corpus test opens the whole world through a workspace (< 2.5 s).

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

- [ ] `./build.sh test` (or `build.bat test`) passes: vet, cross-OS checks, tests
- [ ] Nothing OS-specific outside `tools/build` (see Cross-platform rules)
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

- Riftshadow source: `../riftshadow/code/`
- Odin docs: <https://odin-lang.org/docs/>
- Skald: `vendor/skald/README.md`, `vendor/skald/docs/`,
  `vendor/skald/examples/`

---

**Last Updated**: 2026-10-23  
**Maintainer**: Paul McDowell

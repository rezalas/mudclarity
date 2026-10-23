# Mud Clarity - Project Harness & Conventions

**Project**: Mud Clarity - MUD Area File Visualizer  
**Language**: Odin  
**License**: MIT  
**Author**: Paul McDowell  
**Created**: 2026

## Overview

Mud Clarity is a secure, high-quality Odin-based visualizer for MUD (Multi-User Dungeon) area files using the classic LPC format (late 90s/early 2000s). The application parses `.are` files from Riftshadow and other compatible MUDs, visualizes room layouts and connections, detects errors, and identifies issues such as dead zones and broken linkage.

## Project Architecture

```
mudclarity/
├── mudclarity.odin          # Main entry point
├── build.sh                 # Build script
├── formats/                 # Area file format parsers
│   ├── area_parser.odin     # Main parser orchestration
│   ├── lexer.odin           # Tokenizer for .are files
│   └── validators.odin      # Format validation rules
├── models/                  # Data models for parsed structures
│   ├── area.odin            # Area metadata
│   ├── room.odin            # Room definitions with exits
│   ├── mobile.odin          # NPC/creature definitions
│   ├── object.odin          # Item definitions
│   ├── reset.odin           # Spawn commands
│   └── types.odin           # Shared type definitions
├── vendor/skald/            # Skald GUI library (submodule)
└── Claude.md                # This file
```

## Coding Standards

### Odin Conventions

1. **Package & Imports**
   - Each file belongs to `package main` or a named package (e.g., `package models`, `package formats`)
   - Imports at top, organized in groups: core → vendor → local
   - Use fully qualified imports; avoid `using` except in specific scopes

2. **Naming**
   - `Type_Names` - PascalCase with underscores (Odin convention)
   - `procedure_names` - snake_case
   - `CONSTANT_VALUES` - UPPER_CASE
   - `variable_names` - snake_case
   - Prefix boolean fields with `is_`, `has_`, `can_`

3. **Comments**
   - Line comments: `//` for code explanation
   - Block comments: `/* */` for multi-line context
   - Every public procedure should have a doc comment:
     ```odin
     // Parse an area file from the given file path.
     // Returns Area structure or error if parsing fails.
     parse_area_file :: proc(file_path: string) -> (Area, ParseError) {
     ```

4. **Error Handling**
   - Use tagged unions or explicit error returns: `(T, Error_Type)` tuples
   - Define error enums for domain-specific errors
   - Always check error returns; avoid silent failures
   - Provide context in error messages (file, line, reason)

5. **Memory Management**
   - Prefer stack allocation where possible
   - Use allocators explicitly: `context.allocator`
   - Clean up dynamically allocated memory in cleanup procedures
   - Document ownership: who allocates, who frees

6. **Bounds & Security**
   - Array access: always bounds-check before indexing
   - String parsing: validate lengths and positions
   - File paths: prevent directory traversal attacks
   - Numeric parsing: validate ranges before converting
   - Use `assert()` in debug builds for invariants

## Format & Models Architecture

### formats/ - Area File Parsing

**Responsibility**: Tokenize and parse `.are` file format into structured data.

**Key Files**:
- `lexer.odin` - Tokenize raw file content into tokens
- `area_parser.odin` - Main parser orchestrating section parsing
- `validators.odin` - Validation rules (vnum ranges, required fields, etc.)

**Parsing Pipeline**:
```
File → Lexer (tokens) → Parser (AST) → Validators → Models
```

**Key Procedures**:
- `tokenize(data: []u8) -> ([]Token, Lexer_Error)`
- `parse_area_section(tokens: []Token) -> (Area_Metadata, Parse_Error)`
- `parse_mobiles_section(tokens: []Token) -> ([]Mobile, Parse_Error)`
- `parse_rooms_section(tokens: []Token) -> ([]Room, Parse_Error)`
- `parse_resets_section(tokens: []Token) -> ([]Reset_Command, Parse_Error)`

**Error Strategy**:
- Lexer errors: character position, reason
- Parser errors: section, line number, context
- Validator errors: vnum, field name, constraint violation

### models/ - Data Structures

**Responsibility**: Define in-memory representations of parsed MUD structures.

**Key Files**:
- `types.odin` - Shared constants and base types
- `area.odin` - Area metadata container
- `room.odin` - Room with exits and descriptions
- `mobile.odin` - NPC/creature stats and equipment
- `object.odin` - Item definitions
- `reset.odin` - Reset command types

**Design Principles**:
- Immutable after construction where possible
- Separate data (fields) from computed views (methods)
- Use slices for collections, not arrays (flexibility)
- Document field ranges and constraints as comments

**Example Structure**:
```odin
Room :: struct {
    vnum:        int,           // Virtual number (unique in area)
    name:        string,        // Short title
    description: string,        // Long description
    zone:        string,        // Area/zone name
    flags:       Bit_Set,       // Room flags (indoors, dark, etc.)
    exits:       [dynamic]Exit, // Exits to other rooms
    // Computed views below
}

Exit :: struct {
    direction: Direction,  // NORTH, SOUTH, EAST, WEST, UP, DOWN
    target:    int,        // Target room vnum
    door_flag: int,        // -1 (no door), 0 (open), 1+ (door state)
    key:       int,        // Key vnum if locked, -1 if no key
}
```

## Build & Development

### Building

```bash
# Debug build with symbols
./build.sh

# Run after build
./build.sh run

# Manual build
cd mudclarity
odin build . \
    -collection:gui="./vendor/skald" \
    -debug \
    -out:build/mudclarity
```

### Dependencies
- **Odin**: Latest stable (2026.x)
- **Skald**: Git submodule in `vendor/skald/` (UI framework)
- **raylib**: Built into Odin core library

### File Organization

- All source code in root or `formats/`/`models/` folders
- Build output: `build/` directory (gitignored)
- No binary artifacts in version control

## Testing & Validation

### Test Files (Future)

```
test_data/
├── valid/
│   ├── small_area.are      # Minimal valid area
│   └── complete_area.are   # Full-featured area
├── invalid/
│   ├── missing_section.are # Missing required section
│   ├── bad_vnum.are        # Invalid room vnum
│   └── broken_links.are    # Rooms referencing non-existent exits
```

### Validation Strategy
1. **Format validation**: Lexer catches syntax errors
2. **Structure validation**: Parser ensures required sections exist
3. **Semantic validation**: Validators check constraints (vnum ranges, room links exist)
4. **Visualization validation**: GUI detects and highlights errors

## Security Considerations

### File Input
- [ ] Validate file path (no `..` or absolute paths outside project)
- [ ] Limit file size to prevent DoS (e.g., max 10 MB per file)
- [ ] Validate all numeric fields to prevent integer overflow
- [ ] String lengths bounded to prevent buffer exhaustion
- [ ] XML/HTML chars in descriptions escaped before display

### Parsing
- [ ] Fail fast on malformed input
- [ ] Provide clear error messages without leaking internals
- [ ] No arbitrary code execution or eval semantics
- [ ] Bounded recursion depth if parsing nested structures

### Memory
- [ ] All allocations tracked and freed
- [ ] No use-after-free or buffer overruns
- [ ] Stack depth validated (no unbounded recursion)

## Visualization (Skald & raylib)

### GUI Architecture (TBD)
- Main window: Room/area network visualization
- Left panel: Room inspector (details, exits, mobs)
- Right panel: Error/validation log
- Toolbar: Load file, zoom, search, filters

### Rendering
- Use Skald for UI framework (windows, panels, buttons)
- Use raylib for 2D/3D visualization (room graphs, connections)
- Color scheme: Distinct colors for room types, errors, mob spawn zones

## Quality & Code Review Standards

### Peer Review Checklist
- [ ] Code compiles without warnings
- [ ] Follows naming and style conventions
- [ ] Error handling is complete (no silent failures)
- [ ] Bounds checking on all array/string access
- [ ] Comments explain non-obvious logic
- [ ] No security vulnerabilities (path traversal, overflow, etc.)
- [ ] Test data provided for parsers (valid + invalid cases)

### Performance Targets
- Parse 1 MB area file in < 100 ms
- Display 1000+ rooms without visible lag
- Memory overhead < 5x raw file size after parsing

## Development Workflow

### Starting New Work
1. Review Claude.md (this file) - ensure familiarity with conventions
2. Identify feature/fix scope
3. Create focused task (parsing single section, adding data structure, etc.)
4. Implement with test data
5. Self-review against checklist above
6. Commit with clear message

### Commit Messages
- Format: `[scope] Brief description`
- Examples:
  - `[formats] Add mobile section parser with error handling`
  - `[models] Define Room struct with exit tracking`
  - `[gui] Add room inspector panel`

### Branch Strategy (if using git branches)
- `main` - stable, tested code
- `feature/foo` - work in progress
- `fix/bar` - bugfixes

## Resources

### MUD Area File Format
- Format analyzed from: `/Users/paulmcdowell/Documents/source/paul/riftshadow/area/`
- Key sections: #AREA, #MOBILES, #OBJECTS, #ROOMS, #RESETS, #SHOPS, #SPECIALS
- Reference implementation: school.are (2181 lines), midgaard.are (larger, complex)

### Odin Documentation
- [Odin Official Docs](https://odin-lang.org/)
- [Odin Book](https://odin-lang.org/docs/)
- Built-in packages: `core:*`, `vendor:*`

### Skald GUI
- Located: `vendor/skald/`
- Examples: `vendor/skald/examples/`
- Collection flag in build: `-collection:gui="./vendor/skald"`

## License & Attribution

All code in Mud Clarity is MIT licensed. Preserve license headers in files:

```odin
/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
```

---

**Last Updated**: 2026-10-23  
**Maintainer**: Paul McDowell

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package clarity

import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:testing"

import "../formats"
import "../models"
import "../validation"

// Shared helpers for the clarity tests.

TEST_DATE :: "2026-10-23"

// An area named `name` (vnums 100-199) with the given #ROOMS records.
area_text :: proc(name, room_records: string) -> string {
	return fmt.tprintf("#AREA\n%s~\n%s~\nTester~\n1 50\n100 199\nnormal\ntemperate\n0\n1\nNone~\n#ROOMS\n%s#0\n#$\n", name, name, room_records)
}

// Room 100 <-> 101, a broken exit 100 -> 150, and an isolated room 102.
// Findings: Broken_Exit (100, 150), Orphan_Room (102), Dead_End_Room (102).
BASE_ROOMS :: "#100\nA~\n~\ncity\nD NORTH 101 0 0\n~\n~\nD EAST 150 0 0\n~\n~\nS\n#101\nB~\n~\ncity\nD SOUTH 100 0 0\n~\n~\nS\n#102\nC~\n~\ncity\nS\n"

// A world of parsed areas plus their names and hashes, as the CLI builds it.
Test_World :: struct {
	loaded:      [dynamic]^formats.Loaded_Area,
	areas:       [dynamic]^models.Area,
	names:       [dynamic]string,
	hashes:      [dynamic]string,
	diagnostics: []validation.Diagnostic,
}

// Parse and validate `texts` (named "a.are", "b.are", ...). Free with world_destroy.
world_make :: proc(t: ^testing.T, texts: ..string, loc := #caller_location) -> Test_World {
	w: Test_World
	w.loaded = make([dynamic]^formats.Loaded_Area, context.temp_allocator)
	w.areas = make([dynamic]^models.Area, context.temp_allocator)
	w.names = make([dynamic]string, context.temp_allocator)
	w.hashes = make([dynamic]string, context.temp_allocator)
	for text, i in texts {
		name := fmt.tprintf("%c.are", 'a' + i)
		loaded, err := formats.load_area_bytes(transmute([]u8)text, name)
		if err != nil {
			testing.expectf(t, false, "%s", formats.parse_error_to_string(err, name, context.temp_allocator), loc = loc)
			continue
		}
		append(&w.loaded, loaded)
		append(&w.areas, &loaded.area)
		append(&w.names, name)
		append(&w.hashes, sha256_hex(loaded.data, context.temp_allocator))
	}
	w.diagnostics = validation.validate(w.areas[:], false, context.temp_allocator)
	return w
}

world_destroy :: proc(w: ^Test_World) {
	for l in w.loaded {
		formats.unload_area(l)
	}
}

// File entries for the world's areas, in area order.
world_files :: proc(w: ^Test_World) -> []File_Entry {
	files := make([]File_Entry, len(w.loaded), context.temp_allocator)
	for l, i in w.loaded {
		files[i] = file_entry_for(w.names[i], l, context.temp_allocator)
	}
	return files
}

world_merge :: proc(w: ^Test_World, doc: ^Document) -> Review_Result {
	return merge(doc, w.names[:], w.hashes[:], w.diagnostics, context.temp_allocator)
}

// The finding with `check` in a merge result, or fail the test.
finding :: proc(t: ^testing.T, result: Review_Result, check: validation.Check, loc := #caller_location) -> Reviewed_Finding {
	for f in result.findings {
		if f.diagnostic.check == check {
			return f
		}
	}
	testing.expectf(t, false, "no %v finding", check, loc = loc)
	return {}
}

// An arena for a test's documents; destroy it at the end of the test.
test_arena :: proc(arena: ^virtual.Arena) -> virtual.Allocator_Error {
	return virtual.arena_init_growing(arena)
}

// A fresh, empty temporary directory named `name` (tests run in parallel,
// so each needs its own name).
temp_dir :: proc(t: ^testing.T, name: string) -> string {
	base, _ := os.temp_directory(context.temp_allocator)
	dir, _ := filepath.join({base, name}, context.temp_allocator)
	_ = os.remove_all(dir)
	testing.expect(t, os.make_directory(dir) == nil)
	return dir
}

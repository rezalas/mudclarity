/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package clarity

import "core:fmt"
import "core:mem/virtual"
import "core:testing"

import "../formats"
import "../models"
import "../validation"

// Shared helpers for the clarity tests.

TEST_DATE :: "2026-10-23"

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


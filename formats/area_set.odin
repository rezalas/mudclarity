/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "base:runtime"
import "core:path/filepath"

import "../models"

// An area file that could not be loaded.
Area_Load_Failure :: struct {
	name:  string, // Entry from area.lst
	error: Parse_Error,
}

// Every area listed in an area.lst. Files that fail to parse are recorded in
// `failures` and the rest still load, so the others can be validated.
Area_Set :: struct {
	loaded:    [dynamic]^Loaded_Area,
	failures:  [dynamic]Area_Load_Failure,
	list_data: []u8, // area.lst contents; area and failure names point into it
	allocator: runtime.Allocator,
}

// Load every area listed in the area.lst at `list_path`, resolving names
// relative to the list's directory. Returns an error only if the list itself
// can't be read; per-file problems go in `set.failures`.
// The caller must call unload_area_set, also after an error.
load_area_set :: proc(list_path: string, allocator := context.allocator) -> (set: Area_Set, err: Parse_Error) {
	set.allocator = allocator
	set.loaded = make([dynamic]^Loaded_Area, allocator)
	set.failures = make([dynamic]Area_Load_Failure, allocator)
	set.list_data = read_file_capped(list_path, MAX_AREA_LIST_SIZE, allocator) or_return
	names := parse_area_list(set.list_data, context.temp_allocator) or_return

	dir := filepath.dir(list_path)
	for name in names {
		path, _ := filepath.join({dir, name}, context.temp_allocator)
		loaded, load_err := load_area_file(path)
		if load_err != nil {
			append(&set.failures, Area_Load_Failure{name = name, error = load_err})
			continue
		}
		loaded.area.source_name = name
		append(&set.loaded, loaded)
	}
	return set, nil
}

// The parsed areas of a set, for validation. Allocated with `allocator`.
area_set_areas :: proc(set: ^Area_Set, allocator := context.allocator) -> []^models.Area {
	areas := make([]^models.Area, len(set.loaded), allocator)
	for loaded, i in set.loaded {
		areas[i] = &loaded.area
	}
	return areas
}

// Free every area in the set and the set's own memory.
unload_area_set :: proc(set: ^Area_Set) {
	for loaded in set.loaded {
		unload_area(loaded)
	}
	delete(set.loaded)
	delete(set.failures)
	delete(set.list_data, set.allocator)
	set^ = {}
}

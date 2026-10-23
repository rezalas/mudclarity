/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:mem/virtual"

import "../models"

// A parsed area together with the memory it lives in. The file contents and
// every allocation made while parsing come from `arena`, so unload_area frees
// everything at once.
Loaded_Area :: struct {
	area:  models.Area,
	data:  []u8,
	arena: virtual.Arena,
}

// Load and parse the area file at `file_path` into its own arena.
// On success the caller owns the result and must call unload_area.
// On failure all memory has already been released.
load_area_file :: proc(file_path: string) -> (loaded: ^Loaded_Area, err: Parse_Error) {
	loaded = new(Loaded_Area)
	if virtual.arena_init_growing(&loaded.arena) != nil {
		free(loaded)
		return nil, make_failure(.Io_Error, 0, 0, "", 0, "could not reserve memory")
	}
	allocator := virtual.arena_allocator(&loaded.arena)
	area, data, parse_err := parse_area_file(file_path, allocator)
	if parse_err != nil {
		unload_area(loaded)
		return nil, parse_err
	}
	loaded.area = area
	loaded.data = data
	return loaded, nil
}

// Load an area from bytes already in memory. The bytes are copied into the
// arena, so `data` does not need to outlive the result.
load_area_bytes :: proc(data: []u8, source_name: string) -> (loaded: ^Loaded_Area, err: Parse_Error) {
	loaded = new(Loaded_Area)
	if virtual.arena_init_growing(&loaded.arena) != nil {
		free(loaded)
		return nil, make_failure(.Io_Error, 0, 0, "", 0, "could not reserve memory")
	}
	allocator := virtual.arena_allocator(&loaded.arena)
	copied := make([]u8, len(data), allocator)
	copy(copied, data)
	area, parse_err := parse_area(copied, source_name, allocator)
	if parse_err != nil {
		unload_area(loaded)
		return nil, parse_err
	}
	loaded.area = area
	loaded.data = copied
	return loaded, nil
}

// Free a Loaded_Area and everything it owns. Safe to call with nil.
unload_area :: proc(loaded: ^Loaded_Area) {
	if loaded == nil {
		return
	}
	virtual.arena_destroy(&loaded.arena)
	free(loaded)
}

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package workspace

import "base:runtime"
import "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:strings"

import "../clarity"
import "../formats"
import "../models"
import "../validation"

/*
 A loaded world: its areas, their findings and the review file. The CLI and
 the GUI both work through a Workspace, so loading, review edits and saving
 are written once.

 Memory: a Workspace is heap-allocated and everything it holds, including
 strings passed to edits, lives in its arena or the areas' own arenas.
 close frees it all at once.
*/
Workspace :: struct {
	arena:        virtual.Arena,
	set:          formats.Area_Set,
	areas:        []^models.Area,
	names:        []string, // names[i] is how area.lst names areas[i]
	hashes:       []string, // SHA-256 of each area file, as loaded
	is_complete:  bool,     // The whole area.lst loaded, so missing vnums are errors
	list_path:    string,   // The area.lst opened; empty for loose .are files
	clarity_path: string,   // Empty when loose .are files were opened
	diagnostics:  []validation.Diagnostic,
	document:     clarity.Document,
}

// File name of the review file, next to area.lst.
REVIEW_FILE_NAME :: "area.clarity"

// Open a world: an area list when `paths` is one area.lst, otherwise loose
// area files. See open_area_list and open_area_files.
open :: proc(paths: []string) -> (ws: ^Workspace, err: Error) {
	if len(paths) == 1 && is_area_list(paths[0]) {
		return open_area_list(paths[0])
	}
	return open_area_files(paths)
}

// Whether `path` names an area list. Extensions are compared ignoring case:
// Windows and macOS file systems usually ignore it too, so AREA.LST is the
// same file as area.lst.
is_area_list :: proc(path: string) -> bool {
	return strings.equal_fold(filepath.ext(path), ".lst")
}

// Whether `path` names an area file (ends in .are, in any case).
is_area_file :: proc(path: string) -> bool {
	return strings.equal_fold(filepath.ext(path), ".are")
}

// Load every area in the area.lst at `path`, validate the world and load
// area.clarity next to it (or start a new one). Files that fail to parse are
// recorded in `ws.set.failures`; only an unreadable list or review file is an
// error. On success the caller owns the result and must call close; on
// failure nothing needs freeing.
open_area_list :: proc(path: string) -> (ws: ^Workspace, err: Error) {
	ws = workspace_new() or_return
	allocator := virtual.arena_allocator(&ws.arena)

	list_err: formats.Parse_Error
	ws.set, list_err = formats.load_area_set(path, allocator)
	if failure, failed := list_err.(formats.Parse_Failure); failed {
		close(ws)
		return nil, Area_List_Failure{path = path, failure = failure}
	}
	ws.is_complete = len(ws.set.failures) == 0
	ws.list_path = strings.clone(path, allocator)
	ws.clarity_path, _ = filepath.join({filepath.dir(path), REVIEW_FILE_NAME}, allocator)
	finish_loading(ws)

	if os.exists(ws.clarity_path) {
		doc, load_err := clarity.load_document(ws.clarity_path, allocator)
		if failure, failed := load_err.(clarity.Load_Failure); failed {
			review_err := Review_File_Failure {
				path    = strings.clone(ws.clarity_path, context.temp_allocator),
				failure = failure,
			}
			close(ws)
			return nil, review_err
		}
		ws.document = doc
	}
	return ws, nil
}

// Load and validate loose area files. A file that fails to parse is recorded
// in `ws.set.failures`, so this fails only when out of memory. The world has
// no review file: edits and save return No_Review_File. The caller must call
// close.
open_area_files :: proc(paths: []string) -> (ws: ^Workspace, err: Error) {
	ws = workspace_new() or_return
	allocator := virtual.arena_allocator(&ws.arena)
	ws.set.allocator = allocator
	ws.set.loaded = make([dynamic]^formats.Loaded_Area, allocator)
	ws.set.failures = make([dynamic]formats.Area_Load_Failure, allocator)
	for path in paths {
		loaded, load_err := formats.load_area_file(path)
		if load_err != nil {
			append(&ws.set.failures, formats.Area_Load_Failure{name = strings.clone(path, allocator), error = load_err})
			continue
		}
		append(&ws.set.loaded, loaded)
	}
	finish_loading(ws)
	return ws, nil
}

// Free the workspace and everything in it. Safe to call with nil.
close :: proc(ws: ^Workspace) {
	if ws == nil {
		return
	}
	formats.unload_area_set(&ws.set)
	virtual.arena_destroy(&ws.arena)
	free(ws)
}

// The allocator a workspace's own data lives in.
allocator :: proc(ws: ^Workspace) -> runtime.Allocator {
	return virtual.arena_allocator(&ws.arena)
}

// The current SHA-256 of the area file `file` (as area.lst names it), or ""
// if it isn't loaded.
hash_of :: proc(ws: ^Workspace, file: string) -> string {
	for name, i in ws.names {
		if name == file {
			return ws.hashes[i]
		}
	}
	return ""
}

@(private = "file")
workspace_new :: proc() -> (ws: ^Workspace, err: Error) {
	ws = new(Workspace)
	if ws == nil {
		return nil, Out_Of_Memory{}
	}
	if virtual.arena_init_growing(&ws.arena) != nil {
		free(ws)
		return nil, Out_Of_Memory{}
	}
	return ws, nil
}

// Fill in names, hashes and findings for the loaded areas, and start an
// empty review document.
@(private = "file")
finish_loading :: proc(ws: ^Workspace) {
	allocator := virtual.arena_allocator(&ws.arena)
	ws.areas = formats.area_set_areas(&ws.set, allocator)
	ws.names = make([]string, len(ws.set.loaded), allocator)
	ws.hashes = make([]string, len(ws.set.loaded), allocator)
	for loaded, i in ws.set.loaded {
		ws.names[i] = loaded.area.source_name
		ws.hashes[i] = clarity.sha256_hex(loaded.data, allocator)
	}
	ws.diagnostics = validation.validate(ws.areas, ws.is_complete, allocator)
	ws.document = clarity.document_make("area.lst", allocator)
}

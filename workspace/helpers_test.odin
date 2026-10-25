/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package workspace

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

// Shared helpers for the workspace tests.

TEST_DATE :: "2026-10-25"

// An area named `name` (vnums 100-199) with the given #ROOMS records.
area_text :: proc(name, room_records: string) -> string {
	return fmt.tprintf("#AREA\n%s~\n%s~\nTester~\n1 50\n100 199\nnormal\ntemperate\n0\n1\nNone~\n#ROOMS\n%s#0\n#$\n", name, name, room_records)
}

// Room 100 <-> 101, a broken exit 100 -> 150, and an isolated room 102.
// Findings: Broken_Exit (100, 150), Orphan_Room (102), Dead_End_Room (102).
BASE_ROOMS :: "#100\nA~\n~\ncity\nD NORTH 101 0 0\n~\n~\nD EAST 150 0 0\n~\n~\nS\n#101\nB~\n~\ncity\nD SOUTH 100 0 0\n~\n~\nS\n#102\nC~\n~\ncity\nS\n"

BROKEN_EXIT_ID :: "a.are:Broken_Exit:100:150"

// A fresh, empty temporary directory named `name` (tests run in parallel,
// so each needs its own name). Remove it with os.remove_all.
temp_dir :: proc(t: ^testing.T, name: string) -> string {
	base, _ := os.temp_directory(context.temp_allocator)
	dir, _ := filepath.join({base, name}, context.temp_allocator)
	_ = os.remove_all(dir)
	testing.expect(t, os.make_directory(dir) == nil)
	return dir
}

// Write `text` to `dir/name`. Returns the file's path.
write_file :: proc(t: ^testing.T, dir, name, text: string, loc := #caller_location) -> string {
	path, _ := filepath.join({dir, name}, context.temp_allocator)
	testing.expect(t, os.write_entire_file(path, transmute([]u8)text) == nil, loc = loc)
	return path
}

// Write a world to `dir`: area files named "a.are", "b.are", ... with the
// given texts, and an area.lst listing them. Returns the area.lst path.
write_world :: proc(t: ^testing.T, dir: string, texts: ..string, loc := #caller_location) -> string {
	list: strings.Builder
	strings.builder_init(&list, context.temp_allocator)
	for text, i in texts {
		name := fmt.tprintf("%c.are", 'a' + i)
		write_file(t, dir, name, text, loc)
		fmt.sbprintf(&list, "%s\n", name)
	}
	strings.write_string(&list, "$\n")
	return write_file(t, dir, "area.lst", strings.to_string(list), loc)
}

// Open the area list at `path`, failing the test on an error.
open_or_fail :: proc(t: ^testing.T, path: string, loc := #caller_location) -> ^Workspace {
	ws, err := open_area_list(path)
	testing.expectf(t, err == nil, "open_area_list: %s", error_message(err, context.temp_allocator), loc = loc)
	return ws
}

// The kind of an Edit_Failure, or fail the test if `err` is something else.
edit_kind :: proc(t: ^testing.T, err: Error, loc := #caller_location) -> Edit_Error_Kind {
	failure, ok := err.(Edit_Failure)
	testing.expectf(t, ok, "expected an Edit_Failure, got %v", err, loc = loc)
	return failure.kind
}

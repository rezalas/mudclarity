/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package testkit

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

/*
 Helpers shared by the test suites of several packages. Only *_test.odin
 files import this package, so it never ends up in the program. Everything
 returned is allocated with the temp allocator.
*/

// An area named `name` (vnums 100-199) with the given #ROOMS records.
area_text :: proc(name, room_records: string) -> string {
	return fmt.tprintf("#AREA\n%s~\n%s~\nTester~\n1 50\n100 199\nnormal\ntemperate\n0\n1\nNone~\n#ROOMS\n%s#0\n#$\n", name, name, room_records)
}

// Room 100 <-> 101, a broken exit 100 -> 150, and an isolated room 102.
// Findings: Broken_Exit (100, 150), Orphan_Room (102), Dead_End_Room (102),
// and, when loaded as a whole area.lst, Area_Without_Entrance.
BASE_ROOMS :: "#100\nA~\n~\ncity\nD NORTH 101 0 0\n~\n~\nD EAST 150 0 0\n~\n~\nS\n#101\nB~\n~\ncity\nD SOUTH 100 0 0\n~\n~\nS\n#102\nC~\n~\ncity\nS\n"

// The id of BASE_ROOMS' broken exit when it is the first area ("a.are").
BROKEN_EXIT_ID :: "a.are:Broken_Exit:100:150"

// A fresh, empty temporary directory named `name` (tests run in parallel,
// so each needs its own name). Remove it with os.remove_all.
temp_dir :: proc(t: ^testing.T, name: string, loc := #caller_location) -> string {
	base, _ := os.temp_directory(context.temp_allocator)
	dir, _ := filepath.join({base, name}, context.temp_allocator)
	_ = os.remove_all(dir)
	testing.expect(t, os.make_directory(dir) == nil, loc = loc)
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

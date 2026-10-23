/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:os"
import "core:path/filepath"
import "core:testing"

// Write files into a fresh temporary directory named `name`; returns its
// path. Each test needs its own name because tests run in parallel.
@(private = "file")
Test_File :: struct {
	name, text: string,
}

@(private = "file")
make_area_dir :: proc(t: ^testing.T, name: string, files: []Test_File) -> string {
	base, _ := os.temp_directory(context.temp_allocator)
	dir, _ := filepath.join({base, name}, context.temp_allocator)
	_ = os.remove_all(dir)
	testing.expect(t, os.make_directory(dir) == nil)
	for file in files {
		path, _ := filepath.join({dir, file.name}, context.temp_allocator)
		testing.expect(t, os.write_entire_file(path, transmute([]u8)file.text) == nil)
	}
	return dir
}

@(test)
test_area_set_loads_listed_areas_and_records_failures :: proc(t: ^testing.T) {
	files := []Test_File {
		{"area.lst", "good.are\rbroken.are\rmissing.are\r$"},
		{"good.are", with_header("#ROOMS\n#101\nHall~\n~\ncity\nS\n#0\n")},
		{"broken.are", with_header("#ROOMS\n#101\nHall\n")},
	}
	dir := make_area_dir(t, "mudclarity_area_set_load", files)
	defer os.remove_all(dir)

	list_path, _ := filepath.join({dir, "area.lst"}, context.temp_allocator)
	set, err := load_area_set(list_path)
	defer unload_area_set(&set)
	if !testing.expect(t, err == nil) do return

	if testing.expect_value(t, len(set.loaded), 1) {
		testing.expect_value(t, set.loaded[0].area.source_name, "good.are")
		testing.expect_value(t, len(set.loaded[0].area.rooms), 1)
	}
	if testing.expect_value(t, len(set.failures), 2) {
		testing.expect_value(t, set.failures[0].name, "broken.are")
		expect_failure(t, set.failures[0].error, .Unterminated_String)
		testing.expect_value(t, set.failures[1].name, "missing.are")
		expect_failure(t, set.failures[1].error, .Io_Error)
	}
	areas := area_set_areas(&set)
	defer delete(areas)
	testing.expect_value(t, len(areas), 1)
}

@(test)
test_area_set_missing_list :: proc(t: ^testing.T) {
	set, err := load_area_set(TEST_DATA_DIR + "/no_such_dir/area.lst")
	defer unload_area_set(&set)
	expect_failure(t, err, .Io_Error)
	testing.expect_value(t, len(set.loaded), 0)
}

@(test)
test_area_set_rejects_path_entries :: proc(t: ^testing.T) {
	files := []Test_File{{"area.lst", "../escape.are\n$\n"}}
	dir := make_area_dir(t, "mudclarity_area_set_paths", files)
	defer os.remove_all(dir)
	list_path, _ := filepath.join({dir, "area.lst"}, context.temp_allocator)
	set, err := load_area_set(list_path)
	defer unload_area_set(&set)
	expect_failure(t, err, .Bad_Area_List_Entry, 1)
}

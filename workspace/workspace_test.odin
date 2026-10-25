/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package workspace

import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

@(test)
test_open_area_list :: proc(t: ^testing.T) {
	dir := temp_dir(t, "mudclarity_ws_open")
	defer os.remove_all(dir)
	list := write_world(t, dir, area_text("A", BASE_ROOMS), area_text("B", "#110\nD~\n~\ncity\nS\n"))

	ws := open_or_fail(t, list)
	defer close(ws)
	if ws == nil do return
	testing.expect_value(t, len(ws.areas), 2)
	testing.expect_value(t, len(ws.set.failures), 0)
	testing.expect(t, ws.is_complete)
	testing.expect_value(t, ws.names[0], "a.are")
	testing.expect_value(t, ws.names[1], "b.are")
	testing.expect_value(t, len(ws.hashes[0]), 64)
	testing.expect(t, ws.hashes[0] != ws.hashes[1])
	testing.expect_value(t, hash_of(ws, "b.are"), ws.hashes[1])
	testing.expect_value(t, hash_of(ws, "missing.are"), "")
	testing.expect_value(t, ws.list_path, list)
	expected_review, _ := filepath.join({dir, REVIEW_FILE_NAME}, context.temp_allocator)
	testing.expect_value(t, ws.clarity_path, expected_review)
	testing.expect(t, len(ws.diagnostics) > 0)
	// No area.clarity yet: an empty document, and nothing written.
	testing.expect_value(t, len(ws.document.files), 0)
	testing.expect(t, !os.exists(ws.clarity_path))
}

@(test)
test_open_area_list_records_bad_files :: proc(t: ^testing.T) {
	dir := temp_dir(t, "mudclarity_ws_bad_file")
	defer os.remove_all(dir)
	list := write_world(t, dir, area_text("A", BASE_ROOMS), "#AREA\nunterminated")

	ws := open_or_fail(t, list)
	defer close(ws)
	if ws == nil do return
	testing.expect_value(t, len(ws.areas), 1)
	testing.expect_value(t, len(ws.set.failures), 1)
	testing.expect_value(t, ws.set.failures[0].name, "b.are")
	testing.expect(t, !ws.is_complete, "a world with a failed file is not complete")
}

@(test)
test_open_missing_area_list :: proc(t: ^testing.T) {
	dir := temp_dir(t, "mudclarity_ws_missing_list")
	defer os.remove_all(dir)
	list, _ := filepath.join({dir, "area.lst"}, context.temp_allocator)

	ws, err := open_area_list(list)
	testing.expect(t, ws == nil)
	failure, ok := err.(Area_List_Failure)
	if !testing.expect(t, ok) do return
	testing.expect_value(t, failure.path, list)
	testing.expect(t, strings.has_prefix(error_message(err, context.temp_allocator), list))
}

@(test)
test_open_bad_review_file :: proc(t: ^testing.T) {
	dir := temp_dir(t, "mudclarity_ws_bad_review")
	defer os.remove_all(dir)
	list := write_world(t, dir, area_text("A", BASE_ROOMS))
	review := write_file(t, dir, REVIEW_FILE_NAME, "{ not json")

	ws, err := open_area_list(list)
	testing.expect(t, ws == nil)
	failure, ok := err.(Review_File_Failure)
	if !testing.expect(t, ok) do return
	testing.expect_value(t, failure.path, review)
	testing.expect_value(t, failure.failure.kind, .Bad_Json)
	testing.expect(t, strings.has_prefix(error_message(err, context.temp_allocator), review))
}

@(test)
test_open_area_files :: proc(t: ^testing.T) {
	dir := temp_dir(t, "mudclarity_ws_loose")
	defer os.remove_all(dir)
	good := write_file(t, dir, "good.are", area_text("A", BASE_ROOMS))
	missing, _ := filepath.join({dir, "missing.are"}, context.temp_allocator)

	ws, err := open_area_files({good, missing})
	defer close(ws)
	if !testing.expect(t, err == nil) do return
	testing.expect_value(t, len(ws.areas), 1)
	testing.expect_value(t, len(ws.set.failures), 1)
	testing.expect_value(t, ws.set.failures[0].name, missing)
	testing.expect(t, !ws.is_complete)
	testing.expect_value(t, ws.clarity_path, "")
	testing.expect(t, len(ws.diagnostics) > 0)

	// Loose files have no review file, so every edit is refused.
	testing.expect_value(t, edit_kind(t, record_run(ws)), Edit_Error_Kind.No_Review_File)
	testing.expect_value(t, edit_kind(t, save(ws)), Edit_Error_Kind.No_Review_File)
	testing.expect_value(t, edit_kind(t, add_note(ws, ws.names[0], "room", 100, "x", TEST_DATE)), Edit_Error_Kind.No_Review_File)
}

@(test)
test_close_nil :: proc(t: ^testing.T) {
	close(nil)
}

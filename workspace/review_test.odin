/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package workspace

import "core:os"
import "core:strings"
import "core:testing"

import "../clarity"

@(test)
test_current_finding_key :: proc(t: ^testing.T) {
	dir := temp_dir(t, "mudclarity_ws_finding_key")
	defer os.remove_all(dir)
	ws := open_or_fail(t, write_world(t, dir, area_text("A", BASE_ROOMS)))
	defer close(ws)
	if ws == nil do return

	key, err := current_finding_key(ws, BROKEN_EXIT_ID)
	testing.expect(t, err == nil)
	testing.expect_value(t, key, clarity.Finding_Key{"a.are", "Broken_Exit", 100, 150})

	_, err = current_finding_key(ws, "nonsense")
	testing.expect_value(t, edit_kind(t, err), Edit_Error_Kind.Bad_Finding_Id)
	_, err = current_finding_key(ws, "a.are:Broken_Exit:100:151")
	testing.expect_value(t, edit_kind(t, err), Edit_Error_Kind.Unknown_Finding)
	testing.expect_value(t, error_message(err, context.temp_allocator), "no current finding has id a.are:Broken_Exit:100:151")
}

@(test)
test_review_save_and_reopen :: proc(t: ^testing.T) {
	dir := temp_dir(t, "mudclarity_ws_review")
	defer os.remove_all(dir)
	list := write_world(t, dir, area_text("A", BASE_ROOMS))

	{
		ws := open_or_fail(t, list)
		defer close(ws)
		if ws == nil do return
		key, _ := current_finding_key(ws, BROKEN_EXIT_ID)
		testing.expect(t, set_review(ws, key, clarity.REVIEW_ACCEPTED, "on purpose", TEST_DATE) == nil)
		testing.expect(t, record_run(ws) == nil)
		testing.expect(t, save(ws) == nil)
	}

	ws := open_or_fail(t, list)
	defer close(ws)
	if ws == nil do return
	testing.expect_value(t, len(ws.document.reviews), 1)
	testing.expect_value(t, ws.document.reviews[0].note, "on purpose")
	testing.expect_value(t, ws.document.reviews[0].file_sha256, ws.hashes[0])
	testing.expect_value(t, len(ws.document.snapshot), len(ws.diagnostics))

	result := merge(ws, context.temp_allocator)
	testing.expect_value(t, result.state_counts[.Accepted], 1)
	testing.expect_value(t, result.new_count, 0)

	key, _ := current_finding_key(ws, BROKEN_EXIT_ID)
	testing.expect(t, remove_review(ws, key, BROKEN_EXIT_ID) == nil)
	err := remove_review(ws, key, BROKEN_EXIT_ID)
	testing.expect_value(t, edit_kind(t, err), Edit_Error_Kind.No_Decision)
	testing.expect_value(t, error_message(err, context.temp_allocator), "no decision recorded for " + BROKEN_EXIT_ID)
}

@(test)
test_notes_and_issues :: proc(t: ^testing.T) {
	dir := temp_dir(t, "mudclarity_ws_notes")
	defer os.remove_all(dir)
	list := write_world(t, dir, area_text("A", BASE_ROOMS))
	ws := open_or_fail(t, list)
	defer close(ws)
	if ws == nil do return

	// Strings are cloned into the workspace, so the caller's can go away.
	text := strings.clone("check the door", context.temp_allocator)
	testing.expect(t, add_note(ws, "a.are", clarity.KIND_ROOM, 100, text, TEST_DATE) == nil)
	first, first_err := add_issue(ws, "a.are", clarity.KIND_ROOM, 102, "no way in", TEST_DATE)
	second, second_err := add_issue(ws, "a.are", clarity.KIND_AREA, 0, "rename", TEST_DATE)
	testing.expect(t, first_err == nil && second_err == nil)
	testing.expect_value(t, first, 1)
	testing.expect_value(t, second, 2)
	testing.expect_value(t, len(ws.document.notes), 1)
	testing.expect_value(t, ws.document.notes[0].text, "check the door")

	err := add_note(ws, "missing.are", clarity.KIND_ROOM, 100, "x", TEST_DATE)
	testing.expect_value(t, edit_kind(t, err), Edit_Error_Kind.Unknown_File)
	testing.expect_value(t, error_message(err, context.temp_allocator), strings.concatenate({"missing.are is not in ", list}, context.temp_allocator))
	_, err = add_issue(ws, "a.are", "door", 100, "x", TEST_DATE)
	testing.expect_value(t, edit_kind(t, err), Edit_Error_Kind.Unknown_Kind)
	testing.expect_value(t, len(ws.document.notes), 1)
	testing.expect_value(t, len(ws.document.issues), 2)
}

@(test)
test_save_failure_names_review_file :: proc(t: ^testing.T) {
	dir := temp_dir(t, "mudclarity_ws_save_failure")
	defer os.remove_all(dir)
	ws := open_or_fail(t, write_world(t, dir, area_text("A", BASE_ROOMS)))
	defer close(ws)
	if ws == nil do return
	// A directory where the file should be makes the rename fail.
	testing.expect(t, os.make_directory(ws.clarity_path) == nil)

	err := save(ws)
	failure, ok := err.(Review_File_Failure)
	if !testing.expect(t, ok) do return
	testing.expect_value(t, failure.path, ws.clarity_path)
}

@(test)
test_today_format :: proc(t: ^testing.T) {
	date := today(context.temp_allocator)
	testing.expect_value(t, len(date), 10)
	testing.expect(t, date[4] == '-' && date[7] == '-')
}

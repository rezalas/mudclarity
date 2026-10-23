/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package clarity

import "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

@(private = "file")
VALID_DOCUMENT :: `{
  "format": "mudclarity",
  "version": 1,
  "area_list": "area.lst",
  "files": [
    {"name": "a.are", "sha256": "00", "size": 10, "rooms": 3, "mobiles": 0, "objects": 0}
  ],
  "reviews": [
    {"file": "a.are", "check": "Broken_Exit", "vnum": 100, "related_vnum": 150,
     "status": "accepted", "note": "maze", "file_sha256": "00", "date": "2026-10-23"}
  ],
  "issues": [
    {"id": 1, "file": "a.are", "kind": "room", "vnum": 101, "status": "open",
     "title": "Typo", "note": "", "date": "2026-10-23"}
  ],
  "notes": [
    {"file": "a.are", "kind": "area", "vnum": 0, "text": "Starter area", "date": "2026-10-23"}
  ],
  "snapshot": [
    {"file": "a.are", "check": "Broken_Exit", "severity": "error", "vnum": 100,
     "related_vnum": 150, "line": 18, "message": "north exit is broken"}
  ]
}
`

@(test)
test_sha256_known_vectors :: proc(t: ^testing.T) {
	testing.expect_value(t, sha256_hex(nil, context.temp_allocator), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
	testing.expect_value(t, sha256_hex(transmute([]u8)string("abc"), context.temp_allocator), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
}

@(test)
test_parse_valid_document :: proc(t: ^testing.T) {
	doc, err := parse_document(transmute([]u8)string(VALID_DOCUMENT))
	defer document_destroy(&doc)
	if !testing.expectf(t, err == nil, "%v", err) do return
	testing.expect_value(t, doc.area_list, "area.lst")
	testing.expect_value(t, len(doc.files), 1)
	testing.expect_value(t, doc.files[0].rooms, 3)
	testing.expect_value(t, doc.reviews[0].note, "maze")
	testing.expect_value(t, doc.issues[0].title, "Typo")
	testing.expect_value(t, doc.notes[0].kind, KIND_AREA)
	testing.expect_value(t, doc.snapshot[0].line, 18)
}

@(private = "file")
expect_load_error :: proc(t: ^testing.T, text: string, kind: Load_Error_Kind, loc := #caller_location) {
	doc, err := parse_document(transmute([]u8)text)
	defer document_destroy(&doc)
	failure, failed := err.(Load_Failure)
	if testing.expectf(t, failed, "expected %v, got success", kind, loc = loc) {
		testing.expectf(t, failure.kind == kind, "expected %v, got %v: %s", kind, failure.kind, failure.detail, loc = loc)
	}
}

@(private = "file")
with_replaced :: proc(old, new: string) -> string {
	result, _ := strings.replace(VALID_DOCUMENT, old, new, 1, context.temp_allocator)
	return result
}

@(test)
test_load_errors :: proc(t: ^testing.T) {
	expect_load_error(t, "{not json", .Bad_Json)
	expect_load_error(t, "", .Bad_Json)
	expect_load_error(t, with_replaced(`"format": "mudclarity"`, `"format": "other"`), .Wrong_Format)
	expect_load_error(t, with_replaced(`"version": 1`, `"version": 2`), .Unsupported_Version)
	expect_load_error(t, with_replaced(`"version": 1`, `"version": 0`), .Bad_Field)
	expect_load_error(t, with_replaced(`{"name": "a.are"`, `{"name": "../a.are"`), .Bad_Field)
	expect_load_error(t, with_replaced(`{"name": "a.are"`, `{"name": "dir/a.are"`), .Bad_Field)
	expect_load_error(t, with_replaced(`"status": "accepted"`, `"status": "maybe"`), .Bad_Field)
	expect_load_error(t, with_replaced(`"kind": "room"`, `"kind": "door"`), .Bad_Field)
	expect_load_error(t, with_replaced(`"status": "open"`, `"status": "accepted"`), .Bad_Field)
	expect_load_error(t, with_replaced(`"severity": "error"`, `"severity": "fatal"`), .Bad_Field)
	expect_load_error(t, with_replaced(`{"id": 1,`, `{"id": 0,`), .Bad_Field)
}

@(test)
test_duplicate_issue_ids_are_rejected :: proc(t: ^testing.T) {
	issue := `{"id": 1, "file": "a.are", "kind": "room", "vnum": 101, "status": "open", "title": "Typo", "note": "", "date": "2026-10-23"}`
	text := with_replaced(`"issues": [`, strings.concatenate({`"issues": [`, issue, ","}, context.temp_allocator))
	expect_load_error(t, text, .Bad_Field)
}

@(test)
test_unknown_check_names_are_kept :: proc(t: ^testing.T) {
	arena: virtual.Arena
	if !testing.expect(t, test_arena(&arena) == nil) do return
	defer virtual.arena_destroy(&arena)
	allocator := virtual.arena_allocator(&arena)

	text := with_replaced(`"check": "Broken_Exit", "vnum": 100, "related_vnum": 150,
     "status"`, `"check": "Retired_Check", "vnum": 100, "related_vnum": 150,
     "status"`)
	doc, err := parse_document(transmute([]u8)text, allocator)
	if !testing.expectf(t, err == nil, "%v", err) do return
	dir := temp_dir(t, "mudclarity_clarity_unknown")
	defer os.remove_all(dir)
	path, _ := filepath.join({dir, "area.clarity"}, context.temp_allocator)
	testing.expect(t, save_document(path, &doc) == nil)
	again, load_err := load_document(path, allocator)
	testing.expect(t, load_err == nil)
	testing.expect_value(t, again.reviews[0].check, "Retired_Check")
}

@(test)
test_round_trip_is_byte_identical :: proc(t: ^testing.T) {
	arena: virtual.Arena
	if !testing.expect(t, test_arena(&arena) == nil) do return
	defer virtual.arena_destroy(&arena)
	allocator := virtual.arena_allocator(&arena)

	doc, err := parse_document(transmute([]u8)string(VALID_DOCUMENT), allocator)
	if !testing.expect(t, err == nil) do return
	add_note(&doc, "a.are", KIND_ROOM, 102, "Second note", TEST_DATE, allocator)
	add_note(&doc, "a.are", KIND_ROOM, 101, "First by vnum", TEST_DATE, allocator)

	dir := temp_dir(t, "mudclarity_clarity_round_trip")
	defer os.remove_all(dir)
	first_path, _ := filepath.join({dir, "first.clarity"}, context.temp_allocator)
	second_path, _ := filepath.join({dir, "second.clarity"}, context.temp_allocator)
	testing.expect(t, save_document(first_path, &doc) == nil)
	loaded, load_err := load_document(first_path, allocator)
	testing.expect(t, load_err == nil)
	testing.expect(t, save_document(second_path, &loaded) == nil)

	first, _ := os.read_entire_file(first_path, context.temp_allocator)
	second, _ := os.read_entire_file(second_path, context.temp_allocator)
	testing.expect_value(t, string(second), string(first))
	// Notes were sorted by vnum on save.
	testing.expect_value(t, loaded.notes[1].vnum, 101)
	testing.expect(t, strings.has_suffix(string(first), "}\n"))
}

@(test)
test_save_is_atomic :: proc(t: ^testing.T) {
	arena: virtual.Arena
	if !testing.expect(t, test_arena(&arena) == nil) do return
	defer virtual.arena_destroy(&arena)
	allocator := virtual.arena_allocator(&arena)

	dir := temp_dir(t, "mudclarity_clarity_atomic")
	defer os.remove_all(dir)
	path, _ := filepath.join({dir, "area.clarity"}, context.temp_allocator)
	doc := document_make("area.lst", allocator)
	testing.expect(t, save_document(path, &doc) == nil)
	testing.expect(t, os.exists(path))
	testing.expect(t, !os.exists(strings.concatenate({path, ".tmp"}, context.temp_allocator)), "temporary file left behind")

	// Saving into a directory that doesn't exist fails without touching anything.
	bad_path, _ := filepath.join({dir, "missing", "area.clarity"}, context.temp_allocator)
	failure, failed := save_document(bad_path, &doc).(Load_Failure)
	testing.expect(t, failed && failure.kind == .Io_Error)
	_, still_ok := load_document(path, allocator)
	testing.expect(t, still_ok == nil)
}

@(test)
test_load_missing_and_oversized_files :: proc(t: ^testing.T) {
	_, err := load_document("/definitely/not/here.clarity")
	failure, failed := err.(Load_Failure)
	testing.expect(t, failed && failure.kind == .Io_Error)

	big := make([]u8, MAX_DOCUMENT_SIZE + 1)
	defer delete(big)
	_, big_err := parse_document(big)
	big_failure, big_failed := big_err.(Load_Failure)
	testing.expect(t, big_failed && big_failure.kind == .File_Too_Large)
}

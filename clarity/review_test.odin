/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package clarity

import "core:strings"
import "core:testing"

// --- Finding IDs ---

@(test)
test_finding_id_round_trip :: proc(t: ^testing.T) {
	key := Finding_Key{"mtcim.are", "Mismatched_Return", 218, 219}
	id := finding_id(key, context.temp_allocator)
	testing.expect_value(t, id, "mtcim.are:Mismatched_Return:218:219")
	parsed, ok := parse_finding_id(id)
	testing.expect(t, ok)
	testing.expect_value(t, parsed, key)

	negative, neg_ok := parse_finding_id("x.are:Locked_Door_No_Key:100:-1")
	testing.expect(t, neg_ok)
	testing.expect_value(t, negative.related_vnum, -1)

	// The file is everything before the last three fields.
	colon, colon_ok := parse_finding_id("odd:name.are:Orphan_Room:102:0")
	testing.expect(t, colon_ok)
	testing.expect_value(t, colon.file, "odd:name.are")
}

@(test)
test_bad_finding_ids :: proc(t: ^testing.T) {
	for id in ([]string{"", "a.are", "a.are:Broken_Exit:100", ":Broken_Exit:1:2", "a.are::1:2", "a.are:Broken_Exit:x:2", "a.are:Broken_Exit:1:"}) {
		_, ok := parse_finding_id(id)
		testing.expectf(t, !ok, "%q should not parse", id)
	}
}

// --- Merge states ---

@(test)
test_unreviewed_findings_are_open :: proc(t: ^testing.T) {
	w := world_make(t, area_text("a", BASE_ROOMS))
	defer world_destroy(&w)
	doc := document_make("area.lst", context.temp_allocator)
	result := world_merge(&w, &doc)
	testing.expect_value(t, len(result.findings), 3)
	testing.expect_value(t, result.state_counts[.Open], 3)
	// Never saved, so nothing counts as new.
	testing.expect_value(t, result.new_count, 0)
	testing.expect_value(t, len(result.added_files), 1)
}

@(test)
test_accepted_and_flagged :: proc(t: ^testing.T) {
	w := world_make(t, area_text("a", BASE_ROOMS))
	defer world_destroy(&w)
	doc := document_make("area.lst", context.temp_allocator)
	set_review(&doc, {"a.are", "Broken_Exit", 100, 150}, REVIEW_FLAGGED, "fix me", w.hashes[0], TEST_DATE, context.temp_allocator)
	set_review(&doc, {"a.are", "Orphan_Room", 102, 0}, REVIEW_ACCEPTED, "teleport only", w.hashes[0], TEST_DATE, context.temp_allocator)

	result := world_merge(&w, &doc)
	testing.expect_value(t, finding(t, result, .Broken_Exit).state, State.Flagged)
	testing.expect_value(t, finding(t, result, .Orphan_Room).state, State.Accepted)
	testing.expect_value(t, finding(t, result, .Dead_End_Room).state, State.Open)
	testing.expect_value(t, result.state_counts[.Accepted], 1)
	testing.expect_value(t, len(result.resolved), 0)
}

@(test)
test_changed_file_needs_review_but_stays_matched :: proc(t: ^testing.T) {
	before := world_make(t, area_text("a", BASE_ROOMS))
	defer world_destroy(&before)
	doc := document_make("area.lst", context.temp_allocator)
	set_review(&doc, {"a.are", "Orphan_Room", 102, 0}, REVIEW_ACCEPTED, "", before.hashes[0], TEST_DATE, context.temp_allocator)

	// Longer descriptions move every line, but the finding's key is the same.
	edited, _ := strings.replace_all(BASE_ROOMS, "~\ncity", "\nMore text here.\n~\ncity", context.temp_allocator)
	after := world_make(t, area_text("a", edited))
	defer world_destroy(&after)
	result := world_merge(&after, &doc)
	orphan := finding(t, result, .Orphan_Room)
	testing.expect_value(t, orphan.state, State.Needs_Review)
	testing.expect_value(t, orphan.review, 0)
	testing.expect(t, orphan.diagnostic.line != finding(t, world_merge(&before, &doc), .Orphan_Room).diagnostic.line)
}

@(test)
test_reviews_of_fixed_findings_are_resolved :: proc(t: ^testing.T) {
	doc := document_make("area.lst", context.temp_allocator)
	set_review(&doc, {"a.are", "Broken_Exit", 100, 150}, REVIEW_FLAGGED, "", "x", TEST_DATE, context.temp_allocator)
	fixed, _ := strings.replace(BASE_ROOMS, "D EAST 150", "D EAST 101", 1, context.temp_allocator)
	w := world_make(t, area_text("a", fixed))
	defer world_destroy(&w)
	result := world_merge(&w, &doc)
	testing.expect_value(t, len(result.resolved), 1)
	testing.expect_value(t, result.state_counts[.Flagged], 0)
}

@(test)
test_reviews_with_unknown_checks_are_reported :: proc(t: ^testing.T) {
	w := world_make(t, area_text("a", BASE_ROOMS))
	defer world_destroy(&w)
	doc := document_make("area.lst", context.temp_allocator)
	set_review(&doc, {"a.are", "Retired_Check", 100, 0}, REVIEW_ACCEPTED, "", w.hashes[0], TEST_DATE, context.temp_allocator)
	result := world_merge(&w, &doc)
	testing.expect_value(t, len(result.unknown_checks), 1)
	testing.expect_value(t, len(result.resolved), 0)
}

@(test)
test_snapshot_new_and_fixed :: proc(t: ^testing.T) {
	before := world_make(t, area_text("a", BASE_ROOMS))
	defer world_destroy(&before)
	doc := document_make("area.lst", context.temp_allocator)
	refresh(&doc, world_files(&before), before.diagnostics, context.temp_allocator)
	testing.expect_value(t, len(doc.snapshot), 3)

	// Unchanged world: nothing new, nothing fixed, no changed files.
	same := world_merge(&before, &doc)
	testing.expect_value(t, same.new_count, 0)
	testing.expect_value(t, len(same.fixed), 0)
	testing.expect_value(t, len(same.changed_files), 0)

	// Fix the broken exit and give room 102 a new broken one.
	edited, _ := strings.replace(BASE_ROOMS, "D EAST 150", "D EAST 101", 1, context.temp_allocator)
	edited, _ = strings.replace(edited, "#102\nC~\n~\ncity\n", "#102\nC~\n~\ncity\nD UP 170 0 0\n~\n~\n", 1, context.temp_allocator)
	after := world_make(t, area_text("a", edited))
	defer world_destroy(&after)
	result := world_merge(&after, &doc)
	testing.expect_value(t, len(result.fixed), 1)
	testing.expect_value(t, doc.snapshot[result.fixed[0]].related_vnum, 150)
	testing.expect_value(t, result.new_count, 1)
	testing.expect_value(t, len(result.changed_files), 1)
}

@(test)
test_added_and_removed_files :: proc(t: ^testing.T) {
	one := world_make(t, area_text("a", BASE_ROOMS))
	defer world_destroy(&one)
	doc := document_make("area.lst", context.temp_allocator)
	refresh(&doc, world_files(&one), one.diagnostics, context.temp_allocator)

	two := world_make(t, area_text("a", BASE_ROOMS), area_text("b", BASE_ROOMS))
	defer world_destroy(&two)
	result := world_merge(&two, &doc)
	testing.expect_value(t, len(result.added_files), 1)
	testing.expect_value(t, result.added_files[0], "b.are")

	doc_two := document_make("area.lst", context.temp_allocator)
	refresh(&doc_two, world_files(&two), two.diagnostics, context.temp_allocator)
	removed := world_merge(&one, &doc_two)
	testing.expect_value(t, len(removed.removed_files), 1)
}

// --- Edits ---

@(test)
test_set_and_remove_review :: proc(t: ^testing.T) {
	doc := document_make("area.lst", context.temp_allocator)
	key := Finding_Key{"a.are", "Orphan_Room", 102, 0}
	set_review(&doc, key, REVIEW_FLAGGED, "first", "h", TEST_DATE, context.temp_allocator)
	set_review(&doc, key, REVIEW_ACCEPTED, "second", "h", TEST_DATE, context.temp_allocator)
	testing.expect_value(t, len(doc.reviews), 1)
	testing.expect_value(t, doc.reviews[0].status, REVIEW_ACCEPTED)
	testing.expect_value(t, doc.reviews[0].note, "second")
	testing.expect(t, remove_review(&doc, key))
	testing.expect(t, !remove_review(&doc, key))
	testing.expect_value(t, len(doc.reviews), 0)
}

@(test)
test_issue_ids_increase :: proc(t: ^testing.T) {
	doc := document_make("area.lst", context.temp_allocator)
	testing.expect_value(t, add_issue(&doc, "a.are", KIND_ROOM, 100, "one", TEST_DATE, context.temp_allocator), 1)
	testing.expect_value(t, add_issue(&doc, "a.are", KIND_MOB, 120, "two", TEST_DATE, context.temp_allocator), 2)
	testing.expect(t, set_issue_status(&doc, 1, ISSUE_RESOLVED, context.temp_allocator))
	testing.expect(t, !set_issue_status(&doc, 9, ISSUE_RESOLVED, context.temp_allocator))
	testing.expect_value(t, add_issue(&doc, "a.are", KIND_AREA, 0, "three", TEST_DATE, context.temp_allocator), 3)
	testing.expect_value(t, doc.issues[0].status, ISSUE_RESOLVED)
	testing.expect_value(t, doc.issues[1].status, ISSUE_OPEN)
}

@(test)
test_refresh_keeps_user_data :: proc(t: ^testing.T) {
	w := world_make(t, area_text("a", BASE_ROOMS))
	defer world_destroy(&w)
	doc := document_make("area.lst", context.temp_allocator)
	set_review(&doc, {"a.are", "Orphan_Room", 102, 0}, REVIEW_ACCEPTED, "", w.hashes[0], TEST_DATE, context.temp_allocator)
	add_issue(&doc, "a.are", KIND_ROOM, 101, "typo", TEST_DATE, context.temp_allocator)
	add_note(&doc, "a.are", KIND_AREA, 0, "starter area", TEST_DATE, context.temp_allocator)

	refresh(&doc, world_files(&w), w.diagnostics, context.temp_allocator)
	refresh(&doc, world_files(&w), w.diagnostics, context.temp_allocator)
	testing.expect_value(t, len(doc.reviews), 1)
	testing.expect_value(t, len(doc.issues), 1)
	testing.expect_value(t, len(doc.notes), 1)
	testing.expect_value(t, len(doc.files), 1)
	testing.expect_value(t, len(doc.snapshot), 3)
	testing.expect_value(t, doc.files[0].sha256, w.hashes[0])
	testing.expect_value(t, doc.files[0].rooms, 3)
	for entry in doc.snapshot {
		_, known := check_from_name(entry.check)
		testing.expect(t, known)
	}
}

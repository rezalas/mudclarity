/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package cli

import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

import "../clarity"
import "../testkit"

// Load the area.clarity in `dir`, in the temp allocator.
@(private = "file")
load_review :: proc(t: ^testing.T, dir: string, loc := #caller_location) -> clarity.Document {
	path, _ := filepath.join({dir, "area.clarity"}, context.temp_allocator)
	doc, err := clarity.load_document(path, context.temp_allocator)
	testing.expectf(t, err == nil, "%v", err, loc = loc)
	return doc
}

@(test)
test_save :: proc(t: ^testing.T) {
	dir, list := base_world(t, "mudclarity_cli_save")
	defer os.remove_all(dir)
	r := run_cli("save", list)
	testing.expect_value(t, r.code, EXIT_OK)
	expect_contains(t, r.out, "saved ")
	expect_contains(t, r.out, "area.clarity: 1 files, 4 findings")
	doc := load_review(t, dir)
	testing.expect_value(t, len(doc.files), 1)
	testing.expect_value(t, len(doc.snapshot), 4)
}

@(test)
test_accept_flag_and_reopen :: proc(t: ^testing.T) {
	dir, list := base_world(t, "mudclarity_cli_decide")
	defer os.remove_all(dir)
	id :: testkit.BROKEN_EXIT_ID

	r := run_cli("accept", list, id, "a", "deliberate", "maze")
	testing.expect_value(t, r.code, EXIT_OK)
	testing.expect_value(t, r.out, "accepted " + id + "\n")
	doc := load_review(t, dir)
	testing.expect_value(t, len(doc.reviews), 1)
	testing.expect_value(t, doc.reviews[0].note, "a deliberate maze")

	// Flagging replaces the decision.
	r = run_cli("flag", list, id)
	testing.expect_value(t, r.out, "flagged " + id + "\n")
	doc = load_review(t, dir)
	testing.expect_value(t, len(doc.reviews), 1)
	testing.expect_value(t, doc.reviews[0].status, clarity.REVIEW_FLAGGED)

	r = run_cli("reopen", list, id)
	testing.expect_value(t, r.code, EXIT_OK)
	testing.expect_value(t, r.out, "reopened " + id + "\n")
	testing.expect_value(t, len(load_review(t, dir).reviews), 0)

	r = run_cli("reopen", list, id)
	testing.expect_value(t, r.code, EXIT_USAGE)
	testing.expect_value(t, r.err, "no decision recorded for " + id + "\n")
}

@(test)
test_decide_rejects_bad_ids :: proc(t: ^testing.T) {
	dir, list := base_world(t, "mudclarity_cli_bad_ids")
	defer os.remove_all(dir)

	r := run_cli("accept", list, "nonsense")
	testing.expect_value(t, r.code, EXIT_USAGE)
	testing.expect_value(t, r.err, "nonsense is not a finding id (file:check:vnum:related_vnum)\n")

	// Well-formed but not a current finding: point at `check`.
	r = run_cli("flag", list, "a.are:Broken_Exit:100:151")
	testing.expect_value(t, r.code, EXIT_USAGE)
	testing.expect_value(t, r.err, "no current finding has id a.are:Broken_Exit:100:151; run check to see the ids\n")

	r = run_cli("reopen", list, "nonsense")
	testing.expect_value(t, r.err, "no decision recorded for nonsense\n")
	path, _ := filepath.join({dir, "area.clarity"}, context.temp_allocator)
	testing.expect(t, !os.exists(path), "a refused edit must not write area.clarity")
}

@(test)
test_note_and_issue :: proc(t: ^testing.T) {
	dir, list := base_world(t, "mudclarity_cli_records")
	defer os.remove_all(dir)

	r := run_cli("note", list, "a.are", "room", "100", "check", "the", "door")
	testing.expect_value(t, r.code, EXIT_OK)
	testing.expect_value(t, r.out, "added note to a.are room 100\n")
	r = run_cli("issue", list, "a.are", "room", "102", "no", "way", "in")
	testing.expect_value(t, r.out, "added issue #1\n")
	r = run_cli("issue", list, "a.are", "area", "0", "rename")
	testing.expect_value(t, r.out, "added issue #2\n")

	doc := load_review(t, dir)
	testing.expect_value(t, len(doc.notes), 1)
	testing.expect_value(t, doc.notes[0].text, "check the door")
	testing.expect_value(t, len(doc.issues), 2)
	testing.expect_value(t, doc.issues[0].title, "no way in")

	// The summary counts them.
	expect_contains(t, run_cli(list).out, "2 open issues, 1 notes")
}

@(test)
test_note_rejects_bad_records :: proc(t: ^testing.T) {
	dir, list := base_world(t, "mudclarity_cli_bad_records")
	defer os.remove_all(dir)

	r := run_cli("note", list, "a.are", "room", "x1", "text")
	testing.expect_value(t, r.code, EXIT_USAGE)
	testing.expect_value(t, r.err, "x1 is not a vnum\n")
	r = run_cli("issue", list, "b.are", "room", "100", "text")
	testing.expect_value(t, r.code, EXIT_USAGE)
	testing.expect_value(t, r.err, strings.concatenate({"b.are is not in ", list, "\n"}, context.temp_allocator))
	r = run_cli("note", list, "a.are", "door", "100", "text")
	testing.expect_value(t, r.code, EXIT_USAGE)
	expect_contains(t, r.err, "kind must be one of")
}

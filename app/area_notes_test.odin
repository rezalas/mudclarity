/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "base:runtime"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

import "../clarity"
import "../components"
import "../testkit"
import "../validation"
import "../workspace"

@(test)
test_area_inspector_data :: proc(t: ^testing.T) {
	dir, list := world_on_disk(t, "mudclarity_app_area_inspector")
	defer os.remove_all(dir)
	s := init()
	s.generation = 1
	s, _ = step(s, load_now(1, list))
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return

	d := area_inspector_data(s)
	testing.expect_value(t, d.header.name, "A")
	testing.expect_value(t, d.file, "a.are")
	testing.expect_value(t, d.rooms, 3)
	// BASE_ROOMS: the broken exit; an orphan, a dead end, no entrance.
	testing.expect_value(t, d.open, [validation.Severity]int{.Error = 1, .Warning = 3, .Info = 0})
	testing.expect_value(t, len(d.notes), 0)
	testing.expect(t, d.can_add)
}

@(test)
test_adding_a_note_saves_it :: proc(t: ^testing.T) {
	dir, list := world_on_disk(t, "mudclarity_app_area_note")
	defer os.remove_all(dir)
	s := init()
	s.generation = 1
	s, _ = step(s, load_now(1, list))
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return
	effect: Effect

	// A blank draft adds nothing.
	s, _ = step(s, Note_Draft_Changed{"   "})
	s, effect = step(s, Note_Added{})
	testing.expect(t, effect == nil)
	testing.expect_value(t, len(s.world.ws.document.notes), 0)

	s, _ = step(s, Note_Draft_Changed{"  Needs a second entrance.\n"})
	s, effect = step(s, Note_Added{})
	save, is_save := effect.(Save_Review)
	if !testing.expect(t, is_save) do return
	testing.expect_value(t, s.note_draft, "")
	notes := area_inspector_data(s).notes
	if !testing.expect_value(t, len(notes), 1) do return
	testing.expect_value(t, notes[0].text, "Needs a second entrance.")
	testing.expect_value(t, notes[0].date, workspace.today(context.temp_allocator))

	result := save_review(save).(Review_Saved)
	testing.expect_value(t, result.error, "")
	s, _ = step(s, result)
	testing.expect_value(t, s.error, "")

	// It's in the file, as the CLI would have written it.
	clarity_path, _ := filepath.join({dir, workspace.REVIEW_FILE_NAME}, context.temp_allocator)
	doc, failure := clarity.load_document(clarity_path, context.temp_allocator)
	if !testing.expectf(t, failure == nil, "%v", failure) do return
	testing.expect_value(t, len(doc.notes), 1)
	testing.expect_value(t, doc.notes[0].file, "a.are")
	testing.expect_value(t, doc.notes[0].kind, clarity.KIND_AREA)
	testing.expect_value(t, doc.notes[0].vnum, 0)
}

@(test)
test_a_draft_belongs_to_its_area :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_app_area_draft")
	defer os.remove_all(dir)
	list := testkit.write_world(t, dir, testkit.area_text("A", testkit.BASE_ROOMS), testkit.area_text("B", ""))
	s := init()
	s.generation = 1
	s, _ = step(s, load_now(1, list))
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return

	s, _ = step(s, Note_Draft_Changed{"half a thought"})
	s, _ = step(s, Area_Map{components.Area_Clicked{0}})
	testing.expect_value(t, s.note_draft, "half a thought")
	s, _ = step(s, Area_Map{components.Area_Clicked{1}})
	testing.expect_value(t, s.note_draft, "")
}

@(test)
test_loose_files_cannot_take_notes :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_app_area_loose")
	defer os.remove_all(dir)
	area := testkit.write_file(t, dir, "a.are", testkit.area_text("A", testkit.BASE_ROOMS))
	s := init()
	s.generation = 1
	s, _ = step(s, load_now(1, area))
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return

	testing.expect(t, !area_inspector_data(s).can_add)
	s, _ = step(s, Note_Draft_Changed{"a note"})
	effect: Effect
	s, effect = step(s, Note_Added{})
	testing.expect(t, effect == nil)
	testing.expect(t, s.error != "", "the refusal is shown")
	testing.expect_value(t, len(s.world.ws.document.notes), 0)
}

@(test)
test_a_failed_save_is_shown :: proc(t: ^testing.T) {
	s := init()
	s, _ = step(s, Review_Saved{error = strings.clone("disk full", runtime.heap_allocator())})
	testing.expect_value(t, s.error, "disk full")
	finish(s)
}

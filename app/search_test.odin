/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:os"
import "core:testing"

import "../testkit"

@(private = "file")
entries :: proc(values: ..Search_Entry) -> []Search_Entry {
	out := make([]Search_Entry, len(values), context.temp_allocator)
	copy(out, values)
	return out
}

@(test)
test_search_ranks_vnum_exact_prefix_contains :: proc(t: ^testing.T) {
	index := entries(
		{Room_Ref{0, 0}, 3001, "the temple"},
		{Room_Ref{0, 1}, 3002, "temple square"},
		{Room_Ref{0, 2}, 3003, "temple"},
		{Room_Ref{1, 0}, 42, "room 3001's twin"},
		{Room_Ref{1, 1}, 3001, "duplicate vnum"},
		{Room_Ref{1, 2}, 50, "market"},
	)
	hits, total := search_rooms(index, "TEMPLE", 10, context.temp_allocator)
	testing.expect_value(t, total, 3)
	testing.expect_value(t, len(hits), 3)
	testing.expect_value(t, hits[0], Room_Ref{0, 2}) // Exact name
	testing.expect_value(t, hits[1], Room_Ref{0, 1}) // Starts with it
	testing.expect_value(t, hits[2], Room_Ref{0, 0}) // Contains it

	// A vnum finds every room with it first, then names that mention it.
	hits, total = search_rooms(index, "3001", 10, context.temp_allocator)
	if !testing.expect_value(t, len(hits), 3) do return
	testing.expect_value(t, hits[0], Room_Ref{0, 0})
	testing.expect_value(t, hits[1], Room_Ref{1, 1})
	testing.expect_value(t, hits[2], Room_Ref{1, 0})
	// With a "#" (and spaces) it is only a vnum: no name contains "#3001".
	hits, total = search_rooms(index, "  #3001 ", 10, context.temp_allocator)
	testing.expect_value(t, total, 2)
	if !testing.expect_value(t, len(hits), 2) do return
	testing.expect_value(t, hits[0], Room_Ref{0, 0})
	testing.expect_value(t, hits[1], Room_Ref{1, 1})
}

@(test)
test_search_limit_and_blank_queries :: proc(t: ^testing.T) {
	index := entries({Room_Ref{0, 0}, 1, "road"}, {Room_Ref{0, 1}, 2, "road"}, {Room_Ref{0, 2}, 3, "side road"}, {Room_Ref{0, 3}, 4, "a road"})
	hits, total := search_rooms(index, "road", 2, context.temp_allocator)
	testing.expect_value(t, total, 4) // Every match is counted...
	testing.expect_value(t, len(hits), 2) // ...but only the best are kept
	testing.expect_value(t, hits[0], Room_Ref{0, 0})
	testing.expect_value(t, hits[1], Room_Ref{0, 1})

	for query in ([]string{"", "   "}) {
		hits, total = search_rooms(index, query, 10, context.temp_allocator)
		testing.expect_value(t, len(hits), 0)
		testing.expect_value(t, total, 0)
	}
	hits, total = search_rooms(index, "nowhere", 10, context.temp_allocator)
	testing.expect_value(t, total, 0)
	hits, total = search_rooms(index, "#", 10, context.temp_allocator)
	testing.expect_value(t, total, 0) // Not a vnum, and no name has a "#"
}

@(test)
test_search_index_and_latin1_names :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_app_search_index")
	defer os.remove_all(dir)
	// "Café" in Latin-1, and a second area that sorts first in the picker.
	list := testkit.write_world(t, dir, testkit.area_text("Zed", "#100\nCaf\xe9 Royale~\n~\ncity\nS\n"), testkit.area_text("Alpha", "#150\nGate~\n~\ncity\nS\n"))
	world, error := world_open(paths(list))
	defer world_close(world)
	if !testing.expectf(t, error == "", "%s", error) do return

	index := world.search_index
	if !testing.expect_value(t, len(index), 2) do return
	testing.expect_value(t, index[0].ref, Room_Ref{1, 0}) // Picker order: Alpha first
	testing.expect_value(t, index[1].name, "café royale")
	hits, _ := search_rooms(index, "CAFÉ", 10, context.temp_allocator)
	testing.expect_value(t, len(hits), 1)
}

@(test)
test_search_in_the_gui :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_app_search_step")
	defer os.remove_all(dir)
	room_b := "#200\nGate~\n~\ncity\nS\n#201\nGatehouse~\n~\ncity\nS\n"
	list := testkit.write_world(t, dir, testkit.area_text("A", testkit.BASE_ROOMS), testkit.area_text("B", room_b))
	s := init()
	s.generation = 1
	s, _ = step(s, load_now(1, list))
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return
	effect: Effect

	s, _ = step(s, Search_Changed{"gate"})
	testing.expect_value(t, s.search, "gate")
	testing.expect_value(t, s.search_total, 2)
	if !testing.expect_value(t, len(s.search_hits), 2) do return
	testing.expect_value(t, s.search_hits[0], Room_Ref{1, 0})

	// Choosing from the area map goes to the room graph, in the room's area.
	s, _ = step(s, Center_Chosen{.Areas})
	s, effect = step(s, Search_Chosen{s.search_hits[1]})
	testing.expect_value(t, s.center, Center_View.Rooms)
	testing.expect_value(t, s.area, 1)
	testing.expect_value(t, s.selected_room, 1)
	testing.expect_value(t, s.graph.focus, 1) // Centred once the new area is fitted
	testing.expect_value(t, s.search, "")
	testing.expect_value(t, len(s.search_hits), 0)
	_, is_redraw := effect.(Redraw_Soon)
	testing.expect(t, is_redraw)

	// A result out of range is ignored; a reload clears the search.
	s, effect = step(s, Search_Chosen{Room_Ref{5, 0}})
	testing.expect(t, effect == nil)
	testing.expect_value(t, s.area, 1)
	s, _ = step(s, Search_Changed{"100"})
	testing.expect_value(t, s.search_total, 1)
	s.generation = 2
	s, _ = step(s, load_now(2, list))
	testing.expect_value(t, s.search, "")
	testing.expect_value(t, s.search_total, 0)
}

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:os"
import "core:path/filepath"
import "core:testing"

import "../models"
import "../testkit"

@(test)
test_area_sort_key :: proc(t: ^testing.T) {
	testing.expect_value(t, area_sort_key("The Dragon Tower"), "dragon tower")
	testing.expect_value(t, area_sort_key("  the   Dale "), "dale")
	testing.expect_value(t, area_sort_key("A Mad Tea Party"), "mad tea party")
	testing.expect_value(t, area_sort_key("An Old Mill"), "old mill")
	testing.expect_value(t, area_sort_key("Midgaard"), "midgaard")
	// Only whole leading words count.
	testing.expect_value(t, area_sort_key("Theramore"), "theramore")
	testing.expect_value(t, area_sort_key("Anvil Pass"), "anvil pass")
	testing.expect_value(t, area_sort_key("The"), "the") // Nothing after it: keep it
	testing.expect_value(t, area_sort_key(""), "")
}

@(test)
test_area_label :: proc(t: ^testing.T) {
	testing.expect_value(t, area_label("Midgaard", "midgaard.are", context.temp_allocator), "Midgaard (midgaard.are)")
	// Loose files: only the base name is shown.
	testing.expect_value(t, area_label("Midgaard", "test_data/valid/midgaard.are", context.temp_allocator), "Midgaard (midgaard.are)")
	testing.expect_value(t, area_label("  ", "x.are", context.temp_allocator), "x.are (no name)")
}

@(test)
test_area_picker_order :: proc(t: ^testing.T) {
	named :: proc(name: string) -> models.Area {
		return models.Area{header = {name = name}}
	}
	areas := []models.Area{named("The Dragon Tower"), named("midgaard"), named("Abyss"), named("The Dale"), named("Midgaard"), named("")}
	pointers := make([]^models.Area, len(areas), context.temp_allocator)
	for &a, i in areas {
		pointers[i] = &a
	}
	names := []string{"dragon.are", "zz_mid.are", "abyss.are", "dale.are", "aa_mid.are", "social.are"}
	order := area_picker_order(pointers, names, context.temp_allocator)
	// Abyss, Dale, Dragon Tower, the two Midgaards by file name, then the
	// unnamed area under its file name, "social.are".
	testing.expect_value(t, len(order), 6)
	expected := []int{2, 3, 0, 4, 1, 5}
	for want, i in expected {
		testing.expect_value(t, order[i], want)
	}
}

@(test)
test_world_picker_and_first_area :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_app_picker")
	defer os.remove_all(dir)
	// a.are "Zed" (has rooms), b.are "The Empty" (no rooms), c.are "Bee" (has rooms).
	list := testkit.write_world(t, dir, testkit.area_text("Zed", testkit.BASE_ROOMS), testkit.area_text("The Empty", ""), testkit.area_text("Bee", "#110\nX~\n~\ncity\nS\n"))
	world, error := world_open(paths(list))
	defer world_close(world)
	if !testing.expectf(t, error == "", "%s", error) do return
	testing.expect_value(t, world.picker_labels[0], "Bee (c.are)")
	testing.expect_value(t, world.picker_labels[1], "The Empty (b.are)") // Sorted under E
	testing.expect_value(t, world.picker_labels[2], "Zed (a.are)")
	// The first area shown is the first in picker order that has rooms.
	testing.expect_value(t, first_area_with_rooms(world), 2)
}

@(test)
test_same_file_name_in_two_folders_gets_distinct_labels :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_app_same_name")
	defer os.remove_all(dir)
	for sub in ([]string{"one", "two"}) {
		path, _ := filepath.join({dir, sub}, context.temp_allocator)
		testing.expect(t, os.make_directory(path) == nil)
		testkit.write_file(t, path, "x.are", testkit.area_text("Same", ""))
	}
	one, _ := filepath.join({dir, "one", "x.are"}, context.temp_allocator)
	two, _ := filepath.join({dir, "two", "x.are"}, context.temp_allocator)
	world, error := world_open(paths(one, two))
	defer world_close(world)
	if !testing.expectf(t, error == "", "%s", error) do return
	testing.expect_value(t, world.labels[0], "Same (x.are)")
	testing.expect(t, world.labels[1] != world.labels[0], "the second gets its full path")
}

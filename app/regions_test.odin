/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:testing"

import "gui:skald"

import "../components"

@(test)
test_next_region :: proc(t: ^testing.T) {
	s := init()
	regions := world_regions(s)
	testing.expect_value(t, regions[0], skald.hash_id(AREA_PICKER_ID))
	testing.expect_value(t, regions[1], skald.hash_id(components.INSPECTOR_SCROLL_ID))
	testing.expect_value(t, regions[2], skald.hash_id(components.ROOM_GRAPH_ID))

	// F6 goes round in order; Shift+F6 the other way.
	testing.expect_value(t, next_region(regions, regions[0], 1), 1)
	testing.expect_value(t, next_region(regions, regions[1], 1), 2)
	testing.expect_value(t, next_region(regions, regions[2], 1), 0)
	testing.expect_value(t, next_region(regions, regions[0], -1), 2)
	testing.expect_value(t, next_region(regions, regions[2], -1), 1)

	// From nowhere: the first going forward, the last going back.
	testing.expect_value(t, next_region(regions, 0, 1), 0)
	testing.expect_value(t, next_region(regions, 0, -1), 2)
	// The search box is part of the toolbar.
	search := skald.hash_id(SEARCH_INPUT_ID)
	testing.expect_value(t, next_region(regions, search, 1), 1)
	testing.expect_value(t, next_region(regions, search, -1), 2)

	// On the area map, the map region is its canvas.
	s.center = .Areas
	testing.expect_value(t, world_regions(s)[2], skald.hash_id(components.AREA_MAP_ID))
	finish(s)
}

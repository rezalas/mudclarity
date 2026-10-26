/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:log"
import "core:mem/virtual"
import "core:path/filepath"
import "core:testing"
import "core:time"

import "../components"

/*
 Opens the whole Riftshadow world as the GUI's loading thread does.
 Skipped unless built with -define:MUDCLARITY_CORPUS_DIR=/path/to/riftshadow/area.
 The corpus is only read, never written.
*/
CORPUS_DIR :: #config(MUDCLARITY_CORPUS_DIR, "")

@(test)
test_corpus_world :: proc(t: ^testing.T) {
	when CORPUS_DIR == "" {
		log.info("corpus test skipped: build with -define:MUDCLARITY_CORPUS_DIR=<riftshadow/area>")
	} else {
		open_corpus(t, CORPUS_DIR)
	}
}

@(private = "file")
open_corpus :: proc(t: ^testing.T, dir: string) {
	list, _ := filepath.join({dir, "area.lst"}, context.temp_allocator)
	start := time.now()
	world, error := world_open(paths(list))
	defer world_close(world)
	if !testing.expectf(t, error == "", "%s", error) do return
	elapsed := time.since(start)
	// The workspace (2.5 s) and layouts (250 ms) budgets, plus the rest.
	testing.expectf(t, time.duration_seconds(elapsed) < 3, "opening the world took %v", elapsed)

	// The area map again on its own, to see what it costs.
	start = time.now()
	build_area_map(world, virtual.arena_allocator(&world.arena))
	map_time := time.since(start)
	m := world.area_map
	testing.expect_value(t, len(m.positions), len(world.ws.areas))
	testing.expect(t, len(m.links) > 0)
	testing.expectf(t, time.duration_seconds(map_time) < 0.25, "the area map took %v", map_time)
	// Areas without links once ended up ~10,000 units out.
	lo, hi := components.map_bounds(m.positions, m.rooms)
	testing.expectf(t, hi.x - lo.x < 6000 && hi.y - lo.y < 6000, "the area map is %v across", hi - lo)
	log.infof("corpus: world of %d areas opened in %v; area map with %d links, %v across, in %v", len(world.ws.areas), elapsed, len(m.links), hi - lo, map_time)
}

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package layout

import "core:log"
import "core:mem/virtual"
import "core:path/filepath"
import "core:testing"
import "core:time"

import "../formats"

/*
 Lays out every area in the Riftshadow world and checks each layout.
 Skipped unless built with -define:MUDCLARITY_CORPUS_DIR=/path/to/riftshadow/area.
*/
CORPUS_DIR :: #config(MUDCLARITY_CORPUS_DIR, "")

@(test)
test_corpus_layouts :: proc(t: ^testing.T) {
	when CORPUS_DIR == "" {
		log.info("corpus test skipped: build with -define:MUDCLARITY_CORPUS_DIR=<riftshadow/area>")
	} else {
		layout_corpus(t, CORPUS_DIR)
	}
}

@(private = "file")
layout_corpus :: proc(t: ^testing.T, dir: string) {
	list, _ := filepath.join({dir, "area.lst"}, context.temp_allocator)
	set, err := formats.load_area_set(list)
	defer formats.unload_area_set(&set)
	if !testing.expect(t, err == nil && len(set.failures) == 0) do return

	// One arena for every layout, as the GUI will hold them.
	arena: virtual.Arena
	if !testing.expect(t, virtual.arena_init_growing(&arena) == nil) do return
	defer virtual.arena_destroy(&arena)
	allocator := virtual.arena_allocator(&arena)

	layouts := make([]Layout, len(set.loaded), context.temp_allocator)
	start := time.now()
	for loaded, i in set.loaded {
		layouts[i] = compute(&loaded.area, allocator)
	}
	elapsed := time.since(start)

	rooms, bent, displaced, components, externals := 0, 0, 0, 0, 0
	for loaded, i in set.loaded {
		l := &layouts[i]
		expect_valid(t, &loaded.area, l)
		rooms += len(l.rooms)
		components += len(l.components)
		externals += len(l.externals)
		for r in l.rooms {
			displaced += 1 if r.is_displaced else 0
		}
		for e in l.edges {
			bent += 1 if e.kind == .Bent else 0
		}
	}
	// Laying out is done once per load, but should not hold up opening.
	testing.expectf(t, time.duration_milliseconds(elapsed) < 250, "laying out the world took %v", elapsed)
	log.infof(
		"corpus: laid out %d areas, %d rooms in %v: %d components, %d displaced rooms, %d bent edges, %d external exits",
		len(layouts),
		rooms,
		elapsed,
		components,
		displaced,
		bent,
		externals,
	)
}

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:log"
import "core:path/filepath"
import "core:testing"
import "core:time"

/*
 Parses every area listed in a real Riftshadow area.lst. Skipped unless the
 tests are built with:
   -define:MUDCLARITY_CORPUS_DIR=/path/to/riftshadow/area
 (build.sh does this when RIFTSHADOW_AREA_DIR is set.)
*/
CORPUS_DIR :: #config(MUDCLARITY_CORPUS_DIR, "")

// Parse budget from CLAUDE.md: 1 MB in under 100 ms. Small files get a floor
// so timer noise can't fail the run.
CORPUS_MS_PER_MB :: 100.0
CORPUS_MIN_BUDGET_MS :: 20.0

@(test)
test_corpus_parses_every_listed_area :: proc(t: ^testing.T) {
	when CORPUS_DIR == "" {
		log.info("corpus test skipped: build with -define:MUDCLARITY_CORPUS_DIR=<riftshadow/area>")
	} else {
		parse_corpus(t, CORPUS_DIR)
	}
}

// Parse every area listed in `dir`/area.lst, checking errors and parse time.
@(private = "file")
parse_corpus :: proc(t: ^testing.T, dir: string) {
	list_path, _ := filepath.join({dir, "area.lst"}, context.temp_allocator)
	list_data, list_err := read_file_capped(list_path, MAX_AREA_LIST_SIZE, context.temp_allocator)
	if !testing.expectf(t, list_err == nil, "could not read %s: %v", list_path, list_err) {
		return
	}
	names, names_err := parse_area_list(list_data, context.temp_allocator)
	if !testing.expectf(t, names_err == nil, "could not parse area.lst: %v", names_err) {
		return
	}
	testing.expect(t, len(names) > 0, "area.lst lists no areas")

	total_rooms := 0
	for name in names {
		path, _ := filepath.join({dir, name}, context.temp_allocator)
		start := time.tick_now()
		loaded, err := load_area_file(path)
		elapsed := time.duration_milliseconds(time.tick_since(start))
		if err != nil {
			testing.expectf(t, false, "%s", parse_error_to_string(err, name, context.temp_allocator))
			continue
		}
		size_mb := f64(len(loaded.data)) / (1024 * 1024)
		budget := max(size_mb * CORPUS_MS_PER_MB, CORPUS_MIN_BUDGET_MS)
		testing.expectf(t, elapsed <= budget, "%s took %.1f ms to parse (budget %.1f ms)", name, elapsed, budget)
		log.debugf("%s: %d rooms, %d mobs, %d objects, %d resets in %.2f ms", name, len(loaded.area.rooms), len(loaded.area.mobiles), len(loaded.area.objects), len(loaded.area.resets), elapsed)
		total_rooms += len(loaded.area.rooms)
		unload_area(loaded)
	}
	log.infof("corpus: parsed %d areas, %d rooms", len(names), total_rooms)
}

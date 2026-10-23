/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package validation

import "core:log"
import "core:path/filepath"
import "core:testing"
import "core:time"

import "../formats"

/*
 Validates the whole Riftshadow world. Skipped unless built with
   -define:MUDCLARITY_CORPUS_DIR=/path/to/riftshadow/area
 (build.sh does this when RIFTSHADOW_AREA_DIR is set.)
*/
CORPUS_DIR :: #config(MUDCLARITY_CORPUS_DIR, "")
CORPUS_VALIDATE_BUDGET_MS :: 500.0

@(test)
test_corpus_validates :: proc(t: ^testing.T) {
	when CORPUS_DIR == "" {
		log.info("corpus test skipped: build with -define:MUDCLARITY_CORPUS_DIR=<riftshadow/area>")
	} else {
		validate_corpus(t, CORPUS_DIR)
	}
}

@(private = "file")
validate_corpus :: proc(t: ^testing.T, dir: string) {
	list_path, _ := filepath.join({dir, "area.lst"}, context.temp_allocator)
	set, err := formats.load_area_set(list_path)
	defer formats.unload_area_set(&set)
	if !testing.expectf(t, err == nil, "could not load %s: %v", list_path, err) {
		return
	}
	testing.expectf(t, len(set.failures) == 0, "%d areas failed to parse", len(set.failures))
	areas := formats.area_set_areas(&set, context.temp_allocator)

	start := time.tick_now()
	diagnostics := validate(areas, len(set.failures) == 0, context.temp_allocator)
	elapsed := time.duration_milliseconds(time.tick_since(start))
	testing.expectf(t, elapsed <= CORPUS_VALIDATE_BUDGET_MS, "validation took %.1f ms (budget %.0f ms)", elapsed, CORPUS_VALIDATE_BUDGET_MS)

	for d in diagnostics {
		testing.expect(t, d.area >= 0 && d.area < len(areas))
		testing.expect(t, d.line >= 1 && d.message != "")
	}
	severities := count_by_severity(diagnostics)
	log.infof("corpus: %d areas validated in %.1f ms: %d errors, %d warnings, %d info", len(areas), elapsed, severities[.Error], severities[.Warning], severities[.Info])
	for count, check in count_by_check(diagnostics) {
		if count > 0 {
			log.infof("  %v: %d", check, count)
		}
	}
}

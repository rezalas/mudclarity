/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package workspace

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:testing"
import "core:time"

/*
 Opens the whole Riftshadow world through a Workspace, as the CLI and GUI do.
 Skipped unless built with -define:MUDCLARITY_CORPUS_DIR=/path/to/riftshadow/area.
 The corpus (including any area.clarity in it) is only read, never written.
*/
CORPUS_DIR :: #config(MUDCLARITY_CORPUS_DIR, "")

@(test)
test_corpus_workspace :: proc(t: ^testing.T) {
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
	ws := open_or_fail(t, list)
	defer close(ws)
	if ws == nil do return
	elapsed := time.since(start)

	testing.expect_value(t, len(ws.set.failures), 0)
	testing.expect(t, ws.is_complete)
	testing.expect(t, len(ws.diagnostics) > 0)
	testing.expect_value(t, len(ws.names), len(ws.areas))
	// Within the parse budget (2 s) plus validation and hashing.
	testing.expectf(t, time.duration_seconds(elapsed) < 2.5, "opening the world took %v", elapsed)
	result := merge(ws, context.temp_allocator)
	testing.expect_value(t, len(result.findings), len(ws.diagnostics))
	log.infof("corpus: workspace with %d areas, %d findings, review file %s in %v", len(ws.areas), len(ws.diagnostics), "found" if os.exists(ws.clarity_path) else "absent", elapsed)
}

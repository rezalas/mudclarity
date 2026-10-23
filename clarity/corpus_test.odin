/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package clarity

import "core:log"
import "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:testing"

import "../formats"
import "../validation"

/*
 Saves a review file for the whole Riftshadow world and reads it back.
 Skipped unless built with -define:MUDCLARITY_CORPUS_DIR=/path/to/riftshadow/area.
 The .clarity file is written to a temporary directory, never the corpus.
*/
CORPUS_DIR :: #config(MUDCLARITY_CORPUS_DIR, "")

@(test)
test_corpus_review_file :: proc(t: ^testing.T) {
	when CORPUS_DIR == "" {
		log.info("corpus test skipped: build with -define:MUDCLARITY_CORPUS_DIR=<riftshadow/area>")
	} else {
		review_corpus(t, CORPUS_DIR)
	}
}

@(private = "file")
review_corpus :: proc(t: ^testing.T, dir: string) {
	arena: virtual.Arena
	if !testing.expect(t, test_arena(&arena) == nil) do return
	defer virtual.arena_destroy(&arena)
	allocator := virtual.arena_allocator(&arena)

	list_path, _ := filepath.join({dir, "area.lst"}, context.temp_allocator)
	set, err := formats.load_area_set(list_path)
	defer formats.unload_area_set(&set)
	if !testing.expect(t, err == nil && len(set.failures) == 0) do return

	areas := formats.area_set_areas(&set, context.temp_allocator)
	diagnostics := validation.validate(areas, true, context.temp_allocator)
	files := make([]File_Entry, len(set.loaded), context.temp_allocator)
	names := make([]string, len(set.loaded), context.temp_allocator)
	hashes := make([]string, len(set.loaded), context.temp_allocator)
	for loaded, i in set.loaded {
		files[i] = file_entry_for(loaded.area.source_name, loaded, context.temp_allocator)
		names[i] = files[i].name
		hashes[i] = files[i].sha256
	}

	doc := document_make("area.lst", allocator)
	refresh(&doc, files, diagnostics, allocator)
	out_dir := temp_dir(t, "mudclarity_clarity_corpus")
	defer os.remove_all(out_dir)
	path, _ := filepath.join({out_dir, "area.clarity"}, context.temp_allocator)
	if !testing.expect(t, save_document(path, &doc) == nil) do return

	loaded, load_err := load_document(path, allocator)
	if !testing.expectf(t, load_err == nil, "%v", load_err) do return
	testing.expect_value(t, len(loaded.files), len(set.loaded))
	testing.expect_value(t, len(loaded.snapshot), len(diagnostics))

	result := merge(&loaded, names, hashes, diagnostics, context.temp_allocator)
	testing.expect_value(t, result.state_counts[.Open], len(diagnostics))
	testing.expect_value(t, result.new_count, 0)
	testing.expect_value(t, len(result.fixed), 0)
	testing.expect_value(t, len(result.changed_files), 0)

	again_path, _ := filepath.join({out_dir, "again.clarity"}, context.temp_allocator)
	testing.expect(t, save_document(again_path, &loaded) == nil)
	first, _ := os.read_entire_file(path, context.temp_allocator)
	second, _ := os.read_entire_file(again_path, context.temp_allocator)
	testing.expect(t, string(first) == string(second), "corpus document did not round-trip byte for byte")
	log.infof("corpus: review file for %d areas, %d findings, %d bytes", len(loaded.files), len(loaded.snapshot), len(first))
}

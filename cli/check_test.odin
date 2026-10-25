/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package cli

import "core:os"
import "core:strings"
import "core:testing"

import "../testkit"

@(test)
test_check_area_list :: proc(t: ^testing.T) {
	dir, list := base_world(t, "mudclarity_cli_check")
	defer os.remove_all(dir)

	// Same with and without the command name.
	for r in ([]Cli_Result{run_cli(list), run_cli("check", list)}) {
		testing.expect_value(t, r.code, EXIT_FAILED) // The broken exit is an error
		testing.expect_value(t, r.err, "")
		expect_contains(t, r.out, "a.are:")
		expect_contains(t, r.out, ": error Broken_Exit [#100]: ")
		expect_contains(t, r.out, "{" + testkit.BROKEN_EXIT_ID + "}")
		expect_contains(t, r.out, "\n1 areas, 3 rooms: 1 errors, 3 warnings, 0 info\n")
		expect_contains(t, r.out, "  Broken_Exit                  1  (1 error)\n")
		expect_contains(t, r.out, "review (area.clarity): 4 open, 0 flagged, 0 accepted, 0 need review")
		expect_contains(t, r.out, "not saved yet")
	}
}

@(test)
test_check_passes_without_errors :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_cli_check_clean")
	defer os.remove_all(dir)
	// A lone room: warnings only.
	list := testkit.write_world(t, dir, testkit.area_text("A", "#100\nA~\n~\ncity\nS\n"))
	r := run_cli(list)
	testing.expect_value(t, r.code, EXIT_OK)
	expect_contains(t, r.out, "0 errors")
}

@(test)
test_check_loose_files :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_cli_check_loose")
	defer os.remove_all(dir)
	good := testkit.write_file(t, dir, "good.are", testkit.area_text("A", testkit.BASE_ROOMS))
	bad := testkit.write_file(t, dir, "bad.are", "#AREA\nunterminated")

	r := run_cli(good, bad)
	testing.expect_value(t, r.code, EXIT_FAILED)
	expect_contains(t, r.err, bad) // The parse failure names the file
	expect_contains(t, r.out, "1 areas, 3 rooms")
	testing.expectf(t, !strings.contains(r.out, "review ("), "loose files have no review section:\n%s", r.out)
}

@(test)
test_check_after_accepting :: proc(t: ^testing.T) {
	dir, list := base_world(t, "mudclarity_cli_check_accepted")
	defer os.remove_all(dir)
	testing.expect_value(t, run_cli("save", list).code, EXIT_OK)
	testing.expect_value(t, run_cli("accept", list, testkit.BROKEN_EXIT_ID, "on", "purpose").code, EXIT_OK)

	// The only error is accepted: check passes and hides it.
	r := run_cli(list)
	testing.expect_value(t, r.code, EXIT_OK)
	testing.expect(t, !strings.contains(r.out, testkit.BROKEN_EXIT_ID), r.out)
	expect_contains(t, r.out, "1 accepted (hidden; --all shows them)")
	expect_contains(t, r.out, "since last save: 0 new, 0 fixed")

	all := run_cli(list, "--all")
	expect_contains(t, all.out, "{" + testkit.BROKEN_EXIT_ID + "}")
	expect_contains(t, all.out, " [accepted]")
}

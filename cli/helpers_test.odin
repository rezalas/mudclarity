/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package cli

import "core:strings"
import "core:testing"

import "../testkit"

// Shared helpers for the CLI tests.

// What a command line printed and returned.
Cli_Result :: struct {
	code: int,
	out:  string,
	err:  string,
}

// Run a command line, capturing its output (in the temp allocator).
run_cli :: proc(args: ..string) -> Cli_Result {
	out, err: strings.Builder
	strings.builder_init(&out, context.temp_allocator)
	strings.builder_init(&err, context.temp_allocator)
	code := run(args, Output{out = strings.to_writer(&out), err = strings.to_writer(&err)})
	return Cli_Result{code, strings.to_string(out), strings.to_string(err)}
}

// Write a one-area world (BASE_ROOMS: one error, three warnings) to a new
// temp dir named `name`. Returns the dir and its area.lst; remove the dir
// with os.remove_all.
base_world :: proc(t: ^testing.T, name: string) -> (dir, list: string) {
	dir = testkit.temp_dir(t, name)
	list = testkit.write_world(t, dir, testkit.area_text("A", testkit.BASE_ROOMS))
	return
}

// Expect `text` to contain `part`.
expect_contains :: proc(t: ^testing.T, text, part: string, loc := #caller_location) {
	testing.expectf(t, strings.contains(text, part), "expected %q in:\n%s", part, text, loc = loc)
}

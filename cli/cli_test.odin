/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package cli

import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

import "../testkit"

@(test)
test_usage_lists_every_command :: proc(t: ^testing.T) {
	for args in ([][]string{{}, {"save"}, {"--all"}}) {
		r := run_cli(..args)
		testing.expect_value(t, r.code, EXIT_USAGE)
		testing.expect_value(t, r.out, "")
		expect_contains(t, r.err, "usage:")
		for command in COMMANDS {
			expect_contains(t, r.err, command.arguments)
			expect_contains(t, r.err, strings.split_lines(command.summary, context.temp_allocator)[0])
		}
	}
}

@(test)
test_edit_commands_need_an_area_list :: proc(t: ^testing.T) {
	r := run_cli("accept", "midgaard.are", "id")
	testing.expect_value(t, r.code, EXIT_USAGE)
	testing.expect_value(t, r.err, "accept needs an area.lst, not midgaard.are\n")
}

@(test)
test_missing_arguments_print_command_usage :: proc(t: ^testing.T) {
	dir, list := base_world(t, "mudclarity_cli_missing_args")
	defer os.remove_all(dir)
	for name in ([]string{"accept", "flag", "reopen", "note", "issue"}) {
		r := run_cli(name, list)
		testing.expect_value(t, r.code, EXIT_USAGE)
		command := find_command(name)
		expect_contains(t, r.err, strings.concatenate({"usage: mudclarity ", name, " ", command.arguments}, context.temp_allocator))
	}
	// Nothing was written.
	testing.expect(t, !os.exists(filepath.join({dir, "area.clarity"}, context.temp_allocator) or_else ""))
}

@(test)
test_unreadable_area_list :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_cli_no_list")
	defer os.remove_all(dir)
	list, _ := filepath.join({dir, "area.lst"}, context.temp_allocator)
	r := run_cli(list)
	testing.expect_value(t, r.code, EXIT_FAILED)
	testing.expect(t, strings.has_prefix(r.err, list), r.err)
}

@(test)
test_find_command :: proc(t: ^testing.T) {
	testing.expect(t, find_command("check") == &COMMANDS[0])
	testing.expect(t, find_command("issue") != nil)
	testing.expect(t, find_command("area.lst") == nil)
}

@(test)
test_help :: proc(t: ^testing.T) {
	for flag in ([]string{"help", "--help", "-h"}) {
		r := run_cli(flag)
		testing.expect_value(t, r.code, EXIT_OK)
		testing.expect_value(t, r.err, "")
		expect_contains(t, r.out, "usage:")
		expect_contains(t, r.out, "mudclarity open <area.lst | file.are...>")
	}
}

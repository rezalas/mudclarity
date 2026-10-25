/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package cli

import "core:fmt"
import "core:strings"

// A command-line command. The usage text is built from these, so adding a
// command here documents it.
Command :: struct {
	name:            string,
	arguments:       string, // As shown in the usage, after the name
	summary:         string,
	needs_area_list: bool,   // Takes an area.lst (it edits area.clarity)
	min_args:        int,    // Arguments required after the area.lst
	run:             proc(c: ^Call) -> int,
}

// `check` comes first: it is the command when none is named.
COMMANDS := [?]Command {
	{
		name      = "check",
		arguments = "<area.lst | file.are...> [--all]",
		summary   = "Validate areas. With an area.lst, findings are compared with area.clarity\nnext to it; accepted findings are hidden unless --all is given.",
		run       = run_check,
	},
	{
		name            = "save",
		arguments       = "<area.lst>",
		summary         = "Record files, hashes and findings in area.clarity.",
		needs_area_list = true,
		run             = run_save,
	},
	{
		name            = "accept",
		arguments       = "<area.lst> <finding-id> [note]",
		summary         = "Mark a finding as intended (e.g. a deliberate maze).",
		needs_area_list = true,
		min_args        = 1,
		run             = run_decide,
	},
	{
		name            = "flag",
		arguments       = "<area.lst> <finding-id> [note]",
		summary         = "Mark a finding as a problem to fix.",
		needs_area_list = true,
		min_args        = 1,
		run             = run_decide,
	},
	{
		name            = "reopen",
		arguments       = "<area.lst> <finding-id>",
		summary         = "Remove the decision on a finding.",
		needs_area_list = true,
		min_args        = 1,
		run             = run_reopen,
	},
	{
		name            = "note",
		arguments       = "<area.lst> <file> <area|room|mob|object> <vnum> <text>",
		summary         = "Attach a note to an area or a record.",
		needs_area_list = true,
		min_args        = 4,
		run             = run_note,
	},
	{
		name            = "issue",
		arguments       = "<area.lst> <file> <area|room|mob|object> <vnum> <title>",
		summary         = "Open an issue on an area or a record.",
		needs_area_list = true,
		min_args        = 4,
		run             = run_issue,
	},
}

USAGE_FOOTER :: `Finding ids are printed at the end of each finding, e.g. {mtcim.are:Mismatched_Return:218:219}.
Exits with 1 if a file fails to parse or an unaccepted error is found.`

// The command named `name`, or nil.
find_command :: proc(name: string) -> ^Command {
	for &command in COMMANDS {
		if command.name == name {
			return &command
		}
	}
	return nil
}

// The usage text, built from COMMANDS. Allocated with the temp allocator.
usage :: proc() -> string {
	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	strings.write_string(&b, "usage:\n")
	strings.write_string(&b, "  mudclarity\n      Open the window. `mudclarity open <area.lst | file.are...>` opens it on a world.\n")
	for command, i in COMMANDS {
		name := "[check]" if i == 0 else command.name
		fmt.sbprintfln(&b, "  mudclarity %s %s", name, command.arguments)
		summary := command.summary
		for line in strings.split_lines_iterator(&summary) {
			fmt.sbprintfln(&b, "      %s", line)
		}
	}
	strings.write_string(&b, "\n")
	strings.write_string(&b, USAGE_FOOTER)
	return strings.to_string(b)
}

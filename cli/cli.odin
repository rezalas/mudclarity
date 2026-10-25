/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package cli

import "core:fmt"
import "core:io"
import "core:os"
import "core:slice"

import "../formats"
import "../workspace"

/*
 The command-line interface: validating areas and editing the review file.
 Commands are listed in COMMANDS (commands.odin); each one lives in its own
 file. Nothing here calls os.exit, so run can be tested: it returns the exit
 code and writes to the given Output.

 Memory: everything a command allocates is temporary (the temp allocator)
 or belongs to the workspace it opens, which is closed before run returns.
*/

EXIT_OK :: 0
EXIT_FAILED :: 1 // A file failed to parse, an unaccepted error was found, or I/O failed
EXIT_USAGE :: 2  // Bad arguments or a refused edit

// Where a command's output goes. Tests pass string builders.
Output :: struct {
	out: io.Writer,
	err: io.Writer,
}

// Output to the process's stdout and stderr.
std_output :: proc() -> Output {
	return Output{out = os.to_writer(os.stdout), err = os.to_writer(os.stderr)}
}

// What a command's run procedure is given.
Call :: struct {
	output:   Output,
	command:  ^Command,
	ws:       ^workspace.Workspace,
	args:     []string, // Arguments after the area list (for check: none)
	show_all: bool,     // --all was given
	today:    string,
}

// Run a command line (without the program name) and return the exit code.
// A first argument that isn't a command name means `check`.
run :: proc(args: []string, output: Output) -> int {
	args := args
	if len(args) == 1 && (args[0] == "help" || args[0] == "--help" || args[0] == "-h") {
		fmt.wprintln(output.out, usage())
		return EXIT_OK
	}
	command := &COMMANDS[0]
	if len(args) > 0 {
		if found := find_command(args[0]); found != nil {
			command = found
			args = args[1:]
		}
	}
	show_all := slice.contains(args, "--all")
	if show_all {
		args = slice.filter(args, proc(a: string) -> bool {return a != "--all"}, context.temp_allocator)
	}
	if len(args) == 0 {
		fmt.wprintln(output.err, usage())
		return EXIT_USAGE
	}

	call := Call {
		output   = output,
		command  = command,
		show_all = show_all,
		today    = workspace.today(context.temp_allocator),
	}
	paths := args
	if command.needs_area_list {
		if !workspace.is_area_list(args[0]) {
			return usage_error(&call, "%s needs an area.lst, not %s", command.name, args[0])
		}
		if len(args) - 1 < command.min_args {
			return usage_error(&call, "usage: mudclarity %s %s", command.name, command.arguments)
		}
		paths = args[:1]
		call.args = args[1:]
	}

	ws, ok := open_world(output, paths)
	if !ok {
		return EXIT_FAILED
	}
	defer workspace.close(ws)
	call.ws = ws
	return command.run(&call)
}

// Print a usage error and return EXIT_USAGE.
usage_error :: proc(c: ^Call, format: string, args: ..any) -> int {
	fmt.wprintfln(c.output.err, format, ..args)
	return EXIT_USAGE
}

// If an edit was refused, print why. Returns the exit code to stop with,
// or EXIT_OK to go on.
check_edit :: proc(c: ^Call, err: workspace.Error) -> int {
	if err == nil {
		return EXIT_OK
	}
	return usage_error(c, "%s", workspace.error_message(err, context.temp_allocator))
}

// Save area.clarity and print `done` (a format and its arguments) if that
// worked. Returns the exit code.
save_and_report :: proc(c: ^Call, done: string, args: ..any) -> int {
	if err := workspace.save(c.ws); err != nil {
		fmt.wprintln(c.output.err, workspace.error_message(err, context.temp_allocator))
		return EXIT_FAILED
	}
	fmt.wprintfln(c.output.out, done, ..args)
	return EXIT_OK
}

// Open an area list (the whole world) or loose area files, and report the
// files that failed to parse. Returns false, having said why, if the world
// can't be opened.
@(private = "file")
open_world :: proc(output: Output, paths: []string) -> (ws: ^workspace.Workspace, ok: bool) {
	err: workspace.Error
	if ws, err = workspace.open(paths); err != nil {
		fmt.wprintln(output.err, workspace.error_message(err, context.temp_allocator))
		return nil, false
	}
	for failure in ws.set.failures {
		fmt.wprintln(output.err, formats.parse_error_to_string(failure.error, failure.name, context.temp_allocator))
	}
	return ws, true
}

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 *
 * Description: Mud clarity provides MUD area file visualization, allowing
 * people to view areas, rooms, connections, and mob/entity assignments and
 * information, as well as identify errors in formatting, linkage, dead zones,
 * and other issues that may make games unplayable or less enjoyable.
 */
package main

import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"

import "clarity"
import "formats"
import "validation"
import "workspace"

/*
 This is the main entry point for the Mud Clarity application.
 Until the GUI exists, it validates areas and manages the .clarity review
 file from the command line. Run with no arguments for usage.
*/

USAGE :: `usage:
  mudclarity [check] <area.lst | file.are...> [--all]
      Validate areas. With an area.lst, findings are compared with area.clarity
      next to it; accepted findings are hidden unless --all is given.
  mudclarity save   <area.lst>                    Record files, hashes and findings in area.clarity
  mudclarity accept <area.lst> <finding-id> [note] Mark a finding as intended
  mudclarity flag   <area.lst> <finding-id> [note] Mark a finding as a problem to fix
  mudclarity reopen <area.lst> <finding-id>        Remove the decision on a finding
  mudclarity note   <area.lst> <file> <area|room|mob|object> <vnum> <text>
  mudclarity issue  <area.lst> <file> <area|room|mob|object> <vnum> <title>

Finding ids are printed at the end of each finding, e.g. {mtcim.are:Mismatched_Return:218:219}.
Exits with 1 if a file fails to parse or an unaccepted error is found.`

COMMANDS :: [?]string{"check", "save", "accept", "flag", "reopen", "note", "issue"}

main :: proc() {
	arena: virtual.Arena
	if virtual.arena_init_growing(&arena) != nil {
		fmt.eprintln("out of memory")
		os.exit(1)
	}
	context.allocator = virtual.arena_allocator(&arena)

	args := os.args[1:]
	if len(args) == 0 {
		fmt.eprintln(USAGE)
		os.exit(2)
	}
	command := "check"
	commands := COMMANDS
	if slice.contains(commands[:], args[0]) {
		command = args[0]
		args = args[1:]
	}
	show_all := slice.contains(args, "--all")
	if show_all {
		args = slice.filter(args, proc(a: string) -> bool {return a != "--all"})
	}
	if len(args) == 0 {
		fmt.eprintln(USAGE)
		os.exit(2)
	}

	if command == "check" {
		os.exit(run_check(args, show_all))
	}
	// Every other command edits area.clarity, so it needs an area list.
	if !strings.has_suffix(args[0], ".lst") {
		fail("%s needs an area.lst, not %s", command, args[0])
	}
	ws := open_world(args[:1])
	defer workspace.close(ws)
	rest := args[1:]
	today := workspace.today()

	switch command {
	case "save":
		edit_or_fail(workspace.record_run(ws))
		save_or_exit(ws)
		fmt.printfln("saved %s: %d files, %d findings", ws.clarity_path, len(ws.document.files), len(ws.document.snapshot))
	case "accept", "flag":
		if len(rest) < 1 do fail("%s needs a finding id", command)
		key, key_err := workspace.current_finding_key(ws, rest[0])
		if failure, ok := key_err.(workspace.Edit_Failure); ok && failure.kind == .Unknown_Finding {
			fail("%s; run check to see the ids", workspace.error_message(key_err))
		}
		edit_or_fail(key_err)
		status := clarity.REVIEW_ACCEPTED if command == "accept" else clarity.REVIEW_FLAGGED
		note := strings.join(rest[1:], " ")
		edit_or_fail(workspace.set_review(ws, key, status, note, today))
		save_or_exit(ws)
		fmt.printfln("%s %s", status, rest[0])
	case "reopen":
		if len(rest) < 1 do fail("reopen needs a finding id")
		key, ok := clarity.parse_finding_id(rest[0])
		if !ok do fail("no decision recorded for %s", rest[0])
		edit_or_fail(workspace.remove_review(ws, key, rest[0]))
		save_or_exit(ws)
		fmt.printfln("reopened %s", rest[0])
	case "note", "issue":
		if len(rest) < 4 do fail("%s needs <file> <kind> <vnum> <text>", command)
		file, kind := rest[0], rest[1]
		vnum, vnum_ok := strconv.parse_int(rest[2], 10)
		if !vnum_ok do fail("%s is not a vnum", rest[2])
		text := strings.join(rest[3:], " ")
		if command == "note" {
			edit_or_fail(workspace.add_note(ws, file, kind, vnum, text, today))
			save_or_exit(ws)
			fmt.printfln("added note to %s %s %d", file, kind, vnum)
		} else {
			id, err := workspace.add_issue(ws, file, kind, vnum, text, today)
			edit_or_fail(err)
			save_or_exit(ws)
			fmt.printfln("added issue #%d", id)
		}
	}
}

fail :: proc(format: string, args: ..any) -> ! {
	fmt.eprintfln(format, ..args)
	os.exit(2)
}

// Exit with a usage error if an edit was refused.
edit_or_fail :: proc(err: workspace.Error) {
	if err != nil {
		fail("%s", workspace.error_message(err))
	}
}

save_or_exit :: proc(ws: ^workspace.Workspace) {
	if err := workspace.save(ws); err != nil {
		fmt.eprintln(workspace.error_message(err))
		os.exit(1)
	}
}

// Open an area list (the whole world) or loose area files, and report the
// files that failed to parse.
open_world :: proc(paths: []string) -> ^workspace.Workspace {
	ws: ^workspace.Workspace
	err: workspace.Error
	if len(paths) == 1 && strings.has_suffix(paths[0], ".lst") {
		ws, err = workspace.open_area_list(paths[0])
	} else {
		ws, err = workspace.open_area_files(paths)
	}
	if err != nil {
		fmt.eprintln(workspace.error_message(err))
		os.exit(1)
	}
	for failure in ws.set.failures {
		fmt.eprintln(formats.parse_error_to_string(failure.error, failure.name))
	}
	return ws
}

SEVERITY_NAMES := [validation.Severity]string {
	.Error   = "error",
	.Warning = "warning",
	.Info    = "info",
}

STATE_TAGS := [clarity.State]string {
	.Open         = "",
	.Accepted     = " [accepted]",
	.Flagged      = " [flagged]",
	.Needs_Review = " [needs review: file changed]",
}

// Validate and print findings. Returns the exit code.
run_check :: proc(paths: []string, show_all: bool) -> int {
	ws := open_world(paths)
	defer workspace.close(ws)
	result := workspace.merge(ws)

	failing := len(ws.set.failures) > 0
	for f in result.findings {
		d := f.diagnostic
		if d.severity == .Error && f.state != .Accepted {
			failing = true
		}
		if f.state == .Accepted && !show_all {
			continue
		}
		vnum := fmt.tprintf(" [#%d]", d.vnum) if d.vnum != 0 else ""
		new_tag := " (new)" if f.is_new else ""
		fmt.printfln(
			"%s:%d: %s %v%s: %s%s%s {{%s}}",
			ws.names[d.area],
			d.line,
			SEVERITY_NAMES[d.severity],
			d.check,
			vnum,
			d.message,
			STATE_TAGS[f.state],
			new_tag,
			clarity.finding_id(f.key),
		)
	}
	print_summary(ws, result)
	return 1 if failing else 0
}

print_summary :: proc(ws: ^workspace.Workspace, result: clarity.Review_Result) {
	doc := &ws.document
	rooms := 0
	for area in ws.areas {
		rooms += len(area.rooms)
	}
	severities := validation.count_by_severity(ws.diagnostics)
	fmt.printfln("\n%d areas, %d rooms: %d errors, %d warnings, %d info", len(ws.areas), rooms, severities[.Error], severities[.Warning], severities[.Info])

	by_check: [validation.Check][validation.Severity]int
	for d in ws.diagnostics {
		by_check[d.check][d.severity] += 1
	}
	for counts, check in by_check {
		total := counts[.Error] + counts[.Warning] + counts[.Info]
		if total == 0 {
			continue
		}
		parts := make([dynamic]string)
		for count, severity in counts {
			if count > 0 {
				append(&parts, fmt.tprintf("%d %s", count, SEVERITY_NAMES[severity]))
			}
		}
		total_text := strings.right_justify(fmt.tprintf("%d", total), 5, " ")
		fmt.printfln("  %-24v %s  (%s)", check, total_text, strings.join(parts[:], ", "))
	}

	if ws.clarity_path == "" {
		return
	}
	fmt.printfln(
		"\nreview (%s): %d open, %d flagged, %d accepted%s, %d need review",
		filepath.base(ws.clarity_path),
		result.state_counts[.Open],
		result.state_counts[.Flagged],
		result.state_counts[.Accepted],
		"" if result.state_counts[.Accepted] == 0 else " (hidden; --all shows them)",
		result.state_counts[.Needs_Review],
	)
	if len(doc.files) > 0 {
		fmt.printfln("  since last save: %d new, %d fixed", result.new_count, len(result.fixed))
		for i in result.fixed {
			entry := doc.snapshot[i]
			fmt.printfln("    fixed: %s:%d %s [#%d]", entry.file, entry.line, entry.check, entry.vnum)
		}
		print_names("  changed files: ", result.changed_files)
		print_names("  new files: ", result.added_files)
		print_names("  files no longer listed: ", result.removed_files)
	} else {
		fmt.println("  not saved yet; run `mudclarity save` to record a baseline")
	}
	for i in result.resolved {
		r := doc.reviews[i]
		fmt.printfln("  resolved (finding gone): {{%s:%s:%d:%d}} %s", r.file, r.check, r.vnum, r.related_vnum, r.status)
	}
	for i in result.unknown_checks {
		r := doc.reviews[i]
		fmt.printfln("  review names an unknown check: {{%s:%s:%d:%d}}", r.file, r.check, r.vnum, r.related_vnum)
	}
	open_issues := 0
	for issue in doc.issues {
		if issue.status != clarity.ISSUE_RESOLVED {
			open_issues += 1
		}
	}
	if open_issues > 0 || len(doc.notes) > 0 {
		fmt.printfln("  %d open issues, %d notes", open_issues, len(doc.notes))
	}
}

print_names :: proc(label: string, names: []string) {
	if len(names) > 0 {
		fmt.printfln("%s%s", label, strings.join(names, ", "))
	}
}

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
import "core:time"

import "clarity"
import "formats"
import "models"
import "validation"

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

// The loaded world: areas, their names in area.lst, and their hashes.
World :: struct {
	set:          formats.Area_Set,
	areas:        []^models.Area,
	names:        []string,
	hashes:       []string,
	is_complete:  bool,
	clarity_path: string, // Empty when loose .are files were given
	diagnostics:  []validation.Diagnostic,
}

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
	world := load_world(args[:1])
	defer formats.unload_area_set(&world.set)
	doc := load_or_new_document(&world)
	rest := args[1:]

	switch command {
	case "save":
		files := make([]clarity.File_Entry, len(world.set.loaded))
		for loaded, i in world.set.loaded {
			files[i] = clarity.file_entry_for(world.names[i], loaded)
		}
		clarity.refresh(&doc, files, world.diagnostics)
		save(&world, &doc)
		fmt.printfln("saved %s: %d files, %d findings", world.clarity_path, len(doc.files), len(doc.snapshot))
	case "accept", "flag":
		if len(rest) < 1 do fail("%s needs a finding id", command)
		key := current_finding_key(&world, rest[0])
		status := clarity.REVIEW_ACCEPTED if command == "accept" else clarity.REVIEW_FLAGGED
		note := strings.join(rest[1:], " ")
		clarity.set_review(&doc, key, status, note, hash_of(&world, key.file), today())
		save(&world, &doc)
		fmt.printfln("%s %s", status, rest[0])
	case "reopen":
		if len(rest) < 1 do fail("reopen needs a finding id")
		key, ok := clarity.parse_finding_id(rest[0])
		if !ok || !clarity.remove_review(&doc, key) {
			fail("no decision recorded for %s", rest[0])
		}
		save(&world, &doc)
		fmt.printfln("reopened %s", rest[0])
	case "note", "issue":
		if len(rest) < 4 do fail("%s needs <file> <kind> <vnum> <text>", command)
		file, kind := rest[0], rest[1]
		kinds := clarity.KINDS
		if !slice.contains(world.names, file) do fail("%s is not in %s", file, args[0])
		if !slice.contains(kinds[:], kind) do fail("kind must be one of %v", kinds)
		vnum, vnum_ok := strconv.parse_int(rest[2], 10)
		if !vnum_ok do fail("%s is not a vnum", rest[2])
		text := strings.join(rest[3:], " ")
		if command == "note" {
			clarity.add_note(&doc, file, kind, vnum, text, today())
			save(&world, &doc)
			fmt.printfln("added note to %s %s %d", file, kind, vnum)
		} else {
			id := clarity.add_issue(&doc, file, kind, vnum, text, today())
			save(&world, &doc)
			fmt.printfln("added issue #%d", id)
		}
	}
}

fail :: proc(format: string, args: ..any) -> ! {
	fmt.eprintfln(format, ..args)
	os.exit(2)
}

today :: proc() -> string {
	year, month, day := time.date(time.now())
	return fmt.aprintf("%04d-%02d-%02d", year, int(month), day)
}

// Load an area list (the whole world) or loose area files, and validate them.
load_world :: proc(paths: []string) -> (world: World) {
	if len(paths) == 1 && strings.has_suffix(paths[0], ".lst") {
		list_err: formats.Parse_Error
		world.set, list_err = formats.load_area_set(paths[0])
		if list_err != nil {
			fmt.eprintln(formats.parse_error_to_string(list_err, paths[0]))
			os.exit(1)
		}
		world.is_complete = len(world.set.failures) == 0
		world.clarity_path, _ = filepath.join({filepath.dir(paths[0]), "area.clarity"})
	} else {
		world.set.loaded = make([dynamic]^formats.Loaded_Area)
		world.set.failures = make([dynamic]formats.Area_Load_Failure)
		for path in paths {
			loaded, err := formats.load_area_file(path)
			if err != nil {
				append(&world.set.failures, formats.Area_Load_Failure{name = path, error = err})
				continue
			}
			append(&world.set.loaded, loaded)
		}
	}
	for failure in world.set.failures {
		fmt.eprintln(formats.parse_error_to_string(failure.error, failure.name))
	}
	world.areas = formats.area_set_areas(&world.set)
	world.names = make([]string, len(world.set.loaded))
	world.hashes = make([]string, len(world.set.loaded))
	for loaded, i in world.set.loaded {
		world.names[i] = loaded.area.source_name
		world.hashes[i] = clarity.sha256_hex(loaded.data)
	}
	world.diagnostics = validation.validate(world.areas, world.is_complete)
	return world
}

load_or_new_document :: proc(world: ^World) -> clarity.Document {
	if world.clarity_path == "" || !os.exists(world.clarity_path) {
		return clarity.document_make("area.lst")
	}
	doc, err := clarity.load_document(world.clarity_path)
	if err != nil {
		fmt.eprintfln("%s: %s", world.clarity_path, err.(clarity.Load_Failure).detail)
		os.exit(1)
	}
	return doc
}

save :: proc(world: ^World, doc: ^clarity.Document) {
	if err := clarity.save_document(world.clarity_path, doc); err != nil {
		fmt.eprintfln("%s: %s", world.clarity_path, err.(clarity.Load_Failure).detail)
		os.exit(1)
	}
}

hash_of :: proc(world: ^World, file: string) -> string {
	for name, i in world.names {
		if name == file {
			return world.hashes[i]
		}
	}
	return ""
}

// Parse a finding id and make sure it names a current finding, so typos
// don't create reviews that never match anything.
current_finding_key :: proc(world: ^World, id: string) -> clarity.Finding_Key {
	key, ok := clarity.parse_finding_id(id)
	if !ok do fail("%s is not a finding id (file:check:vnum:related_vnum)", id)
	for d in world.diagnostics {
		if clarity.key_of(d, world.names) == key {
			return key
		}
	}
	fail("no current finding has id %s; run check to see the ids", id)
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
	world := load_world(paths)
	defer formats.unload_area_set(&world.set)
	doc := load_or_new_document(&world)
	result := clarity.merge(&doc, world.names, world.hashes, world.diagnostics)

	failing := len(world.set.failures) > 0
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
			world.names[d.area],
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
	print_summary(&world, &doc, result)
	return 1 if failing else 0
}

print_summary :: proc(world: ^World, doc: ^clarity.Document, result: clarity.Review_Result) {
	rooms := 0
	for area in world.areas {
		rooms += len(area.rooms)
	}
	severities := validation.count_by_severity(world.diagnostics)
	fmt.printfln("\n%d areas, %d rooms: %d errors, %d warnings, %d info", len(world.areas), rooms, severities[.Error], severities[.Warning], severities[.Info])

	by_check: [validation.Check][validation.Severity]int
	for d in world.diagnostics {
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

	if world.clarity_path == "" {
		return
	}
	fmt.printfln(
		"\nreview (%s): %d open, %d flagged, %d accepted%s, %d need review",
		filepath.base(world.clarity_path),
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

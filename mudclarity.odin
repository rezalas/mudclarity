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
import "core:os"
import "core:strings"

import "formats"
import "models"
import "validation"

/*
 This is the main entry point for the Mud Clarity application.
 Until the GUI exists, it validates area files from the command line:

   mudclarity path/to/area.lst     validate every listed area (whole world)
   mudclarity file.are ...         validate just these files

 Exits with 1 if any file fails to parse or any Error is found.
*/
main :: proc() {
	if len(os.args) < 2 {
		fmt.eprintln("usage: mudclarity <area.lst> | <file.are>...")
		os.exit(2)
	}

	set: formats.Area_Set
	defer formats.unload_area_set(&set)
	is_complete := false
	if len(os.args) == 2 && strings.has_suffix(os.args[1], ".lst") {
		list_err: formats.Parse_Error
		set, list_err = formats.load_area_set(os.args[1])
		if list_err != nil {
			fmt.eprintln(formats.parse_error_to_string(list_err, os.args[1], context.temp_allocator))
			os.exit(1)
		}
		// Areas that failed to parse are missing from the world.
		is_complete = len(set.failures) == 0
	} else {
		set.loaded = make([dynamic]^formats.Loaded_Area)
		set.failures = make([dynamic]formats.Area_Load_Failure)
		for path in os.args[1:] {
			loaded, err := formats.load_area_file(path)
			if err != nil {
				append(&set.failures, formats.Area_Load_Failure{name = path, error = err})
				continue
			}
			append(&set.loaded, loaded)
		}
	}

	for failure in set.failures {
		fmt.eprintln(formats.parse_error_to_string(failure.error, failure.name, context.temp_allocator))
	}

	areas := formats.area_set_areas(&set, context.temp_allocator)
	diagnostics := validation.validate(areas, is_complete, context.temp_allocator)
	print_diagnostics(areas, diagnostics)

	if len(set.failures) > 0 || validation.count_by_severity(diagnostics)[.Error] > 0 {
		os.exit(1)
	}
}

SEVERITY_NAMES := [validation.Severity]string {
	.Error   = "error",
	.Warning = "warning",
	.Info    = "info",
}

print_diagnostics :: proc(areas: []^models.Area, diagnostics: []validation.Diagnostic) {
	for d in diagnostics {
		vnum := fmt.tprintf(" [#%d]", d.vnum) if d.vnum != 0 else ""
		fmt.printfln("%s:%d: %s %v%s: %s", areas[d.area].source_name, d.line, SEVERITY_NAMES[d.severity], d.check, vnum, d.message)
	}

	rooms := 0
	for area in areas {
		rooms += len(area.rooms)
	}
	severities := validation.count_by_severity(diagnostics)
	fmt.printfln(
		"\n%d areas, %d rooms: %d errors, %d warnings, %d info",
		len(areas),
		rooms,
		severities[.Error],
		severities[.Warning],
		severities[.Info],
	)
	// Per check, how many findings at each severity.
	by_check: [validation.Check][validation.Severity]int
	for d in diagnostics {
		by_check[d.check][d.severity] += 1
	}
	for counts, check in by_check {
		total := counts[.Error] + counts[.Warning] + counts[.Info]
		if total == 0 {
			continue
		}
		parts := make([dynamic]string, context.temp_allocator)
		for count, severity in counts {
			if count > 0 {
				append(&parts, fmt.tprintf("%d %s", count, SEVERITY_NAMES[severity]))
			}
		}
		total_text := strings.right_justify(fmt.tprintf("%d", total), 5, " ", context.temp_allocator)
		fmt.printfln("  %-24v %s  (%s)", check, total_text, strings.join(parts[:], ", ", context.temp_allocator))
	}
}

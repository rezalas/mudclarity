/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package validation

import "core:math/rand"
import "core:slice"
import "core:testing"
import "core:time"

import "../formats"
import "../models"

/*
 Golden tests on fixture files. Every expected finding here was checked by
 hand against the raw file (see the comments), not copied from the
 validator's output.
*/

MIDGAARD_ARE :: #load("../test_data/valid/midgaard.are")
CLEAN_WORLD_ARE :: #load("../test_data/valid/clean_world.are")

@(test)
test_clean_world_fixture_has_no_findings :: proc(t: ^testing.T) {
	expect_clean(t, run_one(t, string(CLEAN_WORLD_ARE)))
}

@(test)
test_golden_midgaard_alone :: proc(t: ^testing.T) {
	diagnostics := run_one(t, string(MIDGAARD_ARE))
	counts := count_by_check(diagnostics)
	// Exits into areas that aren't loaded, e.g. 3044 south -> 23600 and
	// 3040 west -> 6000 (Haon Dor). Unresolved, so Info.
	testing.expect_value(t, counts[.Broken_Exit], 13)
	for d in of_check(diagnostics, .Broken_Exit) {
		testing.expect_value(t, d.severity, Severity.Info)
	}
	// 17 `S` lines in #IMPROGS.
	testing.expect_value(t, counts[.Ignored_Program_Line], 17)
	testing.expect_value(t, len(diagnostics), 37)

	// Room 3160's north door is locked (ABCD, DOOR reset LOCKED) with key
	// 3161. Object 3161 exists, but the only reset naming 3161 is a MOB.
	d, _ := expect_one(t, of_check(diagnostics, .Key_Never_Placed)[:1], .Key_Never_Placed, .Warning, line = 5425, vnum = 3160)
	testing.expect_value(t, d.related_vnum, 3161)
	testing.expect_value(t, counts[.Key_Never_Placed], 2) // and 3161's south door

	// No exit leads into 3170; its north exit goes to 3044, whose south exit
	// goes to 23600.
	orphans := of_check(diagnostics, .Orphan_Room)
	testing.expect_value(t, len(orphans), 2)
	testing.expect(t, slice.any_of_proc(orphans, proc(d: Diagnostic) -> bool {return d.vnum == 3170}))
	m, _ := expect_one(t, diagnostics, .Mismatched_Return, .Warning, line = 5476, vnum = 3170)
	testing.expect_value(t, m.related_vnum, 3044)

	// 3032 is the pet shop's storage room: no exits, and nothing leads in.
	expect_one(t, diagnostics, .Dead_End_Room, .Warning, line = 7191, vnum = 3032)

	// Portal 3369 leads to 11521, outside every loaded area.
	p, _ := expect_one(t, diagnostics, .Portal_Missing_Target, .Info, vnum = 3369)
	testing.expect_value(t, p.related_vnum, 11521)
}

@(test)
test_diagnostics_are_sorted :: proc(t: ^testing.T) {
	a := test_area("a", 100, 199, rooms(room(100, exit("NORTH", 150)), room(101), room(102, exit("EAST", 160))))
	b := test_area("b", 200, 299, rooms(room(200, exit("NORTH", 250))))
	diagnostics := run_validation(t, {a, b}, false)
	testing.expect(t, len(diagnostics) > 3)
	sorted := slice.is_sorted_by(diagnostics, proc(x, y: Diagnostic) -> bool {
		if x.area != y.area {
			return x.area < y.area
		}
		if x.line != y.line {
			return x.line < y.line
		}
		return x.check < y.check
	})
	testing.expect(t, sorted, "diagnostics are not sorted by area, line, check")
}

@(test)
test_validate_with_no_areas :: proc(t: ^testing.T) {
	testing.expect_value(t, len(validate({}, true, context.temp_allocator)), 0)
	testing.expect_value(t, len(validate({}, false, context.temp_allocator)), 0)
}

// --- Robustness ---

@(private = "file")
same_diagnostics :: proc(x, y: []Diagnostic) -> bool {
	if len(x) != len(y) {
		return false
	}
	for d, i in x {
		e := y[i]
		if d.check != e.check || d.severity != e.severity || d.area != e.area || d.line != e.line || d.vnum != e.vnum || d.related_vnum != e.related_vnum || d.message != e.message {
			return false
		}
	}
	return true
}

@(test)
test_validation_is_deterministic :: proc(t: ^testing.T) {
	loaded, err := formats.load_area_bytes(MIDGAARD_ARE, "midgaard.are")
	defer formats.unload_area(loaded)
	if !testing.expect(t, err == nil) do return
	areas := []^models.Area{&loaded.area}
	first := validate(areas, false, context.temp_allocator)
	for _ in 0 ..< 3 {
		testing.expect(t, same_diagnostics(first, validate(areas, false, context.temp_allocator)))
	}
}

@(test)
test_validation_survives_damaged_areas :: proc(t: ^testing.T) {
	// Validate every mutation of the fixtures that still parses. Damaged data
	// (odd vnums, missing records) must never crash the validator.
	testing.set_fail_timeout(t, 60 * time.Second)
	state := rand.create(0x76616c6964617465) // "validate"
	gen := rand.default_random_generator(&state)
	midgaard := MIDGAARD_ARE
	sources := [][]u8{CLEAN_WORLD_ARE, midgaard[:20000]}
	digits := "0123456789-"
	parsed := 0
	for source in sources {
		buffer := make([]u8, len(source))
		defer delete(buffer)
		for _ in 0 ..< 300 {
			copy(buffer, source)
			// Changing digits keeps most files parseable while scrambling vnums.
			for _ in 0 ..< 1 + rand.int_max(6, gen) {
				i := rand.int_max(len(buffer), gen)
				if buffer[i] >= '0' && buffer[i] <= '9' {
					buffer[i] = digits[rand.int_max(len(digits), gen)]
				}
			}
			loaded, err := formats.load_area_bytes(buffer, "fuzz.are")
			if err != nil {
				continue
			}
			parsed += 1
			for complete in ([]bool{false, true}) {
				for d in validate({&loaded.area}, complete, context.temp_allocator) {
					testing.expect(t, d.area == 0)
					testing.expect(t, d.line >= 1)
					testing.expect(t, d.message != "")
				}
			}
			formats.unload_area(loaded)
		}
	}
	testing.expectf(t, parsed > 100, "only %d mutations parsed; the test isn't exercising the validator", parsed)
}

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package validation

import "core:fmt"
import "core:strings"
import "core:testing"

import "../formats"
import "../models"

// Shared helpers for the validation tests.

// Number of lines in the header test_area writes before the body.
HEADER_LINES :: 11

// An area file with the given vnum range and body sections.
test_area :: proc(name: string, min_vnum, max_vnum: int, body: string, area_type := "normal") -> string {
	return fmt.tprintf(
		"#AREA\n%s~\n%s~\nTester~\n1 50\n%d %d\n%s\ntemperate\n0\n1\nNone~\n%s\n#$\n",
		name,
		name,
		min_vnum,
		max_vnum,
		area_type,
		body,
	)
}

// Line number in a test_area file of line `n` of its body.
body_line :: proc(n: int) -> int {
	return HEADER_LINES + n
}

// A room with the given exits, e.g. room(100, "D NORTH 101 0 0\n~\n~\n").
room :: proc(vnum: int, exits := "") -> string {
	return fmt.tprintf("#%d\nRoom %d~\n~\ncity\n%sS\n", vnum, vnum, exits)
}

// An exit line plus its empty keyword and description strings.
exit :: proc(dir: string, target: int, flags := "0", key := 0, keyword := "") -> string {
	return fmt.tprintf("D %s %d %s %d\n%s~\n~\n", dir, target, flags, key, keyword)
}

// A minimal mob.
mob :: proc(vnum: int) -> string {
	return fmt.tprintf("#%d\nmob~\na mob~\nA mob is here.\n~\n~\n0 0 0 human~\n1 1d1+1 1d1+1 0 0 hit\n0 0 0 0\nstanding male none\n0 0 medium\n", vnum)
}

// A minimal object of the given type and values.
object :: proc(vnum: int, item_type := "trash", values := "0 0 0 0 0") -> string {
	return fmt.tprintf("#%d\nthing~\na thing~\nA thing is here.~\n%s\nstuff~\n%s\n1 1 1 P\n", vnum, item_type, values)
}

// Sections helpers.
rooms :: proc(records: ..string) -> string {
	return strings.concatenate({"#ROOMS\n", strings.concatenate(records, context.temp_allocator), "#0\n"}, context.temp_allocator)
}
mobs :: proc(records: ..string) -> string {
	return strings.concatenate({"#MOBS\n", strings.concatenate(records, context.temp_allocator), "#0\n"}, context.temp_allocator)
}
objects :: proc(records: ..string) -> string {
	return strings.concatenate({"#OBJS\n", strings.concatenate(records, context.temp_allocator), "#0\n"}, context.temp_allocator)
}
resets :: proc(lines: ..string) -> string {
	return strings.concatenate({"#RESETS\n", strings.join(lines, "\n", context.temp_allocator), "\nS\n"}, context.temp_allocator)
}
sections :: proc(parts: ..string) -> string {
	return strings.concatenate(parts, context.temp_allocator)
}

// Parse each text as an area, validate them together, and unload them.
// Diagnostics (and their messages) live in the temp allocator.
run_validation :: proc(t: ^testing.T, texts: []string, is_complete: bool, loc := #caller_location) -> []Diagnostic {
	loaded := make([dynamic]^formats.Loaded_Area, context.temp_allocator)
	defer for l in loaded {
		formats.unload_area(l)
	}
	areas := make([dynamic]^models.Area, context.temp_allocator)
	for text, i in texts {
		l, err := formats.load_area_bytes(transmute([]u8)text, fmt.tprintf("area%d.are", i))
		if err != nil {
			testing.expectf(t, false, "area %d failed to parse: %s", i, formats.parse_error_to_string(err, "test", context.temp_allocator), loc = loc)
			return nil
		}
		append(&loaded, l)
		append(&areas, &l.area)
	}
	return validate(areas[:], is_complete, context.temp_allocator)
}

// Validate one area that isn't the whole world.
run_one :: proc(t: ^testing.T, text: string, loc := #caller_location) -> []Diagnostic {
	return run_validation(t, {text}, false, loc)
}

// The diagnostics of one check.
of_check :: proc(diagnostics: []Diagnostic, check: Check) -> []Diagnostic {
	found := make([dynamic]Diagnostic, context.temp_allocator)
	for d in diagnostics {
		if d.check == check {
			append(&found, d)
		}
	}
	return found[:]
}

// Expect exactly one diagnostic of `check`, with the given details.
// A `line` or `vnum` of -1 skips that comparison.
expect_one :: proc(t: ^testing.T, diagnostics: []Diagnostic, check: Check, severity: Severity, area := 0, line := -1, vnum := -1, loc := #caller_location) -> (Diagnostic, bool) {
	found := of_check(diagnostics, check)
	if !testing.expectf(t, len(found) == 1, "expected one %v, got %d: %v", check, len(found), diagnostics, loc = loc) {
		return {}, false
	}
	d := found[0]
	ok := testing.expectf(t, d.severity == severity, "%v: expected %v, got %v", check, severity, d.severity, loc = loc)
	ok &= testing.expectf(t, d.area == area, "%v: expected area %d, got %d", check, area, d.area, loc = loc)
	if line != -1 {
		ok &= testing.expectf(t, d.line == line, "%v: expected line %d, got %d", check, line, d.line, loc = loc)
	}
	if vnum != -1 {
		ok &= testing.expectf(t, d.vnum == vnum, "%v: expected vnum %d, got %d", check, vnum, d.vnum, loc = loc)
	}
	ok &= testing.expectf(t, d.message != "", "%v: empty message", check, loc = loc)
	return d, ok
}

// Expect no diagnostic of `check`.
expect_none :: proc(t: ^testing.T, diagnostics: []Diagnostic, check: Check, loc := #caller_location) {
	found := of_check(diagnostics, check)
	testing.expectf(t, len(found) == 0, "expected no %v, got %v", check, found, loc = loc)
}

// Expect no diagnostics at all.
expect_clean :: proc(t: ^testing.T, diagnostics: []Diagnostic, loc := #caller_location) {
	testing.expectf(t, len(diagnostics) == 0, "expected no diagnostics, got %v", diagnostics, loc = loc)
}

// 1-based line number of the first line of `text` that starts with `prefix`.
line_of :: proc(text, prefix: string) -> int {
	line := 1
	rest := text
	for len(rest) > 0 {
		if strings.has_prefix(rest, prefix) {
			return line
		}
		next := strings.index_byte(rest, '\n')
		if next < 0 {
			break
		}
		rest = rest[next + 1:]
		line += 1
	}
	return -2 // Never matches a real line
}

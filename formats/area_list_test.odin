/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:testing"

@(private = "file")
expect_names :: proc(t: ^testing.T, text: string, expected: []string, loc := #caller_location) {
	names, err := parse_area_list(transmute([]u8)text)
	defer delete(names)
	if !testing.expectf(t, err == nil, "unexpected error: %v", err, loc = loc) {
		return
	}
	if !testing.expect_value(t, len(names), len(expected), loc = loc) {
		return
	}
	for name, i in names {
		testing.expect_value(t, name, expected[i], loc = loc)
	}
}

@(test)
test_area_list_line_endings :: proc(t: ^testing.T) {
	expected := []string{"limbo.are", "midgaard.are"}
	expect_names(t, "limbo.are\nmidgaard.are\n$\n", expected)
	expect_names(t, "limbo.are\r\nmidgaard.are\r\n$\r\n", expected)
	// Riftshadow's area.lst uses bare CR.
	expect_names(t, "limbo.are\rmidgaard.are\r$", expected)
}

@(test)
test_area_list_skips_blanks_and_stops_at_dollar :: proc(t: ^testing.T) {
	expect_names(t, "\n  limbo.are  \n\n$\nignored.are\n", {"limbo.are"})
	expect_names(t, "$\n", {})
}

@(test)
test_area_list_rejects_paths :: proc(t: ^testing.T) {
	for text in ([]string{"../secret.are\n$\n", "sub/dir.are\n$\n", "c:\\x.are\n$\n", "/etc/passwd\n$\n", "a..b\n$\n"}) {
		names, err := parse_area_list(transmute([]u8)text)
		testing.expect(t, names == nil)
		expect_failure(t, err, .Bad_Area_List_Entry, 1)
	}
}

@(test)
test_area_list_error_line_with_bare_cr :: proc(t: ^testing.T) {
	_, err := parse_area_list(transmute([]u8)string("a.are\rb.are\r../c.are\r$"))
	expect_failure(t, err, .Bad_Area_List_Entry, 3)
}

@(test)
test_area_list_requires_dollar :: proc(t: ^testing.T) {
	names, err := parse_area_list(transmute([]u8)string("limbo.are\n"))
	testing.expect(t, names == nil)
	expect_failure(t, err, .Missing_End_Marker)
}

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:strings"
import "core:testing"

// Shared helpers for the formats tests.

TEST_DATA_DIR :: #directory + "/../test_data"

// A minimal valid #AREA section for building test inputs.
TEST_HEADER :: `#AREA
test.are~
Test Area~
Tester~
1 50
100 199
normal
temperate
0
1
None~
`

// Wrap section text in a header and the #$ end marker.
// The result is allocated with the temp allocator.
with_header :: proc(body: string) -> string {
	return strings.concatenate({TEST_HEADER, body, "\n#$\n"}, context.temp_allocator)
}

// Parse `text` into its own arena. The caller must unload_area the result.
parse_text :: proc(text: string) -> (^Loaded_Area, Parse_Error) {
	return load_area_bytes(transmute([]u8)text, "test.are")
}

// Parse `text`, failing the test if parsing fails. The caller must unload_area.
must_parse :: proc(t: ^testing.T, text: string, loc := #caller_location) -> ^Loaded_Area {
	loaded, err := parse_text(text)
	if err != nil {
		testing.expectf(t, false, "unexpected parse error: %s", parse_error_to_string(err, "test.are", context.temp_allocator), loc = loc)
		return nil
	}
	return loaded
}

// Check that `err` is a failure of `kind` on `line` (line 0 skips the line check).
expect_failure :: proc(t: ^testing.T, err: Parse_Error, kind: Parse_Error_Kind, line := 0, loc := #caller_location) -> bool {
	failure, is_failure := err.(Parse_Failure)
	if !testing.expectf(t, is_failure, "expected a %v error, got success", kind, loc = loc) {
		return false
	}
	ok := testing.expectf(t, failure.kind == kind, "expected %v, got %v (%s)", kind, failure.kind, failure.detail, loc = loc)
	if line != 0 {
		ok &= testing.expectf(t, failure.line == line, "expected %v on line %d, got line %d", kind, line, failure.line, loc = loc)
	}
	return ok
}

// Parse `text` and expect it to fail with `kind` on `line`.
expect_parse_failure :: proc(t: ^testing.T, text: string, kind: Parse_Error_Kind, line := 0, loc := #caller_location) -> Parse_Failure {
	loaded, err := parse_text(text)
	if loaded != nil {
		unload_area(loaded)
	}
	expect_failure(t, err, kind, line, loc)
	failure, _ := err.(Parse_Failure)
	return failure
}

// Line number within with_header(body) of a line number within `body`.
body_line :: proc(n: int) -> int {
	return strings.count(TEST_HEADER, "\n") + n
}

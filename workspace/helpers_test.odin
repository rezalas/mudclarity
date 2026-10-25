/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package workspace

import "core:testing"

// Shared helpers for the workspace tests.

TEST_DATE :: "2026-10-25"

// Open the area list at `path`, failing the test on an error.
open_or_fail :: proc(t: ^testing.T, path: string, loc := #caller_location) -> ^Workspace {
	ws, err := open_area_list(path)
	testing.expectf(t, err == nil, "open_area_list: %s", error_message(err, context.temp_allocator), loc = loc)
	return ws
}

// The kind of an Edit_Failure, or fail the test if `err` is something else.
edit_kind :: proc(t: ^testing.T, err: Error, loc := #caller_location) -> Edit_Error_Kind {
	failure, ok := err.(Edit_Failure)
	testing.expectf(t, ok, "expected an Edit_Failure, got %v", err, loc = loc)
	return failure.kind
}

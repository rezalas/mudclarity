/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package workspace

import "core:fmt"

import "../clarity"
import "../formats"

// The area.lst itself couldn't be read or parsed. `path` is the path given
// to open_area_list.
Area_List_Failure :: struct {
	path:    string,
	failure: formats.Parse_Failure,
}

// area.clarity couldn't be loaded or saved.
Review_File_Failure :: struct {
	path:    string,
	failure: clarity.Load_Failure,
}

Out_Of_Memory :: struct {}

Edit_Error_Kind :: enum {
	No_Review_File,  // Loose .are files were opened, so there is no area.clarity
	Bad_Finding_Id,  // Not of the form file:check:vnum:related_vnum
	Unknown_Finding, // A well-formed id that no current finding has
	No_Decision,     // Reopening a finding that has no decision
	Unknown_File,    // A file that isn't in the area list
	Unknown_Kind,    // Not one of clarity.KINDS
}

// An edit named something that isn't in the world. `value` is the offending
// input, as the caller passed it; `list_path` is the area list it was checked
// against.
Edit_Failure :: struct {
	kind:      Edit_Error_Kind,
	value:     string,
	list_path: string,
}

/*
 nil means success.

 Strings in an Error point into the caller's arguments, the workspace or the
 temp allocator, so turn it into text with error_message before any of
 those go away (in particular before handing it to another thread).
*/
Error :: union {
	Area_List_Failure,
	Review_File_Failure,
	Out_Of_Memory,
	Edit_Failure,
}

// A one-line description of `err` for the user, allocated with `allocator`.
error_message :: proc(err: Error, allocator := context.allocator) -> string {
	switch e in err {
	case Area_List_Failure:
		return formats.parse_error_to_string(e.failure, e.path, allocator)
	case Review_File_Failure:
		return fmt.aprintf("%s: %s", e.path, e.failure.detail, allocator = allocator)
	case Out_Of_Memory:
		return fmt.aprint("out of memory", allocator = allocator)
	case Edit_Failure:
		return edit_failure_message(e, allocator)
	}
	return fmt.aprint("ok", allocator = allocator)
}

@(private = "file")
edit_failure_message :: proc(e: Edit_Failure, allocator := context.allocator) -> string {
	switch e.kind {
	case .No_Review_File:
		return fmt.aprint("loose area files have no review file; open an area.lst", allocator = allocator)
	case .Bad_Finding_Id:
		return fmt.aprintf("%s is not a finding id (file:check:vnum:related_vnum)", e.value, allocator = allocator)
	case .Unknown_Finding:
		return fmt.aprintf("no current finding has id %s", e.value, allocator = allocator)
	case .No_Decision:
		return fmt.aprintf("no decision recorded for %s", e.value, allocator = allocator)
	case .Unknown_File:
		return fmt.aprintf("%s is not in %s", e.value, e.list_path, allocator = allocator)
	case .Unknown_Kind:
		kinds := clarity.KINDS
		return fmt.aprintf("kind must be one of %v", kinds, allocator = allocator)
	}
	return fmt.aprint("invalid edit", allocator = allocator)
}

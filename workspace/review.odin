/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package workspace

import "core:fmt"
import "core:slice"
import "core:time"

import "../clarity"

/*
 Review operations shared by the CLI and the GUI. Each checks its input
 against the world before touching the document, because clarity's edit
 procedures assert on bad input. Strings are cloned into the workspace.
 Nothing is written to disk until save.
*/

// Compare the current findings with the review file. Slices in the result
// are allocated with `allocator` and point into the workspace.
merge :: proc(ws: ^Workspace, allocator := context.allocator) -> clarity.Review_Result {
	return clarity.merge(&ws.document, ws.names, ws.hashes, ws.diagnostics, allocator)
}

// Parse a finding id and make sure it names a current finding, so typos
// don't create reviews that never match anything. The key's strings point
// into `id`.
current_finding_key :: proc(ws: ^Workspace, id: string) -> (key: clarity.Finding_Key, err: Error) {
	ok: bool
	key, ok = clarity.parse_finding_id(id)
	if !ok {
		return {}, Edit_Failure{.Bad_Finding_Id, id, ws.list_path}
	}
	for d in ws.diagnostics {
		if clarity.key_of(d, ws.names) == key {
			return key, nil
		}
	}
	return {}, Edit_Failure{.Unknown_Finding, id, ws.list_path}
}

// Record a decision (clarity.REVIEW_ACCEPTED or REVIEW_FLAGGED) on a finding,
// stamped with its file's current hash.
set_review :: proc(ws: ^Workspace, key: clarity.Finding_Key, status, note, date: string) -> Error {
	check_review_file(ws) or_return
	clarity.set_review(&ws.document, key, status, note, hash_of(ws, key.file), date, allocator(ws))
	return nil
}

// Remove the decision on a finding. `id` is only used in the error.
remove_review :: proc(ws: ^Workspace, key: clarity.Finding_Key, id: string) -> Error {
	check_review_file(ws) or_return
	if !clarity.remove_review(&ws.document, key) {
		return Edit_Failure{.No_Decision, id, ws.list_path}
	}
	return nil
}

// Attach a note to an area or a record in a loaded file.
add_note :: proc(ws: ^Workspace, file, kind: string, vnum: int, text, date: string) -> Error {
	check_record(ws, file, kind) or_return
	clarity.add_note(&ws.document, file, kind, vnum, text, date, allocator(ws))
	return nil
}

// Open an issue on an area or a record in a loaded file. Returns its id.
add_issue :: proc(ws: ^Workspace, file, kind: string, vnum: int, title, date: string) -> (id: int, err: Error) {
	check_record(ws, file, kind) or_return
	return clarity.add_issue(&ws.document, file, kind, vnum, title, date, allocator(ws)), nil
}

// Record the current files, hashes and findings in the document, so the
// next merge compares against this run.
record_run :: proc(ws: ^Workspace) -> Error {
	check_review_file(ws) or_return
	files := make([]clarity.File_Entry, len(ws.set.loaded), context.temp_allocator)
	for loaded, i in ws.set.loaded {
		files[i] = clarity.file_entry_for(ws.names[i], loaded, context.temp_allocator)
	}
	clarity.refresh(&ws.document, files, ws.diagnostics, allocator(ws))
	return nil
}

// Write the document to area.clarity, atomically.
save :: proc(ws: ^Workspace) -> Error {
	check_review_file(ws) or_return
	if failure, failed := clarity.save_document(ws.clarity_path, &ws.document).(clarity.Load_Failure); failed {
		return Review_File_Failure{path = ws.clarity_path, failure = failure}
	}
	return nil
}

// Today's date as YYYY-MM-DD, for stamping edits. Allocated with `allocator`.
today :: proc(allocator := context.allocator) -> string {
	year, month, day := time.date(time.now())
	return fmt.aprintf("%04d-%02d-%02d", year, int(month), day, allocator = allocator)
}

@(private = "file")
check_review_file :: proc(ws: ^Workspace) -> Error {
	if ws.clarity_path == "" {
		return Edit_Failure{.No_Review_File, "", ""}
	}
	return nil
}

@(private = "file")
check_record :: proc(ws: ^Workspace, file, kind: string) -> Error {
	check_review_file(ws) or_return
	if !slice.contains(ws.names, file) {
		return Edit_Failure{.Unknown_File, file, ws.list_path}
	}
	kinds := clarity.KINDS
	if !slice.contains(kinds[:], kind) {
		return Edit_Failure{.Unknown_Kind, kind, ws.list_path}
	}
	return nil
}

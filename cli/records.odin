/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package cli

import "core:strconv"
import "core:strings"

import "../workspace"

// The record a note or issue is about: <file> <kind> <vnum> <text...>.
@(private = "file")
Record_Args :: struct {
	file: string,
	kind: string,
	vnum: int,
	text: string,
}

@(private = "file")
parse_record_args :: proc(c: ^Call) -> (record: Record_Args, ok: bool) {
	record.file, record.kind = c.args[0], c.args[1]
	record.vnum, ok = strconv.parse_int(c.args[2], 10)
	record.text = strings.join(c.args[3:], " ", context.temp_allocator)
	return
}

// `note`: attach a note to an area or a record.
run_note :: proc(c: ^Call) -> int {
	r, ok := parse_record_args(c)
	if !ok {
		return usage_error(c, "%s is not a vnum", c.args[2])
	}
	if code := check_edit(c, workspace.add_note(c.ws, r.file, r.kind, r.vnum, r.text, c.today)); code != EXIT_OK {
		return code
	}
	return save_and_report(c, "added note to %s %s %d", r.file, r.kind, r.vnum)
}

// `issue`: open an issue on an area or a record.
run_issue :: proc(c: ^Call) -> int {
	r, ok := parse_record_args(c)
	if !ok {
		return usage_error(c, "%s is not a vnum", c.args[2])
	}
	id, err := workspace.add_issue(c.ws, r.file, r.kind, r.vnum, r.text, c.today)
	if code := check_edit(c, err); code != EXIT_OK {
		return code
	}
	return save_and_report(c, "added issue #%d", id)
}

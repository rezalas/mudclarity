/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:strings"

// Largest area.lst accepted.
MAX_AREA_LIST_SIZE :: 1024 * 1024

/*
 Parse area.lst: one file name per line, ending at a line that starts with
 '$'. Lines may end in LF, CRLF or bare CR (Riftshadow's area.lst uses CR).
 Blank lines are skipped.

 Entries are resolved relative to the list's directory by the caller, so any
 entry containing a path separator or ".." is rejected to keep loads inside
 that directory. Returned names are views into `data`; the slice itself is
 allocated with `allocator`.
*/
parse_area_list :: proc(data: []u8, allocator := context.allocator) -> (names: []string, err: Parse_Error) {
	result := make([dynamic]string, allocator)
	r := reader_make(data)
	r.section = "area.lst"
	for !at_eof(&r) {
		line, column := r.line, r.column
		start := r.pos
		for !at_eof(&r) && r.data[r.pos] != '\n' && r.data[r.pos] != '\r' {
			advance(&r)
		}
		entry := strings.trim_space(string(r.data[start:r.pos]))
		// Bare CR does not advance the reader's line count, so count it here.
		if !at_eof(&r) && r.data[r.pos] == '\r' && (r.pos + 1 >= len(r.data) || r.data[r.pos + 1] != '\n') {
			r.line += 1
			r.column = 0
		}
		if !at_eof(&r) {
			advance(&r)
		}
		if entry == "" {
			continue
		}
		if entry[0] == '$' {
			return result[:], nil
		}
		if strings.contains_any(entry, "/\\") || strings.contains(entry, "..") || strings.contains_rune(entry, 0) {
			delete(result)
			return nil, reader_fail_at(&r, line, column, .Bad_Area_List_Entry, "entries must be plain file names", entry)
		}
		append(&result, entry)
	}
	delete(result)
	return nil, reader_fail(&r, .Missing_End_Marker, "area.lst has no closing $")
}

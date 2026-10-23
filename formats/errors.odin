/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:fmt"
import "core:strings"

Parse_Error_Kind :: enum {
	Io_Error,
	File_Too_Large,
	Unexpected_EOF,
	Expected_Hash,
	Bad_Number,
	Number_Out_Of_Range,
	Bad_Flag,
	Word_Too_Long,
	String_Too_Long,
	Unterminated_String,
	Unknown_Section,
	Unsupported_Section,
	Missing_Area_Header,
	Missing_End_Marker,
	Vnum_Out_Of_Range,
	Bad_Direction,
	Bad_Reset,
	Bad_Program_Line,
	Bad_Mobile,
	Bad_Object,
	Bad_Area_List_Entry,
}

// Details of a parse failure. A failure owns no heap memory, so it stays
// valid after the source buffer is freed: `section` and `detail` are string
// literals and the offending input is copied into `token_bytes`.
Parse_Failure :: struct {
	kind:        Parse_Error_Kind,
	line:        int,    // 1-based; 0 if not tied to a position
	column:      int,    // 1-based
	section:     string, // e.g. "ROOMS"; empty before the first section
	vnum:        int,    // Vnum of the record being parsed; 0 if none
	detail:      string,
	token_bytes: [MAX_ERROR_TOKEN]u8, // Offending input, truncated; read with failure_token
	token_len:   int,
}

// nil means success, which makes `or_return` work on parse procedures.
Parse_Error :: union {
	Parse_Failure,
}

MAX_ERROR_TOKEN :: 40

// The offending input recorded in a failure.
failure_token :: proc(failure: ^Parse_Failure) -> string {
	return string(failure.token_bytes[:failure.token_len])
}

// Build a failure, copying `token` up to its first line break and at most
// MAX_ERROR_TOKEN bytes.
make_failure :: proc(kind: Parse_Error_Kind, line, column: int, section: string, vnum: int, detail: string, token := "") -> Parse_Failure {
	f := Parse_Failure {
		kind    = kind,
		line    = line,
		column  = column,
		section = section,
		vnum    = vnum,
		detail  = detail,
	}
	first_line := token
	if end := strings.index_any(token, "\r\n"); end >= 0 {
		first_line = token[:end]
	}
	f.token_len = copy(f.token_bytes[:], first_line)
	return f
}

// Format a parse error for display as "file:line:col: [SECTION #vnum] detail".
// The result is allocated with `allocator`.
parse_error_to_string :: proc(err: Parse_Error, file_name: string, allocator := context.allocator) -> string {
	failure, is_failure := err.(Parse_Failure)
	if !is_failure {
		return fmt.aprintf("%s: ok", file_name, allocator = allocator)
	}
	location := ""
	if failure.section != "" && failure.vnum != 0 {
		location = fmt.tprintf(" [#%s #%d]", failure.section, failure.vnum)
	} else if failure.section != "" {
		location = fmt.tprintf(" [#%s]", failure.section)
	}
	token := ""
	if failure.token_len > 0 {
		token = fmt.tprintf(" near %q", failure_token(&failure))
	}
	return fmt.aprintf(
		"%s:%d:%d:%s %v: %s%s",
		file_name,
		failure.line,
		failure.column,
		location,
		failure.kind,
		failure.detail,
		token,
		allocator = allocator,
	)
}

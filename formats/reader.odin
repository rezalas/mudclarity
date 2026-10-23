/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:strings"

/*
 Byte-level reader for .are files, ported from Riftshadow's fread_* helpers
 (riftshadow/code/db.c). The format has no context-free token grammar: the
 loader decides what kind of field comes next, so the parser calls these
 procedures in the same order the game does.

 The reader never allocates except in read_string when a string contains
 '\r' that must be stripped. All other returned strings are views into `data`.
 Input is treated as raw bytes (area files contain Latin-1), never as UTF-8.
*/

// Longest word fread_word accepts (MAX_INPUT_LENGTH in merc.h).
MAX_WORD_LENGTH :: 4608
// Longest string fread_string can hold (MAX_BUF in recycle.h).
MAX_STRING_LENGTH :: 16384

Reader :: struct {
	data:    []u8,
	pos:     int,
	line:    int, // 1-based line of data[pos]
	column:  int, // 1-based column of data[pos]
	// Context copied into errors; set by the parser.
	section: string,
	vnum:    int,
}

// Create a reader over `data`. The reader does not take ownership.
reader_make :: proc(data: []u8) -> Reader {
	return Reader{data = data, line = 1, column = 1}
}

// True when all input has been consumed.
at_eof :: proc(r: ^Reader) -> bool {
	return r.pos >= len(r.data)
}

// Peek at the next byte without consuming it.
peek_byte :: proc(r: ^Reader) -> (b: u8, ok: bool) {
	if r.pos >= len(r.data) {
		return 0, false
	}
	return r.data[r.pos], true
}

// Build a failure at the reader's current position.
reader_fail :: proc(r: ^Reader, kind: Parse_Error_Kind, detail: string, token := "") -> Parse_Error {
	return reader_fail_at(r, r.line, r.column, kind, detail, token)
}

// Build a failure at an explicit position (e.g. the start of a string).
reader_fail_at :: proc(r: ^Reader, line, column: int, kind: Parse_Error_Kind, detail: string, token := "") -> Parse_Error {
	return make_failure(kind, line, column, r.section, r.vnum, detail, token)
}

// The next few bytes of input, for error messages.
@(private)
upcoming :: proc(r: ^Reader) -> string {
	end := min(r.pos + MAX_ERROR_TOKEN, len(r.data))
	return string(r.data[r.pos:end])
}

@(private)
advance :: proc(r: ^Reader) {
	if r.data[r.pos] == '\n' {
		r.line += 1
		r.column = 1
	} else {
		r.column += 1
	}
	r.pos += 1
}

// C isspace() in the "C" locale.
is_space :: proc(b: u8) -> bool {
	return b == ' ' || b == '\t' || b == '\n' || b == '\v' || b == '\f' || b == '\r'
}

@(private)
is_digit :: proc(b: u8) -> bool {
	return b >= '0' && b <= '9'
}

@(private)
is_alpha :: proc(b: u8) -> bool {
	return (b >= 'A' && b <= 'Z') || (b >= 'a' && b <= 'z')
}

// ASCII uppercase; other bytes are returned unchanged.
to_upper :: proc(b: u8) -> u8 {
	return b - 32 if b >= 'a' && b <= 'z' else b
}

skip_whitespace :: proc(r: ^Reader) {
	for r.pos < len(r.data) && is_space(r.data[r.pos]) {
		advance(r)
	}
}

// Skip whitespace and return the position where the next field starts,
// for error messages about that field.
next_position :: proc(r: ^Reader) -> (line, column: int) {
	skip_whitespace(r)
	return r.line, r.column
}

// fread_letter: skip whitespace and consume one byte.
read_letter :: proc(r: ^Reader) -> (letter: u8, err: Parse_Error) {
	skip_whitespace(r)
	if at_eof(r) {
		return 0, reader_fail(r, .Unexpected_EOF, "expected a letter")
	}
	letter = r.data[r.pos]
	advance(r)
	return letter, nil
}

// Like read_letter, but does not consume anything.
peek_letter :: proc(r: ^Reader) -> (letter: u8, ok: bool) {
	saved := r^
	defer r^ = saved
	l, err := read_letter(r)
	return l, err == nil
}

// fread_number: optional sign, digits, and `a|b` meaning a + b.
// A single space after the number is consumed, as in the game.
read_number :: proc(r: ^Reader) -> (value: int, err: Parse_Error) {
	total := 0
	for {
		skip_whitespace(r)
		if at_eof(r) {
			return 0, reader_fail(r, .Unexpected_EOF, "expected a number")
		}
		line, column := r.line, r.column
		start := r.pos
		negative := false
		if r.data[r.pos] == '+' || r.data[r.pos] == '-' {
			negative = r.data[r.pos] == '-'
			advance(r)
		}
		if at_eof(r) || !is_digit(r.data[r.pos]) {
			return 0, reader_fail_at(r, line, column, .Bad_Number, "expected a number", string(r.data[start:min(start + MAX_ERROR_TOKEN, len(r.data))]))
		}
		n := 0
		for !at_eof(r) && is_digit(r.data[r.pos]) {
			n = n * 10 + int(r.data[r.pos] - '0')
			if n > int(max(i32)) {
				return 0, reader_fail_at(r, line, column, .Number_Out_Of_Range, "number does not fit in 32 bits", string(r.data[start:r.pos + 1]))
			}
			advance(r)
		}
		total += -n if negative else n
		if total > int(max(i32)) || total < int(min(i32)) {
			return 0, reader_fail_at(r, line, column, .Number_Out_Of_Range, "number does not fit in 32 bits", string(r.data[start:r.pos]))
		}
		if at_eof(r) {
			return total, nil
		}
		switch r.data[r.pos] {
		case '|':
			advance(r)
			continue
		case ' ':
			advance(r)
		}
		return total, nil
	}
}

// fread_flag / fread_flag_new: a flag token made of an optional '-', letters,
// digits, and '|' separators. Returns the raw token, e.g. "0", "ABQ", "A|B".
read_flag_token :: proc(r: ^Reader) -> (token: string, err: Parse_Error) {
	skip_whitespace(r)
	if at_eof(r) {
		return "", reader_fail(r, .Unexpected_EOF, "expected flags")
	}
	start := r.pos
	for {
		part_start := r.pos
		if !at_eof(r) && r.data[r.pos] == '-' {
			advance(r)
		}
		for !at_eof(r) && is_alpha(r.data[r.pos]) {
			advance(r)
		}
		for !at_eof(r) && is_digit(r.data[r.pos]) {
			advance(r)
		}
		if r.pos == part_start || (r.pos == part_start + 1 && r.data[part_start] == '-') {
			return "", reader_fail(r, .Bad_Flag, "expected flag letters or digits", upcoming(r))
		}
		if !at_eof(r) && r.data[r.pos] == '|' {
			advance(r)
			continue
		}
		break
	}
	token = string(r.data[start:r.pos])
	if !at_eof(r) && r.data[r.pos] == ' ' {
		advance(r)
	}
	return token, nil
}

// fread_word: a whitespace-delimited word, or a word quoted with ' or ".
// Quotes are not included. The delimiter after an unquoted word is left
// unconsumed; EOF also ends an unquoted word.
read_word :: proc(r: ^Reader) -> (word: string, err: Parse_Error) {
	skip_whitespace(r)
	if at_eof(r) {
		return "", reader_fail(r, .Unexpected_EOF, "expected a word")
	}
	line, column := r.line, r.column
	quote := r.data[r.pos]
	if quote == '\'' || quote == '"' {
		advance(r)
		start := r.pos
		for {
			if at_eof(r) {
				return "", reader_fail_at(r, line, column, .Unexpected_EOF, "unterminated quoted word", string(r.data[start - 1:]))
			}
			if r.data[r.pos] == quote {
				break
			}
			if r.pos - start >= MAX_WORD_LENGTH {
				return "", reader_fail_at(r, line, column, .Word_Too_Long, "quoted word is too long", string(r.data[start:r.pos]))
			}
			advance(r)
		}
		word = string(r.data[start:r.pos])
		advance(r) // closing quote
		return word, nil
	}
	start := r.pos
	for !at_eof(r) && !is_space(r.data[r.pos]) {
		if r.pos - start >= MAX_WORD_LENGTH {
			return "", reader_fail_at(r, line, column, .Word_Too_Long, "word is too long", string(r.data[start:r.pos]))
		}
		advance(r)
	}
	return string(r.data[start:r.pos]), nil
}

// fread_string: skip leading whitespace, then read up to a '~' terminator.
// '\r' bytes are dropped; if any are present the result is allocated with
// `allocator`, otherwise it is a view into the input.
read_string :: proc(r: ^Reader, allocator := context.allocator) -> (value: string, err: Parse_Error) {
	skip_whitespace(r)
	if at_eof(r) {
		return "", reader_fail(r, .Unexpected_EOF, "expected a ~-terminated string")
	}
	line, column := r.line, r.column
	start := r.pos
	has_cr := false
	for {
		if at_eof(r) {
			return "", reader_fail_at(r, line, column, .Unterminated_String, "string has no closing ~", string(r.data[start:]))
		}
		b := r.data[r.pos]
		if b == '~' {
			break
		}
		if b == '\r' {
			has_cr = true
		}
		if r.pos - start >= MAX_STRING_LENGTH {
			return "", reader_fail_at(r, line, column, .String_Too_Long, "string is longer than the game allows", string(r.data[start:r.pos]))
		}
		advance(r)
	}
	raw := string(r.data[start:r.pos])
	advance(r) // closing ~
	if !has_cr {
		return raw, nil
	}
	stripped, _ := strings.remove_all(raw, "\r", allocator)
	return stripped, nil
}

// fread_to_eol: skip to the end of the line and past any newline characters.
read_to_eol :: proc(r: ^Reader) {
	for !at_eof(r) && r.data[r.pos] != '\n' && r.data[r.pos] != '\r' {
		advance(r)
	}
	for !at_eof(r) && (r.data[r.pos] == '\n' || r.data[r.pos] == '\r') {
		advance(r)
	}
}

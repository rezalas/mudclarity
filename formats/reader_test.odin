/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:strings"
import "core:testing"

@(private = "file")
reader_for :: proc(text: string) -> Reader {
	return reader_make(transmute([]u8)text)
}

// --- read_letter ---

@(test)
test_read_letter_skips_whitespace :: proc(t: ^testing.T) {
	r := reader_for(" \t\r\n  X")
	letter, err := read_letter(&r)
	testing.expect(t, err == nil)
	testing.expect_value(t, letter, u8('X'))
	testing.expect(t, at_eof(&r))
}

@(test)
test_read_letter_at_eof :: proc(t: ^testing.T) {
	r := reader_for("   ")
	_, err := read_letter(&r)
	expect_failure(t, err, .Unexpected_EOF)
}

@(test)
test_peek_letter_does_not_consume :: proc(t: ^testing.T) {
	r := reader_for("  Q")
	letter, ok := peek_letter(&r)
	testing.expect(t, ok)
	testing.expect_value(t, letter, u8('Q'))
	testing.expect_value(t, r.pos, 0)
}

// --- read_number ---

@(test)
test_read_number_plain_and_signed :: proc(t: ^testing.T) {
	r := reader_for("42 +7 -12\n0")
	for expected in ([]int{42, 7, -12, 0}) {
		n, err := read_number(&r)
		testing.expect(t, err == nil)
		testing.expect_value(t, n, expected)
	}
}

@(test)
test_read_number_pipe_sums :: proc(t: ^testing.T) {
	r := reader_for("1|2|4 ")
	n, err := read_number(&r)
	testing.expect(t, err == nil)
	testing.expect_value(t, n, 7)
}

@(test)
test_read_number_stops_at_non_digit :: proc(t: ^testing.T) {
	// Dice are read as number, letter, number, letter, number.
	r := reader_for("1d6+3")
	count, _ := read_number(&r)
	d, _ := read_letter(&r)
	sides, _ := read_number(&r)
	plus, _ := read_letter(&r)
	bonus, err := read_number(&r)
	testing.expect(t, err == nil)
	testing.expect_value(t, count, 1)
	testing.expect_value(t, d, u8('d'))
	testing.expect_value(t, sides, 6)
	testing.expect_value(t, plus, u8('+'))
	testing.expect_value(t, bonus, 3)
}

@(test)
test_read_number_consumes_one_trailing_space :: proc(t: ^testing.T) {
	r := reader_for("5  x")
	_, _ = read_number(&r)
	testing.expect_value(t, r.pos, 2)
}

@(test)
test_read_number_bad_format_reports_position :: proc(t: ^testing.T) {
	r := reader_for("\n  abc")
	_, err := read_number(&r)
	if expect_failure(t, err, .Bad_Number, 2) {
		failure := err.(Parse_Failure)
		testing.expect_value(t, failure.column, 3)
		testing.expect_value(t, failure_token(&failure), "abc")
	}
}

@(test)
test_read_number_sign_without_digits :: proc(t: ^testing.T) {
	r := reader_for("- 5")
	_, err := read_number(&r)
	expect_failure(t, err, .Bad_Number)
}

@(test)
test_read_number_overflow :: proc(t: ^testing.T) {
	r := reader_for("99999999999")
	_, err := read_number(&r)
	expect_failure(t, err, .Number_Out_Of_Range)

	r = reader_for("2147483647|1")
	_, err = read_number(&r)
	expect_failure(t, err, .Number_Out_Of_Range)

	r = reader_for("2147483647 -2147483647")
	a, err_a := read_number(&r)
	b, err_b := read_number(&r)
	testing.expect(t, err_a == nil && err_b == nil)
	testing.expect_value(t, a, 2147483647)
	testing.expect_value(t, b, -2147483647)
}

@(test)
test_read_number_at_eof :: proc(t: ^testing.T) {
	r := reader_for("")
	_, err := read_number(&r)
	expect_failure(t, err, .Unexpected_EOF)

	r = reader_for("-")
	_, err = read_number(&r)
	expect_failure(t, err, .Bad_Number)
}

// --- read_flag_token ---

@(test)
test_read_flag_token_forms :: proc(t: ^testing.T) {
	r := reader_for("0 ABQ A|B -5 AB12\nx")
	for expected in ([]string{"0", "ABQ", "A|B", "-5", "AB12"}) {
		token, err := read_flag_token(&r)
		testing.expect(t, err == nil)
		testing.expect_value(t, token, expected)
	}
	// The newline after the last token is not consumed.
	testing.expect_value(t, r.data[r.pos], u8('\n'))
}

@(test)
test_read_flag_token_rejects_non_flags :: proc(t: ^testing.T) {
	for text in ([]string{"~", "-", "A|", "'x'"}) {
		r := reader_for(text)
		_, err := read_flag_token(&r)
		expect_failure(t, err, .Bad_Flag)
	}
}

// --- read_word ---

@(test)
test_read_word_plain :: proc(t: ^testing.T) {
	r := reader_for("  hello world\n")
	a, _ := read_word(&r)
	b, err := read_word(&r)
	testing.expect(t, err == nil)
	testing.expect_value(t, a, "hello")
	testing.expect_value(t, b, "world")
	// The delimiter after a word is not consumed.
	testing.expect_value(t, r.data[r.pos], u8('\n'))
}

@(test)
test_read_word_quoted :: proc(t: ^testing.T) {
	r := reader_for(`'acid stream' "x y" '' end`)
	for expected in ([]string{"acid stream", "x y", "", "end"}) {
		word, err := read_word(&r)
		testing.expect(t, err == nil)
		testing.expect_value(t, word, expected)
	}
}

@(test)
test_read_word_ends_at_eof :: proc(t: ^testing.T) {
	r := reader_for("last")
	word, err := read_word(&r)
	testing.expect(t, err == nil)
	testing.expect_value(t, word, "last")
	testing.expect(t, at_eof(&r))
}

@(test)
test_read_word_errors :: proc(t: ^testing.T) {
	r := reader_for("  ")
	_, err := read_word(&r)
	expect_failure(t, err, .Unexpected_EOF)

	r = reader_for("\n'unterminated")
	_, err = read_word(&r)
	expect_failure(t, err, .Unexpected_EOF, 2)

	long := strings.repeat("w", MAX_WORD_LENGTH + 1, context.temp_allocator)
	r = reader_for(long)
	_, err = read_word(&r)
	expect_failure(t, err, .Word_Too_Long)

	ok_long := strings.repeat("w", MAX_WORD_LENGTH, context.temp_allocator)
	r = reader_for(ok_long)
	word, ok_err := read_word(&r)
	testing.expect(t, ok_err == nil)
	testing.expect_value(t, len(word), MAX_WORD_LENGTH)
}

// --- read_string ---

@(test)
test_read_string_empty_and_simple :: proc(t: ^testing.T) {
	r := reader_for("~ hello~\n  \n  multi\nline~")
	for expected in ([]string{"", "hello", "multi\nline"}) {
		s, err := read_string(&r)
		testing.expect(t, err == nil)
		testing.expect_value(t, s, expected)
	}
}

@(test)
test_read_string_without_cr_is_a_view :: proc(t: ^testing.T) {
	text := "abc~"
	r := reader_for(text)
	s, _ := read_string(&r)
	testing.expect(t, raw_data(s) == raw_data(text), "expected a view into the input")
}

@(test)
test_read_string_strips_cr :: proc(t: ^testing.T) {
	r := reader_for("line one\r\nline two\r\n~")
	s, err := read_string(&r)
	defer delete(s)
	testing.expect(t, err == nil)
	testing.expect_value(t, s, "line one\nline two\n")
}

@(test)
test_read_string_unterminated_reports_start :: proc(t: ^testing.T) {
	r := reader_for("\n\n  never closed\nmore text")
	_, err := read_string(&r)
	if expect_failure(t, err, .Unterminated_String, 3) {
		testing.expect_value(t, err.(Parse_Failure).column, 3)
	}
}

@(test)
test_read_string_length_limit :: proc(t: ^testing.T) {
	at_limit := strings.concatenate({strings.repeat("s", MAX_STRING_LENGTH, context.temp_allocator), "~"}, context.temp_allocator)
	r := reader_for(at_limit)
	s, err := read_string(&r)
	testing.expect(t, err == nil)
	testing.expect_value(t, len(s), MAX_STRING_LENGTH)

	over := strings.concatenate({strings.repeat("s", MAX_STRING_LENGTH + 1, context.temp_allocator), "~"}, context.temp_allocator)
	r = reader_for(over)
	_, err = read_string(&r)
	expect_failure(t, err, .String_Too_Long)
}

@(test)
test_read_string_keeps_latin1_bytes :: proc(t: ^testing.T) {
	r := reader_for("caf\xe9 \xa9 2001~")
	s, err := read_string(&r)
	testing.expect(t, err == nil)
	testing.expect_value(t, s, "caf\xe9 \xa9 2001")
}

// --- read_to_eol and position tracking ---

@(test)
test_read_to_eol_skips_line_endings :: proc(t: ^testing.T) {
	r := reader_for("comment here\r\n\r\n\nX")
	read_to_eol(&r)
	testing.expect_value(t, r.data[r.pos], u8('X'))
	testing.expect_value(t, r.line, 4)
	testing.expect_value(t, r.column, 1)

	r = reader_for("no newline")
	read_to_eol(&r)
	testing.expect(t, at_eof(&r))
}

@(test)
test_line_and_column_tracking :: proc(t: ^testing.T) {
	r := reader_for("first~\nsecond\nline~ word")
	_, _ = read_string(&r)
	_, _ = read_string(&r)
	testing.expect_value(t, r.line, 3)
	testing.expect_value(t, r.column, 6)
	_, _ = read_word(&r)
	testing.expect_value(t, r.column, 11)
}

@(test)
test_errors_carry_reader_context :: proc(t: ^testing.T) {
	r := reader_for("oops")
	r.section = "ROOMS"
	r.vnum = 3001
	_, err := read_number(&r)
	failure := err.(Parse_Failure)
	testing.expect_value(t, failure.section, "ROOMS")
	testing.expect_value(t, failure.vnum, 3001)
}

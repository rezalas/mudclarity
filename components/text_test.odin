/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:strings"
import "core:testing"
import "core:unicode/utf8"

@(test)
test_display_text_ascii_unchanged :: proc(t: ^testing.T) {
	testing.expect_value(t, display_text("The Temple of Midgaard"), "The Temple of Midgaard")
	testing.expect_value(t, display_text(""), "")
}

@(test)
test_display_text_latin1 :: proc(t: ^testing.T) {
	// 0xA9 is the copyright sign in Latin-1 (it appears in the corpus).
	bytes := []u8{'(', 0xA9, ')', ' ', 0xE9, 0xFF}
	raw := string(bytes)
	text := display_text(raw)
	testing.expect_value(t, text, "(©) éÿ")
	testing.expect(t, utf8.valid_string(text))
}

@(test)
test_display_text_controls :: proc(t: ^testing.T) {
	bytes := []u8{'a', 0x00, 'b', '\t', 'c', 0x1B, 'd', 0x7F, 'e', 0x85, 'f'}
	raw := string(bytes)
	testing.expect_value(t, display_text(raw), "a b c d e�f")
}

@(test)
test_display_text_newlines :: proc(t: ^testing.T) {
	raw := "one\r\ntwo\rthree\nfour"
	testing.expect_value(t, display_text(raw), "one two three four")
	testing.expect_value(t, display_text(raw, keep_newlines = true), "one\ntwo\nthree\nfour")
}

@(test)
test_display_text_cuts_long_input :: proc(t: ^testing.T) {
	raw := strings.repeat("x", MAX_DISPLAY_INPUT + 100, context.temp_allocator)
	text := display_text(raw)
	testing.expect_value(t, len(text), MAX_DISPLAY_INPUT + 3)
	testing.expect(t, strings.has_suffix(text, "..."))
}

@(test)
test_display_text_every_byte_is_valid_utf8 :: proc(t: ^testing.T) {
	all: [256]u8
	for &b, i in all {
		b = u8(i)
	}
	testing.expect(t, utf8.valid_string(display_text(string(all[:]), keep_newlines = true)))
}

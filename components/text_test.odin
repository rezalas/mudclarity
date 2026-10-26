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

@(test)
test_display_user_text_keeps_utf8 :: proc(t: ^testing.T) {
	testing.expect_value(t, display_user_text("Café — ✓ 龍"), "Café — ✓ 龍")
	// The same bytes through display_text would be read as Latin-1.
	testing.expect(t, display_text("Café") != "Café")
}

@(test)
test_display_user_text_cleans_bad_input :: proc(t: ^testing.T) {
	testing.expect_value(t, display_user_text("a\xffb"), "a�b")       // Invalid byte
	testing.expect_value(t, display_user_text("a\xe2\x9c"), "a��") // Cut-off sequence
	testing.expect_value(t, display_user_text("a\tb\x00c\u0085d"), "a b c d") // C0 and C1 controls
	testing.expect_value(t, display_user_text("a\r\nb\rc\nd"), "a b c d")
	testing.expect_value(t, display_user_text("a\r\nb\rc\nd", keep_newlines = true), "a\nb\nc\nd")
}

@(test)
test_display_user_text_cuts_long_input :: proc(t: ^testing.T) {
	raw := strings.repeat("é", MAX_DISPLAY_INPUT, context.temp_allocator) // Two bytes each
	text := display_user_text(raw)
	testing.expect(t, strings.has_suffix(text, "..."))
	testing.expect(t, len(text) <= MAX_DISPLAY_INPUT + 3)
	testing.expect(t, utf8.valid_string(text))
}

@(test)
test_display_user_text_every_byte_pair_is_valid_utf8 :: proc(t: ^testing.T) {
	pair: [2]u8
	for a in 0 ..< 256 {
		for b in 0 ..< 256 {
			pair = {u8(a), u8(b)}
			if !utf8.valid_string(display_user_text(string(pair[:]), keep_newlines = true)) {
				testing.expectf(t, false, "bytes %x %x", a, b)
				return
			}
		}
	}
}

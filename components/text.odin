/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:strings"
import "core:unicode/utf8"

// Longest text display_text returns, in bytes of input. Room descriptions
// are a few hundred bytes; anything far longer is cut rather than laid out.
MAX_DISPLAY_INPUT :: 16 * 1024

/*
 Text from an area file, made safe to draw. Area files are Latin-1 and
 untrusted, while Skald draws UTF-8, so every string read from a file goes
 through here before it reaches a widget:

 - bytes 0xA0-0xFF become the Latin-1 characters they stand for;
 - C1 control bytes (0x80-0x9F) become U+FFFD;
 - control characters become spaces, except newlines when `keep_newlines`
   (CR LF and bare CR count as one newline);
 - input longer than MAX_DISPLAY_INPUT is cut and ends in "...".

 Allocated with `allocator` (by default the frame's temp allocator, which
 suits text built inside `view`).
*/
display_text :: proc(raw: string, keep_newlines := false, allocator := context.temp_allocator) -> string {
	input := raw
	is_cut := len(input) > MAX_DISPLAY_INPUT
	if is_cut {
		input = input[:MAX_DISPLAY_INPUT]
	}
	b: strings.Builder
	strings.builder_init(&b, 0, len(input) + 8, allocator)
	for i := 0; i < len(input); i += 1 {
		c := input[i]
		switch {
		case c == '\r' || c == '\n':
			if c == '\r' && i + 1 < len(input) && input[i + 1] == '\n' {
				i += 1
			}
			strings.write_byte(&b, '\n' if keep_newlines else ' ')
		case c < 0x20 || c == 0x7F:
			strings.write_byte(&b, ' ')
		case c < 0x80:
			strings.write_byte(&b, c)
		case c < 0xA0:
			strings.write_rune(&b, utf8.RUNE_ERROR)
		case:
			strings.write_rune(&b, rune(c))
		}
	}
	if is_cut {
		strings.write_string(&b, "...")
	}
	return strings.to_string(b)
}

/*
 Text the user wrote (notes and issues in area.clarity), made safe to draw.
 Unlike area files it is UTF-8, but the file can be edited by hand, so it
 is checked the same way: invalid UTF-8 becomes U+FFFD, control characters
 (C1 included) become spaces except newlines when `keep_newlines`, and
 input longer than MAX_DISPLAY_INPUT is cut and ends in "...".

 Allocated with `allocator` (by default the frame's temp allocator).
*/
display_user_text :: proc(raw: string, keep_newlines := false, allocator := context.temp_allocator) -> string {
	input := raw
	is_cut := len(input) > MAX_DISPLAY_INPUT
	if is_cut {
		input = input[:MAX_DISPLAY_INPUT]
	}
	b: strings.Builder
	strings.builder_init(&b, 0, len(input) + 8, allocator)
	for i := 0; i < len(input); {
		r, size := utf8.decode_rune_in_string(input[i:])
		switch {
		case r == '\r' || r == '\n':
			if r == '\r' && i + 1 < len(input) && input[i + 1] == '\n' {
				size += 1
			}
			strings.write_byte(&b, '\n' if keep_newlines else ' ')
		case r < 0x20 || (r >= 0x7F && r < 0xA0):
			strings.write_byte(&b, ' ')
		case:
			// decode_rune gives RUNE_ERROR for invalid bytes (size 1).
			strings.write_rune(&b, r)
		}
		i += size
	}
	if is_cut {
		strings.write_string(&b, "...")
	}
	return strings.to_string(b)
}

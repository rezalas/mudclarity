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

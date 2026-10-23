/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:bytes"
import "core:math/rand"
import "core:testing"
import "core:time"

/*
 Robustness tests: damaged input must produce a result or an error, never a
 crash, hang, or leak. The test runner turns crashes (including failed bounds
 checks) into test failures and reports leaks.
*/

FUZZ_SEED :: 0x6d75_6463_6c61_7269 // "mudclari"
FUZZ_MUTATIONS :: 2000

// Bytes that matter to the format, used when mutating input.
@(private = "file")
INTERESTING_BYTES := [?]u8{'~', '#', '\n', '\r', ' ', '0', '9', '-', '|', '\'', '"', 'S', 'D', 'E', 'A', 'M', '$', 0, 0xff}

// Parse `data` and check that any failure points somewhere inside the input.
@(private = "file")
parse_survives :: proc(t: ^testing.T, data: []u8, loc := #caller_location) {
	loaded, err := load_area_bytes(data, "fuzz.are")
	defer unload_area(loaded)
	if failure, is_failure := err.(Parse_Failure); is_failure {
		max_line := bytes.count(data, {'\n'}) + 1
		testing.expectf(t, failure.line >= 1 && failure.line <= max_line, "failure line %d outside 1..%d", failure.line, max_line, loc = loc)
		testing.expectf(t, failure.column >= 1, "failure column %d < 1", failure.column, loc = loc)
	} else {
		testing.expect(t, loaded != nil, loc = loc)
	}
}

@(test)
test_fuzz_every_truncation :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 60 * time.Second)
	data := ALSTEATOMB_ARE
	for end in 0 ..= len(data) {
		parse_survives(t, data[:end])
	}
}

@(test)
test_fuzz_truncated_midgaard_samples :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 60 * time.Second)
	state := rand.create(FUZZ_SEED)
	gen := rand.default_random_generator(&state)
	data := MIDGAARD_ARE
	for _ in 0 ..< 300 {
		parse_survives(t, data[:rand.int_max(len(data) + 1, gen)])
	}
}

@(test)
test_fuzz_random_mutations :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, 60 * time.Second)
	state := rand.create(FUZZ_SEED)
	gen := rand.default_random_generator(&state)
	original := ALSTEATOMB_ARE
	buffer := make([]u8, len(original))
	defer delete(buffer)
	for _ in 0 ..< FUZZ_MUTATIONS {
		copy(buffer, original)
		edits := 1 + rand.int_max(4, gen)
		for _ in 0 ..< edits {
			i := rand.int_max(len(buffer), gen)
			if rand.int_max(2, gen) == 0 {
				buffer[i] = INTERESTING_BYTES[rand.int_max(len(INTERESTING_BYTES), gen)]
			} else {
				buffer[i] = u8(rand.int_max(256, gen))
			}
		}
		parse_survives(t, buffer)
	}
}

@(test)
test_fuzz_pathological_inputs :: proc(t: ^testing.T) {
	inputs := []string {
		"#",
		"##",
		"#$$",
		"~~~~",
		"#AREA\n",
		"#AREA\n~\n~\n~\n",
		"#ROOMS\n#0\n#$",
		"#AREA\nx~\nx~\nx~\n1|1|1|1|1|1|1|1|1|1 2 3 4 a b 0|0|0|0 1 x~\n#$",
		"\x00\x00\x00",
		"#AREA\n\xff\xfe~",
	}
	for text in inputs {
		parse_survives(t, transmute([]u8)text)
	}
}

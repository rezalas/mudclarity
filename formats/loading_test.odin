/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:strings"
import "core:testing"

@(test)
test_load_area_file_from_disk :: proc(t: ^testing.T) {
	loaded, err := load_area_file(TEST_DATA_DIR + "/valid/alsteatomb.are")
	defer unload_area(loaded)
	if !testing.expectf(t, err == nil, "unexpected error: %v", err) do return
	testing.expect_value(t, loaded.area.header.name, "The Tomb of Alstea")
	testing.expect_value(t, len(loaded.data), 4114)
}

@(test)
test_load_area_file_missing :: proc(t: ^testing.T) {
	loaded, err := load_area_file(TEST_DATA_DIR + "/valid/does_not_exist.are")
	testing.expect(t, loaded == nil)
	expect_failure(t, err, .Io_Error)
}

@(test)
test_load_area_file_reports_parse_errors :: proc(t: ^testing.T) {
	// The old ROM #AREA header has no security or builders fields, so the
	// loader reaches #MOBILES while expecting the security number, just as
	// Riftshadow's own boot would.
	loaded, err := load_area_file(TEST_DATA_DIR + "/invalid/legacy_rom_school.are")
	testing.expect(t, loaded == nil)
	if expect_failure(t, err, .Bad_Number, 11) {
		// The failure must stay readable after the file's memory is freed.
		failure := err.(Parse_Failure)
		testing.expect_value(t, failure.section, "AREA")
		testing.expect_value(t, failure_token(&failure), "#MOBILES")
	}
}

@(test)
test_read_file_capped_rejects_large_files :: proc(t: ^testing.T) {
	data, err := read_file_capped(TEST_DATA_DIR + "/valid/alsteatomb.are", 1000)
	testing.expect(t, data == nil)
	expect_failure(t, err, .File_Too_Large)
}

@(test)
test_unload_area_accepts_nil :: proc(t: ^testing.T) {
	unload_area(nil)
}

@(test)
test_load_area_bytes_copies_input :: proc(t: ^testing.T) {
	text := strings.clone(with_header("#ROOMS\n#101\nHall~\n~\ncity\nS\n#0\n"))
	loaded, err := load_area_bytes(transmute([]u8)text, "copy.are")
	defer unload_area(loaded)
	// Overwrite the caller's buffer; the parsed area must be unaffected.
	for &b in transmute([]u8)text {
		b = 'x'
	}
	delete(text)
	if !testing.expect(t, err == nil) do return
	testing.expect_value(t, loaded.area.rooms[0].name, "Hall")
	testing.expect_value(t, loaded.area.source_name, "copy.are")
}

@(test)
test_parse_error_to_string :: proc(t: ^testing.T) {
	_, err := parse_text(with_header("#ROOMS\n#101\nA~\n~\ncity\nD 0 102 0 0\n~\n~\nS\n#0\n"))
	message := parse_error_to_string(err, "x.are", context.temp_allocator)
	testing.expect_value(t, message, `x.are:17:3: [#ROOMS #101] Bad_Direction: unknown exit direction near "0"`)
	testing.expect_value(t, parse_error_to_string(nil, "x.are", context.temp_allocator), "x.are: ok")
}

@(test)
test_failure_token_is_truncated :: proc(t: ^testing.T) {
	long_section := strings.concatenate({"#", strings.repeat("Z", 100, context.temp_allocator)}, context.temp_allocator)
	failure := expect_parse_failure(t, with_header(long_section), .Unknown_Section)
	testing.expect_value(t, len(failure_token(&failure)), MAX_ERROR_TOKEN)
}

@(test)
test_failure_token_stops_at_line_break :: proc(t: ^testing.T) {
	failure := make_failure(.Bad_Number, 1, 1, "", 0, "x", "#MOBILES\r\n#3700")
	testing.expect_value(t, failure_token(&failure), "#MOBILES")
}

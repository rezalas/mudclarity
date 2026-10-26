/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package settings

import "core:encoding/json"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

import "../testkit"

@(private = "file")
CUSTOM :: Settings {
	theme      = .Dark,
	text_scale = 150,
	palette    = .Colour_Blind,
	filters    = {severities = {.Error}, states = {.Open, .Accepted}},
}

@(private = "file")
read :: proc(text: string) -> Loaded {
	return parse(transmute([]u8)text, context.temp_allocator)
}

@(test)
test_round_trip_is_stable :: proc(t: ^testing.T) {
	text := encode(CUSTOM, "")
	l := read(text)
	testing.expect_value(t, l.status, Load_Status.Read)
	testing.expect_value(t, l.warning, "")
	testing.expect_value(t, l.settings, CUSTOM)
	// Saving what was read gives the same bytes, so the file only changes
	// when a setting does.
	testing.expect_value(t, encode(l.settings, l.original), text)
	testing.expect(t, strings.contains(text, `"theme": "dark"`))
	testing.expect(t, strings.has_suffix(text, "}\n"))
}

@(test)
test_missing_keys_use_defaults :: proc(t: ^testing.T) {
	l := read(`{"format": "mudclarity-settings", "version": 1, "theme": "light"}`)
	testing.expect_value(t, l.status, Load_Status.Read)
	testing.expect_value(t, l.warning, "")
	want := DEFAULTS
	want.theme = .Light
	testing.expect_value(t, l.settings, want)
}

@(test)
test_bad_values_reset_only_that_setting :: proc(t: ^testing.T) {
	l := read(`{"format": "mudclarity-settings", "version": 1, "theme": "purple", "text_size": "large", "palette": 3,
		"filters": {"severities": ["error", "loud"], "states": ["open"]}}`)
	testing.expect_value(t, l.status, Load_Status.Read)
	testing.expect_value(t, l.settings.theme, DEFAULTS.theme)
	testing.expect_value(t, l.settings.text_scale, 125) // The old name "large"
	testing.expect_value(t, l.settings.palette, DEFAULTS.palette)
	testing.expect_value(t, l.settings.filters, DEFAULT_FILTERS)
	for key in ([]string{"theme", "palette", "filters"}) {
		testing.expectf(t, strings.contains(l.warning, key), "the warning %q should name %s", l.warning, key)
	}
	testing.expect(t, !strings.contains(l.warning, "text_size"))
}

@(test)
test_unreadable_files_give_defaults :: proc(t: ^testing.T) {
	big := strings.repeat(" ", MAX_SETTINGS_SIZE + 1, context.temp_allocator)
	for text in ([]string{"", "not json", "[1, 2]", `{"version": 1}`, `{"format": "other", "version": 1}`, `{"format": "mudclarity-settings", "version": 0}`, `{"format": "mudclarity-settings", "version": "1"}`, big}) {
		l := read(text)
		testing.expectf(t, l.status == .Unreadable, "%.40q was read as %v", text, l.status)
		testing.expect_value(t, l.settings, DEFAULTS)
		testing.expect(t, l.warning != "")
		testing.expect_value(t, l.original, "")
	}
}

@(test)
test_unknown_keys_are_kept :: proc(t: ^testing.T) {
	original := `{"format": "mudclarity-settings", "version": 1, "recent": ["/a/area.lst"], "theme": "light",
		"filters": {"severities": ["error"], "states": ["open"], "sort": "name"}}`
	l := read(original)
	text := encode(CUSTOM, l.original)
	value, err := json.parse_string(text, parse_integers = true, allocator = context.temp_allocator)
	if !testing.expect_value(t, err, json.Error.None) do return
	root := value.(json.Object)
	testing.expect_value(t, len(root["recent"].(json.Array)), 1)
	testing.expect_value(t, root["theme"].(json.String), "dark")
	filters := root["filters"].(json.Object)
	testing.expect_value(t, filters["sort"].(json.String), "name")
	testing.expect_value(t, read(text).settings, CUSTOM)
}

@(test)
test_newer_files_are_read_but_never_saved_over :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_settings_newer")
	defer os.remove_all(dir)
	path, _ := filepath.join({dir, FILE_NAME}, context.temp_allocator)
	original := `{"format": "mudclarity-settings", "version": 2, "theme": "dark", "zoom": 3}`
	testing.expect(t, os.write_entire_file(path, original) == nil)

	l := load(path, context.temp_allocator)
	testing.expect_value(t, l.status, Load_Status.Newer)
	testing.expect_value(t, l.settings.theme, Theme_Choice.Dark)
	testing.expect(t, l.warning != "")
	err := save(path, CUSTOM, &l)
	failure, failed := err.(Save_Failure)
	testing.expect(t, failed)
	testing.expect_value(t, failure.kind, Save_Error_Kind.Newer_Version)
	data, _ := os.read_entire_file(path, context.temp_allocator)
	testing.expect_value(t, string(data), original)
}

@(test)
test_save_creates_the_folder_and_reads_back :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_settings_save")
	defer os.remove_all(dir)
	path, _ := filepath.join({dir, APP_DIR_NAME, FILE_NAME}, context.temp_allocator)

	l := load(path, context.temp_allocator)
	testing.expect_value(t, l.status, Load_Status.Missing)
	testing.expect_value(t, l.settings, DEFAULTS)
	testing.expect_value(t, l.warning, "")
	testing.expect(t, save(path, CUSTOM, &l) == nil)
	testing.expect(t, !os.exists(strings.concatenate({path, ".tmp"}, context.temp_allocator)))

	again := load(path, context.temp_allocator)
	testing.expect_value(t, again.status, Load_Status.Read)
	testing.expect_value(t, again.settings, CUSTOM)
}

@(test)
test_unreadable_files_are_backed_up_once :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_settings_backup")
	defer os.remove_all(dir)
	path, _ := filepath.join({dir, FILE_NAME}, context.temp_allocator)
	backup := strings.concatenate({path, BACKUP_SUFFIX}, context.temp_allocator)
	testing.expect(t, os.write_entire_file(path, "{ broken") == nil)

	l := load(path, context.temp_allocator)
	testing.expect_value(t, l.status, Load_Status.Unreadable)
	testing.expect(t, save(path, CUSTOM, &l) == nil)
	data, _ := os.read_entire_file(backup, context.temp_allocator)
	testing.expect_value(t, string(data), "{ broken")
	testing.expect_value(t, load(path, context.temp_allocator).settings, CUSTOM)

	// The next save replaces the file but leaves the backup alone.
	testing.expect_value(t, l.status, Load_Status.Read)
	testing.expect(t, save(path, DEFAULTS, &l) == nil)
	data, _ = os.read_entire_file(backup, context.temp_allocator)
	testing.expect_value(t, string(data), "{ broken")
}

@(test)
test_default_path :: proc(t: ^testing.T) {
	path, ok := default_path(context.temp_allocator)
	if !ok {
		return // No home or config directory in this environment
	}
	testing.expect_value(t, filepath.base(path), FILE_NAME)
	testing.expect_value(t, filepath.base(filepath.dir(path)), APP_DIR_NAME)
}

@(test)
test_destroy_frees_what_load_allocated :: proc(t: ^testing.T) {
	l := parse(transmute([]u8)string(`{"format": "mudclarity-settings", "version": 1, "theme": 7}`))
	testing.expect(t, l.original != "" && l.warning != "")
	destroy(&l)
	testing.expect_value(t, l.original, "")
	bad := parse(transmute([]u8)string("nope"))
	destroy(&bad)
}

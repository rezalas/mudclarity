/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package settings

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

/*
 The settings file: settings.json in a "mudclarity" folder in the OS's
 per-user config directory. Pretty-printed JSON with sorted keys:

     {"format": "mudclarity-settings", "version": 1, "theme": "system", ...}

 It is untrusted input. Reading never fails: a missing file gives the
 defaults, an unreadable one gives the defaults and a warning, and a bad
 value resets just that setting. Keys this version doesn't know are kept
 when saving, a file from a newer version is never overwritten, and an
 unreadable file is kept as settings.json.bak before it is replaced.
*/

FORMAT_NAME :: "mudclarity-settings"
FORMAT_VERSION :: 1
MAX_SETTINGS_SIZE :: 64 * 1024
APP_DIR_NAME :: "mudclarity"
FILE_NAME :: "settings.json"
BACKUP_SUFFIX :: ".bak"

Load_Status :: enum u8 {
	Missing,    // No file yet: defaults
	Read,       // Read (possibly with some settings reset)
	Newer,      // From a newer version: read as far as possible, never saved over
	Unreadable, // Not a settings file: defaults; backed up before the first save
}

// Settings as read from a file, and what saving them needs to know.
Loaded :: struct {
	settings: Settings,
	status:   Load_Status,
	original: string, // The file's text when it was a settings object, so a save keeps keys this version doesn't know
	warning:  string, // What went wrong, for a banner; "" if nothing did
}

Save_Error_Kind :: enum {
	Newer_Version, // The file is from a newer version; it is left alone
	Io_Error,
}

// `detail` is allocated with the temp allocator.
Save_Failure :: struct {
	kind:   Save_Error_Kind,
	detail: string,
}

// nil means success.
Save_Error :: union {
	Save_Failure,
}

// Where the settings file lives on this OS. Allocated with `allocator`.
default_path :: proc(allocator := context.allocator) -> (path: string, ok: bool) {
	dir, err := os.user_config_dir(context.temp_allocator)
	if err != nil || dir == "" {
		return "", false
	}
	joined, join_err := filepath.join({dir, APP_DIR_NAME, FILE_NAME}, allocator)
	return joined, join_err == nil
}

// Read the settings file at `path`. Strings in the result are allocated
// with `allocator`; free them with destroy.
load :: proc(path: string, allocator := context.allocator) -> Loaded {
	if !os.exists(path) {
		return Loaded{settings = DEFAULTS, status = .Missing}
	}
	f, open_err := os.open(path)
	if open_err != nil {
		return unreadable(fmt.tprintf("%s could not be opened", path), allocator)
	}
	defer os.close(f)
	size, size_err := os.file_size(f)
	if size_err != nil || size > MAX_SETTINGS_SIZE {
		return unreadable(fmt.tprintf("%s is larger than %d bytes", path, MAX_SETTINGS_SIZE), allocator)
	}
	data, read_err := os.read_entire_file_from_file(f, context.temp_allocator)
	if read_err != nil {
		return unreadable(fmt.tprintf("%s could not be read", path), allocator)
	}
	return parse(data, allocator)
}

// Read settings from a file's contents. See load.
parse :: proc(data: []u8, allocator := context.allocator) -> Loaded {
	if len(data) > MAX_SETTINGS_SIZE {
		return unreadable(fmt.tprintf("the settings file is larger than %d bytes", MAX_SETTINGS_SIZE), allocator)
	}
	value, json_err := json.parse(data, parse_integers = true, allocator = context.temp_allocator)
	root, is_object := value.(json.Object)
	if json_err != .None || !is_object {
		return unreadable("the settings file is not valid JSON", allocator)
	}
	format, _ := root["format"].(json.String)
	version, has_version := root["version"].(json.Integer)
	if format != FORMAT_NAME || !has_version || version < 1 {
		return unreadable("the file is not a Mud Clarity settings file", allocator)
	}

	l := Loaded{settings = DEFAULTS, status = .Read}
	if version > FORMAT_VERSION {
		l.status = .Newer
	}
	bad := make([dynamic]string, context.temp_allocator)
	read_name(root, "theme", THEME_NAMES, &l.settings.theme, &bad)
	read_text_scale(root, &l.settings.text_scale, &bad)
	read_name(root, "palette", PALETTE_NAMES, &l.settings.palette, &bad)
	read_filters(root, &l.settings.filters, &bad)

	l.original = strings.clone(string(data), allocator)
	switch {
	case l.status == .Newer:
		l.warning = strings.clone("Your settings file is from a newer version of Mud Clarity. Changes to settings will apply, but won't be saved.", allocator)
	case len(bad) > 0:
		l.warning = fmt.aprintf("Some settings in your settings file weren't valid, so they use their defaults: %s.", strings.join(bad[:], ", ", context.temp_allocator), allocator = allocator)
	}
	return l
}

// Free what load or parse allocated.
destroy :: proc(l: ^Loaded, allocator := context.allocator) {
	delete(l.original, allocator)
	delete(l.warning, allocator)
	l.original, l.warning = "", ""
}

// Write `s` to `path`, keeping the keys of `loaded.original` that this
// version doesn't know. The folder is created if needed, an unreadable
// file is first kept as <path>.bak, and the file is written to a temporary
// name and renamed into place. A file from a newer version is refused.
save :: proc(path: string, s: Settings, loaded: ^Loaded) -> Save_Error {
	if loaded.status == .Newer {
		return Save_Failure{.Newer_Version, fmt.tprintf("%s is from a newer version of Mud Clarity", path)}
	}
	if err := os.make_directory_all(filepath.dir(path)); err != nil && err != .Exist {
		return Save_Failure{.Io_Error, fmt.tprintf("could not create the folder for %s", path)}
	}
	if loaded.status == .Unreadable && os.exists(path) {
		backup := strings.concatenate({path, BACKUP_SUFFIX}, context.temp_allocator)
		_ = os.remove(backup) // Rename doesn't replace files on every OS
		if os.rename(path, backup) != nil {
			return Save_Failure{.Io_Error, fmt.tprintf("could not keep the unreadable %s as %s", path, backup)}
		}
	}
	text := encode(s, loaded.original)
	temp_path := strings.concatenate({path, ".tmp"}, context.temp_allocator)
	if os.write_entire_file(temp_path, text) != nil {
		_ = os.remove(temp_path)
		return Save_Failure{.Io_Error, fmt.tprintf("could not write %s", temp_path)}
	}
	if os.rename(temp_path, path) != nil {
		_ = os.remove(temp_path)
		return Save_Failure{.Io_Error, fmt.tprintf("could not replace %s", path)}
	}
	if loaded.status != .Read {
		loaded.status = .Read // Saved: there is nothing left to back up
	}
	return nil
}

// The file's contents for `s`: `original`'s keys with ours written over
// them, pretty-printed with sorted keys and a final newline. Allocated
// with the temp allocator.
encode :: proc(s: Settings, original: string) -> string {
	root: json.Object
	if original != "" {
		value, _ := json.parse_string(original, parse_integers = true, allocator = context.temp_allocator)
		root, _ = value.(json.Object)
	}
	if root == nil {
		root = make(json.Object, context.temp_allocator)
	}
	root["format"] = json.String(FORMAT_NAME)
	root["version"] = json.Integer(FORMAT_VERSION)
	root["theme"] = json.String(THEME_NAMES[s.theme])
	root["text_scale"] = json.Integer(s.text_scale)
	delete_key(&root, "text_size") // Replaced by text_scale; read once, then gone
	root["palette"] = json.String(PALETTE_NAMES[s.palette])
	filters, _ := root["filters"].(json.Object)
	if filters == nil {
		filters = make(json.Object, context.temp_allocator)
	}
	filters["severities"] = name_array(SEVERITY_NAMES, s.filters.severities)
	filters["states"] = name_array(STATE_NAMES, s.filters.states)
	root["filters"] = filters
	options := json.Marshal_Options {
		pretty           = true,
		use_spaces       = true,
		spaces           = 2,
		sort_maps_by_key = true,
	}
	text, _ := json.unparse(root, options, context.temp_allocator)
	return strings.concatenate({text, "\n"}, context.temp_allocator)
}

@(private = "file")
unreadable :: proc(why: string, allocator: runtime.Allocator) -> Loaded {
	return Loaded {
		settings = DEFAULTS,
		status = .Unreadable,
		warning = fmt.aprintf("Your settings couldn't be read (%s), so the defaults are in use. The file will be kept as %s%s when settings are next saved.", why, FILE_NAME, BACKUP_SUFFIX, allocator = allocator),
	}
}

// Set `value` from the name at `key`, if it is one of `names`; a missing
// key leaves the default, anything else is reported in `bad`.
@(private = "file")
read_name :: proc(root: json.Object, key: string, names: [$E]string, value: ^E, bad: ^[dynamic]string) {
	raw, present := root[key]
	if !present {
		return
	}
	if name, is_string := raw.(json.String); is_string {
		for n, e in names {
			if n == name {
				value^ = e
				return
			}
		}
	}
	append(bad, key)
}

// "text_scale" (a percentage), or the older "text_size" name. Out of
// range or between steps is brought onto the nearest step.
@(private = "file")
read_text_scale :: proc(root: json.Object, percent: ^int, bad: ^[dynamic]string) {
	if raw, present := root["text_scale"]; present {
		if n, is_integer := raw.(json.Integer); is_integer {
			percent^ = clamp_text_scale(int(clamp(n, -1000, 1000)))
		} else {
			append(bad, "text_scale")
		}
		return
	}
	raw, present := root["text_size"]
	if !present {
		return
	}
	if name, is_string := raw.(json.String); is_string {
		for legacy in LEGACY_TEXT_SIZES {
			if legacy.name == name {
				percent^ = legacy.percent
				return
			}
		}
	}
	append(bad, "text_size")
}

@(private = "file")
read_filters :: proc(root: json.Object, filters: ^Filters, bad: ^[dynamic]string) {
	raw, present := root["filters"]
	if !present {
		return
	}
	object, is_object := raw.(json.Object)
	severities, severities_ok := read_set(object, "severities", SEVERITY_NAMES)
	states, states_ok := read_set(object, "states", STATE_NAMES)
	if !is_object || !severities_ok || !states_ok {
		append(bad, "filters")
		return
	}
	filters^ = {severities, states}
}

// A set written as an array of names. Every name must be known.
@(private = "file")
read_set :: proc(object: json.Object, key: string, names: [$E]string) -> (set: bit_set[E], ok: bool) {
	array := object[key].(json.Array) or_return
	outer: for item in array {
		name := item.(json.String) or_return
		for n, e in names {
			if n == name {
				set += {e}
				continue outer
			}
		}
		return {}, false
	}
	return set, true
}

@(private = "file")
name_array :: proc(names: [$E]string, set: bit_set[E]) -> json.Array {
	array := make(json.Array, 0, card(set), context.temp_allocator)
	for e in E {
		if e in set {
			append(&array, json.Value(json.String(names[e])))
		}
	}
	return array
}

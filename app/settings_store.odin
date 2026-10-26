/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "base:runtime"
import "core:strings"

import "gui:skald"

import "../settings"

/*
 The settings file as the GUI uses it. run loads it before the window
 opens (it is tiny) into a Settings_Store that lives until the window
 closes; State points at it, so each test can use a store of its own.
 State.settings holds the current values; every change applies them and
 saves them through the Apply_Settings effect.
*/

Settings_Store :: struct {
	path:   string, // Where the file is saved; "" if the OS has no config directory
	loaded: settings.Loaded,
}

// The store run hands to init. Set before the window opens; read-only after.
@(private)
startup_store: ^Settings_Store

// Load the settings file from its usual place, on the heap.
settings_store_open :: proc() -> ^Settings_Store {
	context.allocator = runtime.heap_allocator()
	store := new(Settings_Store)
	path, ok := settings.default_path()
	if !ok {
		store.loaded = {settings = settings.DEFAULTS, status = .Missing}
		return store
	}
	store.path = path
	store.loaded = settings.load(path)
	return store
}

// Free a store from settings_store_open. Safe to call with nil.
settings_store_close :: proc(store: ^Settings_Store) {
	if store == nil {
		return
	}
	context.allocator = runtime.heap_allocator()
	settings.destroy(&store.loaded)
	delete(store.path)
	free(store)
}

// The Skald theme the settings ask for: light, dark or the OS's, with the
// app's type sizes (app_type), at the chosen text size.
theme_for :: proc(s: settings.Settings) -> skald.Theme {
	base: skald.Theme
	switch s.theme {
	case .Light:
		base = skald.theme_light()
	case .Dark:
		base = skald.theme_dark()
	case .System:
		base = skald.theme_system()
	}
	return scaled_theme(app_type(base), f32(settings.clamp_text_scale(s.text_scale)) / 100)
}

// The app's type sizes on `base`. Skald's small and body text (13 and 14
// px) suit a dense widget kit; this app is mostly reading, so labels,
// buttons, captions and inspector text are a step larger. Headings and
// the summary numbers keep Skald's sizes.
app_type :: proc(base: skald.Theme) -> skald.Theme {
	t := base
	t.font.size_xs = 12
	t.font.size_sm = 14
	t.font.size_md = 15
	return t
}

// `base` with its font sizes, spacing and corner radii multiplied by
// `factor` (colours unchanged), so the whole app grows with its text.
// Pill radii stay pills.
scaled_theme :: proc(base: skald.Theme, factor: f32) -> skald.Theme {
	t := base
	for size in ([]^f32{&t.font.size_xs, &t.font.size_sm, &t.font.size_md, &t.font.size_lg, &t.font.size_xl, &t.font.size_display}) {
		size^ *= factor
	}
	for step in ([]^f32{&t.spacing.xs, &t.spacing.sm, &t.spacing.md, &t.spacing.lg, &t.spacing.xl}) {
		step^ *= factor
	}
	for radius in ([]^f32{&t.radius.sm, &t.radius.md, &t.radius.lg, &t.radius.xl}) {
		radius^ *= factor
	}
	return t
}

// Save `s` to the store's file. A file from a newer version is left alone
// quietly (the load warning already said changes won't be kept). Returns
// the error text for a banner, heap-allocated, or "".
save_settings :: proc(store: ^Settings_Store, s: settings.Settings) -> string {
	if store == nil || store.path == "" {
		return ""
	}
	err := settings.save(store.path, s, &store.loaded)
	failure, failed := err.(settings.Save_Failure)
	if !failed || failure.kind == .Newer_Version {
		return ""
	}
	return strings.clone(failure.detail, runtime.heap_allocator())
}

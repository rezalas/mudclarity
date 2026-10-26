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
// app's type sizes (app_type) and the chosen palette, at the chosen text
// size.
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
	if s.palette == .Colour_Blind {
		base = colour_blind(base)
	}
	return scaled_theme(app_type(base), f32(settings.clamp_text_scale(s.text_scale)) / 100)
}

// `base` with error and warning colours that stay apart with protanopia,
// deuteranopia and tritanopia. Skald's red and amber run together for
// deuteranopia, worst on the light theme (CIEDE2000 3.0 apart). These were
// picked by simulating each (Machado et al. 2009, severity 1) and keeping
// every pair of meaning colours (error, warning, info, selection) at least
// ~15 apart, and each at 3.5:1 or more against the panels. The light pair
// is told apart by lightness as well as hue. Info (muted text) and the
// selection (primary) are unchanged: they already stay apart.
colour_blind :: proc(base: skald.Theme) -> skald.Theme {
	t := base
	if is_light(t.color) {
		t.color.danger = skald.rgb(0xee3d52)  // Bright red
		t.color.warning = skald.rgb(0x7d5300) // Dark golden brown
	} else {
		t.color.danger = skald.rgb(0xff7043)  // Bright vermillion
		t.color.warning = skald.rgb(0xfff176) // Light yellow
	}
	return t
}

// Whether a theme has a light background (the OS's choice can be either).
@(private = "file")
is_light :: proc(colors: skald.Theme_Colors) -> bool {
	bg := colors.bg
	return bg.r + bg.g + bg.b > 1.5
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

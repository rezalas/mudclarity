/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "base:runtime"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

import "gui:skald"

import "../settings"
import "../testkit"

// A store for a settings file in `dir` that doesn't exist yet. Free it
// with settings_store_close.
@(private = "file")
temp_store :: proc(dir: string) -> ^Settings_Store {
	heap := runtime.heap_allocator()
	store := new(Settings_Store, heap)
	path, _ := filepath.join({dir, settings.APP_DIR_NAME, settings.FILE_NAME}, heap)
	store.path = path
	store.loaded = {settings = settings.DEFAULTS, status = .Missing}
	return store
}

@(test)
test_settings_start_from_the_store :: proc(t: ^testing.T) {
	s := init()
	testing.expect_value(t, s.settings, settings.DEFAULTS)
	testing.expect(t, s.store == nil)
	finish(s)

	store := Settings_Store {
		loaded = {settings = {theme = .Dark, text_size = .Large, filters = settings.DEFAULT_FILTERS}, status = .Read, warning = "settings were odd"},
	}
	s = init_with(&store)
	testing.expect_value(t, s.store, &store)
	testing.expect_value(t, s.settings, store.loaded.settings)
	testing.expect_value(t, s.warning, "settings were odd")
	s, _ = step(s, Dismiss_Warning{})
	testing.expect_value(t, s.warning, "")
	finish(s)
}

@(test)
test_choosing_a_theme_applies_and_saves_it :: proc(t: ^testing.T) {
	store: Settings_Store
	s := init()
	s.store = &store
	effect: Effect

	s, _ = step(s, Settings_Shown{true})
	testing.expect(t, s.settings_open)
	s, effect = step(s, Theme_Chosen{.Light})
	testing.expect_value(t, s.settings.theme, settings.Theme_Choice.Light)
	apply, ok := effect.(Apply_Settings)
	if !testing.expect(t, ok) do return
	testing.expect_value(t, apply.store, &store)
	testing.expect_value(t, apply.settings.theme, settings.Theme_Choice.Light)

	// The same choice again changes nothing, so nothing is written.
	_, effect = step(s, Theme_Chosen{.Light})
	testing.expect(t, effect == nil)
	s, _ = step(s, Settings_Shown{false})
	testing.expect(t, !s.settings_open)
	finish(s)
}

@(test)
test_only_a_followed_system_theme_changes_with_the_os :: proc(t: ^testing.T) {
	s := init()
	_, effect := step(s, Theme_Changed{})
	_, follows := effect.(Follow_System_Theme)
	testing.expect(t, follows)
	s.settings.theme = .Dark
	_, effect = step(s, Theme_Changed{})
	testing.expect(t, effect == nil, "a chosen theme stays when the OS changes")
	finish(s)
}

@(test)
test_theme_for :: proc(t: ^testing.T) {
	light, dark := settings.DEFAULTS, settings.DEFAULTS
	light.theme, dark.theme = .Light, .Dark
	testing.expect_value(t, theme_for(light).color.bg, skald.theme_light().color.bg)
	testing.expect_value(t, theme_for(dark).color.bg, skald.theme_dark().color.bg)
	testing.expect_value(t, theme_for(settings.DEFAULTS).color.bg, skald.theme_system().color.bg)
}

@(test)
test_save_settings :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_app_settings_save")
	defer os.remove_all(dir)
	store := temp_store(dir)
	defer settings_store_close(store)

	want := settings.DEFAULTS
	want.theme = .Dark
	testing.expect_value(t, save_settings(store, want), "")
	testing.expect_value(t, settings.load(store.path, context.temp_allocator).settings, want)

	// A newer file is left alone, quietly: the load warning covers it.
	store.loaded.status = .Newer
	testing.expect_value(t, save_settings(store, settings.DEFAULTS), "")
	testing.expect_value(t, settings.load(store.path, context.temp_allocator).settings, want)

	// No store, or no settings folder: nothing to do.
	testing.expect_value(t, save_settings(nil, want), "")
	empty: Settings_Store
	testing.expect_value(t, save_settings(&empty, want), "")
}

@(test)
test_a_failed_settings_save_is_shown :: proc(t: ^testing.T) {
	s := init()
	s, _ = step(s, Settings_Saved{error = strings.clone("disk full", runtime.heap_allocator())})
	testing.expect_value(t, s.error, "disk full")
	s, _ = step(s, Settings_Saved{})
	testing.expect_value(t, s.error, "disk full")
	finish(s)
}

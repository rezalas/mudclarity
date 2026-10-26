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

// The Skald theme the settings ask for.
theme_for :: proc(s: settings.Settings) -> skald.Theme {
	switch s.theme {
	case .Light:
		return skald.theme_light()
	case .Dark:
		return skald.theme_dark()
	case .System:
	}
	return skald.theme_system()
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

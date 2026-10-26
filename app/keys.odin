/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:strings"

import "gui:skald"

import "../components"

/*
 Every keyboard shortcut, in one table that the Help dialog shows. Chords
 the app registers itself (SETTINGS_SHORTCUT, the text size keys, ...)
 are the same values as here, so the list can't drift from what the keys
 do; key_bindings_test checks each registered chord is listed. Keys a
 component handles itself (a map's arrow keys) come from that component's
 own table.
*/

// Where a binding works.
Key_Scope :: enum u8 {
	Anywhere,
	Dialogs_And_Lists, // Skald's own widget keys
	Settings,
	Room_Graph,
	Area_Map,
	Search,
}

KEY_SCOPE_TITLES := [Key_Scope]string {
	.Anywhere          = "Anywhere",
	.Dialogs_And_Lists = "Buttons, boxes and lists",
	.Settings          = "In Settings",
	.Room_Graph        = "On the room graph (Tab to it, or click it)",
	.Area_Map          = "On the area map (Tab to it, or click it)",
	.Search            = "In the room search box",
}

Key_Binding :: struct {
	chords: []skald.Shortcut, // Shown as "A or B"; empty when `keys` says it
	keys:   string,           // Shown instead of (or after) the chords, e.g. "?"
	action: string,
	scope:  Key_Scope,
}

// Ctrl on Windows and Linux, Cmd on macOS, as each platform's apps use.
COMMAND_KEY :: skald.Modifier.Super when ODIN_OS == .Darwin else skald.Modifier.Ctrl

HELP_SHORTCUTS := [?]skald.Shortcut{{key = .F1}, {key = .Slash, mods = {COMMAND_KEY}}}
SETTINGS_SHORTCUT :: skald.Shortcut{key = .Comma, mods = {COMMAND_KEY}}
LARGER_TEXT_SHORTCUTS := [?]skald.Shortcut{{key = .Equals, mods = {COMMAND_KEY}}, {key = .Equals, mods = {COMMAND_KEY, .Shift}}}
SMALLER_TEXT_SHORTCUT :: skald.Shortcut{key = .Minus, mods = {COMMAND_KEY}}
RESET_TEXT_SHORTCUT :: skald.Shortcut{key = .N0, mods = {COMMAND_KEY}}
// Jump to room search: Ctrl+F (Cmd+F) anywhere, `/` when not typing.
SEARCH_SHORTCUTS := [?]skald.Shortcut{{key = .F, mods = {COMMAND_KEY}}, {key = .Slash}}

// "?" also opens Help, when no text box has focus (so it can still be
// typed in one). Skald only reports typed text while a text box has
// focus, so it is matched as Shift+/ (where "?" is on US and many other
// layouts) and, when typed text does arrive, as the character itself.
HELP_CHARACTER :: "?"
HELP_CHARACTER_SHORTCUT :: skald.Shortcut{key = .Slash, mods = {.Shift}}

// Every binding, in the order Help lists them. Allocated with the temp
// allocator.
key_bindings :: proc() -> []Key_Binding {
	out := make([dynamic]Key_Binding, context.temp_allocator)
	append(
		&out,
		Key_Binding{chords = HELP_SHORTCUTS[:], keys = HELP_CHARACTER, action = "Show this help and the keyboard shortcuts", scope = .Anywhere},
		Key_Binding{chords = one(SETTINGS_SHORTCUT), action = "Open Settings", scope = .Anywhere},
		Key_Binding{chords = LARGER_TEXT_SHORTCUTS[:1], action = "Larger text (10% at a time)", scope = .Anywhere},
		Key_Binding{chords = one(SMALLER_TEXT_SHORTCUT), action = "Smaller text", scope = .Anywhere},
		Key_Binding{chords = one(RESET_TEXT_SHORTCUT), action = "Text size back to 100%", scope = .Anywhere},
		Key_Binding{chords = SEARCH_SHORTCUTS[:], action = "Find a room: jump to the search box", scope = .Anywhere},
		Key_Binding{keys = "Tab, Shift+Tab", action = "Move to the next or previous button, box or list", scope = .Dialogs_And_Lists},
		Key_Binding{keys = "Enter, Space", action = "Press the focused button or tick the focused box", scope = .Dialogs_And_Lists},
		Key_Binding{keys = "Up, Down, Enter", action = "Choose in an open dropdown, such as the area picker", scope = .Dialogs_And_Lists},
		Key_Binding{keys = "Esc", action = "Close a dialog or popover, or clear the search box", scope = .Dialogs_And_Lists},
		Key_Binding{keys = "Left, Right", action = "Move the text size slider in 5% steps", scope = .Settings},
		Key_Binding{keys = "Up, Down", action = "Move through the results", scope = .Search},
		Key_Binding{keys = "Enter", action = "Go to the highlighted room", scope = .Search},
		Key_Binding{keys = "Esc", action = "Clear the search", scope = .Search},
	)
	for hint in components.ROOM_GRAPH_KEYS {
		append(&out, Key_Binding{keys = hint.keys, action = hint.action, scope = .Room_Graph})
	}
	for hint in components.AREA_MAP_KEYS {
		append(&out, Key_Binding{keys = hint.keys, action = hint.action, scope = .Area_Map})
	}
	return out[:]
}

// How a binding's keys read: its chords, then its `keys` text, joined
// with "or". Allocated with the temp allocator.
binding_keys_text :: proc(b: Key_Binding) -> string {
	parts := make([dynamic]string, context.temp_allocator)
	for chord in b.chords {
		append(&parts, chord_text(chord))
	}
	if b.keys != "" {
		append(&parts, b.keys)
	}
	return strings.join(parts[:], " or ", context.temp_allocator)
}

// A chord as people write it on this platform: "Ctrl+," or "Cmd+,".
// Allocated with the temp allocator.
chord_text :: proc(chord: skald.Shortcut) -> string {
	parts := make([dynamic]string, context.temp_allocator)
	if .Ctrl in chord.mods do append(&parts, "Ctrl")
	if .Super in chord.mods do append(&parts, "Cmd" when ODIN_OS == .Darwin else "Super")
	if .Alt in chord.mods do append(&parts, "Option" when ODIN_OS == .Darwin else "Alt")
	if .Shift in chord.mods do append(&parts, "Shift")
	append(&parts, key_text(chord.key))
	return strings.join(parts[:], "+", context.temp_allocator)
}

// Punctuation and digits by their glyph; everything else by Skald's name.
@(private = "file")
key_text :: proc(key: skald.Key) -> string {
	#partial switch key {
	case .Minus: return "-"
	case .Equals: return "="
	case .Comma: return ","
	case .Period: return "."
	case .Slash: return "/"
	case .N0: return "0"
	}
	return skald.shortcut_format({key = key})
}

@(private = "file")
one :: proc(chord: skald.Shortcut) -> []skald.Shortcut {
	out := make([]skald.Shortcut, 1, context.temp_allocator)
	out[0] = chord
	return out
}

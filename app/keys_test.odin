/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:testing"

import "gui:skald"

// Whether a chord is listed in the key bindings.
@(private = "file")
listed :: proc(chord: skald.Shortcut) -> bool {
	for b in key_bindings() {
		for c in b.chords {
			if c == chord {
				return true
			}
		}
	}
	return false
}

@(test)
test_registered_shortcuts_are_listed :: proc(t: ^testing.T) {
	// Every chord the app registers itself must be in the Help list.
	for chord in HELP_SHORTCUTS {
		testing.expectf(t, listed(chord), "%s isn't in the key bindings", chord_text(chord))
	}
	testing.expect(t, listed(SETTINGS_SHORTCUT))
	testing.expect(t, listed(LARGER_TEXT_SHORTCUTS[0]))
	testing.expect(t, listed(SMALLER_TEXT_SHORTCUT))
	testing.expect(t, listed(RESET_TEXT_SHORTCUT))
	for chord in SEARCH_SHORTCUTS {
		testing.expectf(t, listed(chord), "%s isn't in the key bindings", chord_text(chord))
	}
}

@(test)
test_every_binding_says_what_it_does :: proc(t: ^testing.T) {
	seen: [Key_Scope]bool
	for b in key_bindings() {
		testing.expect(t, b.action != "")
		testing.expect(t, binding_keys_text(b) != "")
		seen[b.scope] = true
	}
	for scope in Key_Scope {
		testing.expectf(t, seen[scope], "nothing is listed for %v", scope)
		testing.expect(t, KEY_SCOPE_TITLES[scope] != "")
	}
}

@(test)
test_chord_text :: proc(t: ^testing.T) {
	COMMAND :: "Cmd" when ODIN_OS == .Darwin else "Ctrl"
	testing.expect_value(t, chord_text(SETTINGS_SHORTCUT), COMMAND + "+,")
	testing.expect_value(t, chord_text(RESET_TEXT_SHORTCUT), COMMAND + "+0")
	testing.expect_value(t, chord_text(LARGER_TEXT_SHORTCUTS[1]), COMMAND + "+Shift+=")
	testing.expect_value(t, chord_text({key = .F1}), "F1")
	testing.expect_value(t, chord_text(HELP_CHARACTER_SHORTCUT), "Shift+/")
	help := Key_Binding{chords = HELP_SHORTCUTS[:], keys = HELP_CHARACTER}
	testing.expect_value(t, binding_keys_text(help), "F1 or " + COMMAND + "+/ or ?")
}

@(test)
test_help_and_settings_take_turns :: proc(t: ^testing.T) {
	s := init()
	s, _ = step(s, Help_Shown{true})
	testing.expect(t, s.help_open)
	s, _ = step(s, Settings_Shown{true})
	testing.expect(t, s.settings_open && !s.help_open, "one dialog at a time")
	s, _ = step(s, Help_Shown{true})
	testing.expect(t, s.help_open && !s.settings_open)
	s, _ = step(s, Help_Shown{false})
	testing.expect(t, !s.help_open)
	finish(s)
}

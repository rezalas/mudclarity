/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:os"
import "core:testing"

import "../clarity"
import "../components"
import "../settings"
import "../testkit"
import "../validation"
import "../workspace"

@(test)
test_filters_show :: proc(t: ^testing.T) {
	f := clarity.Reviewed_Finding {
		diagnostic = {severity = .Warning},
		state      = .Open,
	}
	testing.expect(t, shows(DEFAULT_FILTERS, f))
	f.state = .Accepted
	testing.expect(t, !shows(DEFAULT_FILTERS, f), "accepted findings are hidden by default")
	for state in ([]clarity.State{.Open, .Flagged, .Needs_Review}) {
		f.state = state
		testing.expect(t, shows(DEFAULT_FILTERS, f))
	}
	f.state = .Open
	testing.expect(t, !shows(Filters{severities = {.Error}, states = {.Open}}, f))
	testing.expect(t, !shows(Filters{}, f))
}

@(private = "file")
NONE :: components.Room_Mark{}

@(private = "file")
mark :: proc(severity: validation.Severity) -> components.Room_Mark {
	return {has_finding = true, worst = severity}
}

@(test)
test_filters_mark_rooms_and_areas :: proc(t: ^testing.T) {
	dir, list := world_on_disk(t, "mudclarity_app_filters_marks")
	defer os.remove_all(dir)
	s := init()
	s.generation = 1
	s, _ = step(s, load_now(1, list))
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return
	w := s.world

	// BASE_ROOMS: 100 has the broken exit (error); 102 is an orphan and a
	// dead end (warnings); the area also has no entrance (a warning).
	testing.expect_value(t, w.marks[0][0], mark(.Error))
	testing.expect_value(t, w.marks[0][2], mark(.Warning))
	testing.expect_value(t, w.area_map.marks[0], mark(.Error))
	testing.expect_value(t, area_inspector_data(s).shown, [validation.Severity]int{.Error = 1, .Warning = 3, .Info = 0})

	s, _ = step(s, Severity_Shown{.Error, false})
	testing.expect_value(t, w.marks[0][0], NONE)
	testing.expect_value(t, w.marks[0][2], mark(.Warning))
	testing.expect_value(t, w.area_map.marks[0], mark(.Warning))
	testing.expect_value(t, area_inspector_data(s).shown, [validation.Severity]int{.Error = 0, .Warning = 3, .Info = 0})

	s, _ = step(s, State_Shown{.Open, false})
	testing.expect_value(t, w.marks[0][2], NONE)
	testing.expect_value(t, w.area_map.marks[0], NONE)

	s, _ = step(s, Filters_Reset{})
	testing.expect_value(t, s.settings.filters, DEFAULT_FILTERS)
	testing.expect_value(t, w.marks[0][0], mark(.Error))
}

@(test)
test_filters_show_accepted_findings_and_survive_a_reload :: proc(t: ^testing.T) {
	dir, list := world_on_disk(t, "mudclarity_app_filters_accepted")
	defer os.remove_all(dir)
	{
		world, _ := world_open(paths(list))
		defer world_close(world)
		key, _ := workspace.current_finding_key(world.ws, testkit.BROKEN_EXIT_ID)
		testing.expect(t, workspace.set_review(world.ws, key, clarity.REVIEW_ACCEPTED, "", "2026-10-26") == nil)
		testing.expect(t, workspace.save(world.ws) == nil)
	}
	s := init()
	s.generation = 1
	s, _ = step(s, load_now(1, list))
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return
	testing.expect_value(t, s.world.marks[0][0], NONE)

	s, _ = step(s, State_Shown{.Accepted, true})
	testing.expect_value(t, s.world.marks[0][0], mark(.Error))

	// A reloaded world is marked with the filters in use, not the defaults.
	s.generation = 2
	s, _ = step(s, load_now(2, list))
	testing.expect_value(t, s.world.marks[0][0], mark(.Error))
}

@(test)
test_filters_popover_and_no_world :: proc(t: ^testing.T) {
	s := init()
	testing.expect_value(t, s.settings.filters, DEFAULT_FILTERS)
	s, _ = step(s, Filters_Shown{true})
	testing.expect(t, s.filters_open)
	// Changing filters with no world open just records them.
	s, _ = step(s, Severity_Shown{.Info, false})
	testing.expect_value(t, s.settings.filters.severities, bit_set[validation.Severity]{.Error, .Warning})
	s, _ = step(s, Filters_Shown{false})
	testing.expect(t, !s.filters_open)
	finish(s)
}

@(test)
test_filters_are_saved_with_the_settings :: proc(t: ^testing.T) {
	store := Settings_Store {
		loaded = {settings = settings.DEFAULTS, status = .Missing},
	}
	s := init_with(&store)
	effect: Effect
	s, effect = step(s, Severity_Shown{.Warning, false})
	apply, ok := effect.(Apply_Settings)
	if !testing.expect(t, ok) do return
	testing.expect_value(t, apply.store, &store)
	testing.expect_value(t, apply.settings.filters.severities, bit_set[validation.Severity]{.Error, .Info})
	testing.expect_value(t, apply.settings.theme, s.settings.theme) // Only the filters changed

	// Ticking a box that is already ticked changes nothing, so nothing is saved.
	_, effect = step(s, Severity_Shown{.Error, true})
	testing.expect(t, effect == nil)
	s, effect = step(s, Filters_Reset{})
	_, ok = effect.(Apply_Settings)
	testing.expect(t, ok)
	_, effect = step(s, Filters_Reset{})
	testing.expect(t, effect == nil, "already the defaults")
	finish(s)
}

@(test)
test_saved_filters_mark_a_newly_loaded_world :: proc(t: ^testing.T) {
	dir, list := world_on_disk(t, "mudclarity_app_filters_saved")
	defer os.remove_all(dir)
	// As if the settings file said to hide errors.
	store := Settings_Store {
		loaded = {settings = {filters = {severities = {.Warning, .Info}, states = DEFAULT_FILTERS.states}}, status = .Read},
	}
	s := init_with(&store)
	s.generation = 1
	s, _ = step(s, load_now(1, list))
	defer finish(s)
	if !testing.expect(t, s.world != nil) do return
	testing.expect_value(t, s.world.marks[0][0], NONE) // Room 100's only finding is an error
	testing.expect_value(t, s.world.area_map.marks[0], mark(.Warning))
}

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:testing"

import "gui:skald"

import "../components"
import "../settings"

@(test)
test_scaled_theme :: proc(t: ^testing.T) {
	base := skald.theme_dark()
	testing.expect_value(t, scaled_theme(base, 1), base)

	big := scaled_theme(base, 1.5)
	testing.expect_value(t, big.font.size_md, base.font.size_md * 1.5)
	testing.expect_value(t, big.font.size_display, base.font.size_display * 1.5)
	testing.expect_value(t, big.spacing.md, base.spacing.md * 1.5)
	testing.expect_value(t, big.radius.md, base.radius.md * 1.5)
	testing.expect_value(t, big.radius.pill, base.radius.pill) // Still a pill
	testing.expect_value(t, big.color, base.color)
}

@(test)
test_theme_for_applies_the_text_size :: proc(t: ^testing.T) {
	s := settings.DEFAULTS
	s.theme = .Dark
	for size in settings.Text_Size {
		s.text_size = size
		th := theme_for(s)
		want := skald.theme_dark().font.size_md * settings.TEXT_SCALES[size]
		testing.expectf(t, th.font.size_md == want, "%v: size_md %v, want %v", size, th.font.size_md, want)
		testing.expectf(t, abs(components.ui_scale(&th) - settings.TEXT_SCALES[size]) < 0.0001, "%v: ui_scale %v", size, components.ui_scale(&th))
	}
}

@(test)
test_next_text_size :: proc(t: ^testing.T) {
	testing.expect_value(t, next_text_size(.Default, +1), settings.Text_Size.Large)
	testing.expect_value(t, next_text_size(.Default, -1), settings.Text_Size.Small)
	testing.expect_value(t, next_text_size(.Largest, +1), settings.Text_Size.Largest)
	testing.expect_value(t, next_text_size(.Small, -1), settings.Text_Size.Small)
	testing.expect_value(t, next_text_size(.Small, +10), settings.Text_Size.Largest)
}

@(test)
test_choosing_a_text_size :: proc(t: ^testing.T) {
	store := Settings_Store {
		loaded = {settings = settings.DEFAULTS, status = .Missing},
	}
	s := init_with(&store)
	effect: Effect
	s, effect = step(s, Text_Size_Chosen{.Larger})
	apply, ok := effect.(Apply_Settings)
	if !testing.expect(t, ok) do return
	testing.expect_value(t, apply.settings.text_size, settings.Text_Size.Larger)
	_, effect = step(s, Text_Size_Chosen{.Larger})
	testing.expect(t, effect == nil, "the same size changes nothing")

	// Following the OS's light/dark keeps the chosen size.
	_, effect = step(s, Theme_Changed{})
	follow, follows := effect.(Follow_System_Theme)
	if !testing.expect(t, follows) do return
	testing.expect_value(t, follow.settings.text_size, settings.Text_Size.Larger)
	finish(s)
}

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
test_theme_for_applies_the_text_scale :: proc(t: ^testing.T) {
	s := settings.DEFAULTS
	s.theme = .Dark
	base := app_type(skald.theme_dark())
	for percent in ([]int{75, 100, 115, 150, 200}) {
		s.text_scale = percent
		th := theme_for(s)
		factor := f32(percent) / 100
		testing.expectf(t, abs(th.font.size_md - base.font.size_md * factor) < 0.001, "%d%%: size_md %v", percent, th.font.size_md)
		testing.expectf(t, abs(components.ui_scale(&th) - base.font.size_md * factor / components.BASE_FONT_SIZE) < 0.001, "%d%%: ui_scale %v", percent, components.ui_scale(&th))
	}
	// A value that slipped out of range is used in range.
	s.text_scale = 0
	testing.expect_value(t, theme_for(s).font.size_md, base.font.size_md * f32(settings.MIN_TEXT_SCALE) / 100)
}

@(test)
test_next_text_scale :: proc(t: ^testing.T) {
	testing.expect_value(t, next_text_scale(100, +1), 110)
	testing.expect_value(t, next_text_scale(115, -1), 105)
	testing.expect_value(t, next_text_scale(195, +1), settings.MAX_TEXT_SCALE)
	testing.expect_value(t, next_text_scale(80, -1), settings.MIN_TEXT_SCALE)
}

@(test)
test_choosing_a_text_scale :: proc(t: ^testing.T) {
	store := Settings_Store {
		loaded = {settings = settings.DEFAULTS, status = .Missing},
	}
	s := init_with(&store)
	effect: Effect
	s, effect = step(s, Text_Scale_Chosen{150})
	apply, ok := effect.(Apply_Settings)
	if !testing.expect(t, ok) do return
	testing.expect_value(t, apply.settings.text_scale, 150)
	_, effect = step(s, Text_Scale_Chosen{150})
	testing.expect(t, effect == nil, "the same size changes nothing")

	// Following the OS's light/dark keeps the chosen size.
	_, effect = step(s, Theme_Changed{})
	follow, follows := effect.(Follow_System_Theme)
	if !testing.expect(t, follows) do return
	testing.expect_value(t, follow.settings.text_scale, 150)
	finish(s)
}

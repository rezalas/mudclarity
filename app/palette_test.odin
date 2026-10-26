/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:testing"

import "gui:skald"

import "../settings"

@(test)
test_colour_blind_colours_follow_the_background :: proc(t: ^testing.T) {
	dark, light := skald.theme_dark(), skald.theme_light()
	testing.expect_value(t, colour_blind(dark).color.danger, skald.rgb(0xff7043))
	testing.expect_value(t, colour_blind(dark).color.warning, skald.rgb(0xfff176))
	testing.expect_value(t, colour_blind(light).color.danger, skald.rgb(0xee3d52))
	testing.expect_value(t, colour_blind(light).color.warning, skald.rgb(0x7d5300))
	// Only the severity colours change.
	changed := colour_blind(dark)
	changed.color.danger, changed.color.warning = dark.color.danger, dark.color.warning
	testing.expect_value(t, changed, dark)
}

@(test)
test_theme_for_applies_the_palette :: proc(t: ^testing.T) {
	s := settings.DEFAULTS
	s.theme = .Light
	testing.expect_value(t, theme_for(s).color.danger, skald.theme_light().color.danger)
	s.palette = .Colour_Blind
	testing.expect_value(t, theme_for(s).color.danger, skald.rgb(0xee3d52))
	s.theme = .Dark
	testing.expect_value(t, theme_for(s).color.warning, skald.rgb(0xfff176))
}

@(test)
test_choosing_a_palette :: proc(t: ^testing.T) {
	store := Settings_Store {
		loaded = {settings = settings.DEFAULTS, status = .Missing},
	}
	s := init_with(&store)
	effect: Effect
	s, effect = step(s, Palette_Chosen{.Colour_Blind})
	apply, ok := effect.(Apply_Settings)
	if !testing.expect(t, ok) do return
	testing.expect_value(t, apply.settings.palette, settings.Palette_Choice.Colour_Blind)
	_, effect = step(s, Palette_Chosen{.Colour_Blind})
	testing.expect(t, effect == nil, "the same palette changes nothing")
	finish(s)
}

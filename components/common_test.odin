/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:testing"

import "gui:skald"

@(test)
test_ui_scale :: proc(t: ^testing.T) {
	th := skald.theme_dark()
	testing.expect_value(t, ui_scale(&th), f32(1)) // Skald's default size is the base
	th.font.size_md = BASE_FONT_SIZE * 2
	testing.expect_value(t, ui_scale(&th), f32(2))
	th.font.size_md = 0
	testing.expect_value(t, ui_scale(&th), f32(1)) // A theme without sizes isn't scaled
}

@(test)
test_severity_color :: proc(t: ^testing.T) {
	c := skald.theme_light().color
	testing.expect_value(t, severity_color(c, .Error), c.danger)
	testing.expect_value(t, severity_color(c, .Warning), c.warning)
	testing.expect_value(t, severity_color(c, .Info), c.fg_muted)
	// A palette is a change of theme colours, and severity_color follows it.
	c.danger = skald.rgb(0x123456)
	testing.expect_value(t, severity_color(c, .Error), skald.rgb(0x123456))
}

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

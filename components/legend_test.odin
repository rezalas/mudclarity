/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:testing"

import "gui:skald"

@(test)
test_legend_lists_every_swatch_once :: proc(t: ^testing.T) {
	seen: [Legend_Swatch]int
	for sections in ([][]Legend_Section{ROOM_GRAPH_LEGEND[:], AREA_MAP_LEGEND[:]}) {
		for section in sections {
			testing.expect(t, section.title != "")
			for item in section.items {
				seen[item.swatch] += 1
				testing.expectf(t, item.label != "", "%v has no label", item.swatch)
			}
		}
	}
	for swatch in Legend_Swatch {
		testing.expectf(t, seen[swatch] == 1, "%v is listed %d times", swatch, seen[swatch])
	}
}

@(test)
test_legend_colours_are_the_maps :: proc(t: ^testing.T) {
	for c in ([]skald.Theme_Colors{skald.theme_dark().color, skald.theme_light().color}) {
		error, _ := room_outline(c, {true, .Error}, false)
		testing.expect_value(t, legend_swatch_color(c, .Room_Error), error)
		selected, _ := room_outline(c, {}, true)
		testing.expect_value(t, legend_swatch_color(c, .Room_Selected), selected)
		warning, _ := area_outline(c, {true, .Warning})
		testing.expect_value(t, legend_swatch_color(c, .Area_Warning), warning)
		testing.expect_value(t, legend_swatch_color(c, .Exit_Bent), bent_exit_color(c))
		testing.expect_value(t, legend_swatch_color(c, .Link_Portals_Only), link_color(c, false))
		testing.expect_value(t, legend_swatch_color(c, .Area_Unopened), area_fill(c, true))
	}
	// A different palette (as the colour-blind one changes danger) changes
	// the legend with it.
	c := skald.theme_dark().color
	before := legend_swatch_color(c, .Room_Error)
	c.danger = skald.rgb(0xff7043)
	testing.expect(t, legend_swatch_color(c, .Room_Error) != before)
	testing.expect_value(t, legend_swatch_color(c, .Room_Error), skald.rgb(0xff7043))
}

@(test)
test_every_swatch_draws :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)
	for swatch in Legend_Swatch {
		r := headless()
		d := Legend_Swatch_Data{swatch = swatch, colors = skald.theme_dark().color, scale = 1}
		bounds := skald.Rect{10, 10, LEGEND_SWATCH_WIDTH, LEGEND_ROW_HEIGHT}
		paint_legend_swatch(&d, {r = r, bounds = bounds})
		testing.expectf(t, len(r.batch.indices) > 0, "%v draws nothing", swatch)
		lo, hi := drawn_bounds(r)
		// Within its cell (antialiasing adds a fringe).
		testing.expectf(t, lo.x >= bounds.x - 2 && lo.y >= bounds.y - 2 && hi.x <= bounds.x + bounds.w + 2 && hi.y <= bounds.y + bounds.h + 2, "%v spills out: %v..%v", swatch, lo, hi)
		free_headless(r)
	}
}

@(test)
test_small_dots_are_round :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)
	// One rounded square (a signed distance field), not a few triangles.
	r := headless()
	paint_dot(r, {20, 20}, 2, {1, 1, 1, 1})
	testing.expect_value(t, len(r.batch.indices), 6)
	free_headless(r)
}

@(test)
test_legend_toggles :: proc(t: ^testing.T) {
	g := room_graph_init()
	testing.expect(t, !g.is_legend_open)
	g = room_graph_update(g, Legend_Toggled{}, nil)
	testing.expect(t, g.is_legend_open)
	g = room_graph_update(g, Legend_Toggled{}, nil)
	testing.expect(t, !g.is_legend_open)

	m := area_map_init()
	m = area_map_update(m, Legend_Toggled{}, nil, nil)
	testing.expect(t, m.is_legend_open)
}

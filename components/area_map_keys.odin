/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "gui:skald"

/*
 The area map's keys, while its canvas has focus: arrows select the
 nearest area that way (reported as Area_Clicked, as a click would be),
 bringing it into view if needed; Enter opens it (Area_Opened); and the
 keys every map shares (canvas_keys).
*/

AREA_MAP_KEYS := [?]Key_Hint {
	{"Left, Up, Right, Down", "Select the nearest area in that direction"},
	{"Enter", "Open the selected area's rooms"},
	{"Shift+arrows", "Move the view"},
	{"+, -", "Zoom in or out"},
	{"0", "Fit the map to the view"},
}

@(private)
area_map_keys :: proc(d: ^Area_Map_Data, ctx: ^skald.Ctx(Area_Map_Msg), last: skald.Rect) {
	keys := ctx.input.keys_pressed
	if ctx.input.modifiers == {} && d.current >= 0 && d.current < len(d.positions) {
		arrows := [?]struct {
			key: skald.Key,
			way: [2]f32,
		}{{.Left, {-1, 0}}, {.Right, {1, 0}}, {.Up, {0, -1}}, {.Down, {0, 1}}}
		for a in arrows {
			if a.key not_in keys {
				continue
			}
			if next, ok := area_in_direction(d.positions, d.current, a.way); ok {
				skald.send(ctx, Area_Map_Msg(Area_Clicked{next}))
				// Off screen (or at the edge): bring it to the middle.
				at := to_screen(d.state.camera, {}, d.positions[next])
				margin := 40 * ui_scale(ctx.theme)
				if at.x < margin || at.y < margin || at.x > last.w - margin || at.y > last.h - margin {
					skald.send(ctx, Area_Map_Msg(Panned{[2]f32{last.w, last.h} / 2 - at}))
				}
			}
		}
		if .Enter in keys {
			skald.send(ctx, Area_Map_Msg(Area_Opened{d.current}))
		}
	}
	canvas_keys(ctx, last)
}

// The nearest area from `from` going `way` (a unit vector, y down): within
// 45° of it if any area is, else anywhere on that side.
area_in_direction :: proc(positions: [][2]f32, from: int, way: [2]f32) -> (area: int, ok: bool) {
	origin := positions[from]
	best_cone, best_side := max(f32), max(f32)
	cone, side := -1, -1
	for p, i in positions {
		if i == from {
			continue
		}
		off := p - origin
		along := off.x * way.x + off.y * way.y
		if along <= 0 {
			continue
		}
		across := abs(off.x * way.y - off.y * way.x)
		dist := off.x * off.x + off.y * off.y
		if across <= along && dist < best_cone {
			best_cone, cone = dist, i
		}
		if dist < best_side {
			best_side, side = dist, i
		}
	}
	if cone >= 0 {
		return cone, true
	}
	return side, side >= 0
}

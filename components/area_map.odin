/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:math"

import "gui:skald"

/*
 The map of areas: one circle per area (sized by its rooms, outlined by its
 worst open finding), with a line wherever exits or portals lead from one
 area to another. Clicking an area reports Area_Clicked (the host selects
 it) and double-clicking reports Area_Opened (the host shows its rooms).
 Same composed-component pattern and gestures as the room graph; painting
 is in area_map_paint.odin. Positions come from layout.force_layout.
*/

// Links between two areas `a` < `b`, counted in each direction.
Area_Link :: struct {
	a, b:       int,
	exits_ab:   int,
	exits_ba:   int,
	portals_ab: int,
	portals_ba: int,
}

Area_Map_Data :: struct {
	state:       Area_Map_State,
	names:       []string,  // Display names, by area
	rooms:       []int,     // Room counts, by area
	is_unopened: []bool,    // Area type "unopened", by area
	marks:       []Room_Mark, // Worst open finding, by area
	positions:   [][2]f32,  // Graph-space centres, by area
	links:       []Area_Link,
	current:     int,       // The area the room graph shows
	colors:      skald.Theme_Colors, // Set by area_map_view for painting
}

Area_Map_State :: struct {
	camera:     Camera,
	is_panning: bool,
	needs_fit:  bool,
}

Area_Map_Msg :: union {
	Pan_Started,
	Panned,
	Pan_Ended,
	Zoomed,
	Fitted,
	Area_Clicked,
	Area_Opened,
}

// An area was clicked: for the host to select.
Area_Clicked :: struct {
	area: int,
}

// An area was double-clicked: for the host to open. Its first click has
// already sent Area_Clicked.
Area_Opened :: struct {
	area: int,
}

area_map_init :: proc() -> Area_Map_State {
	return Area_Map_State{camera = Camera{zoom = 1}, needs_fit = true}
}

// A node's radius in graph units, from the area's room count.
area_node_radius :: proc(rooms: int) -> f32 {
	return 12 + 2.5 * math.sqrt(f32(max(rooms, 0)))
}

// Advance the map's state. `positions` and `rooms` are needed to fit.
area_map_update :: proc(s: Area_Map_State, m: Area_Map_Msg, positions: [][2]f32, rooms: []int) -> Area_Map_State {
	out := s
	switch v in m {
	case Pan_Started:
		out.is_panning = true
	case Panned:
		out.camera.pan += v.delta
	case Pan_Ended:
		out.is_panning = false
	case Zoomed:
		out.camera = zoom_at(out.camera, v.factor, v.at)
	case Fitted:
		lo, hi := map_bounds(positions, rooms)
		out.camera = fit_bounds(lo, hi, v.size)
		out.needs_fit = false
	case Area_Clicked, Area_Opened:
	}
	return out
}

// The graph-space rectangle around every node and its label.
map_bounds :: proc(positions: [][2]f32, rooms: []int) -> (lo, hi: [2]f32) {
	if len(positions) == 0 {
		return {}, {}
	}
	lo, hi = positions[0], positions[0]
	for p, i in positions {
		r := area_node_radius(rooms[i])
		lo = {min(lo.x, p.x - r), min(lo.y, p.y - r)}
		hi = {max(hi.x, p.x + r), max(hi.y, p.y + r + 24)} // Room for the label
	}
	return
}

// The area whose circle is under a canvas-local point, if any.
area_at_point :: proc(d: ^Area_Map_Data, local: [2]f32) -> (area: int, ok: bool) {
	g := to_graph(d.state.camera, {}, local)
	for p, i in d.positions {
		r := area_node_radius(d.rooms[i])
		off := g - p
		if off.x * off.x + off.y * off.y <= r * r {
			return i, true
		}
	}
	return 0, false
}

AREA_MAP_ID :: "area-map-canvas"

area_map_view :: proc(d: Area_Map_Data, ctx: ^skald.Ctx(Area_Map_Msg)) -> skald.View {
	th := ctx.theme
	id := skald.hash_id(AREA_MAP_ID)
	last := skald.widget_get(ctx, id, .Canvas).last_rect
	data := new(Area_Map_Data, context.temp_allocator) // Read by paint after view returns
	data^ = d
	data.colors = th.color
	if last.w > 0 {
		if d.state.needs_fit {
			skald.send(ctx, Area_Map_Msg(Fitted{{last.w, last.h}}))
		}
		press := Area_Map_Msg(Pan_Started{})
		if area, ok := area_at_point(data, canvas_local(ctx, last)); ok {
			press = Area_Clicked{area}
			if ctx.input.mouse_click_count[.Left] >= 2 {
				press = Area_Opened{area}
			}
		}
		canvas_gestures(ctx, id, last, d.state.is_panning, press)
	}
	cursor := skald.Cursor_Shape.Move if d.state.is_panning else .Default
	return skald.col(
		skald.row(
			skald.button(ctx, "Fit", Area_Map_Msg(Fitted{{last.w, last.h}}), bg = th.color.surface, fg = th.color.fg),
			caption(ctx, "Each circle is an area; lines are exits and portals between areas. Click an area to see it, double-click to open its rooms."),
			spacing = th.spacing.sm,
			cross_align = .Center,
		),
		skald.flex(1, skald.canvas(ctx, data, paint_area_map, id = id, cursor = cursor)),
		spacing = th.spacing.sm,
		cross_align = .Stretch,
	)
}

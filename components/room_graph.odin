/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:fmt"

import "gui:skald"

import "../layout"
import "../models"
import "../validation"

/*
 The room graph: one area's layout drawn on a canvas, one level at a time,
 with pan (drag empty space), zoom (scroll) and room selection (click).

 It follows Skald's composed-component pattern: Room_Graph_State and
 Room_Graph_Msg are its own; the host embeds room_graph_view with map_msg
 and passes messages back to room_graph_update. Clicking a room only
 reports Room_Clicked: the host decides what selecting it means.
 Painting is in room_graph_paint.odin.
*/

// What the graph shows, besides its own state. Read-only; owned by the
// host. `marks[i]` and `layout.rooms[i]` describe `area.rooms[i]`.
Room_Graph_Data :: struct {
	state:    Room_Graph_State,
	area:     ^models.Area,
	layout:   ^layout.Layout,
	marks:    []Room_Mark,
	selected: int, // Room index, or -1
	colors:   skald.Theme_Colors, // Set by room_graph_view for painting
}

// A room's worst finding that isn't accepted, for colouring it.
Room_Mark :: struct {
	has_finding: bool,
	worst:       validation.Severity,
}

Room_Graph_State :: struct {
	camera:     Camera,
	level:      int,
	is_panning: bool,
	needs_fit:  bool,   // Fit the level to the canvas once its size is known
	viewport:   [2]f32, // Canvas size at the last fit; zero until then
	focus:      int,    // Room to centre on after the pending fit, or -1
}

// Zoom used when centring on a room, so its labels can be read.
FOCUS_ZOOM :: f32(1)

Room_Graph_Msg :: union {
	Pan_Started,
	Panned,
	Pan_Ended,
	Zoomed,
	Fitted,
	Level_Changed,
	Room_Clicked,
	Focus_Room,
}

Pan_Started :: struct {}
Panned :: struct {
	delta: [2]f32,
}
Pan_Ended :: struct {}
Zoomed :: struct {
	factor: f32,
	at:     [2]f32, // Canvas-local
}
// Fit the level to a canvas of this size.
Fitted :: struct {
	size: [2]f32,
}
Level_Changed :: struct {
	level: int,
}
// A room was clicked: for the host to act on.
Room_Clicked :: struct {
	room: int,
}
// Centre on a room (switching to its level), e.g. after following an exit.
// The host sends this; the graph never does.
Focus_Room :: struct {
	room: int,
}

// The state for showing an area afresh: level 0 (where placement starts),
// fitted once the canvas has a size.
room_graph_init :: proc() -> Room_Graph_State {
	return Room_Graph_State{camera = Camera{zoom = 1}, needs_fit = true, focus = -1}
}

// Advance the graph's state. Room_Clicked leaves it unchanged; it is the
// host's to handle.
room_graph_update :: proc(s: Room_Graph_State, m: Room_Graph_Msg, l: ^layout.Layout) -> Room_Graph_State {
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
		lo, hi := level_bounds(l, out.level)
		out.camera = fit(lo, hi, v.size)
		out.needs_fit = false
		out.viewport = v.size
		if out.focus >= 0 {
			out = centre_on(out, l, out.focus)
		}
	case Level_Changed:
		out.level = clamp(v.level, l.min.z, l.max.z)
		out.needs_fit = true
	case Room_Clicked:
	case Focus_Room:
		if v.room < 0 || v.room >= len(l.rooms) {
			return out
		}
		if out.needs_fit || out.viewport == {} {
			out.focus = v.room // Centre once the canvas has been fitted
			out.level = l.rooms[v.room].cell.z
			return out
		}
		out = centre_on(out, l, v.room)
	}
	return out
}

// Show `room`'s level with the room in the middle of the viewport.
@(private = "file")
centre_on :: proc(s: Room_Graph_State, l: ^layout.Layout, room: int) -> Room_Graph_State {
	out := s
	cell := l.rooms[room].cell
	out.level = cell.z
	out.camera.zoom = max(out.camera.zoom, FOCUS_ZOOM)
	out.camera.pan = out.viewport / 2 - cell_center(cell) * out.camera.zoom
	out.focus = -1
	return out
}

// The bounds of the rooms on `level` (the whole layout's if it has none).
level_bounds :: proc(l: ^layout.Layout, level: int) -> (lo, hi: layout.Cell) {
	lo = {max(int), max(int), level}
	hi = {min(int), min(int), level}
	found := false
	for r in l.rooms {
		if r.cell.z != level {
			continue
		}
		found = true
		lo.x, lo.y = min(lo.x, r.cell.x), min(lo.y, r.cell.y)
		hi.x, hi.y = max(hi.x, r.cell.x), max(hi.y, r.cell.y)
	}
	if !found {
		return l.min, l.max
	}
	return
}

// The room under a canvas-local point, if any.
room_at_point :: proc(d: ^Room_Graph_Data, local: [2]f32) -> (room: int, ok: bool) {
	cell := cell_at(to_graph(d.state.camera, {}, local), d.state.level) or_return
	return layout.room_at(d.layout, cell)
}

ROOM_GRAPH_ID :: "room-graph-canvas"

// The graph, with level and fit controls above it. Turns mouse input over
// the canvas into messages.
room_graph_view :: proc(d: Room_Graph_Data, ctx: ^skald.Ctx(Room_Graph_Msg)) -> skald.View {
	th := ctx.theme
	id := skald.hash_id(ROOM_GRAPH_ID)
	last := skald.widget_get(ctx, id, .Canvas).last_rect
	data := new(Room_Graph_Data, context.temp_allocator) // Read by paint after view returns
	data^ = d
	data.colors = th.color
	handle_input(data, ctx, id, last)

	controls := make([dynamic]skald.View, context.temp_allocator)
	if d.layout.max.z > d.layout.min.z {
		s := d.state
		append(
			&controls,
			skald.button(ctx, "Down", Room_Graph_Msg(Level_Changed{s.level - 1}), disabled = s.level <= d.layout.min.z, bg = th.color.surface, fg = th.color.fg),
			skald.text(fmt.tprintf("Level %d", s.level), th.color.fg, th.font.size_md),
			skald.button(ctx, "Up", Room_Graph_Msg(Level_Changed{s.level + 1}), disabled = s.level >= d.layout.max.z, bg = th.color.surface, fg = th.color.fg),
		)
	}
	append(&controls, skald.button(ctx, "Fit", Room_Graph_Msg(Fitted{{last.w, last.h}}), bg = th.color.surface, fg = th.color.fg))
	append(&controls, caption(ctx, "Drag to pan, scroll to zoom, click a room to select it."))

	cursor := skald.Cursor_Shape.Move if d.state.is_panning else .Default
	return skald.col(
		skald.row(..controls[:], spacing = th.spacing.sm, cross_align = .Center),
		skald.flex(1, skald.canvas(ctx, data, paint_room_graph, id = id, cursor = cursor)),
		spacing = th.spacing.sm,
		cross_align = .Stretch,
	)
}

@(private = "file")
handle_input :: proc(d: ^Room_Graph_Data, ctx: ^skald.Ctx(Room_Graph_Msg), id: skald.Widget_ID, last: skald.Rect) {
	if last.w <= 0 {
		return // Not laid out yet (first frame)
	}
	if d.state.needs_fit {
		skald.send(ctx, Room_Graph_Msg(Fitted{{last.w, last.h}}))
	}
	press := Room_Graph_Msg(Pan_Started{})
	if room, ok := room_at_point(d, canvas_local(ctx, last)); ok {
		press = Room_Clicked{room}
	}
	canvas_gestures(ctx, id, last, d.state.is_panning, press)
}

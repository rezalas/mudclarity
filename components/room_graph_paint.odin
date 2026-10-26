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

/*
 Painting the room graph. Only the current level is drawn, and anything
 outside the canvas is skipped, so large areas stay cheap: the per-frame
 work is one pass over the area's rooms and edges with no allocation beyond
 label text.

 - Rooms: a box, outlined by their worst open finding (red error, amber
   warning, muted info), thicker in the accent colour when selected. A
   displaced room (its geometry conflicted) has a small dot in the corner.
 - Exits: straight corridors between neighbours; curves where the rooms
   aren't where the exit says (bent); an arrowhead on one-way exits; a
   triangle on the room for up/down exits and exits to another level; a
   short stub ending in a ring for exits that leave the area.
*/

// Zoom levels below which labels are left out, to keep small text from
// turning into noise.
VNUM_LABEL_ZOOM :: f32(0.45)
NAME_LABEL_ZOOM :: f32(1.15)

paint_room_graph :: proc(d: ^Room_Graph_Data, p: skald.Canvas_Painter) {
	c := d.colors
	skald.draw_rect(p.r, p.bounds, c.bg, 0)
	origin := [2]f32{p.bounds.x, p.bounds.y}
	for e in d.layout.edges {
		paint_edge(d, p, origin, e)
	}
	for ext in d.layout.externals {
		paint_external(d, p, origin, ext)
	}
	for placed, i in d.layout.rooms {
		if placed.cell.z == d.state.level {
			paint_room(d, p, origin, i)
		}
	}
	if d.is_focused {
		paint_focus_ring(p, c.primary)
	}
}

// The keyboard focus ring: an outline just inside the canvas, so it is
// clear when the keys act on the map.
paint_focus_ring :: proc(p: skald.Canvas_Painter, color: skald.Color) {
	b := p.bounds
	skald.draw_rect_outline(p.r, {b.x + 1, b.y + 1, b.w - 2, b.h - 2}, 2, color, 4, true)
}

@(private = "file")
paint_room :: proc(d: ^Room_Graph_Data, p: skald.Canvas_Painter, origin: [2]f32, room: int) {
	c := d.colors
	zoom := d.state.camera.zoom
	centre := to_screen(d.state.camera, origin, cell_center(d.layout.rooms[room].cell))
	half := ROOM_SIZE * zoom / 2
	box := skald.Rect{centre.x - half, centre.y - half, half * 2, half * 2}
	if !overlaps(box, p.bounds) {
		return
	}
	placed := d.layout.rooms[room]
	paint_room_box(p.r, c, box, zoom, d.marks[room], room == d.selected, placed.is_displaced, placed.leads_up, placed.leads_down)

	if zoom >= VNUM_LABEL_ZOOM {
		size := 11 * min(zoom, 1.5) * d.text_scale
		label := fmt.tprintf("%d", d.area.rooms[room].vnum)
		w, _ := skald.measure_text(p.r, label, size)
		// Large text sizes would spill out of the box: shrink to fit.
		if room_width := box.w - 4 * zoom; w > room_width && w > 0 {
			size *= room_width / w
			w = room_width
		}
		// draw_text takes the baseline, and `size` is the cap height.
		skald.draw_text(p.r, label, centre.x - w / 2, centre.y + size / 2, c.fg, size)
	}
	if zoom >= NAME_LABEL_ZOOM {
		size := 10 * min(zoom, 1.5) * d.text_scale
		name := fit_label(p.r, display_text(d.area.rooms[room].name), size, CELL_SIZE * zoom - 4)
		w, _ := skald.measure_text(p.r, name, size)
		baseline := box.y + box.h + 2 * zoom + skald.text_ascent(p.r, size)
		skald.draw_text(p.r, name, centre.x - w / 2, baseline, c.fg_muted, size)
	}
}

// A room's box: filled, outlined (room_outline), with its severity marker,
// the displaced dot (top right) and triangles for exits to another level
// (up at the top right, down at the bottom right). Shared with the legend.
paint_room_box :: proc(r: ^skald.Renderer, c: skald.Theme_Colors, box: skald.Rect, zoom: f32, mark: Room_Mark, is_selected, is_displaced, leads_up, leads_down: bool) {
	radius := 6 * zoom
	skald.draw_rect(r, box, c.surface, radius)
	outline, width := room_outline(c, mark, is_selected)
	skald.draw_rect_outline(r, box, width, outline, radius, true)
	if mark.has_finding {
		paint_room_marker(r, box, zoom, mark.worst, severity_color(c, mark.worst))
	}
	if is_displaced {
		skald.draw_circle(r, {box.x + box.w - 6 * zoom, box.y + 6 * zoom}, 2.5 * zoom, c.fg_muted, true)
	}
	x := box.x + box.w - 7 * zoom
	if leads_up {
		paint_level_triangle(r, {x, box.y + 5 * zoom}, 5 * zoom, true, c.primary)
	}
	if leads_down {
		paint_level_triangle(r, {x, box.y + box.h - 5 * zoom}, 5 * zoom, false, c.primary)
	}
}

@(private = "file")
paint_edge :: proc(d: ^Room_Graph_Data, p: skald.Canvas_Painter, origin: [2]f32, e: layout.Edge) {
	from, to := d.layout.rooms[e.from].cell, d.layout.rooms[e.to].cell
	level := d.state.level
	if from.z != level || to.z != level {
		return // Shown as level markers on the room that is on this level
	}
	camera := d.state.camera
	a := to_screen(camera, origin, cell_center(from))
	b := to_screen(camera, origin, cell_center(to))
	if !overlaps(span(a, b, CELL_SIZE * camera.zoom), p.bounds) {
		return
	}
	c := d.colors
	half := ROOM_SIZE * camera.zoom / 2
	width := max(1, 2 * camera.zoom)
	out := direction_vector(e.direction)

	if e.kind == .Straight {
		start, end := a + out * half, b - out * half
		skald.draw_line(p.r, start, end, width, straight_exit_color(c), true)
		if !e.is_two_way {
			paint_arrowhead(p.r, end, out, 7 * camera.zoom, straight_exit_color(c))
		}
		return
	}
	// Bent: leave in the exit's direction and arrive from the opposite side
	// of whichever way the target lies, so the curve reads as "not where it
	// should be".
	back := direction_vector(layout.OPPOSITE[e.direction]) if e.is_two_way else -out
	reach := CELL_SIZE * camera.zoom * 0.6
	start, end := a + out * half, b + back * half
	bent := bent_exit_color(c)
	skald.draw_bezier(p.r, start, start + out * reach, end + back * reach, end, width, bent, true)
	if !e.is_two_way {
		paint_arrowhead(p.r, end, -back, 7 * camera.zoom, bent)
	}
}

@(private = "file")
paint_external :: proc(d: ^Room_Graph_Data, p: skald.Canvas_Painter, origin: [2]f32, ext: layout.External_Exit) {
	cell := d.layout.rooms[ext.from].cell
	if cell.z != d.state.level || ext.direction == .Up || ext.direction == .Down {
		return
	}
	camera := d.state.camera
	centre := to_screen(camera, origin, cell_center(cell))
	out := direction_vector(ext.direction)
	start := centre + out * ROOM_SIZE * camera.zoom / 2
	end := start + out * CELL_SIZE * camera.zoom * 0.3
	if !overlaps(span(start, end, 8), p.bounds) {
		return
	}
	paint_exit_stub(p.r, start, end, camera.zoom, d.colors.primary)
}

// Screen direction of an exit. North is up the screen.
@(private = "file")
direction_vector :: proc(direction: models.Direction) -> [2]f32 {
	step := layout.DIRECTION_STEPS[direction]
	return {f32(step.x), f32(step.y)}
}

// The rectangle spanning two points, grown by `pad` on every side.
@(private = "file")
span :: proc(a, b: [2]f32, pad: f32) -> skald.Rect {
	lo := [2]f32{min(a.x, b.x), min(a.y, b.y)} - pad
	hi := [2]f32{max(a.x, b.x), max(a.y, b.y)} + pad
	return {lo.x, lo.y, hi.x - lo.x, hi.y - lo.y}
}

@(private = "file")
overlaps :: proc(a, b: skald.Rect) -> bool {
	return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
}

// `text` cut to fit `max_width` at `size`, ending in "…" if cut.
@(private = "file")
fit_label :: proc(r: ^skald.Renderer, text: string, size, max_width: f32) -> string {
	if w, _ := skald.measure_text(r, text, size); w <= max_width {
		return text
	}
	cut := len(text)
	for cut > 0 {
		cut -= 1
		for cut > 0 && (text[cut] & 0xC0) == 0x80 {
			cut -= 1 // Stay on a UTF-8 boundary
		}
		candidate := fmt.tprintf("%s…", text[:cut])
		if w, _ := skald.measure_text(r, candidate, size); w <= max_width {
			return candidate
		}
	}
	return ""
}

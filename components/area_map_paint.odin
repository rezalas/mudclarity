/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:math"

import "gui:skald"

/*
 Painting the area map: links first, then nodes, then labels.

 - Links: a line between the two circles, thicker the more exits there are;
   an arrowhead when they only go one way; the accent colour when portals
   are the only link.
 - Nodes: filled circles outlined by the area's worst open finding (like
   rooms on the room map); unopened areas are drawn faint; the area the
   room graph shows has an accent ring.
*/

AREA_LABEL_ZOOM :: f32(0.35) // Below this, names are left out

paint_area_map :: proc(d: ^Area_Map_Data, p: skald.Canvas_Painter) {
	c := d.colors
	skald.draw_rect(p.r, p.bounds, c.bg, 0)
	origin := [2]f32{p.bounds.x, p.bounds.y}
	for link in d.links {
		paint_link(d, p, origin, link)
	}
	for _, i in d.positions {
		paint_node(d, p, origin, i)
	}
	if d.is_focused {
		paint_focus_ring(p, c.primary)
	}
}

@(private = "file")
paint_link :: proc(d: ^Area_Map_Data, p: skald.Canvas_Painter, origin: [2]f32, link: Area_Link) {
	camera := d.state.camera
	a := to_screen(camera, origin, d.positions[link.a])
	b := to_screen(camera, origin, d.positions[link.b])
	dir := b - a
	dist := math.sqrt(dir.x * dir.x + dir.y * dir.y)
	if dist < 1 {
		return
	}
	dir /= dist
	ra := area_node_radius(d.rooms[link.a]) * camera.zoom
	rb := area_node_radius(d.rooms[link.b]) * camera.zoom
	start, end := a + dir * ra, b - dir * rb
	exits := link.exits_ab + link.exits_ba
	portals := link.portals_ab + link.portals_ba
	color := link_color(d.colors, exits > 0)
	width := max(1, (1 + math.log2(f32(exits + portals) + 1)) * camera.zoom)
	skald.draw_line(p.r, start, end, width, color, true)

	forward := link.exits_ab + link.portals_ab > 0
	backward := link.exits_ba + link.portals_ba > 0
	if forward && !backward {
		paint_arrowhead(p.r, end, dir, max(6, 10 * camera.zoom), color)
	} else if backward && !forward {
		paint_arrowhead(p.r, start, -dir, max(6, 10 * camera.zoom), color)
	}
}

@(private = "file")
paint_node :: proc(d: ^Area_Map_Data, p: skald.Canvas_Painter, origin: [2]f32, area: int) {
	c := d.colors
	camera := d.state.camera
	centre := to_screen(camera, origin, d.positions[area])
	r := area_node_radius(d.rooms[area]) * camera.zoom
	if centre.x + r < p.bounds.x || centre.x - r > p.bounds.x + p.bounds.w || centre.y + r < p.bounds.y || centre.y - r > p.bounds.y + p.bounds.h + 30 {
		return
	}
	paint_area_circle(p.r, c, centre, r, camera.zoom, d.marks[area], d.is_unopened[area], area == d.current)
	if camera.zoom >= AREA_LABEL_ZOOM {
		size := 11 * min(max(camera.zoom, 0.8), 1.5) * d.text_scale
		name := d.names[area]
		w, _ := skald.measure_text(p.r, name, size)
		label := c.fg_muted if d.is_unopened[area] else c.fg
		skald.draw_text(p.r, name, centre.x - w / 2, centre.y + r + 4 + size, label, size)
	}
}

// An area's circle: filled (faint if unopened), outlined (area_outline),
// with its severity marker, and the accent ring when it is the area the
// room graph shows. Shared with the legend.
paint_area_circle :: proc(r: ^skald.Renderer, c: skald.Theme_Colors, centre: [2]f32, radius, zoom: f32, mark: Room_Mark, is_unopened, is_current: bool) {
	paint_dot(r, centre, radius, area_fill(c, is_unopened))
	outline, width := area_outline(c, mark)
	paint_ring(r, centre, radius, width, outline)
	if is_current {
		paint_ring(r, centre, radius + 4 * zoom, 2.5, c.primary)
	}
	if mark.has_finding {
		paint_area_marker(r, centre, radius, mark.worst, severity_color(c, mark.worst))
	}
}

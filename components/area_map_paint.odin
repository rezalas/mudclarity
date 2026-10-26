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
	color := d.colors.fg_muted if exits > 0 else d.colors.primary
	width := max(1, (1 + math.log2(f32(exits + portals) + 1)) * camera.zoom)
	skald.draw_line(p.r, start, end, width, color, true)

	forward := link.exits_ab + link.portals_ab > 0
	backward := link.exits_ba + link.portals_ba > 0
	if forward && !backward {
		paint_head(p, end, dir, camera.zoom, color)
	} else if backward && !forward {
		paint_head(p, start, -dir, camera.zoom, color)
	}
}

@(private = "file")
paint_head :: proc(p: skald.Canvas_Painter, tip, toward: [2]f32, zoom: f32, color: skald.Color) {
	size := max(6, 10 * zoom)
	side := [2]f32{-toward.y, toward.x}
	back := tip - toward * size
	skald.draw_polygon(p.r, {tip, back + side * size * 0.5, back - side * size * 0.5}, color, true)
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
	fill := c.surface
	if d.is_unopened[area] {
		fill[3] *= 0.45
	}
	skald.draw_circle(p.r, centre, r, fill, true)
	outline, width := c.border, f32(1.5)
	if mark := d.marks[area]; mark.has_finding {
		outline = severity_color(c, mark.worst)
		switch mark.worst {
		case .Error: width = 2.5
		case .Warning: width = 2
		case .Info: width = 1.5
		}
	}
	ring(p, centre, r, width, outline)
	if area == d.current {
		ring(p, centre, r + 4 * camera.zoom, 2.5, c.primary)
	}
	if camera.zoom >= AREA_LABEL_ZOOM {
		size := 11 * min(max(camera.zoom, 0.8), 1.5) * d.text_scale
		name := d.names[area]
		w, _ := skald.measure_text(p.r, name, size)
		label := c.fg_muted if d.is_unopened[area] else c.fg
		skald.draw_text(p.r, name, centre.x - w / 2, centre.y + r + 4 + size, label, size)
	}
}

// A circle outline, as a closed polyline.
@(private = "file")
ring :: proc(p: skald.Canvas_Painter, centre: [2]f32, r, width: f32, color: skald.Color) {
	n := clamp(int(r), 16, 96)
	points := make([][2]f32, n + 1, context.temp_allocator)
	for i in 0 ..= n {
		angle := 2 * math.PI * f32(i) / f32(n)
		points[i] = centre + {math.cos(angle), math.sin(angle)} * r
	}
	skald.draw_polyline(p.r, points, width, color, true)
}

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "gui:skald"

import "../validation"

/*
 Severity markers: a small shape beside a room's or area's outline, so its
 worst finding can be read without colour (in greyscale, or with a
 colour vision deficiency the palette doesn't cover): a cross for an
 error, a triangle (as on a warning sign) for a warning, a dot for info.
 The maps and the legend all draw them through paint_severity_marker.
*/

// The marker for `severity`, `size` across, centred on `at`, in `color`.
paint_severity_marker :: proc(r: ^skald.Renderer, at: [2]f32, size: f32, severity: validation.Severity, color: skald.Color) {
	h := size / 2
	switch severity {
	case .Error:
		w := max(1, size * 0.24)
		skald.draw_line(r, at + {-h, -h}, at + {h, h}, w, color, true)
		skald.draw_line(r, at + {-h, h}, at + {h, -h}, w, color, true)
	case .Warning:
		skald.draw_polygon(r, {at + {0, -h}, at + {h, h * 0.8}, at + {-h, h * 0.8}}, color, true)
	case .Info:
		skald.draw_circle(r, at, size * 0.32, color, true)
	}
}

// A room box's marker: in its top-left corner (the others hold the
// displaced dot and the level triangles).
paint_room_marker :: proc(r: ^skald.Renderer, box: skald.Rect, zoom: f32, severity: validation.Severity, color: skald.Color) {
	paint_severity_marker(r, {box.x + 8 * zoom, box.y + 8 * zoom}, 9 * zoom, severity, color)
}

// An area circle's marker: in the middle of the (filled) circle, sized to
// it, so it touches neither the outline nor the links.
paint_area_marker :: proc(r: ^skald.Renderer, centre: [2]f32, radius: f32, severity: validation.Severity, color: skald.Color) {
	paint_severity_marker(r, centre, radius * 0.9, severity, color)
}

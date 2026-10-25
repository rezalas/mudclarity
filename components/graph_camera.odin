/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "../layout"

/*
 How the room graph maps layout cells to the screen. Graph space is cells
 scaled by CELL_SIZE (a room's centre is at cell * CELL_SIZE); the camera
 then scales by `zoom` and shifts by `pan`, relative to the canvas origin:

     screen = origin + pan + graph * zoom
*/

CELL_SIZE :: f32(72) // Graph units between neighbouring rooms
ROOM_SIZE :: f32(40) // A room's box, in graph units

MIN_ZOOM :: f32(0.1)
MAX_ZOOM :: f32(3)
FIT_MARGIN :: f32(48) // Screen pixels kept free around a fitted area

Camera :: struct {
	pan:  [2]f32,
	zoom: f32,
}

// The graph-space centre of a cell (its level is ignored).
cell_center :: proc(cell: layout.Cell) -> [2]f32 {
	return {f32(cell.x), f32(cell.y)} * CELL_SIZE
}

to_screen :: proc(camera: Camera, origin, graph: [2]f32) -> [2]f32 {
	return origin + camera.pan + graph * camera.zoom
}

to_graph :: proc(camera: Camera, origin, screen: [2]f32) -> [2]f32 {
	return (screen - origin - camera.pan) / camera.zoom
}

// The cell whose box contains the graph-space point, on `level`, if any.
cell_at :: proc(graph: [2]f32, level: int) -> (cell: layout.Cell, ok: bool) {
	x := round_to_int(graph.x / CELL_SIZE)
	y := round_to_int(graph.y / CELL_SIZE)
	offset := graph - [2]f32{f32(x), f32(y)} * CELL_SIZE
	half := ROOM_SIZE / 2
	if abs(offset.x) > half || abs(offset.y) > half {
		return {}, false
	}
	return {x, y, level}, true
}

// Zoom by `factor`, keeping the graph point under `at` (canvas-local) still.
zoom_at :: proc(camera: Camera, factor: f32, at: [2]f32) -> Camera {
	zoom := clamp(camera.zoom * factor, MIN_ZOOM, MAX_ZOOM)
	graph := (at - camera.pan) / camera.zoom
	return Camera{pan = at - graph * zoom, zoom = zoom}
}

// A camera that shows cells `lo`..`hi` centred in a viewport of `size`
// screen pixels, never zoomed in past 1.
fit :: proc(lo, hi: layout.Cell, size: [2]f32) -> Camera {
	graph_lo := cell_center(lo) - ROOM_SIZE / 2
	graph_hi := cell_center(hi) + ROOM_SIZE / 2
	extent := graph_hi - graph_lo
	room := size - 2 * FIT_MARGIN
	zoom := min(f32(1), room.x / extent.x, room.y / extent.y)
	zoom = clamp(zoom, MIN_ZOOM, MAX_ZOOM)
	centre := (graph_lo + graph_hi) / 2
	return Camera{pan = size / 2 - centre * zoom, zoom = zoom}
}

@(private = "file")
round_to_int :: proc(v: f32) -> int {
	return int(v + 0.5) if v >= 0 else -int(-v + 0.5)
}

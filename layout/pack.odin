/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package layout

import "core:math"
import "core:slice"

// Empty cells between packed components.
COMPONENT_GAP :: 2

@(private = "file")
Pack_Order :: struct {
	room_count: int,
	component:  int,
}

// Move the components (each placed around its own origin) apart: largest
// first, left to right in rows about as wide as the whole layout is tall.
// Levels are kept as they are. Then record every room's final cell.
pack_components :: proc(layout: ^Layout) {
	for &component in layout.components {
		component.min = {max(int), max(int), max(int)}
		component.max = {min(int), min(int), min(int)}
	}
	for room in layout.rooms {
		c := &layout.components[room.component]
		c.min = {min(c.min.x, room.cell.x), min(c.min.y, room.cell.y), min(c.min.z, room.cell.z)}
		c.max = {max(c.max.x, room.cell.x), max(c.max.y, room.cell.y), max(c.max.z, room.cell.z)}
	}

	// Pack biggest first; ties keep file order, so the result is stable.
	order := make([]Pack_Order, len(layout.components), context.temp_allocator)
	area := 0
	widest := 0
	for c, i in layout.components {
		order[i] = {c.room_count, i}
		area += (width(c) + COMPONENT_GAP) * (height(c) + COMPONENT_GAP)
		widest = max(widest, width(c))
	}
	slice.stable_sort_by(order, proc(a, b: Pack_Order) -> bool {return a.room_count > b.room_count})
	row_width := max(widest, int(math.ceil(math.sqrt(f64(area)))))

	offsets := make([]Cell, len(layout.components), context.temp_allocator)
	x, y, row_height := 0, 0, 0
	for entry in order {
		i := entry.component
		c := &layout.components[i]
		if x > 0 && x + width(c^) > row_width {
			x, y, row_height = 0, y + row_height + COMPONENT_GAP, 0
		}
		offsets[i] = {x - c.min.x, y - c.min.y, 0}
		c.min += offsets[i]
		c.max += offsets[i]
		x += width(c^) + COMPONENT_GAP
		row_height = max(row_height, height(c^))
	}

	layout.min = {max(int), max(int), max(int)}
	layout.max = {min(int), min(int), min(int)}
	if len(layout.rooms) == 0 {
		layout.min, layout.max = {}, {}
	}
	for &room, i in layout.rooms {
		room.cell += offsets[room.component]
		layout.cells[room.cell] = i
		layout.min = {min(layout.min.x, room.cell.x), min(layout.min.y, room.cell.y), min(layout.min.z, room.cell.z)}
		layout.max = {max(layout.max.x, room.cell.x), max(layout.max.y, room.cell.y), max(layout.max.z, room.cell.z)}
	}
}

@(private = "file")
width :: proc(c: Component) -> int {
	return c.max.x - c.min.x + 1
}

@(private = "file")
height :: proc(c: Component) -> int {
	return c.max.y - c.min.y + 1
}

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package layout

import "base:runtime"

import "../models"

/*
 Places an area's rooms on a grid. Area files have no coordinates, so rooms
 are placed by walking exits: north is up the screen, east is right, and
 up/down change the level. MUD geometry is often inconsistent, so:

 - a room that wants a cell another room already holds starts an island:
   it and the rooms placed from it move together, as a block, to the nearest
   spot on its level where they all fit, and it is marked `is_displaced`;
 - an exit whose rooms didn't end up a step apart in its direction is a
   Bent edge, drawn as a curve rather than a straight corridor;
 - rooms that no exit connects (separate components) are laid out on
   their own and packed side by side.

 No two rooms share a cell, so `room_at` doubles as the spatial index for
 hit-testing. Placement is iterative and deterministic: the same area gives
 the same layout. There is no GUI code here.
*/

// A grid position: x grows east, y grows south, level grows up.
Cell :: [3]int

// Where one room went. `layout.rooms[i]` is `area.rooms[i]`.
Placed_Room :: struct {
	vnum:         int,
	cell:         Cell,
	component:    int,  // Index into `layout.components`
	is_displaced: bool, // Its cell was taken, so it (and its island) moved
	leads_up:     bool, // An exit or edge connects it to a higher level (or up out of the area)
	leads_down:   bool, // ...or to a lower one
}

Edge_Kind :: enum u8 {
	Straight, // The rooms are one step apart in the exit's direction
	Bent,     // They aren't (inconsistent geometry or a displaced room)
	Vertical, // An up/down exit between adjacent levels at the same x, y
}

// An exit between two rooms of the area. A pair of exits that lead back to
// each other in opposite directions is one edge with `is_two_way` set.
Edge :: struct {
	from:       int, // Index into area.rooms
	to:         int,
	direction:  models.Direction, // As written on `from`
	kind:       Edge_Kind,
	is_two_way: bool,
}

// An exit to a room that isn't in this area: another area's room, or a
// missing one (validation says which).
External_Exit :: struct {
	from:      int, // Index into area.rooms
	direction: models.Direction,
	target:    int, // Vnum
}

// A connected group of rooms and its bounds after packing.
Component :: struct {
	first_room: int, // Where placement started (index into area.rooms)
	room_count: int,
	min, max:   Cell,
}

Layout :: struct {
	rooms:      []Placed_Room,
	edges:      []Edge,
	externals:  []External_Exit,
	components: []Component,
	min, max:   Cell, // Bounds of all rooms
	cells:      map[Cell]int, // Room index at each occupied cell
	allocator:  runtime.Allocator,
}

// Lay out `area`'s rooms. Everything in the result is allocated with
// `allocator`; free it with destroy (or use an arena).
compute :: proc(area: ^models.Area, allocator := context.allocator) -> Layout {
	result := Layout {
		allocator = allocator,
	}
	result.rooms = make([]Placed_Room, len(area.rooms), allocator)
	result.cells = make(map[Cell]int, allocator)
	place_rooms(area, &result)
	pack_components(&result)
	build_edges(area, &result)
	return result
}

// Free a layout made by compute.
destroy :: proc(layout: ^Layout) {
	delete(layout.rooms, layout.allocator)
	delete(layout.edges, layout.allocator)
	delete(layout.externals, layout.allocator)
	delete(layout.components, layout.allocator)
	delete(layout.cells)
	layout^ = {}
}

// The room at `cell`, as an index into area.rooms.
room_at :: proc(layout: ^Layout, cell: Cell) -> (room: int, ok: bool) {
	return layout.cells[cell]
}

// The cell one step from `cell` in `direction`.
step :: proc(cell: Cell, direction: models.Direction) -> Cell {
	return cell + DIRECTION_STEPS[direction]
}

DIRECTION_STEPS := [models.Direction]Cell {
	.North = {0, -1, 0},
	.East  = {1, 0, 0},
	.South = {0, 1, 0},
	.West  = {-1, 0, 0},
	.Up    = {0, 0, 1},
	.Down  = {0, 0, -1},
}

OPPOSITE := [models.Direction]models.Direction {
	.North = .South,
	.East  = .West,
	.South = .North,
	.West  = .East,
	.Up    = .Down,
	.Down  = .Up,
}

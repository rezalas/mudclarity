/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "gui:skald"

import "../models"

/*
 The room graph's keys, while its canvas has focus (Tab to it, or click
 it): arrows follow the selected room's exits, Page Up and Page Down its
 up and down exits, Escape deselects, and the keys every map shares
 (canvas_keys). Following an exit is reported as Exit_Key, since the
 exit may lead to another area: the host resolves it.
*/

ROOM_GRAPH_KEYS := [?]Key_Hint {
	{"Left, Up, Right, Down", "Follow the selected room's west, north, east or south exit (with no room selected, select the one nearest the middle)"},
	{"Page Up, Page Down", "Follow the up or down exit, or show the level above or below if there isn't one"},
	{"Shift+arrows", "Move the view"},
	{"+, -", "Zoom in or out"},
	{"0", "Fit the level to the view"},
	{"Esc", "Deselect the room (as does clicking empty space)"},
}

@(private)
room_graph_keys :: proc(d: ^Room_Graph_Data, ctx: ^skald.Ctx(Room_Graph_Msg), last: skald.Rect) {
	keys := ctx.input.keys_pressed
	if ctx.input.modifiers == {} {
		arrows := [?]struct {
			key:       skald.Key,
			direction: models.Direction,
		}{{.Left, .West}, {.Up, .North}, {.Right, .East}, {.Down, .South}, {.Page_Up, .Up}, {.Page_Down, .Down}}
		for a in arrows {
			if a.key not_in keys {
				continue
			}
			switch {
			case d.selected >= 0:
				skald.send(ctx, Room_Graph_Msg(Exit_Key{a.direction}))
			case a.direction == .Up || a.direction == .Down:
				skald.send(ctx, Room_Graph_Msg(Level_Changed{d.state.level + (1 if a.direction == .Up else -1)}))
			case:
				if room, ok := room_nearest_middle(d, last); ok {
					skald.send(ctx, Room_Graph_Msg(Room_Clicked{room}))
				}
			}
		}
		if .Escape in keys && d.selected >= 0 {
			skald.send(ctx, Room_Graph_Msg(Room_Deselected{}))
		}
	}
	canvas_keys(ctx, last)
}

// The room on the shown level nearest the middle of the canvas.
room_nearest_middle :: proc(d: ^Room_Graph_Data, last: skald.Rect) -> (room: int, ok: bool) {
	middle := to_graph(d.state.camera, {}, {last.w, last.h} / 2)
	best := max(f32)
	for placed, i in d.layout.rooms {
		if placed.cell.z != d.state.level {
			continue
		}
		off := cell_center(placed.cell) - middle
		if dist := off.x * off.x + off.y * off.y; dist < best {
			best, room, ok = dist, i, true
		}
	}
	return
}

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "../components"

// What the inspector shows for the selected room, resolved from the world:
// each exit's target (name, area, whether it exists) and the room's
// findings with their review state. Built each frame in the temp
// allocator; the selected room has at most six exits and a few findings.
inspector_data :: proc(s: State) -> components.Room_Inspector_Data {
	world := s.world
	area := world.ws.areas[s.area]
	d := components.Room_Inspector_Data {
		area_label = world.labels[s.area],
	}
	if s.selected_room < 0 || s.selected_room >= len(area.rooms) {
		return d
	}
	room := &area.rooms[s.selected_room]
	d.room = room

	exits := make([dynamic]components.Inspector_Exit, context.temp_allocator)
	for maybe_exit in room.exits {
		exit := maybe_exit.? or_continue
		e := components.Inspector_Exit {
			exit = exit,
		}
		if exit.target != 0 {
			if ref, ok := world.rooms_by_vnum[exit.target]; ok {
				e.target_name = world.ws.areas[ref.area].rooms[ref.room].name
				if ref.area != s.area {
					e.elsewhere = world.labels[ref.area]
				}
			} else {
				e.is_missing = true
			}
		}
		append(&exits, e)
	}
	d.exits = exits[:]

	indexes := world.room_findings[s.area][s.selected_room]
	findings := make([]components.Inspector_Finding, len(indexes), context.temp_allocator)
	for n, i in indexes {
		f := world.findings[n]
		findings[i] = {diagnostic = f.diagnostic, state = f.state}
	}
	d.findings = findings
	return d
}

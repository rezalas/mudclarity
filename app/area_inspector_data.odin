/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "../clarity"
import "../components"

// What the area inspector shows for the area shown: its header, open
// findings (any check, as the map's outline counts them) and the notes the
// review document has on it. Built each frame in the temp allocator.
area_inspector_data :: proc(s: State) -> components.Area_Inspector_Data {
	world := s.world
	ws := world.ws
	if s.area < 0 || s.area >= len(ws.areas) {
		return {}
	}
	area := ws.areas[s.area]
	d := components.Area_Inspector_Data {
		header  = &area.header,
		file    = ws.names[s.area],
		rooms   = len(area.rooms),
		draft   = s.note_draft,
		can_add = ws.clarity_path != "",
	}
	for f in world.findings {
		if f.diagnostic.area == s.area && f.state != .Accepted {
			d.open[f.diagnostic.severity] += 1
		}
	}
	notes := make([dynamic]clarity.Note, context.temp_allocator)
	for note in ws.document.notes {
		if note.file == d.file && note.kind == clarity.KIND_AREA {
			append(&notes, note)
		}
	}
	d.notes = notes[:]
	return d
}

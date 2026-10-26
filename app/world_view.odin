/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:fmt"
import "core:path/filepath"

import "gui:skald"

import "../components"
import "../formats"

// A world is open: its name and area picker, summary counts, files that
// failed to load, and the room inspector beside the chosen area's graph,
// or the area inspector beside the map of areas.
world_view :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	th := ctx.theme
	world := s.world
	ws := world.ws

	children := make([dynamic]skald.View, context.temp_allocator)
	append(&children, header(s, ctx), stats(s, ctx))
	if len(ws.set.failures) > 0 {
		first := ws.set.failures[0]
		message := formats.parse_error_to_string(first.error, first.name, context.temp_allocator)
		if len(ws.set.failures) > 1 {
			message = fmt.tprintf("%s (and %d more files)", message, len(ws.set.failures) - 1)
		}
		append(&children, components.banner(ctx, .Warning, components.display_text(message)))
	}
	if len(ws.areas) == 0 {
		append(&children, components.caption(ctx, "No areas loaded."))
		return skald.col(..children[:], spacing = th.spacing.md, cross_align = .Stretch)
	}
	inspector: skald.View
	if s.center == .Areas {
		events := components.Area_Inspector_Events(Msg) {
			on_draft = note_draft_changed,
			add      = Note_Added{},
			open     = Area_Map{components.Area_Opened{s.area}},
		}
		inspector = components.area_inspector_view(ctx, area_inspector_data(s), events)
	} else {
		inspector = components.room_inspector_view(ctx, inspector_data(s), exit_followed)
	}
	body := skald.row(
		inspector,
		skald.flex(1, center_view(s, ctx)),
		spacing = th.spacing.md,
		cross_align = .Stretch,
	)
	append(&children, skald.flex(1, body))
	return skald.col(..children[:], spacing = th.spacing.md, cross_align = .Stretch)
}

// The room graph or the area map, whichever the switch chose.
@(private = "file")
center_view :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	world := s.world
	if s.center == .Areas {
		m := world.area_map
		m.state = s.area_map
		m.current = s.area
		return skald.map_msg(ctx, m, components.area_map_view, wrap_area_map)
	}
	graph := components.Room_Graph_Data {
		state    = s.graph,
		area     = world.ws.areas[s.area],
		layout   = &world.layouts[s.area],
		marks    = world.marks[s.area],
		selected = s.selected_room,
	}
	return skald.map_msg(ctx, graph, components.room_graph_view, wrap_graph)
}

@(private = "file")
header :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	th := ctx.theme
	ws := s.world.ws
	title := filepath.base(ws.list_path) if ws.list_path != "" else fmt.tprintf("%d area files", len(ws.areas))
	location := filepath.dir(ws.list_path) if ws.list_path != "" else ""
	picker, switch_view := skald.spacer(0), skald.spacer(0)
	if len(ws.areas) > 0 {
		picker = skald.select(ctx, s.world.labels[s.area], s.world.picker_labels, area_picked, width = 360)
		switch_view = skald.segmented(ctx, CENTER_LABELS[:], int(s.center), center_chosen)
	}
	return skald.row(
		components.heading(ctx, title, is_large = true),
		components.caption(ctx, location),
		skald.flex(1, skald.spacer(0)),
		switch_view,
		picker,
		skald.button(ctx, "Close", Msg(Close_World{}), bg = th.color.surface, fg = th.color.fg),
		spacing = th.spacing.md,
		cross_align = .Center,
	)
}

@(private = "file")
stats :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	th := ctx.theme
	sum := s.world.summary
	return skald.row(
		components.stat(ctx, count(len(s.world.ws.areas)), "areas"),
		components.stat(ctx, count(sum.rooms), "rooms"),
		components.stat(ctx, count(sum.severities[.Error]), "errors", th.color.danger),
		components.stat(ctx, count(sum.severities[.Warning]), "warnings", th.color.warning),
		components.stat(ctx, count(sum.severities[.Info]), "info"),
		skald.col(components.caption(ctx, review_line(s)), main_align = .Center),
		spacing = th.spacing.md,
		cross_align = .Stretch,
	)
}

@(private = "file")
review_line :: proc(s: State) -> string {
	if s.world.ws.clarity_path == "" {
		return "Loose area files: open their area.lst to keep a review."
	}
	c := s.world.summary.state_counts
	return fmt.tprintf("Review: %d open, %d flagged, %d accepted, %d need review", c[.Open], c[.Flagged], c[.Accepted], c[.Needs_Review])
}

@(private = "file")
area_picked :: proc(label: string) -> Msg {
	return Area_Picked{label = label}
}

// Segment labels, in Center_View order.
@(private = "file")
CENTER_LABELS := [len(Center_View)]string{"Rooms", "Areas"}

@(private = "file")
center_chosen :: proc(index: int) -> Msg {
	return Center_Chosen{view = Center_View(index)}
}

@(private = "file")
wrap_area_map :: proc(m: components.Area_Map_Msg) -> Msg {
	return Area_Map{msg = m}
}

@(private = "file")
wrap_graph :: proc(m: components.Room_Graph_Msg) -> Msg {
	return Graph{msg = m}
}

@(private = "file")
note_draft_changed :: proc(text: string) -> Msg {
	return Note_Draft_Changed{text = text}
}

@(private = "file")
exit_followed :: proc(target: int) -> Msg {
	return Exit_Followed{target = target}
}

@(private = "file")
count :: proc(n: int) -> string {
	return fmt.tprintf("%d", n)
}

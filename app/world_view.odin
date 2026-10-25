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
// failed to load, and the chosen area: the room inspector beside its graph.
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
	graph := components.Room_Graph_Data {
		state    = s.graph,
		area     = ws.areas[s.area],
		layout   = &world.layouts[s.area],
		marks    = world.marks[s.area],
		selected = s.selected_room,
	}
	body := skald.row(
		components.room_inspector_view(ctx, inspector_data(s), exit_followed),
		skald.flex(1, skald.map_msg(ctx, graph, components.room_graph_view, wrap_graph)),
		spacing = th.spacing.md,
		cross_align = .Stretch,
	)
	append(&children, skald.flex(1, body))
	return skald.col(..children[:], spacing = th.spacing.md, cross_align = .Stretch)
}

@(private = "file")
header :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	th := ctx.theme
	ws := s.world.ws
	title := filepath.base(ws.list_path) if ws.list_path != "" else fmt.tprintf("%d area files", len(ws.areas))
	location := filepath.dir(ws.list_path) if ws.list_path != "" else ""
	picker := skald.spacer(0)
	if len(ws.areas) > 0 {
		picker = skald.select(ctx, s.world.labels[s.area], s.world.labels, area_picked, width = 360)
	}
	return skald.row(
		components.heading(ctx, title, is_large = true),
		components.caption(ctx, location),
		skald.flex(1, skald.spacer(0)),
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

@(private = "file")
wrap_graph :: proc(m: components.Room_Graph_Msg) -> Msg {
	return Graph{msg = m}
}

@(private = "file")
exit_followed :: proc(target: int) -> Msg {
	return Exit_Followed{target = target}
}

@(private = "file")
count :: proc(n: int) -> string {
	return fmt.tprintf("%d", n)
}

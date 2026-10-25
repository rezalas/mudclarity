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

// A world is open: its name, summary counts and any files that failed to
// load. The room graph, inspector and findings log will fill the space
// below.
world_view :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	th := ctx.theme
	ws := s.ws
	sum := s.summary

	title := filepath.base(ws.list_path) if ws.list_path != "" else fmt.tprintf("%d area files", len(ws.areas))
	location := filepath.dir(ws.list_path) if ws.list_path != "" else ""
	header := skald.row(
		components.heading(ctx, title, is_large = true),
		components.caption(ctx, location),
		skald.flex(1, skald.spacer(0)),
		skald.button(ctx, "Close", Msg(Close_World{}), bg = th.color.surface, fg = th.color.fg),
		spacing = th.spacing.md,
		cross_align = .Center,
	)

	stats := skald.row(
		components.stat(ctx, count(len(ws.areas)), "areas"),
		components.stat(ctx, count(sum.rooms), "rooms"),
		components.stat(ctx, count(sum.severities[.Error]), "errors", th.color.danger),
		components.stat(ctx, count(sum.severities[.Warning]), "warnings", th.color.warning),
		components.stat(ctx, count(sum.severities[.Info]), "info"),
		spacing = th.spacing.md,
	)

	children := make([dynamic]skald.View, context.temp_allocator)
	append(&children, header, stats, components.caption(ctx, review_line(s)))
	if len(ws.set.failures) > 0 {
		first := ws.set.failures[0]
		message := formats.parse_error_to_string(first.error, first.name, context.temp_allocator)
		if len(ws.set.failures) > 1 {
			message = fmt.tprintf("%s (and %d more files)", message, len(ws.set.failures) - 1)
		}
		append(&children, components.banner(ctx, .Warning, components.display_text(message)))
	}
	append(&children, skald.flex(1, skald.col(components.caption(ctx, "The room graph, room inspector and findings log come next."), main_align = .Center, cross_align = .Center)))
	return skald.col(..children[:], spacing = th.spacing.lg, cross_align = .Stretch)
}

@(private = "file")
review_line :: proc(s: State) -> string {
	if s.ws.clarity_path == "" {
		return "Loose area files: open their area.lst to keep a review."
	}
	c := s.summary.state_counts
	return fmt.tprintf("Review: %d open, %d flagged, %d accepted, %d need review", c[.Open], c[.Flagged], c[.Accepted], c[.Needs_Review])
}

@(private = "file")
count :: proc(n: int) -> string {
	return fmt.tprintf("%d", n)
}

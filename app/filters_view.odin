/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "gui:skald"

import "../clarity"
import "../validation"

/*
 The toolbar's Filters button and its popover: a box per severity and per
 review state, Reset and Done. Escape or a click elsewhere closes it.
*/

FILTERS_BUTTON_ID :: "filters-button"
FILTERS_CARD_WIDTH :: f32(220)
FILTERS_LINE_HEIGHT :: f32(28)
FILTERS_BUTTONS_HEIGHT :: f32(40)

@(private = "file")
SEVERITY_LABELS := [validation.Severity]string {
	.Error   = "Errors",
	.Warning = "Warnings",
	.Info    = "Info",
}

@(private = "file")
STATE_LABELS := [clarity.State]string {
	.Open         = "Open",
	.Flagged      = "Flagged",
	.Accepted     = "Accepted",
	.Needs_Review = "Needs review",
}

// The button, and the popover when it is open.
filters_control :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	th := ctx.theme
	id := skald.hash_id(FILTERS_BUTTON_ID)
	label := "Filters" if s.settings.filters == DEFAULT_FILTERS else "Filters (changed)"
	button := skald.button(ctx, label, Msg(Filters_Shown{!s.filters_open}), id = id, bg = th.color.surface, fg = th.color.fg)
	if !s.filters_open {
		return button
	}
	anchor := skald.widget_get(ctx, id, .Button).last_rect
	if anchor.w <= 0 {
		return button
	}
	input := ctx.input
	if .Escape in input.keys_pressed || (input.mouse_pressed[.Left] && !skald.mouse_over_overlay(ctx) && !skald.widget_hovered(ctx, id)) {
		skald.send(ctx, Msg(Filters_Shown{false}))
	}

	pad := th.spacing.md
	lines := make([dynamic]skald.View, context.temp_allocator)
	append(&lines, line(skald.text("Severity", th.color.fg, th.font.size_md)))
	for severity in validation.Severity {
		box := skald.checkbox(ctx, severity in s.settings.filters.severities, SEVERITY_LABELS[severity], severity, severity_shown)
		append(&lines, line(box))
	}
	append(&lines, line(skald.text("Review state", th.color.fg, th.font.size_md)))
	for state in clarity.State {
		box := skald.checkbox(ctx, state in s.settings.filters.states, STATE_LABELS[state], state, state_shown)
		append(&lines, line(box))
	}
	buttons := skald.row(
		skald.button(ctx, "Reset", Msg(Filters_Reset{}), bg = th.color.bg, fg = th.color.fg, disabled = s.settings.filters == DEFAULT_FILTERS),
		skald.button(ctx, "Done", Msg(Filters_Shown{false}), bg = th.color.primary, fg = th.color.on_primary),
		spacing = th.spacing.sm,
	)
	append(&lines, skald.col(buttons, height = FILTERS_BUTTONS_HEIGHT, main_align = .End))
	height := 2 * pad + f32(len(lines) - 1) * FILTERS_LINE_HEIGHT + FILTERS_BUTTONS_HEIGHT
	card := skald.col(..lines[:], padding = pad, width = FILTERS_CARD_WIDTH, height = height, bg = th.color.surface, radius = th.radius.md)
	offset := [2]f32{0, 4}
	skald.widget_stamp_overlay_rect(ctx.widgets, skald.overlay_placement_rect(ctx, anchor, {FILTERS_CARD_WIDTH, height}, offset = offset))
	return skald.row(button, skald.overlay(anchor, card, offset = offset))
}

@(private = "file")
line :: proc(child: skald.View) -> skald.View {
	return skald.col(child, height = FILTERS_LINE_HEIGHT, main_align = .Center)
}

@(private = "file")
severity_shown :: proc(severity: validation.Severity, is_shown: bool) -> Msg {
	return Severity_Shown{severity, is_shown}
}

@(private = "file")
state_shown :: proc(state: clarity.State, is_shown: bool) -> Msg {
	return State_Shown{state, is_shown}
}

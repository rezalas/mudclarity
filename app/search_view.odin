/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:fmt"

import "gui:skald"

import "../components"

/*
 The room search box in the toolbar, and its results in a popover under
 it while there is a query. Choosing a result (click, or Tab and Enter)
 goes to the room; Escape or the clear button empties the box.
*/

SEARCH_INPUT_ID :: "room-search"
// Sizes at the default text size; scaled by components.ui_scale.
SEARCH_BOX_WIDTH :: f32(280)
SEARCH_CARD_WIDTH :: f32(420)
SEARCH_ROW_HEIGHT :: f32(42)
SEARCH_FOOTER_HEIGHT :: f32(28)

search_box :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	k := components.ui_scale(ctx.theme)
	return skald.text_input(
		ctx,
		s.search,
		search_changed,
		id = skald.hash_id(SEARCH_INPUT_ID),
		placeholder = "Find a room by vnum or name",
		width = SEARCH_BOX_WIDTH * k,
		clear_button = true,
		escape_clears = true,
		max_chars = 80,
	)
}

// The results popover, or an empty view when there is no query. It
// publishes its rect so the canvases beneath ignore clicks on it.
search_results :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	th := ctx.theme
	anchor := skald.widget_get(ctx, skald.hash_id(SEARCH_INPUT_ID), .Text_Input).last_rect
	if s.search == "" || s.world == nil || anchor.w <= 0 {
		return skald.spacer(0)
	}
	k := components.ui_scale(th)
	pad := th.spacing.sm
	card_width, row_height, footer_height := SEARCH_CARD_WIDTH * k, SEARCH_ROW_HEIGHT * k, SEARCH_FOOTER_HEIGHT * k
	inner := card_width - 2 * pad
	rows := make([dynamic]skald.View, context.temp_allocator)
	for ref in s.search_hits {
		room := s.world.ws.areas[ref.area].rooms[ref.room]
		row := skald.col(
			skald.text(fmt.tprintf("#%d  %s", room.vnum, components.display_text(room.name)), th.color.fg, th.font.size_md, overflow = .Ellipsis),
			skald.text(s.world.labels[ref.area], th.color.fg_muted, th.font.size_sm, overflow = .Ellipsis),
			width = inner,
			height = row_height,
			main_align = .Center,
			cross_align = .Stretch,
		)
		append(&rows, skald.clickable(ctx, row, Msg(Search_Chosen{ref})))
	}
	height := 2 * pad + f32(len(rows)) * row_height
	footer := ""
	switch {
	case s.search_total == 0:
		footer = "No rooms match."
	case s.search_total > len(s.search_hits):
		footer = fmt.tprintf("Showing %d of %d rooms. Keep typing to narrow it down.", len(s.search_hits), s.search_total)
	}
	if footer != "" {
		append(&rows, skald.col(components.caption(ctx, footer), height = footer_height, main_align = .Center))
		height += footer_height
	}
	card := skald.col(..rows[:], padding = pad, width = card_width, height = height, bg = th.color.surface, radius = th.radius.md)
	offset := [2]f32{0, 4}
	skald.widget_stamp_overlay_rect(ctx.widgets, skald.overlay_placement_rect(ctx, anchor, {card_width, height}, offset = offset))
	return skald.overlay(anchor, card, offset = offset)
}

@(private = "file")
search_changed :: proc(text: string) -> Msg {
	return Search_Changed{text = text}
}

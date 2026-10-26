/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "gui:skald"

/*
 Pointer gestures over a map canvas, shared by the room graph and the area
 map: a press sends `on_press` (the caller's hit-test result, or
 Pan_Started over empty space), dragging while panning sends Panned,
 releasing sends Pan_Ended, and the wheel zooms at the pointer. `last` is
 the canvas's rect from the previous frame; nothing is sent before it has
 one. The message types are the room graph's (room_graph.odin).
*/
canvas_gestures :: proc(ctx: ^skald.Ctx($Msg), id: skald.Widget_ID, last: skald.Rect, is_panning: bool, on_press: Msg) {
	if last.w <= 0 {
		return
	}
	input := ctx.input
	// Not under an open popover (a dropdown, search results): a click on
	// it must not also reach the canvas.
	is_over := skald.widget_hovered(ctx, id) && !skald.mouse_over_overlay(ctx)
	if is_over && input.mouse_pressed[.Left] {
		skald.send(ctx, on_press)
	}
	if is_panning {
		if input.mouse_buttons[.Left] && input.mouse_delta != {} {
			skald.send(ctx, Msg(Panned{input.mouse_delta}))
		}
		if input.mouse_released[.Left] {
			skald.send(ctx, Msg(Pan_Ended{}))
		}
	}
	if is_over && input.scroll.y != 0 {
		local := input.mouse_pos - {last.x, last.y}
		skald.send(ctx, Msg(Zoomed{factor = 1 + input.scroll.y * 0.1, at = local}))
	}
}

// The pointer's position relative to a canvas whose rect is `last`.
canvas_local :: proc(ctx: ^skald.Ctx($Msg), last: skald.Rect) -> [2]f32 {
	return ctx.input.mouse_pos - {last.x, last.y}
}

// How much one press of a zoom button zooms.
ZOOM_STEP :: f32(1.25)

// Zoom out, zoom in and Fit buttons for a map canvas whose rect is `last`
// and whose camera is at `zoom`. Zooming keeps the canvas's centre in
// place. The message types are the room graph's, as for the gestures.
zoom_buttons :: proc(ctx: ^skald.Ctx($Msg), last: skald.Rect, zoom: f32) -> skald.View {
	th := ctx.theme
	centre := [2]f32{last.w, last.h} / 2
	return skald.row(
		skald.button(ctx, "−", Msg(Zoomed{1 / ZOOM_STEP, centre}), bg = th.color.surface, fg = th.color.fg, disabled = zoom <= MIN_ZOOM),
		skald.button(ctx, "+", Msg(Zoomed{ZOOM_STEP, centre}), bg = th.color.surface, fg = th.color.fg, disabled = zoom >= MAX_ZOOM),
		skald.button(ctx, "Fit", Msg(Fitted{{last.w, last.h}}), bg = th.color.surface, fg = th.color.fg),
		spacing = th.spacing.xs,
	)
}

// A canvas's one-line hint beside its buttons. It takes the rest of the
// row and is cut short with "..." when that's too narrow, so the canvas
// below never has to be wider than the window.
hint :: proc(ctx: ^skald.Ctx($Msg), text: string) -> skald.View {
	th := ctx.theme
	return skald.flex(1, skald.text(text, th.color.fg_muted, th.font.size_md, overflow = .Ellipsis))
}

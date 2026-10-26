/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "gui:skald"

/*
 The frame the inspectors share: a fixed-width scrolling panel left of
 the map, with section titles and text wrapped to its width.
*/

INSPECTOR_WIDTH :: f32(340) // At the default text size; see inspector_width
INSPECTOR_SCROLL_ID :: "inspector-scroll"
FOCUS_BORDER :: f32(2) // The panel's focus border

// The panel's width at the theme's text size.
inspector_width :: proc(ctx: ^skald.Ctx($Msg)) -> f32 {
	return INSPECTOR_WIDTH * ui_scale(ctx.theme)
}

@(private)
section :: proc(ctx: ^skald.Ctx($Msg), title: string) -> skald.View {
	th := ctx.theme
	return skald.col(skald.spacer(th.spacing.sm), skald.text(title, th.color.fg, th.font.size_md))
}

// The panel: fixed width, scrolling when its content is taller.
@(private)
panel :: proc(ctx: ^skald.Ctx($Msg), content: skald.View) -> skald.View {
	th := ctx.theme
	id := skald.hash_id(INSPECTOR_SCROLL_ID)
	// The scroll fills the panel's height only as a flex child (a zero
	// size means "what my flex parent gives me").
	inner := skald.col(
		// Focusable, so F6 can land on the panel (the arrow and page keys
		// scroll it, Tab moves on to its links).
		skald.flex(1, skald.scroll(ctx, {inspector_width(ctx) - 2 * th.spacing.md - 2 * FOCUS_BORDER, 0}, content, id = id, focusable = true)),
		padding = th.spacing.md,
		bg = th.color.surface,
		radius = th.radius.md,
		cross_align = .Stretch,
	)
	// A scroll draws no focus ring, so the panel shows it: an accent
	// border in a margin that is always there, so nothing moves.
	return skald.col(
		skald.flex(1, inner),
		width = inspector_width(ctx),
		padding = FOCUS_BORDER,
		bg = th.color.primary if skald.widget_has_focus(ctx, id) else {},
		radius = th.radius.md + FOCUS_BORDER,
		cross_align = .Stretch,
	)
}

@(private)
text_width :: proc(ctx: ^skald.Ctx($Msg)) -> f32 {
	return inspector_width(ctx) - 2 * ctx.theme.spacing.md - 2 * FOCUS_BORDER - 12 * ui_scale(ctx.theme) // Room for the scrollbar
}

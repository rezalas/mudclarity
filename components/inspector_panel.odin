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
	// The scroll fills the panel's height only as a flex child (a zero
	// size means "what my flex parent gives me").
	return skald.col(
		skald.flex(1, skald.scroll(ctx, {inspector_width(ctx) - 2 * th.spacing.md, 0}, content)),
		width = inspector_width(ctx),
		padding = th.spacing.md,
		bg = th.color.surface,
		radius = th.radius.md,
		cross_align = .Stretch,
	)
}

@(private)
text_width :: proc(ctx: ^skald.Ctx($Msg)) -> f32 {
	return inspector_width(ctx) - 2 * ctx.theme.spacing.md - 12 * ui_scale(ctx.theme) // Room for the scrollbar
}

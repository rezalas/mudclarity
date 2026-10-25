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

// Nothing open: a card with the Open button (or loading progress), centred.
welcome_view :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	th := ctx.theme
	action: skald.View
	if is_loading(s) {
		action = skald.row(
			skald.spinner(ctx, 18),
			skald.text(fmt.tprintf("Loading %s…", filepath.base(s.loading_path)), th.color.fg_muted, th.font.size_md),
			spacing = th.spacing.sm,
			cross_align = .Center,
		)
	} else {
		action = skald.button(ctx, "Open area.lst…", Msg(Open_Requested{}), bg = th.color.primary, fg = th.color.on_primary)
	}

	card := skald.col(
		components.heading(ctx, "Mud Clarity", is_large = true),
		components.caption(ctx, "See a Riftshadow world's rooms and how they connect, and what is wrong with them.", max_width = 440),
		skald.spacer(th.spacing.lg),
		action,
		skald.spacer(th.spacing.sm),
		components.caption(ctx, "Or drop an area.lst or .are files anywhere in this window."),
		spacing = th.spacing.sm,
		padding = th.spacing.xl,
		bg = th.color.surface,
		radius = th.radius.lg,
	)
	return skald.col(card, main_align = .Center, cross_align = .Center)
}

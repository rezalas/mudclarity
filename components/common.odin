/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "gui:skald"

import "../validation"

/*
 Small widgets shared by screens and components. They are generic over the
 caller's Msg type, so any screen can use them without map_msg. Text passed
 in is drawn as is: run file text through display_text first.
*/

// A screen or section title.
heading :: proc(ctx: ^skald.Ctx($Msg), text: string, is_large := false) -> skald.View {
	th := ctx.theme
	return skald.text(text, th.color.fg, th.font.size_xl if is_large else th.font.size_lg)
}

// A muted line of explanation under a heading.
caption :: proc(ctx: ^skald.Ctx($Msg), text: string, max_width: f32 = 0) -> skald.View {
	th := ctx.theme
	return skald.text(text, th.color.fg_muted, th.font.size_md, max_width = max_width)
}

// A count with its label underneath, as on a summary card. `color` tints
// the number (zero value: normal text).
stat :: proc(ctx: ^skald.Ctx($Msg), value, label: string, color: skald.Color = {}) -> skald.View {
	th := ctx.theme
	return skald.col(
		skald.text(value, color if color != {} else th.color.fg, th.font.size_xl),
		skald.text(label, th.color.fg_muted, th.font.size_sm),
		spacing = th.spacing.xs,
		padding = th.spacing.md,
		bg = th.color.surface,
		radius = th.radius.md,
		cross_align = .Start,
	)
}

Banner_Kind :: enum u8 {
	Info,
	Warning,
	Error,
}

// A full-width message strip, with a Dismiss button when `on_dismiss` is
// given.
banner :: proc(ctx: ^skald.Ctx($Msg), kind: Banner_Kind, message: string, on_dismiss: Maybe(Msg) = nil) -> skald.View {
	th := ctx.theme
	accent := th.color.primary
	switch kind {
	case .Info:
	case .Warning: accent = th.color.warning
	case .Error: accent = th.color.danger
	}
	dismiss := skald.spacer(0)
	if msg, ok := on_dismiss.?; ok {
		dismiss = skald.button(ctx, "Dismiss", msg, bg = th.color.surface, fg = th.color.fg)
	}
	return skald.row(
		skald.rect({4, 0}, accent, 2),
		skald.flex(1, skald.col(skald.text(message, th.color.fg, th.font.size_md, overflow = .Ellipsis), main_align = .Center)),
		dismiss,
		spacing = th.spacing.md,
		padding = th.spacing.md,
		bg = th.color.elevated,
		radius = th.radius.md,
		cross_align = .Stretch,
	)
}

// The body text size the app's fixed sizes were designed at (Skald's
// default `size_md`).
BASE_FONT_SIZE :: f32(14)

// How much the theme's text is scaled (the Text size setting), worked out
// from the theme itself so nothing else needs passing around. Fixed widths
// and heights, and text drawn on canvases, are multiplied by it.
ui_scale :: proc(th: ^skald.Theme) -> f32 {
	return th.font.size_md / BASE_FONT_SIZE if th.font.size_md > 0 else 1
}

// The colour that stands for a severity: the theme's danger and warning
// colours (which the colour-blind palette replaces) and muted text for
// info. Everything that shows a severity by colour goes through here.
severity_color :: proc(colors: skald.Theme_Colors, severity: validation.Severity) -> skald.Color {
	switch severity {
	case .Error:
		return colors.danger
	case .Warning:
		return colors.warning
	case .Info:
	}
	return colors.fg_muted
}

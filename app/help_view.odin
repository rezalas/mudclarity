/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:strings"

import "gui:skald"

import "../components"

/*
 The Help dialog: what the app is, and every keyboard shortcut from the
 key_bindings table, grouped by where they work. F1, Ctrl+/ (Cmd+/ on
 macOS) or typing "?" outside a text box open it; Close or Escape close
 it.
*/

HELP_DIALOG_WIDTH :: f32(600) // At the default text size
HELP_KEYS_WIDTH :: f32(190)   // The keys column, likewise

// The button that opens Help, for a screen's header.
help_button :: proc(ctx: ^skald.Ctx(Msg)) -> skald.View {
	th := ctx.theme
	return skald.button(ctx, "Help", Msg(Help_Shown{true}), bg = th.color.surface, fg = th.color.fg)
}

// Register the keys that open Help (from view, before other widgets).
help_shortcuts :: proc(s: State, ctx: ^skald.Ctx(Msg)) {
	if s.help_open || s.settings_open {
		return
	}
	for chord in HELP_SHORTCUTS {
		skald.shortcut(ctx, chord, Msg(Help_Shown{true}))
	}
	if skald.is_typing(ctx) {
		return
	}
	skald.shortcut(ctx, HELP_CHARACTER_SHORTCUT, Msg(Help_Shown{true}))
	if strings.contains(ctx.input.text, HELP_CHARACTER) {
		skald.send(ctx, Msg(Help_Shown{true}))
	}
}

// The dialog, or nothing while it is closed.
help_dialog :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	if !s.help_open {
		return skald.dialog(ctx, false, skald.spacer(0), help_closed) // As settings_dialog
	}
	th := ctx.theme
	k := components.ui_scale(th)
	width := HELP_DIALOG_WIDTH * k
	inner := width - 2 * th.spacing.lg
	parts := make([dynamic]skald.View, context.temp_allocator)
	append(
		&parts,
		components.caption(ctx, "Mud Clarity shows a Riftshadow world's rooms, how they connect, and what is wrong with them. Everything can be done with the keyboard as well as the mouse.", max_width = inner - 16 * k),
	)
	bindings := key_bindings()
	for scope in Key_Scope {
		append(&parts, skald.col(skald.spacer(th.spacing.sm), skald.text(KEY_SCOPE_TITLES[scope], th.color.fg, th.font.size_md)))
		for b in bindings {
			if b.scope == scope {
				append(&parts, binding_row(ctx, b, inner - 16 * k))
			}
		}
	}
	list := skald.col(..parts[:], spacing = th.spacing.xs)
	height := 460 * k
	if ctx.renderer != nil {
		height = min(height, f32(ctx.renderer.fb_size.y) * 0.6)
	}
	content := skald.col(
		components.heading(ctx, "Help"),
		skald.scroll(ctx, {inner, height}, list),
		skald.row(
			skald.flex(1, skald.spacer(0)),
			skald.button(ctx, "Close", Msg(Help_Shown{false}), bg = th.color.primary, fg = th.color.on_primary),
		),
		spacing = th.spacing.sm,
		cross_align = .Stretch,
	)
	return skald.dialog(ctx, s.help_open, content, help_closed, width = width, max_width = width, padding = th.spacing.lg)
}

// The keys, then what they do (wrapping), on one row.
@(private = "file")
binding_row :: proc(ctx: ^skald.Ctx(Msg), b: Key_Binding, width: f32) -> skald.View {
	th := ctx.theme
	keys_width := HELP_KEYS_WIDTH * components.ui_scale(th)
	return skald.row(
		skald.col(skald.text(binding_keys_text(b), th.color.fg, th.font.size_md, max_width = keys_width), width = keys_width),
		components.caption(ctx, b.action, max_width = width - keys_width - th.spacing.md),
		spacing = th.spacing.md,
	)
}

@(private = "file")
help_closed :: proc() -> Msg {
	return Help_Shown{false}
}

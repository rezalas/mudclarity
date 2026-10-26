/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:fmt"

import "gui:skald"

import "../components"
import "../settings"

/*
 The Settings dialog: a modal over whichever screen is showing, opened by
 the Settings button or Ctrl+, (Cmd+, on macOS). Changes apply at once
 and are saved straight away, so there is only Close.
*/

SETTINGS_DIALOG_WIDTH :: f32(480)

// Ctrl+, opens Settings; Cmd+, on macOS, as Mac apps do.
SETTINGS_SHORTCUT :: skald.Shortcut{key = .Comma, mods = {.Super} when ODIN_OS == .Darwin else {.Ctrl}}

// Segment labels, in Theme_Choice order.
@(private = "file")
THEME_LABELS := [len(settings.Theme_Choice)]string{"Follow the system", "Light", "Dark"}

// The button that opens Settings, for a screen's header.
settings_button :: proc(ctx: ^skald.Ctx(Msg)) -> skald.View {
	th := ctx.theme
	return skald.button(ctx, "Settings", Msg(Settings_Shown{true}), bg = th.color.surface, fg = th.color.fg)
}

// The dialog, or nothing while it is closed.
settings_dialog :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	th := ctx.theme
	labels := THEME_LABELS
	content := skald.col(
		components.heading(ctx, "Settings"),
		section_title(ctx, "Appearance"),
		skald.row(
			skald.text("Theme", th.color.fg, th.font.size_md),
			skald.flex(1, skald.spacer(0)),
			skald.segmented(ctx, labels[:], int(s.settings.theme), theme_chosen),
			cross_align = .Center,
		),
		skald.spacer(th.spacing.md),
		components.caption(ctx, saved_where(s), max_width = SETTINGS_DIALOG_WIDTH - 2 * th.spacing.lg),
		skald.row(
			skald.flex(1, skald.spacer(0)),
			skald.button(ctx, "Close", Msg(Settings_Shown{false}), bg = th.color.primary, fg = th.color.on_primary),
		),
		spacing = th.spacing.sm,
		cross_align = .Stretch,
	)
	return skald.dialog(ctx, s.settings_open, content, settings_closed, width = SETTINGS_DIALOG_WIDTH, padding = th.spacing.lg)
}

@(private = "file")
section_title :: proc(ctx: ^skald.Ctx(Msg), title: string) -> skald.View {
	th := ctx.theme
	return skald.col(skald.spacer(th.spacing.sm), skald.text(title, th.color.fg_muted, th.font.size_sm))
}

// Where changes go, so people can find (or back up) the file.
@(private = "file")
saved_where :: proc(s: State) -> string {
	switch {
	case s.store == nil || s.store.path == "":
		return "Changes apply now, but can't be saved: this system has no settings folder."
	case s.store.loaded.status == .Newer:
		return "Changes apply now, but aren't saved: the settings file is from a newer version."
	}
	return fmt.tprintf("Changes are saved in %s", s.store.path)
}

@(private = "file")
theme_chosen :: proc(index: int) -> Msg {
	return Theme_Chosen{settings.Theme_Choice(index)}
}

@(private = "file")
settings_closed :: proc() -> Msg {
	return Settings_Shown{false}
}

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

SETTINGS_DIALOG_WIDTH :: f32(480) // At the default text size


// How far Ctrl+= and Ctrl+- move the text size, in percent: the slider
// has 5% steps, but a key press that small is hard to see.
TEXT_SCALE_KEY_STEP :: 10

// The text size slider's marks, which jump there when clicked.
@(private = "file")
TEXT_SCALE_MARKS := [?]int{75, 100, 125, 150, 175, 200}

// Segment labels, in Palette_Choice order.
@(private = "file")
PALETTE_LABELS := [len(settings.Palette_Choice)]string{"Standard", "Colour-blind friendly"}

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
	if !s.settings_open {
		// Build nothing while closed: widgets built here would still
		// handle input, against rects left over from other widgets.
		return skald.dialog(ctx, false, skald.spacer(0), settings_closed)
	}
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
		skald.row(
			skald.text("Colours", th.color.fg, th.font.size_md),
			skald.flex(1, skald.spacer(0)),
			skald.segmented(ctx, PALETTE_LABELS[:], int(s.settings.palette), palette_chosen),
			cross_align = .Center,
		),
		components.caption(ctx, "Colour-blind friendly colours keep errors and warnings apart with red-green and blue-yellow colour blindness.", max_width = SETTINGS_DIALOG_WIDTH * components.ui_scale(th) - 2 * th.spacing.lg),
		text_scale_control(s, ctx),
		components.caption(ctx, text_size_hint(), max_width = SETTINGS_DIALOG_WIDTH * components.ui_scale(th) - 2 * th.spacing.lg),
		skald.spacer(th.spacing.md),
		components.caption(ctx, saved_where(s), max_width = SETTINGS_DIALOG_WIDTH * components.ui_scale(th) - 2 * th.spacing.lg),
		skald.row(
			skald.flex(1, skald.spacer(0)),
			skald.button(ctx, "Close", Msg(Settings_Shown{false}), bg = th.color.primary, fg = th.color.on_primary),
		),
		spacing = th.spacing.sm,
		cross_align = .Stretch,
	)
	// Skald caps dialogs at 480 px unless told otherwise; this one grows
	// with the text.
	width := SETTINGS_DIALOG_WIDTH * components.ui_scale(th)
	return skald.dialog(ctx, s.settings_open, content, settings_closed, width = width, max_width = width, padding = th.spacing.lg)
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

// The text size: its value, a slider in 5% steps, and the marks under it.
// While the slider is dragged the draft is shown; it is applied when the
// mouse is let go.
@(private = "file")
text_scale_control :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	th := ctx.theme
	width := SETTINGS_DIALOG_WIDTH * components.ui_scale(th) - 2 * th.spacing.lg
	percent := s.text_scale_draft if s.text_scale_draft != 0 else s.settings.text_scale
	if s.text_scale_draft != 0 && !ctx.input.mouse_buttons[.Left] {
		skald.send(ctx, Msg(Text_Scale_Chosen{s.text_scale_draft}))
	}
	marks := make([dynamic]skald.View, context.temp_allocator)
	for mark, i in TEXT_SCALE_MARKS {
		if i > 0 {
			append(&marks, skald.flex(1, skald.spacer(0)))
		}
		color := th.color.fg if mark == percent else th.color.fg_muted
		append(&marks, skald.clickable(ctx, skald.text(fmt.tprintf("%d%%", mark), color, th.font.size_sm), Msg(Text_Scale_Chosen{mark})))
	}
	return skald.col(
		skald.row(
			skald.text("Text size", th.color.fg, th.font.size_md),
			skald.flex(1, skald.spacer(0)),
			skald.text(fmt.tprintf("%d%%", percent), th.color.fg, th.font.size_md),
			width = width,
			cross_align = .Center,
		),
		skald.slider(
			ctx,
			f32(percent),
			text_scale_dragged,
			min_value = settings.MIN_TEXT_SCALE,
			max_value = settings.MAX_TEXT_SCALE,
			step = settings.TEXT_SCALE_STEP,
			width = width,
		),
		skald.row(..marks[:], width = width),
		spacing = th.spacing.xs,
	)
}

// Register the text size shortcuts (from view, before other widgets).
text_scale_shortcuts :: proc(s: State, ctx: ^skald.Ctx(Msg)) {
	percent := s.settings.text_scale
	bigger := Msg(Text_Scale_Chosen{next_text_scale(percent, +1)})
	// Ctrl+Shift+= is Ctrl++ on most layouts, so it counts as =.
	for chord in LARGER_TEXT_SHORTCUTS {
		skald.shortcut(ctx, chord, bigger)
	}
	skald.shortcut(ctx, SMALLER_TEXT_SHORTCUT, Msg(Text_Scale_Chosen{next_text_scale(percent, -1)}))
	skald.shortcut(ctx, RESET_TEXT_SHORTCUT, Msg(Text_Scale_Chosen{settings.DEFAULT_TEXT_SCALE}))
}

// The keys for the text size, as this platform writes them (keys.odin).
@(private = "file")
text_size_hint :: proc() -> string {
	return fmt.tprintf(
		"%s and %s change the text size anywhere; %s resets it.",
		chord_text(LARGER_TEXT_SHORTCUTS[0]),
		chord_text(SMALLER_TEXT_SHORTCUT),
		chord_text(RESET_TEXT_SHORTCUT),
	)
}

// The text size `steps` key presses away from `percent`, in range.
next_text_scale :: proc(percent, steps: int) -> int {
	return settings.clamp_text_scale(percent + steps * TEXT_SCALE_KEY_STEP)
}

@(private = "file")
text_scale_dragged :: proc(value: f32) -> Msg {
	return Text_Scale_Dragged{int(value + 0.5)}
}

@(private = "file")
palette_chosen :: proc(index: int) -> Msg {
	return Palette_Chosen{settings.Palette_Choice(index)}
}

@(private = "file")
theme_chosen :: proc(index: int) -> Msg {
	return Theme_Chosen{settings.Theme_Choice(index)}
}

@(private = "file")
settings_closed :: proc() -> Msg {
	return Settings_Shown{false}
}

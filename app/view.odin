/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "gui:skald"

import "../components"

// Paths given on the command line (`mudclarity open <path>`), opened on the
// first frame. Set by run before the window opens; read-only afterwards.
@(private)
startup_paths: []string

// The root view: the current screen under any error banner. The whole
// window accepts dropped files.
view :: proc(s: State, ctx: ^skald.Ctx(Msg)) -> skald.View {
	request_startup_paths(s, ctx)
	th := ctx.theme
	if !s.settings_open {
		skald.shortcut(ctx, SETTINGS_SHORTCUT, Msg(Settings_Shown{true}))
	}

	children := make([dynamic]skald.View, context.temp_allocator)
	if s.error != "" {
		append(&children, components.banner(ctx, .Error, components.display_text(s.error), Msg(Dismiss_Error{})))
	}
	if s.warning != "" {
		append(&children, components.banner(ctx, .Warning, components.display_text(s.warning), Msg(Dismiss_Warning{})))
	}
	body := world_view(s, ctx) if s.screen == .World && s.world != nil else welcome_view(s, ctx)
	append(&children, skald.flex(1, body), settings_dialog(s, ctx))

	page := skald.col(..children[:], spacing = th.spacing.md, padding = th.spacing.lg, bg = th.color.bg, cross_align = .Stretch)
	return skald.drop_zone(ctx, page, files_dropped)
}

// Skald has no startup command, so the first frame asks for the
// command-line paths to be opened. Opening bumps the generation, so this
// happens once even if the request is refused.
@(private = "file")
request_startup_paths :: proc(s: State, ctx: ^skald.Ctx(Msg)) {
	if s.generation == 0 && len(startup_paths) > 0 {
		skald.send(ctx, Msg(Open_Paths{paths = startup_paths}))
	}
}

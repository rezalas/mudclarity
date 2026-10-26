/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:fmt"
import "core:path/filepath"
import "core:strings"

import "gui:skald"

import "../clarity"
import "../models"
import "../validation"

/*
 The area inspector: the area selected on the area map, its open findings
 and the user's notes on it, with a box to add one. It only displays what
 it is given (Area_Inspector_Data, built by the host each frame) and
 reports back through the host's callbacks: the draft changed, Add, and
 Open (show the area's rooms). Generic over the host's Msg for the same
 reason as the room inspector (it scrolls).
*/

Area_Inspector_Data :: struct {
	header:  ^models.Area_Header,      // nil: no area
	file:    string,                   // How area.lst names the file
	rooms:   int,
	open:    [validation.Severity]int, // Findings that aren't accepted
	notes:   []clarity.Note,           // This area's notes, oldest first
	draft:   string,                   // The note being written
	can_add: bool,                     // There is a review file to save notes in
}

// What the inspector reports, as the host's Msgs.
Area_Inspector_Events :: struct($Msg: typeid) {
	on_draft: proc(text: string) -> Msg,
	add:      Msg,
	open:     Msg,
}

AREA_NOTE_INPUT_ID :: "area-note-input"

area_inspector_view :: proc(ctx: ^skald.Ctx($Msg), d: Area_Inspector_Data, events: Area_Inspector_Events(Msg)) -> skald.View {
	th := ctx.theme
	if d.header == nil {
		return panel(ctx, caption(ctx, "Select an area on the map to see its details and notes.", max_width = text_width(ctx)))
	}
	h := d.header
	parts := make([dynamic]skald.View, context.temp_allocator)
	append(&parts, skald.text(base_name(d.file), th.color.fg_muted, th.font.size_md))
	append(&parts, skald.text(area_name(h^), th.color.fg, th.font.size_lg, max_width = text_width(ctx)))
	append(&parts, caption(ctx, area_facts(d), max_width = text_width(ctx)))
	append(&parts, skald.button(ctx, "Open rooms", events.open, bg = th.color.primary, fg = th.color.on_primary))
	append(&parts, section(ctx, "Open findings"))
	append(&parts, findings_line(ctx, d.open))
	if credits := trimmed(h.credits); credits != "" {
		append(&parts, section(ctx, "Credits"))
		append(&parts, caption(ctx, credits, max_width = text_width(ctx)))
	}
	if builders := trimmed(h.builders); builders != "" {
		append(&parts, section(ctx, "Builders"))
		append(&parts, caption(ctx, builders, max_width = text_width(ctx)))
	}

	append(&parts, section(ctx, fmt.tprintf("Notes (%d)", len(d.notes))))
	for note in d.notes {
		append(&parts, note_row(ctx, note))
	}
	if !d.can_add {
		append(&parts, caption(ctx, "Open the world's area.lst to keep notes.", max_width = text_width(ctx)))
	} else {
		input := skald.text_input(
			ctx,
			d.draft,
			events.on_draft,
			id = skald.hash_id(AREA_NOTE_INPUT_ID),
			placeholder = "Add a note about this area",
			width = text_width(ctx),
			multiline = true,
			wrap = true,
			min_lines = 3,
			max_chars = MAX_NOTE_CHARS,
		)
		is_blank := is_blank_text(d.draft)
		// The page colour, so the button stands out from the panel.
		add := skald.button(ctx, "Add note", events.add, bg = th.color.bg, fg = th.color.fg, disabled = is_blank)
		append(&parts, input, add)
	}
	return panel(ctx, skald.col(..parts[:], spacing = th.spacing.xs))
}

// Longest note the box accepts, in characters.
MAX_NOTE_CHARS :: 4000

// Helpers that use other packages stay out of the generic procs: Odin only
// checks a generic body when it is used, so its imports would otherwise
// count as unused in builds that don't use it (the components tests).

@(private = "file")
area_name :: proc(h: models.Area_Header) -> string {
	name := trimmed(h.name)
	return name if name != "" else "(no name)"
}

// File text, for display and with surrounding space removed.
@(private = "file")
trimmed :: proc(raw: string) -> string {
	return strings.trim_space(display_text(raw))
}

@(private = "file")
is_blank_text :: proc(text: string) -> bool {
	return strings.trim_space(text) == ""
}

@(private = "file")
base_name :: proc(path: string) -> string {
	return filepath.base(path)
}

// Levels, vnums, type and climate on one line.
@(private = "file")
area_facts :: proc(d: Area_Inspector_Data) -> string {
	h := d.header
	return fmt.tprintf(
		"%d rooms · levels %d-%d · vnums %d-%d · %s · %s",
		d.rooms,
		h.low_level,
		h.high_level,
		h.min_vnum,
		h.max_vnum,
		display_text(h.area_type),
		display_text(h.climate),
	)
}

@(private = "file")
findings_line :: proc(ctx: ^skald.Ctx($Msg), open: [validation.Severity]int) -> skald.View {
	th := ctx.theme
	if open == {} {
		return caption(ctx, "None.")
	}
	return skald.row(
		skald.text(fmt.tprintf("%d errors", open[.Error]), th.color.danger if open[.Error] > 0 else th.color.fg_muted, th.font.size_md),
		skald.text(fmt.tprintf("%d warnings", open[.Warning]), th.color.warning if open[.Warning] > 0 else th.color.fg_muted, th.font.size_md),
		skald.text(fmt.tprintf("%d info", open[.Info]), th.color.fg_muted, th.font.size_md),
		spacing = th.spacing.md,
	)
}

@(private = "file")
note_row :: proc(ctx: ^skald.Ctx($Msg), note: clarity.Note) -> skald.View {
	th := ctx.theme
	return skald.row(
		skald.rect({4, 0}, th.color.border, 2),
		skald.col(
			caption(ctx, display_user_text(note.date)),
			skald.text(display_user_text(note.text, keep_newlines = true), th.color.fg, th.font.size_md, max_width = text_width(ctx) - 12),
			spacing = 2,
		),
		spacing = th.spacing.sm,
		cross_align = .Stretch,
	)
}

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "core:fmt"
import "core:strings"

import "gui:skald"

import "../clarity"
import "../formats"
import "../models"
import "../validation"

/*
 The room inspector: everything about the selected room in a scrolling
 panel. It only displays what it is given (Room_Inspector_Data, built by
 the host each frame) and reports one thing back: an exit's target was
 clicked, through the host's `on_follow`. Text from the file goes through
 display_text.

 Unlike the room graph it is generic over the host's Msg instead of being
 embedded with map_msg: its scroll is built during rendering (a zero size
 defers through `sized`), after map_msg's stack-allocated sub-context is
 gone, which crashes.
*/


// One exit of the room, resolved by the host.
Inspector_Exit :: struct {
	exit:        models.Exit,
	target_name: string, // The target room's name, "" if it doesn't exist
	elsewhere:   string, // The target's area label if it is in another area, else ""
	is_missing:  bool,   // Not a room in the loaded world (or a negative vnum)
}

// A finding about the room, with how it stands in the review.
Inspector_Finding :: struct {
	diagnostic: validation.Diagnostic,
	state:      clarity.State,
}

Room_Inspector_Data :: struct {
	room:       ^models.Room, // nil: nothing selected
	area_label: string,
	exits:      []Inspector_Exit,
	findings:   []Inspector_Finding,
}

// `on_follow(vnum)` makes the host's Msg for clicking an exit's target.
room_inspector_view :: proc(ctx: ^skald.Ctx($Msg), d: Room_Inspector_Data, on_follow: proc(target: int) -> Msg) -> skald.View {
	th := ctx.theme
	if d.room == nil {
		return panel(ctx, caption(ctx, "Select a room on the map to see its details.", max_width = text_width(ctx)))
	}
	room := d.room
	parts := make([dynamic]skald.View, context.temp_allocator)
	append(&parts, skald.text(fmt.tprintf("#%d", room.vnum), th.color.fg_muted, th.font.size_md))
	append(&parts, skald.text(display_text(room.name), th.color.fg, th.font.size_lg, max_width = text_width(ctx)))
	append(&parts, caption(ctx, room_facts(d), max_width = text_width(ctx)))
	if room.description != "" {
		append(&parts, section(ctx, "Description"))
		// Descriptions are pre-wrapped for an 80-column terminal; let them
		// reflow to the panel instead.
		append(&parts, skald.text(display_text(room.description), th.color.fg, th.font.size_md, max_width = text_width(ctx)))
	}
	append(&parts, section(ctx, fmt.tprintf("Exits (%d)", len(d.exits))))
	if len(d.exits) == 0 {
		append(&parts, caption(ctx, "None: this room has no way out."))
	}
	for e in d.exits {
		append(&parts, exit_row(ctx, e, on_follow))
	}
	if len(d.findings) > 0 {
		append(&parts, section(ctx, fmt.tprintf("Findings (%d)", len(d.findings))))
		for f in d.findings {
			append(&parts, finding_row(ctx, f))
		}
	}
	if len(room.extras) > 0 {
		keywords := make([dynamic]string, context.temp_allocator)
		for extra in room.extras {
			append(&keywords, display_text(extra.keyword))
		}
		append(&parts, section(ctx, "Extra descriptions"))
		append(&parts, caption(ctx, strings.join(keywords[:], ", ", context.temp_allocator), max_width = text_width(ctx)))
	}
	return panel(ctx, skald.col(..parts[:], spacing = th.spacing.xs))
}

// Area, sector and flags on one line.
@(private = "file")
room_facts :: proc(d: Room_Inspector_Data) -> string {
	room := d.room
	facts := make([dynamic]string, context.temp_allocator)
	append(&facts, d.area_label)
	if room.sector != "" {
		append(&facts, display_text(room.sector))
	}
	for flag in room.flags {
		append(&facts, display_text(flag))
	}
	return strings.join(facts[:], " · ", context.temp_allocator)
}

@(private = "file")
exit_row :: proc(ctx: ^skald.Ctx($Msg), e: Inspector_Exit, on_follow: proc(target: int) -> Msg) -> skald.View {
	th := ctx.theme
	direction := skald.text(direction_name(e.exit.direction), th.color.fg_muted, th.font.size_md)
	target: skald.View
	switch {
	case e.exit.target == 0:
		target = caption(ctx, "look only")
	case e.is_missing:
		target = skald.text(fmt.tprintf("#%d (missing)", e.exit.target), th.color.danger, th.font.size_md)
	case:
		label := fmt.tprintf("#%d %s", e.exit.target, display_text(e.target_name))
		target = skald.link(ctx, label, on_follow(e.exit.target), underline = false)
	}
	lines := make([dynamic]skald.View, context.temp_allocator)
	append(&lines, target)
	if e.elsewhere != "" {
		append(&lines, caption(ctx, fmt.tprintf("in %s", e.elsewhere)))
	}
	if door := door_text(e.exit); door != "" {
		append(&lines, caption(ctx, door))
	}
	return skald.row(
		skald.col(direction, width = 48 * ui_scale(th)),
		skald.col(..lines[:]),
		spacing = th.spacing.sm,
	)
}

// Not generic, unlike the views, so the import is used even in builds that
// never instantiate them (vet counts uses only in instantiated code).
@(private = "file")
direction_name :: proc(direction: models.Direction) -> string {
	return formats.DIRECTION_NAMES[direction]
}

// "door, closed, locked, key #3020", or "" for no door.
@(private = "file")
door_text :: proc(exit: models.Exit) -> string {
	flags := validation.door_flags(exit)
	if !flags.is_door {
		return ""
	}
	parts := make([dynamic]string, context.temp_allocator)
	append(&parts, "door")
	if flags.is_closed {
		append(&parts, "closed")
	}
	if flags.is_locked {
		append(&parts, "locked")
	}
	if exit.key > 0 {
		append(&parts, fmt.tprintf("key #%d", exit.key))
	}
	return strings.join(parts[:], ", ", context.temp_allocator)
}

STATE_LABELS := [clarity.State]string {
	.Open         = "",
	.Accepted     = "accepted",
	.Flagged      = "flagged",
	.Needs_Review = "needs review",
}

@(private = "file")
finding_row :: proc(ctx: ^skald.Ctx($Msg), f: Inspector_Finding) -> skald.View {
	th := ctx.theme
	d := f.diagnostic
	color := th.color.fg_muted
	switch d.severity {
	case .Error: color = th.color.danger
	case .Warning: color = th.color.warning
	case .Info:
	}
	title := fmt.tprintf("%v", d.check)
	if label := STATE_LABELS[f.state]; label != "" {
		title = fmt.tprintf("%s (%s)", title, label)
	}
	return skald.row(
		skald.rect({4, 0}, color, 2),
		skald.col(
			skald.text(title, color, th.font.size_md),
			caption(ctx, display_text(d.message), max_width = text_width(ctx) - 12),
			spacing = 2,
		),
		spacing = th.spacing.sm,
		cross_align = .Stretch,
	)
}

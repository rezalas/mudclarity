/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package components

import "gui:skald"

/*
 The map legend: what each mark on the room graph or the area map means.
 Each swatch is drawn with the maps' own painting (map_style.odin,
 paint_room_box, paint_area_circle, markers.odin) in the theme's colours,
 so it always matches the map, whatever the palette or light/dark. It
 opens over the top-left of the canvas with the Legend button or L, and
 clicks on it don't reach the map. Keys are in Help (F1), which it points
 to.
*/

Legend_Swatch :: enum u8 {
	Room,
	Room_Error,
	Room_Warning,
	Room_Info,
	Room_Selected,
	Room_Displaced,
	Room_Up,
	Room_Down,
	Exit_Two_Way,
	Exit_One_Way,
	Exit_Bent,
	Exit_Leaves_Area,
	Area,
	Area_Error,
	Area_Warning,
	Area_Info,
	Area_Unopened,
	Area_Current,
	Link_Exits,
	Link_Portals_Only,
	Link_One_Way,
}

Legend_Item :: struct {
	swatch: Legend_Swatch,
	label:  string,
}

Legend_Section :: struct {
	title: string,
	items: []Legend_Item,
}

@(private = "file")
ROOM_ITEMS := [?]Legend_Item {
	{.Room, "A room (its vnum shows when zoomed in)"},
	{.Room_Error, "Its worst finding shown is an error"},
	{.Room_Warning, "Its worst finding shown is a warning"},
	{.Room_Info, "Its worst finding shown is info"},
	{.Room_Selected, "The selected room"},
	{.Room_Displaced, "Moved: the cell its exits point to was taken"},
	{.Room_Up, "Has an exit up to another level"},
	{.Room_Down, "Has an exit down to another level"},
}

@(private = "file")
EXIT_ITEMS := [?]Legend_Item {
	{.Exit_Two_Way, "An exit both ways"},
	{.Exit_One_Way, "A one-way exit"},
	{.Exit_Bent, "Doesn't lead where its direction says (bent)"},
	{.Exit_Leaves_Area, "Leads to another area"},
}

@(private = "file")
AREA_ITEMS := [?]Legend_Item {
	{.Area, "An area (larger: more rooms)"},
	{.Area_Error, "Its worst finding shown is an error"},
	{.Area_Warning, "Its worst finding shown is a warning"},
	{.Area_Info, "Its worst finding shown is info"},
	{.Area_Unopened, "Unopened (closed to players)"},
	{.Area_Current, "The area on the room graph"},
}

@(private = "file")
LINK_ITEMS := [?]Legend_Item {
	{.Link_Exits, "Exits between areas (thicker: more)"},
	{.Link_Portals_Only, "Joined by portals only"},
	{.Link_One_Way, "Leads one way only"},
}

ROOM_GRAPH_LEGEND := [?]Legend_Section{{"Rooms", ROOM_ITEMS[:]}, {"Exits", EXIT_ITEMS[:]}}
AREA_MAP_LEGEND := [?]Legend_Section{{"Areas", AREA_ITEMS[:]}, {"Links", LINK_ITEMS[:]}}

// Sizes at the default text size; scaled by ui_scale.
LEGEND_WIDTH :: f32(330)
LEGEND_ROW_HEIGHT :: f32(34)
LEGEND_TITLE_HEIGHT :: f32(28)
LEGEND_SWATCH_WIDTH :: f32(46)
LEGEND_FOOTER_HEIGHT :: f32(40)

// The legend's key, in both maps' key lists.
LEGEND_KEY :: skald.Key.L

// The Legend button or L: show or hide a map's legend. Both maps use it.
Legend_Toggled :: struct {}

// The Legend button for a map's control row, shown pressed while open.
legend_button :: proc(ctx: ^skald.Ctx($Msg), is_open: bool) -> skald.View {
	th := ctx.theme
	bg, fg := th.color.surface, th.color.fg
	if is_open {
		bg, fg = th.color.primary, th.color.on_primary
	}
	return skald.button(ctx, "Legend", Msg(Legend_Toggled{}), bg = bg, fg = fg)
}

// The colour a swatch's main mark is drawn in: the same helper the maps
// use for that mark, so it follows the palette and light/dark.
legend_swatch_color :: proc(c: skald.Theme_Colors, swatch: Legend_Swatch) -> skald.Color {
	switch swatch {
	case .Room: return c.border
	case .Room_Error, .Area_Error: return severity_color(c, .Error)
	case .Room_Warning, .Area_Warning: return severity_color(c, .Warning)
	case .Room_Info, .Area_Info: return severity_color(c, .Info)
	case .Room_Selected, .Area_Current: return c.primary
	case .Room_Displaced: return c.fg_muted
	case .Room_Up, .Room_Down, .Exit_Leaves_Area: return c.primary
	case .Exit_Two_Way, .Exit_One_Way: return straight_exit_color(c)
	case .Exit_Bent: return bent_exit_color(c)
	case .Area: return c.border
	case .Area_Unopened: return area_fill(c, true)
	case .Link_Exits, .Link_One_Way: return link_color(c, true)
	case .Link_Portals_Only: return link_color(c, false)
	}
	return c.fg
}

// The legend over the canvas whose rect is `last`, for `sections`. It
// publishes its rect so the canvas ignores clicks on it.
legend_view :: proc(ctx: ^skald.Ctx($Msg), sections: []Legend_Section, last: skald.Rect) -> skald.View {
	th := ctx.theme
	k := ui_scale(th)
	pad := th.spacing.md
	width := LEGEND_WIDTH * k
	inner := width - 2 * pad
	rows := make([dynamic]skald.View, context.temp_allocator)
	height := 2 * pad + LEGEND_FOOTER_HEIGHT * k
	for section in sections {
		append(&rows, skald.col(skald.text(section.title, th.color.fg, th.font.size_md), height = LEGEND_TITLE_HEIGHT * k, main_align = .End))
		height += LEGEND_TITLE_HEIGHT * k
		for item in section.items {
			data := new(Legend_Swatch_Data, context.temp_allocator) // Read by paint after view returns
			data^ = {swatch = item.swatch, colors = th.color, scale = k}
			swatch := skald.canvas(ctx, data, paint_legend_swatch, width = LEGEND_SWATCH_WIDTH * k, height = LEGEND_ROW_HEIGHT * k)
			label := skald.text(item.label, th.color.fg_muted, th.font.size_sm, overflow = .Ellipsis)
			append(&rows, skald.row(swatch, skald.flex(1, label), width = inner, height = LEGEND_ROW_HEIGHT * k, spacing = th.spacing.sm, cross_align = .Center))
			height += LEGEND_ROW_HEIGHT * k
		}
	}
	footer := skald.text("Press L to hide this; F1 lists the map's keys.", th.color.fg_muted, th.font.size_sm, max_width = inner)
	append(&rows, skald.col(footer, height = LEGEND_FOOTER_HEIGHT * k, main_align = .End))
	content := skald.col(..rows[:])
	// Never taller than the canvas: scroll when it doesn't fit (a fixed
	// size, so it is built now, not deferred past map_msg's Ctx).
	if room := max(last.h - 16, 2 * pad + 40); height > room {
		height = room
		content = skald.scroll(ctx, {inner, room - 2 * pad}, content)
	}
	card := skald.col(content, padding = pad, width = width, height = height, bg = th.color.elevated, radius = th.radius.md)
	at := skald.Rect{last.x + 8, last.y + 8, 0, 0}
	skald.widget_stamp_overlay_rect(ctx.widgets, {at.x, at.y, width, height})
	return skald.overlay(at, card, pin = true)
}

Legend_Swatch_Data :: struct {
	swatch: Legend_Swatch,
	colors: skald.Theme_Colors,
	scale:  f32,
}

// One swatch, drawn as the map draws that mark.
paint_legend_swatch :: proc(d: ^Legend_Swatch_Data, p: skald.Canvas_Painter) {
	c, r, b := d.colors, p.r, p.bounds
	zoom := 0.75 * d.scale
	mid := [2]f32{b.x + b.w / 2, b.y + b.h / 2}
	half := ROOM_SIZE * zoom / 2
	box := skald.Rect{mid.x - half, mid.y - half, half * 2, half * 2}
	left, right := [2]f32{b.x + 3 * d.scale, mid.y}, [2]f32{b.x + b.w - 3 * d.scale, mid.y}
	line := max(1, 2 * zoom)
	switch d.swatch {
	case .Room:
		paint_room_box(r, c, box, zoom, {}, false, false, false, false)
	case .Room_Error:
		paint_room_box(r, c, box, zoom, {true, .Error}, false, false, false, false)
	case .Room_Warning:
		paint_room_box(r, c, box, zoom, {true, .Warning}, false, false, false, false)
	case .Room_Info:
		paint_room_box(r, c, box, zoom, {true, .Info}, false, false, false, false)
	case .Room_Selected:
		paint_room_box(r, c, box, zoom, {}, true, false, false, false)
	case .Room_Displaced:
		paint_room_box(r, c, box, zoom, {}, false, true, false, false)
	case .Room_Up:
		paint_room_box(r, c, box, zoom, {}, false, false, true, false)
	case .Room_Down:
		paint_room_box(r, c, box, zoom, {}, false, false, false, true)
	case .Exit_Two_Way:
		skald.draw_line(r, left, right, line, straight_exit_color(c), true)
	case .Exit_One_Way:
		skald.draw_line(r, left, right, line, straight_exit_color(c), true)
		paint_arrowhead(r, right, {1, 0}, 7 * zoom * 1.4, straight_exit_color(c))
	case .Exit_Bent:
		reach := (right.x - left.x) * 0.5
		skald.draw_bezier(r, left + {0, b.h * 0.25}, left + {reach, b.h * 0.25}, right - {reach, b.h * 0.25}, right - {0, b.h * 0.25}, line, bent_exit_color(c), true)
	case .Exit_Leaves_Area:
		paint_exit_stub(r, left, right - {4 * zoom, 0}, zoom * 1.4, c.primary)
	case .Area:
		paint_area_circle(r, c, mid, 9 * d.scale, zoom, {}, false, false)
	case .Area_Error:
		paint_area_circle(r, c, mid, 9 * d.scale, zoom, {true, .Error}, false, false)
	case .Area_Warning:
		paint_area_circle(r, c, mid, 9 * d.scale, zoom, {true, .Warning}, false, false)
	case .Area_Info:
		paint_area_circle(r, c, mid, 9 * d.scale, zoom, {true, .Info}, false, false)
	case .Area_Unopened:
		paint_area_circle(r, c, mid, 9 * d.scale, zoom, {}, true, false)
	case .Area_Current:
		paint_area_circle(r, c, mid, 8 * d.scale, d.scale * 0.7, {}, false, true)
	case .Link_Exits:
		skald.draw_line(r, left, right, max(1, 2.5 * d.scale), link_color(c, true), true)
	case .Link_Portals_Only:
		skald.draw_line(r, left, right, max(1, 1.5 * d.scale), link_color(c, false), true)
	case .Link_One_Way:
		skald.draw_line(r, left, right, max(1, 1.5 * d.scale), link_color(c, true), true)
		paint_arrowhead(r, right, {1, 0}, 9 * d.scale, link_color(c, true))
	}
}

/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "gui:skald"

import "../components"

/*
 F6 and Shift+F6 move keyboard focus between the World screen's regions,
 in reading order: the toolbar (landing on the area picker; the search
 box counts as the toolbar too), the inspector (its scroll area, from
 which Tab reaches its links) and the map (whichever canvas is shown).
 When the findings log (#12) arrives it becomes a fourth region.
*/

AREA_PICKER_ID :: "area-picker"

// The widget each region's focus lands on, in order.
world_regions :: proc(s: State) -> [3]skald.Widget_ID {
	canvas := components.AREA_MAP_ID if s.center == .Areas else components.ROOM_GRAPH_ID
	return {skald.hash_id(AREA_PICKER_ID), skald.hash_id(components.INSPECTOR_SCROLL_ID), skald.hash_id(canvas)}
}

// The region after (steps 1) or before (steps -1) the one holding
// `focused`. Focus outside every region (or on the search box) counts as
// before the first region going forward, and after the last going back,
// except that the search box is part of the toolbar.
next_region :: proc(regions: [3]skald.Widget_ID, focused: skald.Widget_ID, steps: int) -> int {
	current := -1
	for id, i in regions {
		if id == focused {
			current = i
		}
	}
	if focused == skald.hash_id(SEARCH_INPUT_ID) {
		current = 0
	}
	n := len(regions)
	if current < 0 {
		return 0 if steps > 0 else n - 1
	}
	return ((current + steps) % n + n) % n
}

// Register F6 and Shift+F6 (from view, before other widgets).
region_shortcuts :: proc(s: State, ctx: ^skald.Ctx(Msg)) {
	if .F6 not_in ctx.input.keys_pressed {
		return
	}
	for chord, i in REGION_SHORTCUTS {
		if ctx.input.modifiers == chord.mods {
			regions := world_regions(s)
			skald.widget_focus(ctx, regions[next_region(regions, ctx.widgets.focused_id, 1 if i == 0 else -1)])
			ctx.input.keys_pressed -= {.F6}
			return
		}
	}
}

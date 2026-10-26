/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "../clarity"
import "../components"
import "../settings"
import "../validation"
import "../workspace"

Msg :: union {
	Open_Requested,
	Dialog_Cancelled,
	Open_Paths,
	World_Loaded,
	Close_World,
	Area_Picked,
	Graph,
	Center_Chosen,
	Area_Map,
	Search_Changed,
	Search_Chosen,
	Filters_Shown,
	Severity_Shown,
	State_Shown,
	Filters_Reset,
	Note_Draft_Changed,
	Note_Added,
	Review_Saved,
	Exit_Followed,
	Dismiss_Error,
	Dismiss_Warning,
	Settings_Shown,
	Help_Shown,
	Theme_Chosen,
	Palette_Chosen,
	Text_Scale_Chosen,
	Text_Scale_Dragged,
	Settings_Saved,
	Theme_Changed,
	Quit_Requested,
	Redraw,
}

// The Open button: show the file dialog.
Open_Requested :: struct {}

Dialog_Cancelled :: struct {}

// Open a world: an area.lst, or loose .are files. The paths live in the
// frame's temp allocator (from the dialog, a drop or the command line).
Open_Paths :: struct {
	paths: []string,
}

// A loading thread finished. Exactly one of `world` and `error` is set;
// both were allocated with runtime.heap_allocator() and now belong to
// update.
World_Loaded :: struct {
	generation: int,
	world:      ^World,
	error:      string,
}

Close_World :: struct {}

// An entry of the area picker (one of world.labels; in the frame arena).
Area_Picked :: struct {
	label: string,
}

// A message from the room graph component.
Graph :: struct {
	msg: components.Room_Graph_Msg,
}

// The Rooms/Areas switch.
Center_Chosen :: struct {
	view: Center_View,
}

// A message from the area map component.
Area_Map :: struct {
	msg: components.Area_Map_Msg,
}

// The room search box changed (text in the frame arena).
Search_Changed :: struct {
	text: string,
}

// A room search result was chosen.
Search_Chosen :: struct {
	room: Room_Ref,
}

// The Filters button (or Done): open or close the popover.
Filters_Shown :: struct {
	is_open: bool,
}

// A severity's box in the Filters popover.
Severity_Shown :: struct {
	severity: validation.Severity,
	is_shown: bool,
}

// A review state's box in the Filters popover.
State_Shown :: struct {
	state:    clarity.State,
	is_shown: bool,
}

// Back to DEFAULT_FILTERS.
Filters_Reset :: struct {}

// The area inspector's note box changed (text in the frame arena).
Note_Draft_Changed :: struct {
	text: string,
}

// The area inspector's Add note button.
Note_Added :: struct {}

// area.clarity was written. `error` is "" on success, else heap-allocated
// text that now belongs to update.
Review_Saved :: struct {
	error: string,
}

// An exit's target was clicked in the inspector: show that room.
Exit_Followed :: struct {
	target: int, // Vnum
}

Dismiss_Error :: struct {}

// The warning banner's dismiss button.
Dismiss_Warning :: struct {}

// The Settings button, Ctrl+, (Cmd+, on macOS), Close or Escape.
Settings_Shown :: struct {
	is_open: bool,
}

// F1, Ctrl+/ (Cmd+/), "?", Close or Escape.
Help_Shown :: struct {
	is_open: bool,
}

// The Theme choice in the Settings dialog.
Theme_Chosen :: struct {
	theme: settings.Theme_Choice,
}

// The Colours choice in the Settings dialog.
Palette_Chosen :: struct {
	palette: settings.Palette_Choice,
}

// A text size to use, in percent: from the Settings dialog (a mark, the
// slider let go, an arrow key) or Ctrl+= / Ctrl+- / Ctrl+0.
Text_Scale_Chosen :: struct {
	percent: int,
}

// The text size slider is being dragged: shown, but only applied when the
// mouse is let go (restyling mid-drag would move the slider under it).
Text_Scale_Dragged :: struct {
	percent: int,
}

// The settings file was written. `error` is "" on success, else
// heap-allocated text that now belongs to update.
Settings_Saved :: struct {
	error: string,
}

// The OS switched between light and dark.
Theme_Changed :: struct {}

// The window's close button.
Quit_Requested :: struct {}

// Nothing to do; it only makes Skald draw another frame (see Redraw_Soon).
Redraw :: struct {}

/*
 What an update asks the outside world to do. step returns one of these
 instead of a Skald Command, so updates can be tested without Skald
 allocating commands; update turns it into a Command (effects.odin).
*/
Effect :: union {
	Show_Open_Dialog,
	Load_Request,
	Follow_System_Theme,
	Save_Review,
	Apply_Settings,
	Quit,
	Redraw_Soon,
}

Show_Open_Dialog :: struct {}

// Load a world on a worker thread. `paths` are allocated with
// runtime.heap_allocator(); the worker frees them.
Load_Request :: struct {
	generation: int,
	paths:      []string,
}

// The OS switched light/dark and the settings follow it: restyle with
// the OS's theme at the chosen text size.
Follow_System_Theme :: struct {
	settings: settings.Settings,
}

// Restyle the app for `settings` and save them to the store's file.
Apply_Settings :: struct {
	store:    ^Settings_Store,
	settings: settings.Settings,
}

// Write the world's review file (area.clarity) after an edit.
Save_Review :: struct {
	ws: ^workspace.Workspace,
}

Quit :: struct {}

// Draw one more frame even if nothing happens. Skald only redraws on
// events, and a newly shown canvas learns its size in its first frame, so
// the graph needs a second one to fit itself.
Redraw_Soon :: struct {}

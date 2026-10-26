/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "../components"

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
	Exit_Followed,
	Dismiss_Error,
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

// An exit's target was clicked in the inspector: show that room.
Exit_Followed :: struct {
	target: int, // Vnum
}

Dismiss_Error :: struct {}

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

Follow_System_Theme :: struct {}

Quit :: struct {}

// Draw one more frame even if nothing happens. Skald only redraws on
// events, and a newly shown canvas learns its size in its first frame, so
// the graph needs a second one to fit itself.
Redraw_Soon :: struct {}

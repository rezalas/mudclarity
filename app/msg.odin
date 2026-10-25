/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "../workspace"

Msg :: union {
	Open_Requested,
	Dialog_Cancelled,
	Open_Paths,
	World_Loaded,
	Close_World,
	Dismiss_Error,
	Theme_Changed,
	Quit_Requested,
}

// The Open button: show the file dialog.
Open_Requested :: struct {}

Dialog_Cancelled :: struct {}

// Open a world: an area.lst, or loose .are files. The paths live in the
// frame's temp allocator (from the dialog, a drop or the command line).
Open_Paths :: struct {
	paths: []string,
}

// A loading thread finished. Exactly one of `ws` and `error` is set; both
// were allocated with runtime.heap_allocator() and now belong to update.
World_Loaded :: struct {
	generation: int,
	ws:         ^workspace.Workspace,
	summary:    Summary,
	error:      string,
}

Close_World :: struct {}

Dismiss_Error :: struct {}

// The OS switched between light and dark.
Theme_Changed :: struct {}

// The window's close button.
Quit_Requested :: struct {}

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

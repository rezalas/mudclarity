/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 *
 * Description: Mud clarity provides MUD area file visualization, allowing
 * people to view areas, rooms, connections, and mob/entity assignments and
 * information, as well as identify errors in formatting, linkage, dead zones,
 * and other issues that may make games unplayable or less enjoyable.
 */
package main

import "core:fmt"
import "core:mem/virtual"
import "core:os"

import "app"
import "cli"

/*
 The entry point. With no arguments, or `open <area.lst | file.are...>`,
 it opens the GUI (package app); anything else is the command-line
 interface (package cli). `mudclarity help` lists the commands.
*/
main :: proc() {
	args := os.args[1:]
	if len(args) == 0 {
		app.run(nil)
		return
	}
	if args[0] == "open" {
		if len(args) < 2 {
			fmt.eprintln("usage: mudclarity open <area.lst | file.are...>")
			os.exit(cli.EXIT_USAGE)
		}
		app.run(args[1:])
		return
	}

	// The CLI runs once and exits, so one arena holds everything it needs.
	arena: virtual.Arena
	if virtual.arena_init_growing(&arena) != nil {
		fmt.eprintln("out of memory")
		os.exit(1)
	}
	context.allocator = virtual.arena_allocator(&arena)
	os.exit(cli.run(args, cli.std_output()))
}

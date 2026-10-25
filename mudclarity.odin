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

import "cli"

/*
 The entry point. Until the GUI exists, every invocation is the
 command-line interface (package cli); run with no arguments for usage.
*/
main :: proc() {
	arena: virtual.Arena
	if virtual.arena_init_growing(&arena) != nil {
		fmt.eprintln("out of memory")
		os.exit(1)
	}
	context.allocator = virtual.arena_allocator(&arena)
	os.exit(cli.run(os.args[1:], cli.std_output()))
}

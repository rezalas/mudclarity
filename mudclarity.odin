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
import "core:os"

import "formats"

/*
 This is the main entry point for the Mud Clarity application.
 Until the GUI exists, it parses the area files given on the command line and
 prints a summary of each, or the first parse error.
*/
main :: proc() {
	if len(os.args) < 2 {
		fmt.eprintln("usage: mudclarity <file.are>...")
		os.exit(2)
	}
	failed := false
	for path in os.args[1:] {
		loaded, err := formats.load_area_file(path)
		if err != nil {
			fmt.eprintln(formats.parse_error_to_string(err, path, context.temp_allocator))
			failed = true
			continue
		}
		area := loaded.area
		fmt.printfln(
			"%s: %q, %d rooms, %d mobs, %d objects, %d resets",
			path,
			area.header.name,
			len(area.rooms),
			len(area.mobiles),
			len(area.objects),
			len(area.resets),
		)
		formats.unload_area(loaded)
	}
	if failed {
		os.exit(1)
	}
}

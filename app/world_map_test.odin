/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:fmt"
import "core:math"
import "core:os"
import "core:testing"

import "../clarity"
import "../components"
import "../testkit"
import "../workspace"

@(private = "file")
area :: proc(name: string, lo, hi: int, area_type, body: string) -> string {
	return fmt.tprintf("#AREA\n%s~\n%s~\nTester~\n1 50\n%d %d\n%s\ntemperate\n0\n1\nNone~\n%s#$\n", name, name, lo, hi, area_type, body)
}

// Alpha (100-199): 100 east to Bridge's 200, and a portal in 101 to 300.
// The Bridge (200-299): 200 west and 201 up to Alpha's 100.
// c.are (300-399, no name, unopened): 300, reached only by the portal.
@(private = "file")
LINKED_WORLD :: [3]string {
	"#ROOMS\n#100\nA~\n~\ncity\nD EAST 200 0 0\n~\n~\nD SOUTH 0 0 0\n~\n~\nS\n#101\nB~\n~\ncity\nD NORTH 100 0 0\n~\n~\nS\n#0\n" +
	"#OBJS\n#150\ngate~\na gate~\nA gate is here.~\nportal\nstuff~\n-1 0 0 300 0\n1 1 1 P\n#0\n" +
	"#RESETS\nOBJ 150 TO 101\nS\n",
	"#ROOMS\n#200\nC~\n~\ncity\nD WEST 100 0 0\n~\n~\nS\n#201\nD~\n~\ncity\nD UP 100 0 0\n~\n~\nD NORTH 200 0 0\n~\n~\nS\n#0\n",
	"#ROOMS\n#300\nE~\n~\ncity\nS\n#0\n",
}

@(test)
test_area_map_nodes_and_links :: proc(t: ^testing.T) {
	dir := testkit.temp_dir(t, "mudclarity_app_area_map")
	defer os.remove_all(dir)
	bodies := LINKED_WORLD
	list := testkit.write_world(
		t,
		dir,
		area("Alpha", 100, 199, "normal", bodies[0]),
		area("The Bridge", 200, 299, "normal", bodies[1]),
		area("", 300, 399, "unopened", bodies[2]),
	)
	world, error := world_open(paths(list))
	defer world_close(world)
	if !testing.expectf(t, error == "", "%s", error) do return
	m := world.area_map

	testing.expect_value(t, len(m.names), 3)
	testing.expect_value(t, m.names[0], "Alpha")
	testing.expect_value(t, m.names[1], "The Bridge")
	testing.expect_value(t, m.names[2], "c.are")
	testing.expect_value(t, m.rooms[0], 2)
	testing.expect_value(t, m.rooms[2], 1)
	testing.expect(t, !m.is_unopened[0] && !m.is_unopened[1] && m.is_unopened[2])

	// Look-only exits (vnum 0) and exits within an area aren't links.
	if !testing.expect_value(t, len(m.links), 2) do return
	testing.expect_value(t, m.links[0], components.Area_Link{a = 0, b = 1, exits_ab = 1, exits_ba = 2})
	testing.expect_value(t, m.links[1], components.Area_Link{a = 0, b = 2, portals_ab = 1})

	// Every area has a place, and no two circles overlap.
	testing.expect_value(t, len(m.positions), 3)
	for i in 0 ..< 3 {
		for j in i + 1 ..< 3 {
			d := m.positions[i] - m.positions[j]
			need := components.area_node_radius(m.rooms[i]) + components.area_node_radius(m.rooms[j])
			testing.expectf(t, math.sqrt(d.x * d.x + d.y * d.y) >= need, "areas %d and %d overlap", i, j)
		}
	}
}

@(test)
test_area_marks_ignore_accepted_findings :: proc(t: ^testing.T) {
	dir, list := world_on_disk(t, "mudclarity_app_area_marks")
	defer os.remove_all(dir)
	{
		world, _ := world_open(paths(list))
		defer world_close(world)
		// BASE_ROOMS' worst finding is its broken exit.
		testing.expect_value(t, world.area_map.marks[0], components.Room_Mark{has_finding = true, worst = .Error})
		key, _ := workspace.current_finding_key(world.ws, testkit.BROKEN_EXIT_ID)
		testing.expect(t, workspace.set_review(world.ws, key, clarity.REVIEW_ACCEPTED, "", "2026-10-26") == nil)
		testing.expect(t, workspace.save(world.ws) == nil)
	}
	world, _ := world_open(paths(list))
	defer world_close(world)
	// What's left (an orphan, a dead end, no entrance) are warnings.
	testing.expect_value(t, world.area_map.marks[0], components.Room_Mark{has_finding = true, worst = .Warning})
}

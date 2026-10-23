/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package formats

import "core:testing"

import "../models"

/*
 Golden tests on real Riftshadow area files (MIT licensed, copied into
 test_data/valid). Expected counts were cross-checked with awk/grep on the
 raw files, independently of this parser.
*/

MIDGAARD_ARE :: #load("../test_data/valid/midgaard.are")
ALSTEATOMB_ARE :: #load("../test_data/valid/alsteatomb.are")

@(test)
test_golden_midgaard_counts :: proc(t: ^testing.T) {
	loaded, err := load_area_bytes(MIDGAARD_ARE, "midgaard.are")
	defer unload_area(loaded)
	if !testing.expectf(t, err == nil, "%s", parse_error_to_string(err, "midgaard.are", context.temp_allocator)) do return
	area := loaded.area
	testing.expect_value(t, len(area.mobiles), 73)
	testing.expect_value(t, len(area.objects), 177)
	testing.expect_value(t, len(area.rooms), 154)
	testing.expect_value(t, len(area.resets), 377)
	testing.expect_value(t, len(area.programs), 19)
	testing.expect_value(t, len(area.specs), 0)

	ignored := 0
	for program in area.programs {
		if program.target == .Ignored_Spec {
			ignored += 1
		}
	}
	testing.expect_value(t, ignored, 17)

	mob_resets, equip_resets := 0, 0
	for reset in area.resets {
		#partial switch reset.command {
		case .Mob:
			mob_resets += 1
		case .Equip:
			equip_resets += 1
		}
	}
	testing.expect_value(t, mob_resets, 95)
	testing.expect_value(t, equip_resets, 134)
}

@(test)
test_golden_midgaard_details :: proc(t: ^testing.T) {
	loaded, err := load_area_bytes(MIDGAARD_ARE, "midgaard.are")
	defer unload_area(loaded)
	if !testing.expect(t, err == nil) do return
	area := loaded.area

	h := area.header
	testing.expect_value(t, h.name, "Midgaard")
	testing.expect_value(t, h.credits, "Diku")
	testing.expect_value(t, h.min_vnum, 3000)
	testing.expect_value(t, h.max_vnum, 3399)
	testing.expect_value(t, h.area_type, "unopened")

	wizard := area.mobiles[0]
	testing.expect_value(t, wizard.vnum, 3000)
	testing.expect_value(t, wizard.short_description, "the wizard")
	testing.expect_value(t, wizard.level, 38)
	testing.expect_value(t, wizard.hit, models.Dice{1, 1, 999})
	testing.expect_value(t, wizard.damage_type, "magic")
	testing.expect_value(t, len(wizard.flags), 11)
	testing.expect_value(t, wizard.flags[10].kind, "IMM")
	testing.expect_value(t, wizard.flags[10].value, "BASH")

	barrel := area.objects[0]
	testing.expect_value(t, barrel.vnum, 3000)
	testing.expect_value(t, barrel.item_type, "drink")
	testing.expect(t, barrel.values[2] == models.Object_Value("beer"))
	testing.expect_value(t, len(barrel.wear_flags), 1)
	testing.expect_value(t, barrel.wear_flags[0], "TAKE")
	testing.expect_value(t, barrel.limit, 0)
	testing.expect_value(t, barrel.timer, 0)

	concourse: ^models.Room
	for &room in area.rooms {
		if room.vnum == 3100 {
			concourse = &room
		}
	}
	if !testing.expect(t, concourse != nil, "room 3100 not found") do return
	testing.expect_value(t, concourse.name, "Northwest end of Concourse")
	testing.expect_value(t, concourse.sector, "city")
	testing.expect_value(t, len(concourse.flags), 1)
	testing.expect_value(t, concourse.flags[0], "LAW")
	testing.expect_value(t, concourse.exits[.North].?.target, 3051)
	testing.expect_value(t, concourse.exits[.East].?.target, 3101)
	testing.expect_value(t, concourse.exits[.South].?.target, 3270)
	testing.expect_value(t, concourse.exits[.South].?.description, "The concourse continues south.\n")
	_, has_west := concourse.exits[.West].?
	testing.expect(t, !has_west)

	first := area.resets[0]
	testing.expect_value(t, first.command, models.Reset_Command.Mob)
	testing.expect_value(t, first.vnum, 3073)
	testing.expect_value(t, first.room, 3001)
	testing.expect_value(t, area.resets[1].wear_location, "BODY")
	testing.expect_value(t, area.resets[1].context_room, 3001)
}

@(test)
test_golden_alsteatomb :: proc(t: ^testing.T) {
	loaded, err := load_area_bytes(ALSTEATOMB_ARE, "alsteatomb.are")
	defer unload_area(loaded)
	if !testing.expect(t, err == nil) do return
	area := loaded.area
	testing.expect_value(t, len(area.mobiles), 3)
	testing.expect_value(t, len(area.objects), 0)
	testing.expect_value(t, len(area.rooms), 6)
	testing.expect_value(t, len(area.resets), 2)
	testing.expect_value(t, len(area.programs), 2)

	// This mob's NOTES string contains the file's only CR byte.
	ehrlouge := area.mobiles[0]
	testing.expect_value(t, ehrlouge.notes, "Necro's talismanic aura equivalent quest mob.\n")
	testing.expect_value(t, len(ehrlouge.casts), 5)
	testing.expect_value(t, ehrlouge.casts[0], "vampiric touch")
	testing.expect_value(t, ehrlouge.hit, models.Dice{90, 8, 4200})

	ward := area.mobiles[1]
	testing.expect_value(t, ward.armor, [4]int{102, 104, 1, 24})

	study := area.rooms[3]
	testing.expect_value(t, study.vnum, 105)
	testing.expect_value(t, len(study.extras), 2)
	testing.expect_value(t, study.extras[0].keyword, "inscription")
	testing.expect_value(t, study.owner, "none")
	testing.expect_value(t, study.exits[.West].?.description, "A rectangular doorway leads into a tomb.  You notice an inscription\nwritten above it.  \n")
}

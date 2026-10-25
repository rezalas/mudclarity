/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package validation

Severity :: enum u8 {
	Error,   // The game logs, skips, or refuses to boot
	Warning, // Probably a mistake; the game runs but players may be affected
	Info,    // Worth knowing; often intentional or unresolvable here
}

// Every check the validator runs. See CLAUDE.md "Validation" for the rules
// and the Riftshadow code each one is based on.
Check :: enum u8 {
	Broken_Exit,
	Mismatched_Return,
	One_Way_Exit,
	Replaced_Exit,
	Dead_End_Room,
	Orphan_Room,
	Unreachable_Room,
	Area_Without_Entrance,
	Locked_Door_No_Key,
	Missing_Key,
	Key_Never_Placed,
	Door_Reset_No_Exit,
	Reset_Missing_Mob,
	Reset_Missing_Object,
	Reset_Missing_Room,
	Reset_Without_Mob,
	Reset_After_Object,
	Put_Into_Non_Container,
	Portal_Missing_Target,
	Program_Missing_Target,
	Ignored_Program_Line,
	Duplicate_Vnum,
	Vnum_Out_Of_Range,
	Bad_Area_Header,
}

// Default severity for each check. Checks about references to missing vnums
// are reported as Error or Info depending on the completeness rule instead
// (see missing_severity).
CHECK_SEVERITY := [Check]Severity {
	.Broken_Exit            = .Error,
	.Mismatched_Return      = .Warning,
	.One_Way_Exit           = .Info,
	.Replaced_Exit          = .Warning,
	.Dead_End_Room          = .Warning,
	.Orphan_Room            = .Warning,
	.Unreachable_Room       = .Warning,
	.Area_Without_Entrance  = .Warning,
	.Locked_Door_No_Key     = .Warning,
	.Missing_Key            = .Error,
	.Key_Never_Placed       = .Warning,
	.Door_Reset_No_Exit     = .Warning,
	.Reset_Missing_Mob      = .Error,
	.Reset_Missing_Object   = .Error,
	.Reset_Missing_Room     = .Error,
	.Reset_Without_Mob      = .Warning,
	.Reset_After_Object     = .Warning,
	.Put_Into_Non_Container = .Warning,
	.Portal_Missing_Target  = .Error,
	.Program_Missing_Target = .Error,
	.Ignored_Program_Line   = .Info,
	.Duplicate_Vnum         = .Error,
	.Vnum_Out_Of_Range      = .Warning,
	.Bad_Area_Header        = .Warning,
}

// Checks whose `vnum` is always a room, so a finding can be shown on that
// room. Duplicate_Vnum and Vnum_Out_Of_Range are about any kind of record,
// and reset and program checks name mobs, objects or the reset's room
// depending on the check, so they are left out.
ROOM_CHECKS :: bit_set[Check]{
	.Broken_Exit,
	.Mismatched_Return,
	.One_Way_Exit,
	.Replaced_Exit,
	.Dead_End_Room,
	.Orphan_Room,
	.Unreachable_Room,
	.Locked_Door_No_Key,
	.Missing_Key,
	.Key_Never_Placed,
	.Door_Reset_No_Exit,
}

// One finding. `area` indexes the slice passed to validate. `vnum` is the
// record the finding is about (0 for area-level findings) and
// `related_vnum` the other record involved, such as an exit's target.
Diagnostic :: struct {
	check:        Check,
	severity:     Severity,
	area:         int,
	line:         int,
	vnum:         int,
	related_vnum: int,
	message:      string, // Allocated with the allocator passed to validate
}

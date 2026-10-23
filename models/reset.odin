/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package models

// Reset commands from the #RESETS section. The loader keys on the first
// letter only, so `MOB`, `M` and `Mxyz` are all a Mob reset.
Reset_Command :: enum u8 {
	Mob,      // M: mob into room
	Object,   // O: object into room
	Put,      // P: object into container
	Give,     // G: object to the last mob
	Equip,    // E: object equipped on the last mob
	Door,     // D: set door state
	Randomize, // R: randomize exits
	Follow,   // F: last mob follows a leader
}

Door_State :: enum u8 {
	Open,
	Closed,
	Locked,
}

// A single reset. Field meaning depends on `command`:
//   Mob:       vnum = mob,    room = target room, global_limit, local_limit
//   Object:    vnum = object, room = target room
//   Put:       vnum = object, container = container vnum, count
//   Give:      vnum = object
//   Equip:     vnum = object, wear_location
//   Door:      room, direction, door_state
//   Randomize: room, exit_count
//   Follow:    vnum = leader mob, leader_index
// `context_room` is the room the loader attaches the reset to (the previous
// Mob/Object room for Put/Give/Equip/Follow); 0 when there is none yet.
Reset :: struct {
	command:       Reset_Command,
	vnum:          int,
	room:          int,
	container:     int,
	count:         int,
	global_limit:  int,
	local_limit:   int,
	wear_location: string,
	direction:     Direction,
	door_state:    Door_State,
	exit_count:    int,
	leader_index:  int,
	context_room:  int,
	line:          int,
}

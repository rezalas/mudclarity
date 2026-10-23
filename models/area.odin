/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package models

// Metadata from the #AREA section.
Area_Header :: struct {
	file_name:   string,
	name:        string,
	credits:     string,
	low_level:   int,
	high_level:  int,
	min_vnum:    int,
	max_vnum:    int,
	area_type:   string, // Raw word, e.g. "normal", "unopened"
	climate:     string,
	flags:       string, // Raw flag token
	security:    int,
	builders:    string,
	line:        int,
}

// A fully parsed area file.
// Strings may point into the source buffer the area was parsed from, so the
// buffer must outlive the Area (formats.Loaded_Area keeps both together).
Area :: struct {
	source_name:      string, // Name of the file this was parsed from
	header:           Area_Header,
	mobiles:          []Mobile,
	objects:          []Object,
	rooms:            []Room,
	resets:           []Reset,
	programs:         []Program_Binding,
	specs:            []Spec_Binding,
	skipped_sections: []string, // Sections read but not modeled, e.g. "SOCIALS"
}

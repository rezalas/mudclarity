/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package clarity

import "core:strings"

/*
 The .clarity review file: one per world, next to area.lst, stored as
 pretty-printed JSON. It records which area files were reviewed (with
 SHA-256 hashes), decisions on validator findings, the user's own notes and
 issues, and a snapshot of the last validation run.

 Field order here is the order written to disk. Enumerated values (checks,
 statuses, kinds, severities) are stored as their names so the file stays
 readable and unknown names from other versions are kept, not dropped.

 Memory: a loaded Document owns its strings and slices through the
 allocator passed to load_document; free them with document_destroy, or
 load into an arena.
*/

FORMAT_NAME :: "mudclarity"
FORMAT_VERSION :: 1

Document :: struct {
	format:    string,
	version:   int,
	area_list: string, // Name of the area list this file covers, e.g. "area.lst"
	files:     [dynamic]File_Entry,
	reviews:   [dynamic]Review,
	issues:    [dynamic]Issue,
	notes:     [dynamic]Note,
	snapshot:  [dynamic]Snapshot_Entry,
}

// An area file covered by the review, as of the last save.
File_Entry :: struct {
	name:    string, // Plain file name, relative to the .clarity file
	sha256:  string, // Lowercase hex
	size:    int,
	rooms:   int,
	mobiles: int,
	objects: int,
}

// A decision on a validator finding, identified by its key.
Review :: struct {
	file:         string,
	check:        string, // validation.Check name
	vnum:         int,
	related_vnum: int,
	status:       string, // REVIEW_ACCEPTED or REVIEW_FLAGGED
	note:         string,
	file_sha256:  string, // Hash of `file` when the decision was made
	date:         string, // YYYY-MM-DD
}

REVIEW_ACCEPTED :: "accepted" // Intended; hide it
REVIEW_FLAGGED :: "flagged" // Confirmed problem to fix

// A problem the user found that the validator can't detect.
Issue :: struct {
	id:     int, // Unique, never reused
	file:   string,
	kind:   string, // KIND_* name
	vnum:   int,
	status: string, // ISSUE_* name
	title:  string,
	note:   string,
	date:   string,
}

ISSUE_OPEN :: "open"
ISSUE_FLAGGED :: "flagged"
ISSUE_RESOLVED :: "resolved"

// A free-form note attached to an area or record.
Note :: struct {
	file: string,
	kind: string, // KIND_* name
	vnum: int,    // 0 for KIND_AREA
	text: string,
	date: string,
}

// What a note or issue is attached to. Vnum namespaces are separate, so the
// kind is needed to say which record a vnum means.
KIND_AREA :: "area"
KIND_ROOM :: "room"
KIND_MOB :: "mob"
KIND_OBJECT :: "object"

// One validator finding from the last saved run.
Snapshot_Entry :: struct {
	file:         string,
	check:        string,
	severity:     string, // "error", "warning" or "info"
	vnum:         int,
	related_vnum: int,
	line:         int,
	message:      string,
}

KINDS := [?]string{KIND_AREA, KIND_ROOM, KIND_MOB, KIND_OBJECT}
REVIEW_STATUSES := [?]string{REVIEW_ACCEPTED, REVIEW_FLAGGED}
ISSUE_STATUSES := [?]string{ISSUE_OPEN, ISSUE_FLAGGED, ISSUE_RESOLVED}
SEVERITY_NAMES := [?]string{"error", "warning", "info"}

// A new, empty document for the given area list name. Its lists, and
// everything later edits add, use `allocator`.
document_make :: proc(area_list: string, allocator := context.allocator) -> Document {
	return Document {
		format = strings.clone(FORMAT_NAME, allocator),
		version = FORMAT_VERSION,
		area_list = strings.clone(area_list, allocator),
		files = make([dynamic]File_Entry, allocator),
		reviews = make([dynamic]Review, allocator),
		issues = make([dynamic]Issue, allocator),
		notes = make([dynamic]Note, allocator),
		snapshot = make([dynamic]Snapshot_Entry, allocator),
	}
}

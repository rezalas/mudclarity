/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package clarity

import "core:slice"
import "core:strings"

import "../validation"

/*
 Edits to a Document. Strings passed in are cloned with `allocator`, which
 must be the allocator the document was loaded with (an arena in practice).
*/

// Record a decision (REVIEW_ACCEPTED or REVIEW_FLAGGED) on a finding,
// replacing any earlier decision on the same key. `file_sha256` is the
// current hash of the finding's file.
set_review :: proc(doc: ^Document, key: Finding_Key, status, note, file_sha256, date: string, allocator := context.allocator) {
	assert(slice.contains(REVIEW_STATUSES[:], status))
	review := Review {
		file         = strings.clone(key.file, allocator),
		check        = strings.clone(key.check, allocator),
		vnum         = key.vnum,
		related_vnum = key.related_vnum,
		status       = strings.clone(status, allocator),
		note         = strings.clone(note, allocator),
		file_sha256  = strings.clone(file_sha256, allocator),
		date         = strings.clone(date, allocator),
	}
	for &existing in doc.reviews {
		if existing.file == key.file && existing.check == key.check && existing.vnum == key.vnum && existing.related_vnum == key.related_vnum {
			existing = review
			return
		}
	}
	append(&doc.reviews, review)
}

// Remove the decision on a finding, so it is Open again. Returns false if
// there was none.
remove_review :: proc(doc: ^Document, key: Finding_Key) -> bool {
	for review, i in doc.reviews {
		if review.file == key.file && review.check == key.check && review.vnum == key.vnum && review.related_vnum == key.related_vnum {
			ordered_remove(&doc.reviews, i)
			return true
		}
	}
	return false
}

// Add an open issue and return its id. Issues are never deleted (they are
// resolved instead), so ids are never reused.
add_issue :: proc(doc: ^Document, file, kind: string, vnum: int, title, date: string, allocator := context.allocator) -> int {
	assert(slice.contains(KINDS[:], kind))
	id := 1
	for issue in doc.issues {
		id = max(id, issue.id + 1)
	}
	append(
		&doc.issues,
		Issue {
			id = id,
			file = strings.clone(file, allocator),
			kind = strings.clone(kind, allocator),
			vnum = vnum,
			status = strings.clone(ISSUE_OPEN, allocator),
			title = strings.clone(title, allocator),
			note = "",
			date = strings.clone(date, allocator),
		},
	)
	return id
}

// Change an issue's status. Returns false if there is no issue with that id.
set_issue_status :: proc(doc: ^Document, id: int, status: string, allocator := context.allocator) -> bool {
	assert(slice.contains(ISSUE_STATUSES[:], status))
	for &issue in doc.issues {
		if issue.id == id {
			issue.status = strings.clone(status, allocator)
			return true
		}
	}
	return false
}

// Attach a note to an area (KIND_AREA, vnum 0) or a record.
add_note :: proc(doc: ^Document, file, kind: string, vnum: int, text, date: string, allocator := context.allocator) {
	assert(slice.contains(KINDS[:], kind))
	append(
		&doc.notes,
		Note{file = strings.clone(file, allocator), kind = strings.clone(kind, allocator), vnum = vnum, text = strings.clone(text, allocator), date = strings.clone(date, allocator)},
	)
}

// Record the current state of the world: the covered files with their
// hashes and counts, and a snapshot of the findings. Reviews, issues and
// notes are kept. `files[i]` describes the area `diagnostics` call area i.
refresh :: proc(doc: ^Document, files: []File_Entry, diagnostics: []validation.Diagnostic, allocator := context.allocator) {
	clear(&doc.files)
	names := make([]string, len(files), context.temp_allocator)
	for file, i in files {
		entry := file
		entry.name = strings.clone(file.name, allocator)
		entry.sha256 = strings.clone(file.sha256, allocator)
		append(&doc.files, entry)
		names[i] = entry.name
	}
	clear(&doc.snapshot)
	for d in diagnostics {
		append(
			&doc.snapshot,
			Snapshot_Entry {
				file = strings.clone(names[d.area], allocator), // Own copy: document_destroy frees each string once
				check = strings.clone(check_name_of(d.check), allocator),
				severity = strings.clone(SEVERITY_NAMES[d.severity], allocator),
				vnum = d.vnum,
				related_vnum = d.related_vnum,
				line = d.line,
				message = strings.clone(d.message, allocator),
			},
		)
	}
	sort_document(doc)
}

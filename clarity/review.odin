/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package clarity

import "core:fmt"
import "core:strconv"
import "core:strings"

import "../validation"

// Identifies a finding across validation runs and file edits. Line numbers
// are left out on purpose: they change whenever a file is edited.
Finding_Key :: struct {
	file:         string,
	check:        string,
	vnum:         int,
	related_vnum: int,
}

key_less :: proc(a, b: Finding_Key) -> bool {
	if a.file != b.file do return a.file < b.file
	if a.check != b.check do return a.check < b.check
	if a.vnum != b.vnum do return a.vnum < b.vnum
	return a.related_vnum < b.related_vnum
}

// The key of a validator finding. `area_names[d.area]` is the finding's file.
key_of :: proc(d: validation.Diagnostic, area_names: []string) -> Finding_Key {
	return Finding_Key{area_names[d.area], check_name_of(d.check), d.vnum, d.related_vnum}
}

// The ID users type to refer to a finding: "file:check:vnum:related_vnum".
// Allocated with `allocator`.
finding_id :: proc(key: Finding_Key, allocator := context.allocator) -> string {
	return fmt.aprintf("%s:%s:%d:%d", key.file, key.check, key.vnum, key.related_vnum, allocator = allocator)
}

// Parse a finding ID. The result's strings point into `id`.
parse_finding_id :: proc(id: string) -> (key: Finding_Key, ok: bool) {
	// Split from the right: the file name is everything before the last three fields.
	parts: [3]string
	rest := id
	for i := 2; i >= 0; i -= 1 {
		colon := strings.last_index_byte(rest, ':')
		if colon < 0 {
			return {}, false
		}
		parts[i] = rest[colon + 1:]
		rest = rest[:colon]
	}
	if rest == "" || parts[0] == "" {
		return {}, false
	}
	key.file = rest
	key.check = parts[0]
	key.vnum = strconv.parse_int(parts[1], 10) or_return
	key.related_vnum = strconv.parse_int(parts[2], 10) or_return
	return key, true
}

// How a current finding stands against the review file.
State :: enum u8 {
	Open,         // Not reviewed
	Accepted,     // Accepted as intended, file unchanged since
	Flagged,      // Confirmed problem to fix, file unchanged since
	Needs_Review, // Reviewed, but the file has changed since
}

Reviewed_Finding :: struct {
	diagnostic: validation.Diagnostic,
	key:        Finding_Key,
	state:      State,
	review:     int,  // Index into doc.reviews, or -1
	is_new:     bool, // Not in the last saved snapshot
}

// The result of comparing a validation run with a review file.
Review_Result :: struct {
	findings:       []Reviewed_Finding, // In diagnostic order
	resolved:       []int,              // doc.reviews whose finding no longer exists
	unknown_checks: []int,              // doc.reviews naming a check this version doesn't have
	fixed:          []int,              // doc.snapshot entries no longer found
	new_count:      int,
	changed_files:  []string,           // Files whose hash differs from the last save
	added_files:    []string,           // Files not in the last save
	removed_files:  []string,           // Files in the last save but not loaded now
	state_counts:   [State]int,
}

/*
 Compare a validation run with a review file.

 `area_names[i]` and `area_hashes[i]` are the name and current SHA-256 of
 the area `diagnostics` call area i. A review applies to every finding with
 its key. A reviewed finding whose file's hash differs from the hash
 recorded with the review becomes Needs_Review. Findings are only "new" if
 the document has been saved before (it has file entries).

 Slices in the result are allocated with `allocator` and point into `doc`,
 `area_names` and `diagnostics`.
*/
merge :: proc(
	doc: ^Document,
	area_names: []string,
	area_hashes: []string,
	diagnostics: []validation.Diagnostic,
	allocator := context.allocator,
) -> Review_Result {
	assert(len(area_names) == len(area_hashes))
	current_hash := make(map[string]string, context.temp_allocator)
	for name, i in area_names {
		current_hash[name] = area_hashes[i]
	}
	review_index := make(map[Finding_Key]int, context.temp_allocator)
	for review, i in doc.reviews {
		review_index[Finding_Key{review.file, review.check, review.vnum, review.related_vnum}] = i
	}
	snapshot_keys := make(map[Finding_Key]bool, context.temp_allocator)
	for entry in doc.snapshot {
		snapshot_keys[Finding_Key{entry.file, entry.check, entry.vnum, entry.related_vnum}] = true
	}
	has_snapshot := len(doc.files) > 0

	result: Review_Result
	findings := make([]Reviewed_Finding, len(diagnostics), allocator)
	current_keys := make(map[Finding_Key]bool, context.temp_allocator)
	for d, i in diagnostics {
		key := key_of(d, area_names)
		current_keys[key] = true
		f := Reviewed_Finding {
			diagnostic = d,
			key        = key,
			review     = -1,
			is_new     = has_snapshot && !snapshot_keys[key],
		}
		if r, reviewed := review_index[key]; reviewed {
			review := doc.reviews[r]
			f.review = r
			switch {
			case review.file_sha256 != current_hash[key.file]:
				f.state = .Needs_Review
			case review.status == REVIEW_ACCEPTED:
				f.state = .Accepted
			case:
				f.state = .Flagged
			}
		}
		if f.is_new {
			result.new_count += 1
		}
		result.state_counts[f.state] += 1
		findings[i] = f
	}
	result.findings = findings

	resolved := make([dynamic]int, allocator)
	unknown := make([dynamic]int, allocator)
	for review, i in doc.reviews {
		if _, known := check_from_name(review.check); !known {
			append(&unknown, i)
		} else if !current_keys[Finding_Key{review.file, review.check, review.vnum, review.related_vnum}] {
			append(&resolved, i)
		}
	}
	result.resolved = resolved[:]
	result.unknown_checks = unknown[:]

	fixed := make([dynamic]int, allocator)
	for entry, i in doc.snapshot {
		if !current_keys[Finding_Key{entry.file, entry.check, entry.vnum, entry.related_vnum}] {
			append(&fixed, i)
		}
	}
	result.fixed = fixed[:]

	saved := make(map[string]string, context.temp_allocator)
	for file in doc.files {
		saved[file.name] = file.sha256
	}
	changed := make([dynamic]string, allocator)
	added := make([dynamic]string, allocator)
	for name, i in area_names {
		if old, was_saved := saved[name]; !was_saved {
			append(&added, name)
		} else if old != area_hashes[i] {
			append(&changed, name)
		}
	}
	removed := make([dynamic]string, allocator)
	for file in doc.files {
		if file.name not_in current_hash {
			append(&removed, file.name)
		}
	}
	result.changed_files = changed[:]
	result.added_files = added[:]
	result.removed_files = removed[:]
	return result
}

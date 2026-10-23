/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package clarity

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

import "../validation"

// Largest .clarity file accepted.
MAX_DOCUMENT_SIZE :: 10 * 1024 * 1024

Load_Error_Kind :: enum {
	Io_Error,
	File_Too_Large,
	Bad_Json,
	Wrong_Format,
	Unsupported_Version,
	Bad_Field,
}

// Why a .clarity file couldn't be loaded or saved. `detail` is allocated
// with the temp allocator.
Load_Failure :: struct {
	kind:   Load_Error_Kind,
	detail: string,
}

// nil means success.
Load_Error :: union {
	Load_Failure,
}

@(private)
fail :: proc(kind: Load_Error_Kind, format: string, args: ..any) -> Load_Error {
	return Load_Failure{kind = kind, detail = fmt.tprintf(format, ..args)}
}

// Load and check the .clarity file at `path`. Everything in the result is
// allocated with `allocator`; use an arena or document_destroy.
// A file with a newer version than this program understands is refused, so
// it is never overwritten with less information.
load_document :: proc(path: string, allocator := context.allocator) -> (doc: Document, err: Load_Error) {
	f, open_err := os.open(path)
	if open_err != nil {
		return {}, fail(.Io_Error, "could not open %s", path)
	}
	defer os.close(f)
	size, size_err := os.file_size(f)
	if size_err != nil {
		return {}, fail(.Io_Error, "could not read the size of %s", path)
	}
	if size > MAX_DOCUMENT_SIZE {
		return {}, fail(.File_Too_Large, "%s is larger than %d bytes", path, MAX_DOCUMENT_SIZE)
	}
	data, read_err := os.read_entire_file_from_file(f, context.temp_allocator)
	if read_err != nil {
		return {}, fail(.Io_Error, "could not read %s", path)
	}
	return parse_document(data, allocator)
}

// Parse and check a .clarity document held in memory.
parse_document :: proc(data: []u8, allocator := context.allocator) -> (doc: Document, err: Load_Error) {
	if len(data) > MAX_DOCUMENT_SIZE {
		return {}, fail(.File_Too_Large, "document is larger than %d bytes", MAX_DOCUMENT_SIZE)
	}
	if json_err := json.unmarshal(data, &doc, json.DEFAULT_SPECIFICATION, allocator); json_err != nil {
		document_destroy(&doc, allocator)
		return {}, fail(.Bad_Json, "not valid .clarity JSON: %v", json_err)
	}
	if check_err := check_document(&doc); check_err != nil {
		document_destroy(&doc, allocator)
		return {}, check_err
	}
	return doc, nil
}

// Check every field of a loaded document.
@(private)
check_document :: proc(doc: ^Document) -> Load_Error {
	if doc.format != FORMAT_NAME {
		return fail(.Wrong_Format, "not a %s file (format is %q)", FORMAT_NAME, doc.format)
	}
	if doc.version > FORMAT_VERSION {
		return fail(.Unsupported_Version, "file is version %d; this program understands up to %d", doc.version, FORMAT_VERSION)
	}
	if doc.version < 1 {
		return fail(.Bad_Field, "version %d is not valid", doc.version)
	}
	check_name(doc.area_list, "area_list") or_return
	for file in doc.files {
		check_name(file.name, "files.name") or_return
	}
	for review in doc.reviews {
		check_name(review.file, "reviews.file") or_return
		check_one_of(review.status, REVIEW_STATUSES[:], "reviews.status") or_return
	}
	seen_ids := make(map[int]bool, context.temp_allocator)
	for issue in doc.issues {
		check_name(issue.file, "issues.file") or_return
		check_one_of(issue.kind, KINDS[:], "issues.kind") or_return
		check_one_of(issue.status, ISSUE_STATUSES[:], "issues.status") or_return
		if issue.id < 1 || issue.id in seen_ids {
			return fail(.Bad_Field, "issue id %d is not unique and positive", issue.id)
		}
		seen_ids[issue.id] = true
	}
	for note in doc.notes {
		check_name(note.file, "notes.file") or_return
		check_one_of(note.kind, KINDS[:], "notes.kind") or_return
	}
	for entry in doc.snapshot {
		check_name(entry.file, "snapshot.file") or_return
		check_one_of(entry.severity, SEVERITY_NAMES[:], "snapshot.severity") or_return
	}
	return nil
}

// Names are plain file names in the .clarity file's directory, the same
// rule area.lst entries follow, so a .clarity file can't point elsewhere.
@(private)
check_name :: proc(name, field: string) -> Load_Error {
	if name == "" || strings.contains_any(name, "/\\") || strings.contains(name, "..") || strings.contains_rune(name, 0) {
		return fail(.Bad_Field, "%s %q must be a plain file name", field, name)
	}
	return nil
}

@(private)
check_one_of :: proc(value: string, allowed: []string, field: string) -> Load_Error {
	if !slice.contains(allowed, value) {
		return fail(.Bad_Field, "%s %q must be one of %v", field, value, allowed)
	}
	return nil
}

// Write `doc` to `path` as pretty-printed JSON with every list sorted, so
// saving an unchanged document reproduces the same bytes. The file is
// written to a temporary name first and renamed into place, so a failed
// save leaves any existing file intact.
save_document :: proc(path: string, doc: ^Document) -> Load_Error {
	sort_document(doc)
	data, marshal_err := json.marshal(doc^, {pretty = true, use_spaces = true, spaces = 2}, context.temp_allocator)
	if marshal_err != nil {
		return fail(.Io_Error, "could not encode document: %v", marshal_err)
	}
	temp_path := strings.concatenate({path, ".tmp"}, context.temp_allocator)
	contents := strings.concatenate({string(data), "\n"}, context.temp_allocator)
	if write_err := os.write_entire_file(temp_path, contents); write_err != nil {
		_ = os.remove(temp_path)
		return fail(.Io_Error, "could not write %s", temp_path)
	}
	if rename_err := os.rename(temp_path, path); rename_err != nil {
		_ = os.remove(temp_path)
		return fail(.Io_Error, "could not replace %s", path)
	}
	return nil
}

// Sort every list into its on-disk order.
sort_document :: proc(doc: ^Document) {
	slice.sort_by(doc.files[:], proc(a, b: File_Entry) -> bool {return a.name < b.name})
	slice.sort_by(doc.reviews[:], proc(a, b: Review) -> bool {
		return key_less(Finding_Key{a.file, a.check, a.vnum, a.related_vnum}, Finding_Key{b.file, b.check, b.vnum, b.related_vnum})
	})
	slice.sort_by(doc.issues[:], proc(a, b: Issue) -> bool {return a.id < b.id})
	slice.sort_by(doc.notes[:], proc(a, b: Note) -> bool {
		if a.file != b.file do return a.file < b.file
		if a.kind != b.kind do return a.kind < b.kind
		if a.vnum != b.vnum do return a.vnum < b.vnum
		if a.date != b.date do return a.date < b.date
		return a.text < b.text
	})
	slice.sort_by(doc.snapshot[:], proc(a, b: Snapshot_Entry) -> bool {
		if a.file != b.file do return a.file < b.file
		if a.line != b.line do return a.line < b.line
		if a.check != b.check do return a.check < b.check
		if a.vnum != b.vnum do return a.vnum < b.vnum
		return a.related_vnum < b.related_vnum
	})
}

// Free a document loaded with `allocator`. Not needed when an arena was used.
document_destroy :: proc(doc: ^Document, allocator := context.allocator) {
	context.allocator = allocator
	delete(doc.format)
	delete(doc.area_list)
	for f in doc.files {
		delete(f.name)
		delete(f.sha256)
	}
	delete(doc.files)
	for r in doc.reviews {
		delete(r.file)
		delete(r.check)
		delete(r.status)
		delete(r.note)
		delete(r.file_sha256)
		delete(r.date)
	}
	delete(doc.reviews)
	for i in doc.issues {
		delete(i.file)
		delete(i.kind)
		delete(i.status)
		delete(i.title)
		delete(i.note)
		delete(i.date)
	}
	delete(doc.issues)
	for n in doc.notes {
		delete(n.file)
		delete(n.kind)
		delete(n.text)
		delete(n.date)
	}
	delete(doc.notes)
	for s in doc.snapshot {
		delete(s.file)
		delete(s.check)
		delete(s.severity)
		delete(s.message)
	}
	delete(doc.snapshot)
	doc^ = {}
}

// Name of a validation check as stored in the file.
check_name_of :: proc(check: validation.Check) -> string {
	name, _ := fmt.enum_value_to_string(check)
	return name
}

// The validation check with the given name, if this version has it.
check_from_name :: proc(name: string) -> (check: validation.Check, ok: bool) {
	for c in validation.Check {
		if check_name_of(c) == name {
			return c, true
		}
	}
	return {}, false
}

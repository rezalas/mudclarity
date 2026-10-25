/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package app

import "core:fmt"
import "core:path/filepath"
import "core:slice"
import "core:strings"

import "../components"
import "../models"

/*
 How areas are named and ordered in the area picker: by name, ignoring
 case and a leading article, as library catalogues file titles ("The
 Dragon Tower" under D). Ties go by file name. Areas keep their positions
 everywhere else; only the picker uses this order.
*/

// Leading words ignored when sorting (followed by a space). Only "The"
// occurs in the Riftshadow world today.
SORT_ARTICLES :: [?]string{"the", "a", "an"}

// What an area is sorted by: its display name in lower case, without a
// leading article. Allocated with the temp allocator.
area_sort_key :: proc(name: string) -> string {
	key := strings.to_lower(strings.trim_space(components.display_text(name)), context.temp_allocator)
	articles := SORT_ARTICLES
	for article in articles {
		if len(key) > len(article) + 1 && strings.has_prefix(key, article) && key[len(article)] == ' ' {
			return strings.trim_left_space(key[len(article) + 1:])
		}
	}
	return key
}

// The picker's entry for an area: "Name (file)". `file` is the area's name
// in area.lst, or a path for loose files, of which only the base is shown.
// An area without a name is shown, and sorted, by its file name.
area_label :: proc(name, file: string, allocator := context.allocator) -> string {
	shown := strings.trim_space(components.display_text(name, allocator = context.temp_allocator))
	if shown == "" {
		return fmt.aprintf("%s (no name)", filepath.base(file), allocator = allocator)
	}
	return fmt.aprintf("%s (%s)", shown, filepath.base(file), allocator = allocator)
}

// Area indexes in picker order (see the file comment). `names[i]` is how
// area.lst names areas[i]. Allocated with `allocator`.
area_picker_order :: proc(areas: []^models.Area, names: []string, allocator := context.allocator) -> []int {
	Entry :: struct {
		key:   string,
		file:  string,
		index: int,
	}
	entries := make([]Entry, len(areas), context.temp_allocator)
	for area, i in areas {
		file := strings.to_lower(filepath.base(names[i]), context.temp_allocator)
		key := area_sort_key(area.header.name)
		entries[i] = {key if key != "" else file, file, i}
	}
	slice.stable_sort_by(entries, proc(a, b: Entry) -> bool {
		if a.key != b.key {
			return a.key < b.key
		}
		return a.file < b.file
	})
	order := make([]int, len(areas), allocator)
	for e, i in entries {
		order[i] = e.index
	}
	return order
}

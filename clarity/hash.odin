/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package clarity

import "core:crypto/hash"
import "core:encoding/hex"

import "../formats"

// Lowercase hex SHA-256 of `data`, allocated with `allocator`.
sha256_hex :: proc(data: []u8, allocator := context.allocator) -> string {
	digest: [32]u8
	hash.hash_bytes_to_buffer(.SHA256, data, digest[:])
	encoded := hex.encode(digest[:], allocator)
	return string(encoded)
}

// A file entry for a loaded area. `name` is how area.lst names the file.
// Strings are allocated with `allocator`.
file_entry_for :: proc(name: string, loaded: ^formats.Loaded_Area, allocator := context.allocator) -> File_Entry {
	return File_Entry {
		name = name,
		sha256 = sha256_hex(loaded.data, allocator),
		size = len(loaded.data),
		rooms = len(loaded.area.rooms),
		mobiles = len(loaded.area.mobiles),
		objects = len(loaded.area.objects),
	}
}

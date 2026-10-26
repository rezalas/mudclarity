/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package settings

import "../clarity"
import "../validation"

/*
 The user's settings for the app: how it looks and which findings it
 shows. Plain values, so the GUI can keep them in its state and compare
 them. Reading and writing the settings file is in io.odin; this package
 has no GUI code, so it is tested like `clarity`.
*/

Theme_Choice :: enum u8 {
	System, // Follow the OS's light or dark preference
	Light,
	Dark,
}

Text_Size :: enum u8 {
	Small,
	Default,
	Large,
	Larger,
	Largest,
}

// How much each text size scales the theme's fonts and spacing.
TEXT_SCALES := [Text_Size]f32 {
	.Small   = 0.9,
	.Default = 1,
	.Large   = 1.25,
	.Larger  = 1.5,
	.Largest = 2,
}

Palette_Choice :: enum u8 {
	Standard,
	Colour_Blind, // Colours that stay apart with common colour blindness
}

// Which findings the screens show.
Filters :: struct {
	severities: bit_set[validation.Severity],
	states:     bit_set[clarity.State],
}

// Everything but accepted findings: accepted means "intended", so they
// are hidden until asked for.
DEFAULT_FILTERS :: Filters {
	severities = {.Error, .Warning, .Info},
	states     = {.Open, .Flagged, .Needs_Review},
}

Settings :: struct {
	theme:     Theme_Choice,
	text_size: Text_Size,
	palette:   Palette_Choice,
	filters:   Filters,
}

DEFAULTS :: Settings {
	theme     = .System,
	text_size = .Default,
	palette   = .Standard,
	filters   = DEFAULT_FILTERS,
}

// How each value is written in the file. Names, not numbers, so the file
// reads well and survives reordering the enums.
THEME_NAMES := [Theme_Choice]string {
	.System = "system",
	.Light  = "light",
	.Dark   = "dark",
}

TEXT_SIZE_NAMES := [Text_Size]string {
	.Small   = "small",
	.Default = "default",
	.Large   = "large",
	.Larger  = "larger",
	.Largest = "largest",
}

PALETTE_NAMES := [Palette_Choice]string {
	.Standard     = "standard",
	.Colour_Blind = "colour_blind",
}

SEVERITY_NAMES := [validation.Severity]string {
	.Error   = "error",
	.Warning = "warning",
	.Info    = "info",
}

STATE_NAMES := [clarity.State]string {
	.Open         = "open",
	.Accepted     = "accepted",
	.Flagged      = "flagged",
	.Needs_Review = "needs_review",
}

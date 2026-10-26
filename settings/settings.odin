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

// Text size, as a percentage that scales the theme's fonts and spacing:
// MIN_TEXT_SCALE to MAX_TEXT_SCALE in steps of TEXT_SCALE_STEP.
MIN_TEXT_SCALE :: 75
MAX_TEXT_SCALE :: 200
TEXT_SCALE_STEP :: 5
DEFAULT_TEXT_SCALE :: 100

// `percent` brought into range and onto a step.
clamp_text_scale :: proc(percent: int) -> int {
	p := clamp(percent, MIN_TEXT_SCALE, MAX_TEXT_SCALE)
	return (p + TEXT_SCALE_STEP / 2) / TEXT_SCALE_STEP * TEXT_SCALE_STEP
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
	theme:      Theme_Choice,
	text_scale: int, // Percent; see clamp_text_scale
	palette:    Palette_Choice,
	filters:   Filters,
}

DEFAULTS :: Settings {
	theme      = .System,
	text_scale = DEFAULT_TEXT_SCALE,
	palette    = .Standard,
	filters    = DEFAULT_FILTERS,
}

// How each value is written in the file. Names, not numbers, so the file
// reads well and survives reordering the enums.
THEME_NAMES := [Theme_Choice]string {
	.System = "system",
	.Light  = "light",
	.Dark   = "dark",
}

// The named text sizes the first settings files used ("text_size"),
// read as the percentages they stood for.
LEGACY_TEXT_SIZES := [?]struct {
	name:    string,
	percent: int,
}{{"small", 90}, {"default", 100}, {"large", 125}, {"larger", 150}, {"largest", 200}}

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

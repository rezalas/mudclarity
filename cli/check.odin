/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package cli

import "core:fmt"
import "core:io"
import "core:path/filepath"
import "core:strings"

import "../clarity"
import "../validation"
import "../workspace"

SEVERITY_NAMES := [validation.Severity]string {
	.Error   = "error",
	.Warning = "warning",
	.Info    = "info",
}

STATE_TAGS := [clarity.State]string {
	.Open         = "",
	.Accepted     = " [accepted]",
	.Flagged      = " [flagged]",
	.Needs_Review = " [needs review: file changed]",
}

// `check`: print every finding (accepted ones only with --all), then a
// summary. Fails if a file didn't parse or an unaccepted error was found.
run_check :: proc(c: ^Call) -> int {
	ws := c.ws
	out := c.output.out
	result := workspace.merge(ws, context.temp_allocator)

	failing := len(ws.set.failures) > 0
	for f in result.findings {
		d := f.diagnostic
		if d.severity == .Error && f.state != .Accepted {
			failing = true
		}
		if f.state == .Accepted && !c.show_all {
			continue
		}
		vnum := fmt.tprintf(" [#%d]", d.vnum) if d.vnum != 0 else ""
		new_tag := " (new)" if f.is_new else ""
		fmt.wprintfln(
			out,
			"%s:%d: %s %v%s: %s%s%s {{%s}}",
			ws.names[d.area],
			d.line,
			SEVERITY_NAMES[d.severity],
			d.check,
			vnum,
			d.message,
			STATE_TAGS[f.state],
			new_tag,
			clarity.finding_id(f.key, context.temp_allocator),
		)
	}
	print_counts(out, ws)
	print_review(out, ws, result)
	return EXIT_FAILED if failing else EXIT_OK
}

// Totals, then the number of findings of each check by severity.
@(private = "file")
print_counts :: proc(out: io.Writer, ws: ^workspace.Workspace) {
	rooms := 0
	for area in ws.areas {
		rooms += len(area.rooms)
	}
	severities := validation.count_by_severity(ws.diagnostics)
	fmt.wprintfln(out, "\n%d areas, %d rooms: %d errors, %d warnings, %d info", len(ws.areas), rooms, severities[.Error], severities[.Warning], severities[.Info])

	by_check: [validation.Check][validation.Severity]int
	for d in ws.diagnostics {
		by_check[d.check][d.severity] += 1
	}
	for counts, check in by_check {
		total := counts[.Error] + counts[.Warning] + counts[.Info]
		if total == 0 {
			continue
		}
		parts := make([dynamic]string, context.temp_allocator)
		for count, severity in counts {
			if count > 0 {
				append(&parts, fmt.tprintf("%d %s", count, SEVERITY_NAMES[severity]))
			}
		}
		total_text := strings.right_justify(fmt.tprintf("%d", total), 5, " ", context.temp_allocator)
		fmt.wprintfln(out, "  %-24v %s  (%s)", check, total_text, strings.join(parts[:], ", ", context.temp_allocator))
	}
}

// How the findings stand against area.clarity, and what changed since the
// last save. Nothing for loose files.
@(private = "file")
print_review :: proc(out: io.Writer, ws: ^workspace.Workspace, result: clarity.Review_Result) {
	if ws.clarity_path == "" {
		return
	}
	doc := &ws.document
	fmt.wprintfln(
		out,
		"\nreview (%s): %d open, %d flagged, %d accepted%s, %d need review",
		filepath.base(ws.clarity_path),
		result.state_counts[.Open],
		result.state_counts[.Flagged],
		result.state_counts[.Accepted],
		"" if result.state_counts[.Accepted] == 0 else " (hidden; --all shows them)",
		result.state_counts[.Needs_Review],
	)
	if len(doc.files) > 0 {
		fmt.wprintfln(out, "  since last save: %d new, %d fixed", result.new_count, len(result.fixed))
		for i in result.fixed {
			entry := doc.snapshot[i]
			fmt.wprintfln(out, "    fixed: %s:%d %s [#%d]", entry.file, entry.line, entry.check, entry.vnum)
		}
		print_names(out, "  changed files: ", result.changed_files)
		print_names(out, "  new files: ", result.added_files)
		print_names(out, "  files no longer listed: ", result.removed_files)
	} else {
		fmt.wprintln(out, "  not saved yet; run `mudclarity save` to record a baseline")
	}
	for i in result.resolved {
		r := doc.reviews[i]
		fmt.wprintfln(out, "  resolved (finding gone): {{%s:%s:%d:%d}} %s", r.file, r.check, r.vnum, r.related_vnum, r.status)
	}
	for i in result.unknown_checks {
		r := doc.reviews[i]
		fmt.wprintfln(out, "  review names an unknown check: {{%s:%s:%d:%d}}", r.file, r.check, r.vnum, r.related_vnum)
	}
	open_issues := 0
	for issue in doc.issues {
		if issue.status != clarity.ISSUE_RESOLVED {
			open_issues += 1
		}
	}
	if open_issues > 0 || len(doc.notes) > 0 {
		fmt.wprintfln(out, "  %d open issues, %d notes", open_issues, len(doc.notes))
	}
}

@(private = "file")
print_names :: proc(out: io.Writer, label: string, names: []string) {
	if len(names) > 0 {
		fmt.wprintfln(out, "%s%s", label, strings.join(names, ", ", context.temp_allocator))
	}
}

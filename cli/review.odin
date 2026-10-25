/*
 * Author: Paul McDowell
 * Copyright: 2026
 * License: MIT
 */
package cli

import "core:strings"

import "../clarity"
import "../workspace"

// `save`: record the current files, hashes and findings in area.clarity.
run_save :: proc(c: ^Call) -> int {
	if code := check_edit(c, workspace.record_run(c.ws)); code != EXIT_OK {
		return code
	}
	return save_and_report(c, "saved %s: %d files, %d findings", c.ws.clarity_path, len(c.ws.document.files), len(c.ws.document.snapshot))
}

// `accept` and `flag`: record a decision on a current finding.
run_decide :: proc(c: ^Call) -> int {
	id := c.args[0]
	key, key_err := workspace.current_finding_key(c.ws, id)
	if failure, ok := key_err.(workspace.Edit_Failure); ok && failure.kind == .Unknown_Finding {
		return usage_error(c, "%s; run check to see the ids", workspace.error_message(key_err, context.temp_allocator))
	}
	if code := check_edit(c, key_err); code != EXIT_OK {
		return code
	}
	status := clarity.REVIEW_ACCEPTED if c.command.name == "accept" else clarity.REVIEW_FLAGGED
	note := strings.join(c.args[1:], " ", context.temp_allocator)
	if code := check_edit(c, workspace.set_review(c.ws, key, status, note, c.today)); code != EXIT_OK {
		return code
	}
	return save_and_report(c, "%s %s", status, id)
}

// `reopen`: remove the decision on a finding. The finding need not still
// exist, so a decision on a fixed finding can be cleared.
run_reopen :: proc(c: ^Call) -> int {
	id := c.args[0]
	key, ok := clarity.parse_finding_id(id)
	if !ok {
		return usage_error(c, "no decision recorded for %s", id)
	}
	if code := check_edit(c, workspace.remove_review(c.ws, key, id)); code != EXIT_OK {
		return code
	}
	return save_and_report(c, "reopened %s", id)
}

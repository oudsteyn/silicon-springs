class_name VisualParityReporter
extends RefCounted

func generate_markdown(result: Dictionary) -> String:
	var passed := bool(result.get("passed", false))
	var lines: Array[String] = []
	lines.append("# Visual Parity Report")
	lines.append("")
	lines.append("Status: %s" % ("PASS" if passed else "FAIL"))
	lines.append("Mode: %s" % str(result.get("mode", "verify")))
	lines.append("Profiles checked: %d" % int(result.get("profile_count", 0)))
	lines.append("Quality score: %.2f" % float(result.get("quality_score", 0.0)))
	lines.append("Quality threshold: %.2f" % float(result.get("quality_score_threshold", 0.0)))

	var mismatches = result.get("mismatches", [])
	if not (mismatches is Array):
		mismatches = []
	lines.append("Mismatches: %d" % mismatches.size())
	if mismatches.size() > 0:
		lines.append("")
		lines.append("## Signature Mismatches")
		for mismatch in mismatches:
			lines.append("- %s" % str(mismatch.get("profile_id", "unknown_profile")))

	var acceptance = result.get("acceptance", {})
	if not (acceptance is Dictionary):
		acceptance = {}
	if not acceptance.is_empty():
		lines.append("")
		lines.append("## Acceptance By Phase")
		var by_phase = acceptance.get("by_phase", {})
		if not (by_phase is Dictionary):
			by_phase = {}
		for phase in ["day", "dusk", "night"]:
			var phase_result = by_phase.get(phase, {})
			if not (phase_result is Dictionary):
				phase_result = {}
			var phase_passed := bool(phase_result.get("passed", false))
			lines.append("- %s: %s" % [phase, "PASS" if phase_passed else "FAIL"])
			var issues = phase_result.get("issues", [])
			if not (issues is Array):
				issues = []
			for issue in issues:
				lines.append("  - %s" % str(issue))

	var frame_gate = result.get("frame_gate", {})
	if not (frame_gate is Dictionary):
		frame_gate = {}
	if not frame_gate.is_empty():
		lines.append("")
		lines.append("## Frame Gate")
		lines.append("Status: %s" % ("PASS" if bool(frame_gate.get("passed", false)) else "FAIL"))
		lines.append("Compared: %d" % int(frame_gate.get("compared", 0)))
		lines.append("Seeded: %d" % int(frame_gate.get("seeded", 0)))
		var frame_mismatches = frame_gate.get("mismatches", [])
		if not (frame_mismatches is Array):
			frame_mismatches = []
		for mismatch in frame_mismatches:
			lines.append("- %s" % str(mismatch.get("profile_id", "unknown_profile")))

	return "\n".join(lines) + "\n"


func save_report(path: String, text: String) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true

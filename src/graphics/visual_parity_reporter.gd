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
	lines.append("Mismatches: %d" % mismatches.size())
	if mismatches.size() > 0:
		lines.append("")
		lines.append("## Signature Mismatches")
		for mismatch in mismatches:
			lines.append("- %s" % str(mismatch.get("profile_id", "unknown_profile")))

	var acceptance: Dictionary = result.get("acceptance", {})
	if not acceptance.is_empty():
		lines.append("")
		lines.append("## Acceptance By Phase")
		var by_phase: Dictionary = acceptance.get("by_phase", {})
		for phase in ["day", "dusk", "night"]:
			var phase_result: Dictionary = by_phase.get(phase, {})
			var phase_passed := bool(phase_result.get("passed", false))
			lines.append("- %s: %s" % [phase, "PASS" if phase_passed else "FAIL"])
			for issue in phase_result.get("issues", []):
				lines.append("  - %s" % str(issue))

	return "\n".join(lines) + "\n"


func save_report(path: String, text: String) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true

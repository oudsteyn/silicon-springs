extends TestBase

const VisualParityReporterScript = preload("res://src/graphics/visual_parity_reporter.gd")

func test_generate_markdown_for_passing_result() -> void:
	var reporter = VisualParityReporterScript.new()
	var report = reporter.generate_markdown({
		"passed": true,
		"mode": "verify",
		"profile_count": 12,
		"mismatches": [],
		"acceptance": {
			"passed": true,
			"by_phase": {
				"day": {"passed": true, "issues": []},
				"dusk": {"passed": true, "issues": []},
				"night": {"passed": true, "issues": []}
			}
		}
	})

	assert_true(report.find("PASS") >= 0)
	assert_true(report.find("Profiles checked: 12") >= 0)
	assert_true(report.find("Mismatches: 0") >= 0)


func test_generate_markdown_includes_phase_and_mismatch_failures() -> void:
	var reporter = VisualParityReporterScript.new()
	var report = reporter.generate_markdown({
		"passed": false,
		"mode": "verify",
		"profile_count": 12,
		"mismatches": [
			{"profile_id": "ULTRA_dusk", "expected": "a", "actual": "b"}
		],
		"acceptance": {
			"passed": false,
			"by_phase": {
				"day": {"passed": true, "issues": []},
				"dusk": {"passed": false, "issues": ["sun_energy out of range"]},
				"night": {"passed": true, "issues": []}
			}
		}
	})

	assert_true(report.find("FAIL") >= 0)
	assert_true(report.find("ULTRA_dusk") >= 0)
	assert_true(report.find("dusk") >= 0)
	assert_true(report.find("sun_energy out of range") >= 0)

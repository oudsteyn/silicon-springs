extends TestBase

const VisualParityMatrixRunnerScript = preload("res://src/graphics/visual_parity_matrix_runner.gd")


class CliStub:
	extends RefCounted

	var calls: Array[Array] = []
	var exits_by_tier: Dictionary = {}

	func run(args: Array, _dependencies: Dictionary = {}) -> Dictionary:
		calls.append(args.duplicate())
		var tier = ""
		for entry in args:
			var arg = str(entry)
			if arg.begins_with("--meta=tier="):
				tier = arg.trim_prefix("--meta=tier=")
				break
		return {"exit_code": int(exits_by_tier.get(tier, 0)), "manifest": {"status": "PASS"}}


func test_run_matrix_executes_all_quality_tiers() -> void:
	var cli = CliStub.new()
	var runner = VisualParityMatrixRunnerScript.new()

	var result = runner.run_matrix("user://baseline", "user://artifacts", cli)

	assert_eq(int(result.get("exit_code", 1)), 0)
	assert_size(cli.calls, 4)

	var tiers: Array[String] = []
	for args in cli.calls:
		for value in args:
			var arg = str(value)
			if arg.begins_with("--meta=tier="):
				tiers.append(arg.trim_prefix("--meta=tier="))
	assert_eq(tiers, ["low", "medium", "high", "ultra"])


func test_run_matrix_fails_when_any_tier_fails() -> void:
	var cli = CliStub.new()
	cli.exits_by_tier["medium"] = 1
	var runner = VisualParityMatrixRunnerScript.new()

	var result = runner.run_matrix("user://baseline", "user://artifacts", cli)

	assert_eq(int(result.get("exit_code", 0)), 1)
	assert_eq(int(result.get("failed_tiers", 0)), 1)

class_name VisualParityMatrixRunner
extends RefCounted

const DEFAULT_TIERS: Array[String] = ["low", "medium", "high", "ultra"]


func run_matrix(
	baseline_root: String,
	artifact_root: String,
	cli,
	tiers: Array[String] = DEFAULT_TIERS
) -> Dictionary:
	var tier_results: Array = []
	var failed_tiers := 0

	for tier in tiers:
		var normalized_tier = str(tier).to_lower()
		var args = [
			"--profile=ci_strict",
			"--baseline-path=%s/%s/visual_parity_baseline.json" % [baseline_root, normalized_tier],
			"--artifact-dir=%s/%s" % [artifact_root, normalized_tier],
			"--frame-baseline-dir=%s/%s/frames" % [baseline_root, normalized_tier],
			"--mode=verify_or_record",
			"--auto-seed=true",
			"--meta=tier=%s" % normalized_tier
		]
		var result: Dictionary = cli.run(args, {})
		var exit_code = int(result.get("exit_code", 1))
		if exit_code != 0:
			failed_tiers += 1
		tier_results.append({
			"tier": normalized_tier,
			"exit_code": exit_code,
			"manifest": result.get("manifest", {})
		})

	return {
		"exit_code": 1 if failed_tiers > 0 else 0,
		"failed_tiers": failed_tiers,
		"total_tiers": tiers.size(),
		"results": tier_results
	}

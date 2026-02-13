extends SceneTree

const VisualParityCliScript = preload("res://src/graphics/visual_parity_cli.gd")

func _init() -> void:
	var cli = VisualParityCliScript.new()
	var result = cli.run(OS.get_cmdline_user_args(), {})
	print(JSON.stringify(result, "\t", true, true))
	quit(int(result.get("exit_code", 1)))

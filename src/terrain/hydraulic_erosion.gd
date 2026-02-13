extends RefCounted
class_name HydraulicErosion


func erode(height: PackedFloat32Array, size: int, iterations: int, seed: int = 12345) -> void:
	if size <= 2 or iterations <= 0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	const MAX_STEPS := 48
	const INERTIA := 0.05
	const CAPACITY := 3.5
	const DEPOSIT := 0.12
	const ERODE := 0.28
	const EVAP := 0.015
	const GRAVITY := 8.0

	for _it in iterations:
		var x = rng.randf_range(1.0, size - 2.0)
		var y = rng.randf_range(1.0, size - 2.0)
		var direction = Vector2.ZERO
		var speed = 1.0
		var water = 1.0
		var sediment = 0.0

		for _s in MAX_STEPS:
			var xi = int(x)
			var yi = int(y)
			var idx = yi * size + xi
			if idx <= size or idx >= height.size() - size - 1:
				break

			var h0 = height[idx]
			var hx = height[idx + 1] - height[idx - 1]
			var hy = height[idx + size] - height[idx - size]
			var grad = Vector2(hx, hy) * 0.5

			direction = direction * INERTIA - grad * (1.0 - INERTIA)
			if direction.length_squared() < 0.000001:
				break
			direction = direction.normalized()

			x += direction.x
			y += direction.y
			if x < 1.0 or x >= size - 2.0 or y < 1.0 or y >= size - 2.0:
				break

			var nidx = int(y) * size + int(x)
			var h1 = height[nidx]
			var delta_h = h1 - h0
			var capacity = max(-delta_h * speed * water * CAPACITY, 0.01)

			if sediment > capacity:
				var deposited = (sediment - capacity) * DEPOSIT
				sediment -= deposited
				height[idx] += deposited
			elif delta_h > 0.0:
				var uphill_deposit = min(delta_h, sediment) * DEPOSIT
				sediment -= uphill_deposit
				height[idx] += uphill_deposit
			else:
				var eroded = min((capacity - sediment) * ERODE, height[idx])
				sediment += eroded
				height[idx] = max(height[idx] - eroded, 0.0)

			speed = sqrt(max(speed * speed + (-delta_h) * GRAVITY, 0.0))
			water *= (1.0 - EVAP)
			if water < 0.02:
				break

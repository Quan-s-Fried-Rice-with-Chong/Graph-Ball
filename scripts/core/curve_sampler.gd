class_name CurveSampler
extends RefCounted

static func sample(formula_source: Dictionary, boundary: PackedVector2Array) -> Array:
	var formula := FormulaModel.normalized(formula_source)
	var bounds := BoundaryClipper.polygon_bounds(boundary)
	var x_range: Vector2 = formula["x_range"]
	var x_min := maxf(minf(x_range.x, x_range.y), bounds.position.x)
	var x_max := minf(maxf(x_range.x, x_range.y), bounds.end.x)
	if x_max - x_min <= 0.0001:
		return []

	var requested_points := ceili((x_max - x_min) / GameConstants.SAMPLE_STEP) + 1
	var point_count := clampi(requested_points, 2, GameConstants.MAX_SAMPLE_POINTS)
	var step := (x_max - x_min) / float(point_count - 1)
	var material := GameConstants.material_for(formula["type"])
	var surface_override: Dictionary = formula.get("surface_override", {})
	for key in surface_override:
		material[key] = surface_override[key]

	var segments: Array = []
	var previous := Vector2.ZERO
	var previous_valid := false
	for index in point_count:
		var x := x_min + step * index
		var y := FunctionEvaluator.evaluate(formula, x)
		var valid := is_finite(y) and absf(y) < 10000.0
		var current := Vector2(x, y)
		if valid and previous_valid:
			for clipped in BoundaryClipper.clip_segment(previous, current, boundary):
				if clipped["a"].distance_squared_to(clipped["b"]) <= 0.0000001:
					continue
				segments.append({
					"formula_id": formula["id"],
					"type": formula["type"],
					"a": clipped["a"],
					"b": clipped["b"],
					"restitution": clampf(float(material.get("restitution", 0.0)), 0.0, 1.0),
					"friction": clampf(float(material.get("friction", 0.0)), 0.0, 1.0),
					"color": material.get("color", Color.WHITE),
					"surface_overridden": not surface_override.is_empty(),
				})
		previous = current
		previous_valid = valid
	return segments

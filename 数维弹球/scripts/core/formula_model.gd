class_name FormulaModel
extends RefCounted

static func create_line(id: String = "line", a: float = 0.0, b: float = 0.0, x_min: float = -8.0, x_max: float = 8.0) -> Dictionary:
	return {
		"id": id,
		"type": GameConstants.MODULE_LINE,
		"parameters": {"a": a, "b": b},
		"x_range": Vector2(x_min, x_max),
		"surface_override": {},
	}

static func create_quadratic(id: String = "quadratic", a: float = 0.0, b: float = 0.0, c: float = 0.0, x_min: float = -8.0, x_max: float = 8.0) -> Dictionary:
	return {
		"id": id,
		"type": GameConstants.MODULE_QUADRATIC,
		"parameters": {"a": a, "b": b, "c": c},
		"x_range": Vector2(x_min, x_max),
		"surface_override": {},
	}

static func normalized(source: Dictionary) -> Dictionary:
	var module_type := String(source.get("type", GameConstants.MODULE_LINE))
	var source_parameters: Dictionary = source.get("parameters", {})
	var parameters := {
		"a": float(source_parameters.get("a", source.get("a", 0.0))),
		"b": float(source_parameters.get("b", source.get("b", 0.0))),
	}
	if module_type == GameConstants.MODULE_QUADRATIC:
		parameters["c"] = float(source_parameters.get("c", source.get("c", 0.0)))
	if module_type == GameConstants.MODULE_SINE:
		parameters["h"] = float(source_parameters.get("h", 0.0))
		parameters["k"] = float(source_parameters.get("k", 0.0))

	var source_range = source.get("x_range", Vector2(source.get("x_min", -8.0), source.get("x_max", 8.0)))
	var x_range := Vector2(-8.0, 8.0)
	if source_range is Vector2:
		x_range = source_range
	elif source_range is Array and source_range.size() >= 2:
		x_range = Vector2(float(source_range[0]), float(source_range[1]))

	return {
		"id": String(source.get("id", module_type)),
		"type": module_type,
		"parameters": parameters,
		"x_range": x_range,
		"surface_override": Dictionary(source.get("surface_override", {})).duplicate(true),
		"ui_source": Dictionary(source.get("ui_source", {})).duplicate(true),
	}

static func display_text(formula: Dictionary) -> String:
	var normalized_formula := normalized(formula)
	var parameters: Dictionary = normalized_formula["parameters"]
	if normalized_formula["type"] == GameConstants.MODULE_SINE:
		return "y = %.2f sin[%.2f(x − %.2f)] %+.2f" % [parameters.a, parameters.b, parameters.h, parameters.k]
	if normalized_formula["type"] == GameConstants.MODULE_LINE:
		return "y = %.2fx %+.2f" % [parameters["a"], parameters["b"]]
	return "y = %.2fx² %+.2fx %+.2f" % [parameters["a"], parameters["b"], parameters["c"]]

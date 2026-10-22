class_name FunctionEvaluator
extends RefCounted

static func evaluate(formula: Dictionary, x: float) -> float:
	var parameters: Dictionary = formula.get("parameters", {})
	var a := float(parameters.get("a", 0.0))
	var b := float(parameters.get("b", 0.0))
	if formula.get("type") == GameConstants.MODULE_SINE:
		return a * sin(b * (x - float(parameters.get("h", 0.0)))) + float(parameters.get("k", 0.0))
	if formula.get("type", GameConstants.MODULE_LINE) == GameConstants.MODULE_QUADRATIC:
		return a * x * x + b * x + float(parameters.get("c", 0.0))
	return a * x + b

static func derivative(formula: Dictionary, x: float) -> float:
	var parameters: Dictionary = formula.get("parameters", {})
	if formula.get("type") == GameConstants.MODULE_SINE:
		return float(parameters.a) * float(parameters.b) * cos(float(parameters.b) * (x - float(parameters.h)))
	if formula.get("type", GameConstants.MODULE_LINE) == GameConstants.MODULE_QUADRATIC:
		return 2.0 * float(parameters.get("a", 0.0)) * x + float(parameters.get("b", 0.0))
	return float(parameters.get("a", 0.0))

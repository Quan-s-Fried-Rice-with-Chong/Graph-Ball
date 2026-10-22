extends RefCounted
## Shared whitelist for UI metadata, validation, and core parameter conversion.

const TEMPLATES = {
	"linear": {
		"title": "一次函数 · 直线", "expression": "y = ax + b",
		"parameters": [
			{"key": "a", "title": "斜率", "min": -1.5, "max": 1.5, "step": 0.01},
			{"key": "b", "title": "上下平移", "min": -4.0, "max": 6.0, "step": 0.01}
		]
	},
	"quadratic": {
		"title": "二次函数 · 抛物线", "expression": "y = a(x − h)² + k",
		"parameters": [
			{"key": "a", "title": "开口大小", "min": -0.2, "max": 0.2, "step": 0.01},
			{"key": "h", "title": "左右平移", "min": -4.0, "max": 4.0, "step": 0.05},
			{"key": "k", "title": "上下平移", "min": -3.0, "max": 5.0, "step": 0.05}
		]
	},
	"sine": {
		"title": "正弦函数 · 波浪", "expression": "y = a sin[b(x − h)] + k",
		"parameters": [
			{"key": "a", "title": "振幅", "min": 0.25, "max": 3.0, "step": 0.05},
			{"key": "b", "title": "频率", "min": 0.2, "max": 1.2, "step": 0.01},
			{"key": "h", "title": "左右平移", "min": -4.0, "max": 4.0, "step": 0.05},
			{"key": "k", "title": "上下平移", "min": -2.0, "max": 4.0, "step": 0.05}
		]
	}
}

static func evaluate(template_id: String, parameters: Dictionary, x: float) -> float:
	match template_id:
		"linear":
			return float(parameters.a) * x + float(parameters.b)
		"quadratic":
			return float(parameters.a) * pow(x - float(parameters.h), 2.0) + float(parameters.k)
		"sine":
			return float(parameters.a) * sin(float(parameters.b) * (x - float(parameters.h))) + float(parameters.k)
	return NAN

static func validate(template_id: String, parameters: Dictionary) -> String:
	if not TEMPLATES.has(template_id):
		return "这个函数模板还不可用。"
	for spec in TEMPLATES[template_id].parameters:
		var key: String = spec.key
		if not parameters.has(key) or not (parameters[key] is float or parameters[key] is int):
			return "请填写参数 %s。" % key
		var value: float = float(parameters[key])
		if not is_finite(value) or value < float(spec.min) or value > float(spec.max):
			return "参数 %s 应在 %s 到 %s 之间。" % [key, spec.min, spec.max]
	return ""

static func to_core(source: Dictionary, index: int = 0) -> Dictionary:
	var template_id: String = source.get("template", "")
	var p: Dictionary = source.get("parameters", {})
	var domain = source.get("domain", Vector2(-8, 8))
	if domain is Array:
		domain = Vector2(float(domain[0]), float(domain[1]))
	var core_parameters := p.duplicate(true)
	if template_id == "quadratic":
		core_parameters = {"a": p.a, "b": -2.0 * float(p.a) * float(p.h), "c": float(p.a) * float(p.h) * float(p.h) + float(p.k)}
	return {"id": "formula_%d" % index, "type": "line" if template_id == "linear" else template_id,
		"parameters": core_parameters, "x_range": domain, "ui_source": source.duplicate(true)}

static func to_core_list(sources: Array) -> Array:
	var result: Array = []
	for i in sources.size():
		result.append(to_core(sources[i], i))
	return result

static func validate_domain(domain: Variant, bounds: Rect2) -> String:
	if not domain is Vector2:
		return "定义域格式无效。"
	if not is_finite(domain.x) or not is_finite(domain.y):
		return "定义域必须是有效数值。"
	if domain.y - domain.x < 0.05:
		return "定义域的上下界至少相差 0.05。"
	if domain.x < bounds.position.x or domain.y > bounds.end.x:
		return "定义域应位于作图区的 x 范围内。"
	return ""

static func formatted(template_id: String, p: Dictionary) -> String:
	match template_id:
		"linear":
			return "y = %sx %s %s" % [_number(p.a), "+" if p.b >= 0 else "−", _number(absf(p.b))]
		"quadratic":
			return "y = %s(x %s %s)² %s %s" % [_number(p.a), "−" if p.h >= 0 else "+", _number(absf(p.h)), "+" if p.k >= 0 else "−", _number(absf(p.k))]
		"sine":
			return "y = %s sin[%s(x %s %s)] %s %s" % [_number(p.a), _number(p.b), "−" if p.h >= 0 else "+", _number(absf(p.h)), "+" if p.k >= 0 else "−", _number(absf(p.k))]
	return ""

static func _number(value: float) -> String:
	var text := ("%.2f" % value).rstrip("0").rstrip(".")
	return "0" if text == "-0" else text.replace("-", "−")

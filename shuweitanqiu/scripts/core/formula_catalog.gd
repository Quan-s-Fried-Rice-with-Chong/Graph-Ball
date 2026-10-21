extends RefCounted
## B-side template metadata. No player text is executed.

const TEMPLATES = {
	"linear": {
		"title": "一次函数 · 直线", "expression": "y = ax + b",
		"description": "a 改变倾斜方向，b 让整条直线上下移动。",
		"parameters": [
			{"key": "a", "title": "斜率", "min": -1.5, "max": 1.5, "step": 0.01},
			{"key": "b", "title": "上下平移", "min": -4.0, "max": 6.0, "step": 0.01}
		]
	},
	"quadratic": {
		"title": "二次函数 · 抛物线", "expression": "y = a(x − h)² + k",
		"description": "a 改变开口，h 和 k 决定顶点的位置。",
		"parameters": [
			{"key": "a", "title": "开口大小", "min": -0.2, "max": 0.2, "step": 0.01},
			{"key": "h", "title": "左右平移", "min": -4.0, "max": 4.0, "step": 0.05},
			{"key": "k", "title": "上下平移", "min": -3.0, "max": 5.0, "step": 0.05}
		]
	},
	"sine": {
		"title": "正弦函数 · 波浪", "expression": "y = a sin[b(x − h)] + k",
		"description": "a 调整波高，b 调整疏密，h 和 k 移动波形。",
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

static func sample(template_id: String, parameters: Dictionary, bounds: Rect2) -> Array:
	var segments: Array = []
	var points := PackedVector2Array()
	if not validate(template_id, parameters).is_empty():
		return segments
	for i in range(901):
		var x: float = lerpf(bounds.position.x, bounds.end.x, float(i) / 900.0)
		var y: float = evaluate(template_id, parameters, x)
		if is_finite(y) and absf(y) < 200.0:
			points.append(Vector2(x, y))
		else:
			if points.size() > 1:
				segments.append(points)
			points = PackedVector2Array()
	if points.size() > 1:
		segments.append(points)
	return segments

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

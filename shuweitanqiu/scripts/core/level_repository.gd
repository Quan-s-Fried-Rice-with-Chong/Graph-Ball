extends RefCounted

static func load_levels() -> Array:
	var text := FileAccess.get_file_as_string("res://data/levels.json")
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary or not parsed.get("levels") is Array:
		push_error("关卡文件无法读取：res://data/levels.json")
		return []
	var levels: Array = []
	for raw in parsed.levels:
		if not raw is Dictionary:
			continue
		var data: Dictionary = raw.duplicate(true)
		var b: Array = data.bounds
		data.bounds = Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))
		data.start = Vector2(float(data.start[0]), float(data.start[1]))
		data.goal = Vector2(float(data.goal[0]), float(data.goal[1]))
		var checkpoints: Array = []
		for point in data.checkpoints:
			checkpoints.append(Vector2(float(point[0]), float(point[1])))
		data.checkpoints = checkpoints
		var obstacles: Array = []
		for rect in data.obstacles:
			obstacles.append(Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3])))
		data.obstacles = obstacles
		levels.append(data)
	return levels

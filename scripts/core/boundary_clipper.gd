class_name BoundaryClipper
extends RefCounted

const EPSILON := 0.000001

static func point_inside(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	return Geometry2D.is_point_in_polygon(point, polygon) or _point_on_boundary(point, polygon)

static func clip_segment(start: Vector2, end: Vector2, polygon: PackedVector2Array) -> Array:
	if polygon.size() < 3 or start.is_equal_approx(end):
		return []

	var intersections: Array[float] = [0.0, 1.0]
	for index in polygon.size():
		var edge_start := polygon[index]
		var edge_end := polygon[(index + 1) % polygon.size()]
		var parameter := _segment_intersection_parameter(start, end, edge_start, edge_end)
		if parameter >= -EPSILON and parameter <= 1.0 + EPSILON:
			_append_unique(intersections, clampf(parameter, 0.0, 1.0))

	intersections.sort()
	var clipped_segments: Array = []
	var direction := end - start
	for index in intersections.size() - 1:
		var from_t := intersections[index]
		var to_t := intersections[index + 1]
		if to_t - from_t <= EPSILON:
			continue
		var midpoint := start + direction * ((from_t + to_t) * 0.5)
		if point_inside(midpoint, polygon):
			clipped_segments.append({
				"a": start + direction * from_t,
				"b": start + direction * to_t,
			})
	return clipped_segments

static func polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var minimum := polygon[0]
	var maximum := polygon[0]
	for point in polygon:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)

static func _segment_intersection_parameter(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	var r := b - a
	var s := d - c
	var denominator := r.cross(s)
	if absf(denominator) <= EPSILON:
		return -2.0
	var offset := c - a
	var t := offset.cross(s) / denominator
	var u := offset.cross(r) / denominator
	if t >= -EPSILON and t <= 1.0 + EPSILON and u >= -EPSILON and u <= 1.0 + EPSILON:
		return t
	return -2.0

static func _append_unique(values: Array[float], value: float) -> void:
	for existing in values:
		if is_equal_approx(existing, value):
			return
	values.append(value)

static func _point_on_boundary(point: Vector2, polygon: PackedVector2Array) -> bool:
	for index in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])
		if closest.distance_squared_to(point) <= EPSILON * EPSILON:
			return true
	return false

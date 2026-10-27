class_name TrackBuilder
extends Node2D

signal tracks_rebuilt(segments: Array)

var track_segments: Array = []
var world_scale := GameConstants.WORLD_SCALE
var preview_rebuild_count := 0
var collider_rebuild_count := 0
var collision_shape_count := 0

func rebuild(formulas: Array, boundary: PackedVector2Array) -> void:
	track_segments = _sample_tracks(formulas, boundary)
	_clear_bodies()
	collider_rebuild_count += 1
	collision_shape_count = 0
	for formula_source in formulas:
		var formula := FormulaModel.normalized(formula_source)
		var segments := _segments_for_formula(formula["id"])
		_build_formula_body(formula, segments)
	_publish_tracks()

func preview(formulas: Array, boundary: PackedVector2Array) -> void:
	track_segments = _sample_tracks(formulas, boundary)
	_clear_bodies()
	preview_rebuild_count += 1
	collision_shape_count = 0
	_publish_tracks()

func clear() -> void:
	track_segments.clear()
	_clear_bodies()
	collision_shape_count = 0
	_publish_tracks()

func _clear_bodies() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func _sample_tracks(formulas: Array, boundary: PackedVector2Array) -> Array:
	var result: Array = []
	for formula_source in formulas:
		result.append_array(CurveSampler.sample(formula_source, boundary))
	return result

func _segments_for_formula(formula_id: String) -> Array:
	var result: Array = []
	for segment in track_segments:
		if segment["formula_id"] == formula_id:
			result.append(segment)
	return result

func _publish_tracks() -> void:
	queue_redraw()
	tracks_rebuilt.emit(track_segments.duplicate(true))

func _build_formula_body(formula: Dictionary, segments: Array) -> void:
	if segments.is_empty():
		return
	var body := StaticBody2D.new()
	body.name = "Track_%s" % formula["id"]
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("formula_id", formula["id"])
	body.set_meta("module_type", formula["type"])
	var material := PhysicsMaterial.new()
	material.bounce = float(segments[0]["restitution"])
	material.friction = float(segments[0]["friction"])
	material.absorbent = false
	material.rough = true
	body.physics_material_override = material
	add_child(body)

	var radius := GameConstants.TRACK_HALF_THICKNESS * world_scale
	for segment in segments:
		var start := world_to_local_screen(segment["a"])
		var end := world_to_local_screen(segment["b"])
		var direction := end - start
		var length := direction.length()
		if length <= 0.01:
			continue
		var shape := CapsuleShape2D.new()
		shape.radius = radius
		shape.height = maxf(length + radius * 2.0, radius * 2.0)
		var collision_shape := CollisionShape2D.new()
		collision_shape.position = (start + end) * 0.5
		collision_shape.rotation = direction.angle() - PI * 0.5
		collision_shape.shape = shape
		body.add_child(collision_shape)
		collision_shape_count += 1

func world_to_local_screen(point: Vector2) -> Vector2:
	return Vector2(point.x * world_scale, -point.y * world_scale)

func _draw() -> void:
	var width := GameConstants.TRACK_HALF_THICKNESS * world_scale * 2.0
	for segment in track_segments:
		var start := world_to_local_screen(segment["a"])
		var end := world_to_local_screen(segment["b"])
		var color: Color = segment["color"]
		draw_line(start, end, Color(color, 0.20), width + 8.0, true)
		draw_line(start, end, color, width, true)
		if segment["surface_overridden"]:
			draw_line(start, end, Color.WHITE, 1.5, true)

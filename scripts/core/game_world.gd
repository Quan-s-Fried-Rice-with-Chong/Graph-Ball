class_name FormulaGameWorld
extends Node2D

const GOAL_ENTRY_BALL_FACTOR := 0.65

signal checkpoint_reached(index: int)
signal goal_reached
signal world_failed(reason: String)
signal ball_state_changed(position: Vector2, velocity: Vector2)

var level: Dictionary = {}
var formulas: Array = []
var boundary := PackedVector2Array()
var checkpoint_index := 0
var reached: Array = []
var running := false
var paused := false
var goal_latched := false
var previous_position := Vector2.ZERO
var world_scale := GameConstants.WORLD_SCALE
@onready var track_builder: TrackBuilder = $TrackBuilder
@onready var ball: BallController = $Ball

func configure_level(data: Dictionary, current_formulas: Array, build_colliders: bool = true) -> void:
	level = data.duplicate(true)
	boundary = level.boundary
	track_builder.world_scale = world_scale
	ball.configure(world_scale)
	if build_colliders:
		rebuild_tracks(current_formulas)
	else:
		preview_tracks(current_formulas)
	reset_ball()

func rebuild_tracks(current_formulas: Array) -> void:
	formulas = current_formulas.duplicate(true)
	track_builder.rebuild(formulas, boundary)

func preview_tracks(current_formulas: Array) -> void:
	formulas = current_formulas.duplicate(true)
	track_builder.preview(formulas, boundary)

func reset_ball() -> void:
	running = false
	paused = false
	goal_latched = false
	checkpoint_index = 0
	reached = []
	reached.resize(level.get("checkpoints", []).size())
	reached.fill(false)
	previous_position = level.get("start", {}).get("position", Vector2.ZERO)
	ball.reset_ball(world_to_local_screen(previous_position), level.get("start", {}).get("velocity", Vector2.ZERO))

func start_simulation() -> void:
	reset_ball()
	running = true
	ball.start_simulation()

func set_simulation_paused(value: bool) -> void:
	paused = value
	ball.set_simulation_paused(value)

func stop_simulation() -> void:
	running = false
	ball.freeze = true

func ball_world_position() -> Vector2:
	return local_screen_to_world(ball.position)

func world_to_local_screen(p: Vector2) -> Vector2:
	return Vector2(p.x, -p.y) * world_scale

func local_screen_to_world(p: Vector2) -> Vector2:
	return Vector2(p.x, -p.y) / world_scale

func _physics_process(_delta: float) -> void:
	if not running or paused:
		return
	var p := ball_world_position()
	check_motion(previous_position, p)
	previous_position = p
	ball_state_changed.emit(p, ball.world_velocity())

# Earliest contact on a swept segment; INF means no contact.
static func circle_contact(a: Vector2, b: Vector2, center: Vector2, radius: float) -> float:
	var offset := a - center
	if offset.length_squared() <= radius * radius:
		return 0.0
	var d := b - a
	var length := d.length_squared()
	if length < 0.0000001:
		return INF
	var projection := offset.dot(d)
	var discriminant := projection * projection - length * (offset.length_squared() - radius * radius)
	if discriminant < 0:
		return INF
	var t := (-projection - sqrt(discriminant)) / length
	return t if t >= 0 and t <= 1 else INF

static func rect_contact(a: Vector2, b: Vector2, rect: Rect2, radius: float) -> float:
	# Exact rounded rectangle: two expanded strips plus four corner circles.
	var best := INF
	for strip in [Rect2(rect.position - Vector2(radius, 0), rect.size + Vector2(2 * radius, 0)), Rect2(rect.position - Vector2(0, radius), rect.size + Vector2(0, 2 * radius))]:
		var lower := 0.0
		var upper := 1.0
		for axis in 2:
			var delta: float = b[axis] - a[axis]
			if absf(delta) < 0.0000001:
				if a[axis] < strip.position[axis] or a[axis] > strip.end[axis]:
					upper = -1
			else:
				var t1: float = (strip.position[axis] - a[axis]) / delta
				var t2: float = (strip.end[axis] - a[axis]) / delta
				lower = maxf(lower, minf(t1, t2))
				upper = minf(upper, maxf(t1, t2))
		if lower <= upper:
			best = minf(best, lower)
	for corner in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
		best = minf(best, circle_contact(a, b, corner, radius))
	return best

func check_motion(a: Vector2, b: Vector2) -> void:
	var events: Array = []
	var radius := GameConstants.BALL_RADIUS
	for hazard in level.get("hazards", []):
		var t := rect_contact(a, b, hazard.rect, radius) if hazard.has("rect") else circle_contact(a, b, hazard.position, float(hazard.radius) + radius)
		if is_finite(t):
			events.append({"t": t, "kind": 0})
	# Detect leaving any edge, even if a fast segment exits and re-enters a concavity.
	if not BoundaryClipper.point_inside(a, boundary):
		events.append({"t": 0.0, "kind": 0, "boundary": true})
	for i in boundary.size():
		var hit = Geometry2D.segment_intersects_segment(a, b, boundary[i], boundary[(i + 1) % boundary.size()])
		if hit != null and a.distance_squared_to(b) > 0.0000001:
			var t: float = a.distance_to(hit) / a.distance_to(b)
			var after := a.lerp(b, minf(1.0, t + 0.0001))
			if not BoundaryClipper.point_inside(after, boundary):
				events.append({"t": t, "kind": 0, "boundary": true})
	if not BoundaryClipper.point_inside(b, boundary):
		events.append({"t": 1.0, "kind": 0, "boundary": true})
	for i in level.get("checkpoints", []).size():
		if reached[i]:
			continue
		var cp: Dictionary = level.checkpoints[i]
		var t := circle_contact(a, b, cp.position, float(cp.radius) + radius)
		if is_finite(t):
			events.append({"t": t, "kind": 1, "index": i})
	var goal: Dictionary = level.get("goal", {})
	var goal_position: Vector2 = goal.get("position", Vector2.ZERO)
	var goal_radius := float(goal.get("radius", 0.5))
	var goal_trigger_radius := goal_radius + radius * GOAL_ENTRY_BALL_FACTOR
	var goal_t := circle_contact(a, b, goal_position, goal_trigger_radius)
	if is_finite(goal_t):
		events.append({"t": goal_t, "kind": 2, "position": a.lerp(b, goal_t)})
	# If the last checkpoint is collected inside the goal, win at that instant,
	# even when this fast segment leaves the goal before its endpoint.
	for event in events.duplicate():
		if event.kind == 1 and a.lerp(b, event.t).distance_to(goal_position) <= goal_trigger_radius:
			events.append({"t": event.t, "kind": 2, "position": a.lerp(b, event.t)})
	# A checkpoint gathered while already overlapping the goal also unlocks it.
	if b.distance_to(goal_position) <= goal_trigger_radius:
		events.append({"t": 1.0, "kind": 2, "position": b})
	events.sort_custom(func(x: Dictionary, y: Dictionary): return x.kind < y.kind if x.t == y.t else x.t < y.t)
	for event in events:
		if event.kind == 0:
			stop_simulation()
			world_failed.emit("球离开了边框" if event.get("boundary", false) else "球触碰了危险区域")
			return
		if event.kind == 1 and not reached[event.index]:
			reached[event.index] = true
			checkpoint_index += 1
			checkpoint_reached.emit(event.index)
		if event.kind == 2 and checkpoint_index == reached.size() and not goal_latched:
			goal_latched = true
			ball.position = world_to_local_screen(event.get("position", b))
			stop_simulation()
			goal_reached.emit()
			return

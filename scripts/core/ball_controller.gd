class_name BallController
extends RigidBody2D

var world_scale := GameConstants.WORLD_SCALE
var radius_pixels := GameConstants.BALL_RADIUS * GameConstants.WORLD_SCALE
var max_speed_pixels := GameConstants.MAX_SPEED * GameConstants.WORLD_SCALE
var _paused_velocity := Vector2.ZERO
var _paused_angular_velocity := 0.0
var _trail_rotation := 0.0

func _ready() -> void:
	mass = 1.0
	gravity_scale = 1.0
	lock_rotation = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = false
	max_contacts_reported = 0
	linear_damp = 0.02
	angular_damp = 0.08
	_build_collision_shape()
	queue_redraw()

func configure(scale_value: float, radius_world: float = GameConstants.BALL_RADIUS) -> void:
	world_scale = scale_value
	radius_pixels = radius_world * world_scale
	max_speed_pixels = GameConstants.MAX_SPEED * world_scale
	_build_collision_shape()
	queue_redraw()

func reset_ball(screen_position: Vector2, world_velocity: Vector2 = Vector2.ZERO) -> void:
	freeze = true
	sleeping = false
	position = screen_position
	linear_velocity = Vector2(world_velocity.x, -world_velocity.y) * world_scale
	angular_velocity = 0.0
	rotation = 0.0
	_paused_velocity = Vector2.ZERO
	_paused_angular_velocity = 0.0

func start_simulation() -> void:
	freeze = false
	sleeping = false

func set_simulation_paused(paused: bool) -> void:
	if paused and not freeze:
		_paused_velocity = linear_velocity
		_paused_angular_velocity = angular_velocity
		freeze = true
	elif not paused and freeze:
		freeze = false
		linear_velocity = _paused_velocity
		angular_velocity = _paused_angular_velocity
		sleeping = false

func world_velocity() -> Vector2:
	return Vector2(linear_velocity.x, -linear_velocity.y) / world_scale

func set_world_velocity(value: Vector2) -> void:
	linear_velocity = Vector2(value.x, -value.y) * world_scale

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var speed := state.linear_velocity.length()
	if speed > max_speed_pixels:
		state.linear_velocity = state.linear_velocity / speed * max_speed_pixels
	_trail_rotation = state.transform.get_rotation()

func _build_collision_shape() -> void:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	var circle := CircleShape2D.new()
	circle.radius = radius_pixels
	collision_shape.shape = circle

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius_pixels + 5.0, Color("39245f"))
	draw_circle(Vector2.ZERO, radius_pixels, Color("f6f0ff"))
	draw_circle(Vector2(-radius_pixels * 0.28, -radius_pixels * 0.32), radius_pixels * 0.22, Color(1.0, 1.0, 1.0, 0.85))
	draw_arc(Vector2.ZERO, radius_pixels * 0.64, _trail_rotation, _trail_rotation + PI * 0.8, 18, Color("8b5cf6"), 2.0, true)

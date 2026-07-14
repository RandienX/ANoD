extends CharacterBody2D

enum EntityPresets {
	NPC,
	Hunter,
	Chaser,
	HomeDefender,
	Hider
}

const INFINITE_SIGHT: int = 8192

@export var battle: Battle
@export var enemy_sprite_frames: SpriteFrames
@export var player: CharacterBody2D
@export_category("Behavior")
@export var entity_preset: EntityPresets
@export var aggresive: bool
@export var speed: int = 64
@export var chase_speed: int = 0
@export var roam_radius: float = 150.0

@export_subgroup("Optional")
@export_range(-1, 2048, 1) var sight_range: int = -1
@export var hitbox_size: Vector2 = Vector2(16, 16)
@export var require_input_to_interact: bool = false
@export var dialogue: DialogueData
@export var delete_upon_interact: bool

var home_position: Vector2
var current_state: String = "idle" # Start as "idle" to force first target generation

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var wall_coll_check: Area2D = $wall_coll
@onready var hitbox: Area2D = $hitbox
@onready var see_range: Area2D = $see_range
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

func _ready() -> void:
	await get_tree().create_timer(0.1).timeout
	if name in get_tree().current_scene.enemies_deactivated:
		queue_free()
		return
	
	home_position = global_position
	
	# Setup shapes
	hitbox.get_child(0).shape.size = hitbox_size + Vector2(2,2)
	hitbox.get_child(0).position = hitbox.get_child(0).position + Vector2(0,2)
	$StaticBody2D/CollisionShape2D.shape.size = hitbox_size - Vector2(2, 2)
	wall_coll_check.get_child(0).shape.radius = hitbox_size.x
	
	# Enforce Hunter sight range rule
	if entity_preset == EntityPresets.Hunter and sight_range >= 0 and sight_range < 128:
		sight_range = 128
		
	var actual_sight_range = sight_range if sight_range >= 0 else INFINITE_SIGHT
	see_range.get_child(0).shape.radius = actual_sight_range
	animation.sprite_frames = enemy_sprite_frames
	
	# Configure NavigationAgent
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0

	# HomeDefender specific: Anchor see_range to home_position
	if entity_preset == EntityPresets.HomeDefender:
		if see_range.get_parent() == self:
			var parent = get_parent()
			remove_child(see_range)
			parent.add_child(see_range)
			see_range.global_position = home_position

func _physics_process(_delta: float) -> void:
	if not player:
		return

	var is_player_visible = _is_player_in_sight()
	var is_player_in_see_area = _is_player_in_see_area(player.global_position)

	# 1. Determine State and ensure we have a valid target
	match entity_preset:
		EntityPresets.NPC:
			_ensure_roam_target()

		EntityPresets.Hunter:
			if is_player_visible:
				_ensure_chase_target()
			else:
				_ensure_roam_target()

		EntityPresets.Chaser:
			if is_player_visible:
				_ensure_chase_target()
			else:
				_ensure_chaser_roam_target()

		EntityPresets.HomeDefender:
			if is_player_in_see_area:
				_ensure_chase_target()
			elif global_position.distance_to(home_position) > 10.0:
				_ensure_return_home_target()
			else:
				_ensure_defender_roam_target()

		EntityPresets.Hider:
			if is_player_visible:
				_ensure_flee_target()
			else:
				_ensure_roam_target()

	# 2. Apply Navigation Movement
	_update_navigation_movement()
	
	# 3. Animate
	var direction: Vector2 = get_position_delta()
	animate(direction)
	move_and_slide()

func animate(dir):
	if dir != Vector2.ZERO:
		if dir.y < 0:
			$AnimatedSprite2D.play("run2")
		elif dir.y > 0:
			$AnimatedSprite2D.play("run1")
				
		if abs(dir.x) > speed * 0.01:
			$AnimatedSprite2D.play("run0")
			$AnimatedSprite2D.flip_h = dir.x < 0

func _update_navigation_movement() -> void:
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	
	var current_speed = chase_speed if chase_speed != 0 else speed
	velocity = direction * current_speed
	move_and_slide()

# --- TARGET ENSURANCE FUNCTIONS ---
# These guarantee a new target is set if the state changes OR if the old target was reached

func _ensure_roam_target() -> void:
	if current_state != "roaming" or nav_agent.is_navigation_finished():
		current_state = "roaming"
		nav_agent.target_position = _get_random_roam_target()

func _ensure_chaser_roam_target() -> void:
	if current_state != "roaming" or nav_agent.is_navigation_finished():
		current_state = "roaming"
		nav_agent.target_position = _get_random_position_at_distance(roam_radius * 1.5, roam_radius * 3.0)

func _ensure_defender_roam_target() -> void:
	if current_state != "roaming" or nav_agent.is_navigation_finished():
		current_state = "roaming"
		@warning_ignore("incompatible_ternary")
		var max_dist = sight_range if sight_range > 0 else 200.0
		nav_agent.target_position = _get_random_position_at_distance(0.0, max_dist, home_position)

func _ensure_chase_target() -> void:
	if current_state != "chasing":
		current_state = "chasing"
	# Continuously update to player's position for smooth tracking
	nav_agent.target_position = player.global_position

func _ensure_return_home_target() -> void:
	if current_state != "returning" or nav_agent.is_navigation_finished():
		current_state = "returning"
		nav_agent.target_position = home_position

func _ensure_flee_target() -> void:
	if current_state != "fleeing" or nav_agent.is_navigation_finished():
		current_state = "fleeing"
		nav_agent.target_position = _get_flee_position(player.global_position)

# --- HELPER FUNCTIONS ---

func _get_random_roam_target() -> Vector2:
	return _get_random_position_at_distance(0.0, roam_radius, home_position)

func _get_random_position_at_distance(min_dist: float, max_dist: float, origin: Vector2 = home_position) -> Vector2:
	var angle = randf() * TAU
	var distance = randf_range(min_dist, max_dist)
	return origin + Vector2(cos(angle), sin(angle)) * distance

func _get_flee_position(away_from: Vector2) -> Vector2:
	var direction_away = (global_position - away_from).normalized()
	var angle_variance = randf_range(-PI/3, PI/3) # +/- 60 degrees
	var final_direction = direction_away.rotated(angle_variance)
	@warning_ignore("incompatible_ternary")
	var flee_distance = sight_range if sight_range > 0 else 300.0
	
	return global_position + (final_direction * flee_distance)

func _is_player_in_sight() -> bool:
	if sight_range == -1:
		return true
	return global_position.distance_to(player.global_position) <= sight_range

func _is_player_in_see_area(point: Vector2) -> bool:
	if sight_range == -1:
		return true
	return home_position.distance_to(point) <= sight_range

# --- INTERACTION FUNCTIONS ---

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("use") and hitbox.get_overlapping_bodies().has(player):
		_handle_interaction()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body == player and not require_input_to_interact:
		_handle_interaction()

func _handle_interaction() -> void:
	if entity_preset == EntityPresets.NPC:
		if dialogue and DialogueInitiator._dialogue_runner == null:
			DialogueInitiator.start_dialogue(dialogue, false, true)
			if delete_upon_interact:
				get_tree().current_scene.enemies_deactivated.append(name)
				queue_free()
		return

	if battle:
		get_tree().current_scene.create_battle(battle)
		if delete_upon_interact:
			queue_free()

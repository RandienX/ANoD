extends CharacterBody2D

@onready var menu := $Camera2D/CanvasLayer/game_menu
@onready var camera := $Camera2D

@export var stop_move := false
@export var static_shader := true
@export var can_menu := true

enum PIZZARIA_SHADER_ENUM {
	DiningHall,
	Backstage,
	PirateCove,
	Hallways,
	Closet,
	Kitchen,
	Toilets
}
const PIZZARIA_SHADER_COLORS: Dictionary = {
	0: Vector3(225/255.0, 117/255.0, 0),
	1: Vector3(255/255.0, 0, 0),
	2: Vector3(255/255.0, 220/255.0, 0),
	3: Vector3(0, 255/255.0, 0),
	4: Vector3(200/255.0, 255/255.0, 0),
	5: Vector3(0, 255/255.0, 120/255.0),
	6: Vector3(0, 255/255.0, 255/255.0),
}
var room

# Party member sprites and their tracking
var party_sprites: Array[AnimatedSprite2D] = []
var party_positions: Array[Vector2] = []
var party_delays: Array[int] = []
var last_directions: Array[Vector2] = []
var party_idle_states: Array[int] = []
var max_history_size: int = 0

func _ready() -> void:
	$AnimatedSprite2D.play("idle1")
	room = $"..".room_name
	enumify_room()
	camera.global_position = global_position
	$Camera2D/CanvasLayer/shader/crt.visible = static_shader
	$Camera2D/CanvasLayer/shader/Label.visible = static_shader

	# Create party member sprites based on PlayerStats.party array
	await get_tree().create_timer(0.1).timeout
	create_party_sprites()

func enumify_room():
	if room == "Pizzeria - Dining Hall":
		room = PIZZARIA_SHADER_ENUM.DiningHall
	elif room == "Pizzeria - Hallways":
		room = PIZZARIA_SHADER_ENUM.Hallways
	elif room == "Pizzeria - Closet":
		room = PIZZARIA_SHADER_ENUM.Closet
	elif room == "Pizzeria - Backstage":
		room = PIZZARIA_SHADER_ENUM.Backstage
	elif room == "Pizzeria - Pirate Cove":
		room = PIZZARIA_SHADER_ENUM.PirateCove
	elif room == "Pizzeria - Kitchen":
		room = PIZZARIA_SHADER_ENUM.Kitchen
	elif room == "Pizzeria - Toilet":
		room = PIZZARIA_SHADER_ENUM.Toilets
	else:
		$Camera2D/CanvasLayer/shader/PizzariaMap.queue_free()
		return
		
	print(PIZZARIA_SHADER_COLORS[room])
	$Camera2D/CanvasLayer/shader/PizzariaMap/PizzariaMapShader.set_instance_shader_parameter("target_color", PIZZARIA_SHADER_COLORS[room])

func create_party_sprites():
	# Clear existing party sprites
	for sprite in party_sprites:
		sprite.queue_free()
	party_sprites.clear()
	party_positions.clear()
	party_delays.clear()
	last_directions.clear()
	party_idle_states.clear()

	# Create a sprite for each party member
	var index := 0
	for entity in PlayerStats.party:
		if entity.name == "Freddy":
			continue

		var sprite := AnimatedSprite2D.new()
		sprite.name = "PartyMember" + str(entity.name)

		# Start at same position as player (will be positioned relative to global position)
		sprite.global_position = global_position

		add_child(sprite)
		sprite.sprite_frames = entity.sprite
		sprite.play("idle1")

		party_sprites.append(sprite)
		party_positions.append(global_position)  # Start at player's global position
		party_delays.append((20 * (index + 1)) - 1)  # Increasing delay for each member
		party_idle_states.append(1)

		index += 1
		
	if party_delays.size() > 0:
		max_history_size = party_delays.max() + 1
	else:
		max_history_size = 0

func _physics_process(delta: float) -> void:
	movement(delta)

@export var move_speed: float = 10.0
@export_range(1.0, 3.0) var sprint_mult: float = 1.75
@export_range(1.0, 10.0) var friction: float = 3.0
var acceleration = 500

var current_direction: Vector2 = Vector2.ZERO
var target_rotation: float = 0.0

func movement(delta) -> void:
	var direction = Input.get_vector("left", "right", "up", "down")

	if !stop_move:
		if direction.length() > 1.0:
			direction = direction.normalized()
		current_direction = direction
		if Input.is_action_pressed("run"):
			velocity = velocity.move_toward(direction * sprint_mult * move_speed, acceleration * sprint_mult * delta * friction)
		else:
			velocity = velocity.move_toward(direction * move_speed, acceleration * delta * friction)
	else:
		current_direction = Vector2.ZERO
		velocity = Vector2.ZERO
	# Record actual movement after collision resolution
	if current_direction != Vector2.ZERO or velocity.length() > 0:
		last_directions.insert(0, get_real_velocity())
		# Keep history bounded to prevent memory issues and desync
		while last_directions.size() > max_history_size:
			last_directions.pop_back()
	
	# Update party sprites
	update_party_sprites(delta)

	move_and_slide()

	animate()
	if global_position != null:
		PlayerStats.player_position = global_position

var idle_state = 0

func animate(id = 3, is_running = false):
	if current_direction != Vector2.ZERO or id < 3:
		if current_direction.y == -1 or (id == 2 and is_running):
			$AnimatedSprite2D.play("run2")
			idle_state = 2
		elif current_direction.y == 1 or (id == 0 and is_running):
			$AnimatedSprite2D.play("run1")
			idle_state = 1
				
		elif current_direction.x != 0 or (abs(id) == 1 and is_running):
			$AnimatedSprite2D.play("run0")
			idle_state = 0
			$AnimatedSprite2D.flip_h = current_direction.x < 0
			if id == -1:
				$AnimatedSprite2D.flip_h = true
	else:
		$AnimatedSprite2D.play("idle" + str(idle_state))

func update_party_sprites(delta) -> void:
	for pm in range(len(party_sprites)):
		var pos = party_positions[pm]
		var dir = Vector2.ZERO

		if len(last_directions) >= party_delays[pm] + 1:
			dir = last_directions[party_delays[pm]]
			pos += dir * delta

			if len(last_directions) >= party_delays.max() + 1:
				last_directions.pop_back()

		party_positions[pm] = pos
		party_sprites[pm].global_position = pos

		# Animate party sprites based on movement
		if dir != Vector2.ZERO:
			if dir.y < 0:
				party_sprites[pm].play("run2")
				party_idle_states[pm] = 2
			elif dir.y > 0:
				party_sprites[pm].play("run1")
				party_idle_states[pm] = 1
			elif dir.x != 0:
				party_sprites[pm].play("run0")
				party_idle_states[pm] = 0
				party_sprites[pm].flip_h = dir.x < 0
		else:
			party_sprites[pm].play("idle" + str(party_idle_states[pm]))
	
		if global_position.y > party_sprites[pm].global_position.y:
			party_sprites[pm].z_index = -1
		else:
			party_sprites[pm].z_index = 0

func textbox():
	stop_move = true
	can_menu = false

@export var party: Array[Entity]

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("menu") and can_menu:
		if menu.visible == false:
			menu.visible = true
			stop_move = true
		else:
			menu.visible = false
			stop_move = false

func battle_zoom():
		stop_move = true
		$AnimationPlayer.play("camera_battle_zoom")

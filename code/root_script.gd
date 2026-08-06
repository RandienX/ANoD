extends Node2D
class_name RootScene

@export var room_name: String
@export var possible_battles: Array[Battle]
@export_range(0, 100) var enemy_intensity: int = 20
@export_range(0, 100) var enemy_agressiveness: int = 10
@export var battle_bg: Texture2D
@export var bg_music: AudioStreamMP3
@export var bg_music_amp: float
@export var player: CharacterBody2D
@export var room_size: Rect2

@onready var textbox_root = $Textboxes

var textboxes_deactivated := []
var enemies_deactivated := []
var done_things := {}
var completed_dialogues := []
var talked_to_npcs := {}

var player_position: Vector2
var player_steps: int = 100 - enemy_intensity

func _ready() -> void:
	Global.current_scene = scene_file_path
	if !(room_name in Global.scene_data.keys()):
		Global.set_scene_data(self)
	for v in Global.scene_data[room_name].keys():
		if v == "textboxes_deactivated":
			textboxes_deactivated = Global.scene_data[room_name][v]
		elif v == "enemies_deactivated":
			enemies_deactivated = Global.scene_data[room_name][v]
		elif v == "dialogue_completed":
			completed_dialogues = Global.scene_data[room_name][v]
		elif v ==  "done_things":
			done_things = Global.scene_data[room_name][v]
		elif v ==  "talked_npc":
			talked_to_npcs = Global.scene_data[room_name][v]
	
	setup_player()
	setup_music()
	
func setup_player():
	await get_tree().physics_frame
	player.global_position = PlayerStats.player_position
	player.camera.limit_left = room_size.position.x*32 #32 cuz tile size *2 cuz idfk
	player.camera.limit_top = room_size.position.y*32
	player.camera.limit_right = room_size.position.x*32 + room_size.size.x*32
	player.camera.limit_bottom = room_size.position.y*32 + room_size.size.y*32
	player.camera.global_position = player.global_position
	player.camera.position_smoothing_enabled = false
	player.camera.position_smoothing_enabled = true
	player.start_global_pos = player.global_position
	player.create_party_sprites()
		
func setup_music():
	if bg_music:
		if !BackgroundMusic.stream or BackgroundMusic.stream.resource_path != bg_music.resource_path:
			BackgroundMusic.stream = bg_music
	BackgroundMusic.volume_db = bg_music_amp
	if BackgroundMusic.playing != true:
		BackgroundMusic.playing = true
		
func save_data():
	Global.set_scene_data(self)

func _physics_process(_delta: float) -> void:
	player_position = player.global_position
	PlayerStats.player_position = player_position
	
func _input(_event: InputEvent) -> void:
	var rng
	if Input.is_action_pressed("left"):
		rng = randi_range(1, 100)
		if (rng * 0.75 if Input.is_action_pressed("run") else rng * 1.0) <= enemy_agressiveness:
			player_steps -= 1
	if Input.is_action_pressed("right"):
		rng = randi_range(1, 100)
		if (rng * 0.75 if Input.is_action_pressed("run") else rng * 1.0) <= enemy_agressiveness:
			player_steps -= 1
	if Input.is_action_pressed("up"):
		rng = randi_range(1, 100)
		if (rng * 0.75 if Input.is_action_pressed("run") else rng * 1.0) <= enemy_agressiveness:
			player_steps -= 1
	if Input.is_action_pressed("down"):
		rng = randi_range(1, 100)
		if (rng * 0.75 if Input.is_action_pressed("run") else rng * 1.0) <= enemy_agressiveness:
			player_steps -= 1
	if player_steps == 0:
		create_battle()

func create_battle(var_battle = null):
	Global.set_scene_data(self)
	play_sfx("res://assets/sound/sfx/ah shit here we go again.mp3", "2")
	Global.battle_bg = battle_bg
	$player.battle_zoom()
	$player.textbox()
	var battle
	if var_battle == null:
		battle = possible_battles.pick_random()
	elif var_battle is Resource:
		battle = var_battle
	else:
		battle = load(var_battle)
		
	await get_tree().create_timer(1.5).timeout
	
	Global.load_battle(battle)
	
func outbattle_root_check() -> bool:
	return true
	
func done_thing(thing: String, value = true):
	done_things.assign({thing: value})

func play_sfx(audio_path: String, audio_bus: String = "1") -> void:
	audio_bus = "1" if audio_bus == "" else audio_bus
	var audio = load(audio_path)
	var bus = Sfx if audio_bus == "1" else Sfx2
	bus.stream = audio
	bus.play()
	
func play_audio(audio_path: String) -> void:
	var audio = load(audio_path)
	var bus = BackgroundMusic
	bus.stream = audio
	bus.play()

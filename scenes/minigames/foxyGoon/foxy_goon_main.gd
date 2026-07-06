extends Node2D
class_name FoxyGoon

enum Ranks {
	F,
	D,
	C,
	B,
	A,
	S
}

@onready var arrows_folder = $Arrows
const arrow_SCENE = "res://scenes/minigames/foxyGoon/foxy_arrow.tscn"
@export var settings: FoxyGoonSettings
var settings_duplicate

var score: int = 0
var misses: int = 0
var accuracy: float = 1
var notes: int = 0

var hp: float = 30
var max_hp: float
var rank: Ranks

var game_over_active: bool = false
var can_reload = false
var delay_to_arrow: float

var is_story: bool = false

func _ready() -> void:
	settings = Global.current_foxy_track
	settings_duplicate = settings.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	BackgroundMusic.stream = settings_duplicate.music
	BackgroundMusic.play(settings_duplicate.testing_start_pos)
	delay_to_arrow = 5 / settings_duplicate.speed 
	
	var idx = 0
	for c in $gui/HP/VBoxContainer/Control.get_children():
		if c.name == "f":
			c.min_value = 0
			c.max_value = settings_duplicate.rank_hp[idx]
		else:
			c.min_value = settings_duplicate.rank_hp[idx-1]
			c.max_value = settings_duplicate.rank_hp[idx]
		idx += 1
	hp = settings_duplicate.rank_hp[2]
	is_story = Global.is_track_story
	
	for s in settings_duplicate.arrow_schematics:
		if s.after_time >= max(0, settings_duplicate.testing_start_pos + delay_to_arrow / s.speed_mult) or settings_duplicate.testing_start_pos == 0:
			deploy_arrows(s)
			
			
	await get_tree().create_timer(settings_duplicate.song_end_seconds - settings_duplicate.testing_start_pos).timeout
	if !game_over_active:
		end()
	
func deploy_arrows(schematic: ArrowSchematic):
	var s_copy = schematic.duplicate(true)
	
	if s_copy.flip_h:
		s_copy.flip_horizontal()
	if s_copy.speed_mult != 1.0:
		for arrow in s_copy.arrow_data:
			arrow.speed_mult *= s_copy.speed_mult
			
	await get_tree().create_timer(max(0.01, s_copy.after_time - settings_duplicate.testing_start_pos - delay_to_arrow / s_copy.speed_mult)).timeout
	
	for arrow in s_copy.arrow_data:
		create_arrow(arrow)
	
func create_arrow(arrow: ArrowData, is_hold: bool = false, is_hold_end: bool = false):
	var arrow_child = load(arrow_SCENE).instantiate()
	arrow_child.arrow_data = arrow
	if is_hold:
		arrow_child.get_node("Sprite2D").texture = load("res://assets/minigame/foxy_goon/foxy_arrow_middle.png")
		if is_hold_end:
			arrow_child.get_node("Sprite2D").texture = load("res://assets/minigame/foxy_goon/foxy_arrow_tail.png")
		arrow_child.z_index -= 1
	arrows_folder.add_child(arrow_child)
	
func _input(event: InputEvent) -> void:
	if can_reload:
		if event.is_action_pressed("lmb") or event.is_action_pressed("use"):
			reload()
	
func _physics_process(delta: float) -> void:
	for c in $gui/HP/VBoxContainer/Control.get_children():
		if abs(c.value - hp) > 0.01:
			c.value = move_toward(c.value, hp, sqrt(pow((hp - c.value), 2)/2) * delta * 5)
		else:
			c.value = hp
		if hp >= c.max_value:
			$gui/HP/VBoxContainer/Rank.texture = load("res://assets/minigame/foxy_goon/ranks/" + c.name + ".png")
	
func destroy_arrow(arrow: GoonArrow, score_mult = 1.0):
	var arrow_type = arrow.arrow_data.type
	_add_score(settings_duplicate.arrow_type_score[arrow_type] * score_mult)
	_add_hp(settings_duplicate.arrow_type_hp[arrow_type])
	notes += 1
	arrow.queue_free()
	
func hurt_arrow(arrow: GoonArrow):
	var arrow_type = arrow.arrow_data.type
	_add_score(floor(-settings_duplicate.arrow_type_score[arrow_type] * settings_duplicate.arrow_type_score_miss_mult))
	_add_hp(-settings_duplicate.arrow_type_damage[arrow_type])
	notes += 1
	misses += 1
	recalculate_accuracy(0)
	arrow.queue_free()

func _add_score(score_add: int):
	score += score_add

func _add_hp(hp_add: float):
	hp = clamp(hp + hp_add, 0, settings_duplicate.rank_hp[5])
	
	if hp <= 0:
		die()

func recalculate_accuracy(quality: float = 1):
	accuracy = (notes * accuracy + 1 * quality) / (notes + 1)

func die():
	if game_over_active: return
	
	game_over_active = true
	
	var gitgud = preload("res://scenes/ui/game_over.tscn").instantiate()
	gitgud.z_index = 999
	add_child(gitgud)
	BackgroundMusic.playing = false
	Sfx.playing = false
	Sfx2.playing = false
	BackgroundMusic.stream = load("res://assets/sound/sfx/death.wav")
	BackgroundMusic.play()
	gitgud.get_node("AnimationPlayer").play("gitgud")
	
	await get_tree().create_timer(1.5).timeout
	can_reload = true
	
func reload():
	get_tree().change_scene_to_file("res://scenes/minigames/foxyGoon/foxy_goon.tscn")

func end():
	await $transition/black_flash.reappear()
	Global.track_score = score
	Global.track_miss = misses
	Global.track_accuracy = accuracy
	
	if is_story:
		Global.is_track_story = false
		get_tree().change_scene_to_file(Global.current_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/minigames/foxyGoon/foxy_goon_results.tscn")
	

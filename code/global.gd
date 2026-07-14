extends Node

#--Battle Variables--
enum effect {Heal, Mana_Heal, Blind, Poison, Bleed, Power, Tough, Focus, Defend, Kill, Absorb, Revive, Sick, Weak, Slow, Sleep, Burn, Freeze, Paralyzed, Shock, Confuse}
enum AI {Dumb, Casual, Violent, Defensive, Intelligent, Flexible}
var battle_ref: Node = null
var battle_bg: Texture2D = null

var battle_current = null
var shop_current: ShopData = null

var player_ref = null
#--Saved Variables--
var time_played: float = 0.0
var current_scene: String = "res://scenes/maps/pizzeria/1ab.tscn"
var scene_data: Dictionary = {}
var enemies_killed: Dictionary = {}
var battles_won: Dictionary = {"Alpha Battle Hat 1": 0}

var loading = false

func _ready() -> void:
	process_mode = Node.ProcessMode.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	time_played += delta
	
# Helper method to get enemies_killed dictionary (for QuestSystem access)
func get_enemies_killed() -> Dictionary:
	return enemies_killed
		
# === Save Data Management ===
func get_save_data() -> Dictionary:
	# Delegate to PlayerStats for comprehensive save data
	var stats = PlayerStats
	return stats.get_save_data()
	
func get_internal_save_data() -> Dictionary:
	var save_data = {}
	
	save_data = {
		"enemies_killed": enemies_killed,
		"battles_won": battles_won,
		"foxy_data": foxy_data
	}
	
	return save_data

func internally_load_save_data(data):
	for v in data.keys():
		Global[v] = data[v]

func set_scene_data(data: Object):
	var is_room = scene_data.find_key(data.room_name)
	if is_room:
		scene_data.merge({data.room_name: 
			{"textboxes_deactivated": data.textboxes_deactivated,
			"enemies_deactivated": data.enemies_deactivated,
			"dialogue_completed": data.completed_dialogues,
			"done_things": data.done_things,
			"talked_npc": data.talked_to_npcs}
			}, true)
	else:
		scene_data.merge({data.room_name: 
			{"textboxes_deactivated": data.textboxes_deactivated,
			"enemies_deactivated": data.enemies_deactivated,
			"dialogue_completed": data.completed_dialogues,
			"done_things": data.done_things,
			"talked_npc": data.talked_to_npcs}
			})

func get_scenes_data():
	return scene_data

func reload_last_save() -> void:
	Save.load_game(SaveManager.last_slot)

# === Tools ===
func lower_font(target: Label):
	var size = target.theme.default_font_size
	for i in range(size): 
		if target.theme.default_font.get_string_size(target.text.rsplit(str(" "))[0], target.horizontal_alignment, -1, target.theme.default_font_size).x > target.custom_minimum_size.x:
			target.theme.default_font_size -= 1
		else:
			return

func process_frame():
	await get_tree().physics_frame

# === Mics ===
func load_battle(battle: Battle):
	battle_current = battle
	get_tree().change_scene_to_file("res://scenes/ui/battle_engine_stuff/battle_engine.tscn")

#--Minigames--
var current_foxy_track: FoxyGoonSettings = null
var current_foxy_trackname: String = ""
var is_track_story: bool = false
var track_score: int
var track_miss: int
var track_accuracy: float
var foxy_data = {}

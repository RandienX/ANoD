extends Resource
class_name QuestEffect

## QuestEffect - Reward or action triggered when a quest completes
##
## QuestEffects are executed when a quest or quest point is completed.
## They can grant items, start dialogues, change scenes, and more.

enum EffectType {
	ADD_QUEST,          # Add/start a new quest
	ADD_STATUS,         # Apply status effect to player/party
	START_DIALOGUE,     # Begin a dialogue
	START_BATTLE,       # Initiate a battle
	ADD_ITEM,           # Give item(s) to player
	ADD_CURRENCY,       # Give currency
	SAVE_GAME,          # Trigger a save
	CUTSCENE,           # Play a cutscene
	CHANGE_SCENE,       # Change to different scene
	AWAIT,              # Wait/delay before next effect
	CUSTOM,             # Custom effect logic
	REMOVE_QUEST,       # Remove/complete this quest
	GIVE_ACHIEVEMENT,   # Grant an achievement
	TRIGGER_EVENT       # Trigger a custom game event
}

@export_group("Effect Definition")
@export var type: EffectType = EffectType.ADD_ITEM
@export var description: String = ""  # Optional description

@export_group("Effect Data")
@export var target_key: String = ""  # Quest ID, item ID, dialogue ID, etc.
@export var amount: int = 1  # Quantity (items, currency, etc.)
@export var metadata: Dictionary = {}  # Additional data for custom effects

@export_group("Timing")
@export var delay_seconds: float = 0.0  # Delay before executing
@export var execute_immediately: bool = true  # Skip delay if true

@export_group("Optional")
@export var icon_override: Texture2D = null
@export var sound_effect: AudioStream = null

## Execute this effect
func execute(context: Object = null) -> void:
	match type:
		EffectType.ADD_ITEM:
			_execute_add_item()
		EffectType.ADD_CURRENCY:
			_execute_add_currency()
		EffectType.START_DIALOGUE:
			_execute_start_dialogue()
		EffectType.START_BATTLE:
			_execute_start_battle()
		EffectType.ADD_STATUS:
			_execute_add_status(context)
		EffectType.CHANGE_SCENE:
			_execute_change_scene()
		EffectType.SAVE_GAME:
			_execute_save_game()
		EffectType.ADD_QUEST:
			_execute_add_quest()
		EffectType.REMOVE_QUEST:
			_execute_remove_quest()
		EffectType.GIVE_ACHIEVEMENT:
			_execute_give_achievement()
		EffectType.CUTSCENE:
			_execute_cutscene()
		EffectType.AWAIT:
			pass  # Handled by quest system
		EffectType.CUSTOM:
			_execute_custom(context)
		EffectType.TRIGGER_EVENT:
			_execute_trigger_event(context)

func _execute_add_item() -> void:
	if PlayerStats and not target_key.is_empty():
		var item = _load_resource(target_key, "res://resources/items/")
		if item:
			PlayerStats.add_item(item, amount)

func _execute_add_currency() -> void:
	if PlayerStats:
		PlayerStats.add_currency(amount)

func _execute_start_dialogue() -> void:
	if not target_key.is_empty():
		var dialogue = _load_resource(target_key, "res://resources/dialogues/")
		if dialogue:
			# Reuse DialogueTrigger's UI and runner setup logic
			var root = Global.get_tree().root.get_child(-1)
			var textbox_node: CanvasLayer = null
			
			# Find or create CanvasLayer for dialogue UI
			for child in root.get_children():
				if child is CanvasLayer and (child.name.contains("textbox") or child.name.contains("Dialogue")):
					textbox_node = child as CanvasLayer
					break
			
			if not textbox_node:
				textbox_node = CanvasLayer.new()
				textbox_node.name = "DialogueContainer"
				root.add_child(textbox_node)
			
			# Create UI instance if needed (same as DialogueTrigger does)
			var ui_instance: Control = null
			for child in textbox_node.get_children():
				if child is Control and child.has_method("connect_to_runner"):
					ui_instance = child
					break
			
			if not ui_instance:
				ui_instance = load("res://scenes/ui/textbox/textbox.tscn").instantiate()
				textbox_node.add_child(ui_instance)
				ui_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
			
			# Clean up any existing runner
			for child in textbox_node.get_children():
				if child is DialogueRunner:
					child.queue_free()
			
			# Create new runner (same as DialogueTrigger does)
			var dialogue_runner = DialogueRunner.new()
			textbox_node.add_child(dialogue_runner)
			
			# Connect signals (same as DialogueTrigger does)
			dialogue_runner.dialogue_started.connect(_on_dialogue_started.bind(ui_instance))
			dialogue_runner.dialogue_ended.connect(_on_dialogue_ended.bind(ui_instance, dialogue_runner))
			
			# Connect UI to runner (same as DialogueTrigger does)
			if ui_instance.has_method("connect_to_runner"):
				ui_instance.connect_to_runner(dialogue_runner)
			
			# Start dialogue (same as DialogueTrigger does)
			dialogue_runner.start(dialogue, DialogueConditionEvaluator.new())

func _on_dialogue_started(_data: Object, ui_instance: Control) -> void:
	ui_instance.visible = true
	# Disable player movement (same as DialogueTrigger does)
	if PlayerStats and PlayerStats.player and PlayerStats.player.has_method("stop_move"):
		PlayerStats.player.stop_move = true
		PlayerStats.player.can_menu = false

func _on_dialogue_ended(_node: DialogueNode, ui_instance: Control, runner: DialogueRunner) -> void:
	ui_instance.visible = false
	# Re-enable player movement (same as DialogueTrigger does)
	if PlayerStats and PlayerStats.player and PlayerStats.player.has_method("stop_move"):
		PlayerStats.player.stop_move = false
		PlayerStats.player.can_menu = true
	# Clean up runner (same as DialogueTrigger does)
	if is_instance_valid(runner):
		runner.queue_free()

func _execute_start_battle() -> void:
	if not target_key.is_empty():
		var battle = _load_resource(target_key, "res://resources/battles/")
		if battle and Global:
			Global.load_battle(battle)

func _execute_add_status(context: Object = null) -> void:
	if context and context.has_method("apply_effect"):
		# Parse metadata for effect details
		var effect_id = metadata.get("effect_id", 0)
		var level = metadata.get("level", 1)
		var duration = metadata.get("duration", 3)
		context.apply_effect(effect_id, level, duration)

func _execute_change_scene() -> void:
	if not target_key.is_empty() and FileAccess.file_exists(target_key):
		var tree = Engine.get_main_loop()
		if tree:
			tree.change_scene_to_file(target_key)

func _execute_save_game() -> void:
	if SaveManager:
		SaveManager.save_game(0, "Quest Autosave")

func _execute_add_quest() -> void:
	if QuestSystem and not target_key.is_empty():
		QuestSystem.add_quest_by_id(target_key)

func _execute_remove_quest(context: Object = null) -> void:
	if QuestSystem:
		if context:
			QuestSystem.complete_quest(context as Quest)

func _execute_give_achievement() -> void:
	if AchievementSystem and not target_key.is_empty():
		AchievementSystem.unlock_achievement(target_key)

func _execute_cutscene() -> void:
	if not target_key.is_empty():
		var cutscene = _load_resource(target_key, "res://resources/cutscenes/")
		if cutscene and cutscene.has_method("play"):
			cutscene.play()

func _execute_custom(context: Object = null) -> void:
	# Call custom logic via signals or metadata
	if metadata.has("callback"):
		var callback = metadata["callback"]
		if callback is Callable:
			callback.call(context)

func _execute_trigger_event(context: Object = null) -> void:
	# Trigger a custom game event
	if not target_key.is_empty():
		if context and context.has_signal("quest_event_triggered"):
			context.emit_signal("quest_event_triggered", target_key, metadata)

## Helper to load resources from common paths
func _load_resource(key: String, base_path: String) -> Resource:
	if key.begins_with("res://"):
		return load(key)
	
	var path = base_path + key + ".tres"
	if ResourceLoader.exists(path):
		return load(path)
	
	# Try with .resource extension
	path = base_path + key + ".resource"
	if ResourceLoader.exists(path):
		return load(path)
	
	return null

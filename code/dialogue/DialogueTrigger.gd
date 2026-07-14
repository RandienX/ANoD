extends Area2D
class_name DialogueTriggerArea2D
## Place this node in your scene, assign a DialogueData resource,
## and it will automatically show the dialogue when the player enters.

@export var dialogue_data: DialogueData
@export var once_per_session: bool = false
@export var require_input_to_finish: bool = true
@export var require_input_to_start: bool = false

var _has_triggered: bool = false
var _is_ending: bool = false

# Reference to your player or input handler
# Optional: if null, we assume global input is handled elsewhere
@export var player_node_path: CharacterBody2D
var _player: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	if player_node_path:
		_player = player_node_path
	
	# Validate data early
	if not dialogue_data:
		push_warning("DialogueTriggerArea2D: No DialogueData assigned!")
	else:
		var validation_errors = dialogue_data.validate()
		if not validation_errors.is_empty():
			for err in validation_errors:
				push_error("DialogueTriggerArea2D: %s" % err)
			

func _input(_event: InputEvent) -> void:
	if DialogueInitiator._dialogue_runner and DialogueInitiator._dialogue_runner.is_running:
		return
	
	if Input.is_action_just_pressed("use") and require_input_to_start and _player in get_overlapping_bodies() and _is_ending == false:
		# Prevent re-triggering while dialogue is already running
		if _is_ending:
			_is_ending = false
			return
	
		if once_per_session and _has_triggered:
			return
		_has_triggered = true
		DialogueInitiator.trigger_start_dialogue(dialogue_data, self, once_per_session, require_input_to_finish)
		
	elif Input.is_action_just_pressed("use") and _is_ending:
		_is_ending = false
		return

func _on_body_entered(body: Node) -> void:
	if _player and body != _player:
		return
	
	if require_input_to_start:
		return
	
	if (once_per_session and _has_triggered):
		return
	
	if DialogueInitiator._dialogue_runner and DialogueInitiator._dialogue_runner.is_running:
		return
	
	if get_tree():
		if name in get_tree().current_scene.textboxes_deactivated:
			return
	
	_has_triggered = true
	DialogueInitiator.trigger_start_dialogue(dialogue_data, self, once_per_session, require_input_to_finish)

func _on_dialogue_started(_data: Object) -> void:
	# Disable player movement if you have a player reference
	if _player:
		_player.stop_move = true
		_player.can_menu = false

func _on_dialogue_ended(node: DialogueNode) -> void:
	if _is_ending:
		return
	_is_ending = true
	
	# Re-enable player movement
	if _player:
		_player.stop_move = false
		_player.can_menu = true
	if once_per_session:
		get_tree().current_scene.textboxes_deactivated.append(self.name)
	
	if get_tree():
		if get_tree().current_scene.has_method("outbattle_root_check") and node:
			get_tree().current_scene.completed_dialogues.append(name+"_"+node.label)
	
func _exit_tree() -> void:
	if DialogueInitiator._dialogue_runner == null:
		return
	if once_per_session and DialogueInitiator._dialogue_runner.data == dialogue_data:
		get_tree().current_scene.textboxes_deactivated.append(self.name)

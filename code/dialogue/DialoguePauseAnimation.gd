extends AnimationPlayer

@export var dialogue_data: Array[DialogueData]
@export var textbox_node: CanvasLayer
@export var require_input_to_finish: bool = true

var _has_triggered: bool = false
var _dialogue_runner: DialogueRunner
var _ui_instance: Control
var _is_ending: bool = false

@export_node_path("Node") var player_node_path: NodePath
var _player: Node

func _ready() -> void:
	if player_node_path:
		_player = get_node_or_null(player_node_path)
	
	# Validate data early
	if not dialogue_data:
		push_warning("DialogueTriggerArea2D: No DialogueData assigned!")
	else:
		for d in dialogue_data:
			var validation_errors = d.validate()
			if not validation_errors.is_empty():
				for err in validation_errors:
					push_error("DialogueTriggerArea2D: %s" % err)
				
	if get_tree().current_scene.has_node("Dialogue"):
		if get_tree().current_scene.get_node("Dialogue").get_children().size() > 1:
			_ui_instance = get_tree().current_scene.get_node("Dialogue").get_child(1)

func start_dialogue_id(dialogue_id: int) -> void:
	_has_triggered = true
	pause()
	_start_dialogue(dialogue_data[dialogue_id])

func _start_dialogue(dialogue: DialogueData) -> void:
	if not dialogue or dialogue.nodes.is_empty():
		push_error("DialogueTriggerArea2D: Cannot start - invalid dialogue data")
		return
	
	# Create UI if needed
	if not _ui_instance:
		_ui_instance = preload("res://scenes/ui/textbox/textbox.tscn").instantiate()
		textbox_node.add_child(_ui_instance)
		_ui_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Create runner
	_dialogue_runner = DialogueRunner.new()
	_ui_instance.add_child(_dialogue_runner)
	
	# Connect signals
	_dialogue_runner.dialogue_started.connect(_on_dialogue_started)
	_dialogue_runner.node_entered.connect(_on_node_displayed)
	_dialogue_runner.dialogue_ended.connect(_on_dialogue_ended)
	
	_ui_instance.connect_to_runner(_dialogue_runner)
	
	# Start dialogue
	_dialogue_runner.start(dialogue, DialogueConditionEvaluator.new())
	
	if name in get_tree().root.get_child(-1).textboxes_deactivated:
		_on_dialogue_ended()

func _on_dialogue_started(_data: Object) -> void:
	_ui_instance.visible = true

func _on_node_displayed(node: DialogueNode) -> void:
	_ui_instance.display_node(node)

func _on_dialogue_ended(node: DialogueNode = DialogueNode.new()) -> void:
	if _is_ending:
		return
	_is_ending = true
	
	_ui_instance.visible = false
	
	# Clean up
	if _dialogue_runner:
		_dialogue_runner.queue_free()
		_dialogue_runner = null
	
	if !get_tree().current_scene.completed_dialogues.has(str(self.name + "_" + node.label)):
		get_tree().current_scene.completed_dialogues.append(str(self.name + "_" + node.label))
	
	play()

func _input(event: InputEvent) -> void:
	if not _dialogue_runner or not _dialogue_runner.is_running:
		return
	
	if require_input_to_finish:
		if event.is_action_pressed("use") or event is InputEventMouseButton and event.pressed:
			_dialogue_runner.advance()

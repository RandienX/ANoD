extends Node

@export var textbox_node: CanvasLayer
@export var once_per_session: bool = false
@export var require_input_to_finish: bool = true
var starting = false

var _dialogue_runner: DialogueRunner
var _ui_instance: Control

func _ready() -> void:
	if get_tree().current_scene is RootScene:
		textbox_node = get_tree().current_scene.get_node("Dialogue")
		if textbox_node.has_node("textbox"):
			_ui_instance = textbox_node.get_node("textbox")
		else:
			var ui = preload("res://scenes/ui/textbox/textbox.tscn").instantiate()
			textbox_node.add_child(ui)
			_ui_instance = ui

func _input(_event: InputEvent) -> void:
	if starting:
		await get_tree().create_timer(0.05).timeout
		starting = false
		
func trigger_start_dialogue(dialogue_data, trigger, ops, ritf):
	if trigger.name in get_tree().current_scene.textboxes_deactivated:
		return
		
	starting = true
	textbox_node = get_tree().current_scene.get_node("Dialogue")
	if textbox_node.has_node("textbox"):
		_ui_instance = textbox_node.get_node("textbox")
	else:
		var ui = preload("res://scenes/ui/textbox/textbox.tscn").instantiate()
		textbox_node.add_child(ui)
		_ui_instance = ui
		
	_dialogue_runner = DialogueRunner.new()
	_ui_instance.add_child(_dialogue_runner)
	
	_dialogue_runner.dialogue_started.connect(trigger._on_dialogue_started)
	_dialogue_runner.dialogue_ended.connect(trigger._on_dialogue_ended)
	
	start_dialogue(dialogue_data, ops, ritf)

func start_dialogue(dialogue_data, ops: bool, ritf: bool) -> void:
	if not dialogue_data or dialogue_data.nodes.is_empty():
		push_error("DialogueTriggerArea2D: Cannot start - invalid dialogue data")
		return
	
	once_per_session = ops
	require_input_to_finish = ritf
		
	if _dialogue_runner == null:
		textbox_node = get_tree().current_scene.get_node("Dialogue")
		if textbox_node.has_node("textbox"):
			_ui_instance = textbox_node.get_node("textbox")
		else:
			var ui = preload("res://scenes/ui/textbox/textbox.tscn").instantiate()
			textbox_node.add_child(ui)
			_ui_instance = ui
		_dialogue_runner = DialogueRunner.new()
		_ui_instance.add_child(_dialogue_runner)
	
	if !_dialogue_runner.is_connected("dialogue_started", _on_dialogue_started):
		_dialogue_runner.dialogue_started.connect(_on_dialogue_started)
		_dialogue_runner.node_entered.connect(_on_node_displayed)
		_dialogue_runner.dialogue_ended.connect(_on_dialogue_ended)
	
	_ui_instance.connect_to_runner(_dialogue_runner)
	starting = true
	
	_dialogue_runner.start(dialogue_data)

func _on_dialogue_started(_data: Object) -> void:
	_ui_instance.visible = true

func _on_node_displayed(node: DialogueNode) -> void:
	_ui_instance.display_node(node)

func _on_dialogue_ended(_node) -> void:
	_ui_instance.visible = false
	
	if _dialogue_runner:
		_dialogue_runner.queue_free()
		_dialogue_runner = null
		
	if get_tree().current_scene:
		if get_tree().current_scene.name == "BattleEngine":
			get_tree().current_scene.state = get_tree().current_scene.states.OnAction
	if get_tree().current_scene:
		if get_tree().current_scene.name == "Shop":
			get_viewport().set_input_as_handled()
			get_tree().current_scene.input_blocked = false

class_name DialogueRunner
extends Node

## Runtime dialogue executor
## Manages flow, evaluates conditions, emits signals for UI

signal dialogue_started(_data: Object)
signal node_entered(node: DialogueNode)
signal text_displayed(text: String)
signal choice_available(choice: DialogueChoice)
signal choice_selected(choice: DialogueChoice)
signal dialogue_ended(last_node: Object)

var data: Object #DialogueData
var current_node: DialogueNode
var current_label: String
var is_running: bool = false


func start(dialogue_data: DialogueData) -> void:
	data = dialogue_data
	
	if not data:
		push_error("DialogueRunner: No dialogue data provided")
		return
	
	var errors = data.validate()
	if not errors.is_empty():
		for err in errors:
			push_warning("Dialogue validation: %s" % err)
	
	current_label = data.start_label
	if data.start_branches:
		for branch in data.start_branches:
			if branch.evaluate() == true:
				current_label = branch.target_label
				break
	
	is_running = true
	
	dialogue_started.emit(data)
	_goto_label(current_label)

func _goto_label(label: String) -> void:
	var node = data.get_node_by_label(label)
	if not node:
		if label != "":
			push_error("DialogueRunner: Node not found: '%s'" % label)
		end_dialogue()
		return
	
	current_node = node
	current_label = label
	
	await _run_effects(node.on_enter_effects)
	
	node_entered.emit(node)
	text_displayed.emit(node.text)
	
	if node.has_choices():
		for choice in node.choices:
			if choice.is_available() == true:
				choice_available.emit(choice)

func advance() -> void:
	if not is_running or not current_node:
		return
	
	await _run_effects(current_node.on_exit_effects)
	
	if current_node.unskippable == true:
		return
	
	if current_node.has_branches():
		for branch in current_node.branches:
			if branch.evaluate() == true:
				_goto_label(branch.target_label)
				return
	
	if current_node.has_choices():
		return  
	
	if not current_node.next_label.is_empty():
		_goto_label(current_node.next_label)
	else:
		end_dialogue()

func select_choice(choice: DialogueChoice) -> void:
	if not is_running or not current_node:
		return
		
	choice_selected.emit(choice)
	
	var label = choice.get_target_label()
	if label.is_empty():
		push_error("DialogueRunner: Choice '%s' has no target label or availability branch target." % choice.text)
		end_dialogue()
		return
		
	_goto_label(label)

func end_dialogue() -> void:
	if not is_running:
		return
	
	is_running = false
	var last_node = current_node
	current_node = null
	current_label = ""
	
	dialogue_ended.emit(last_node)
	
func _run_effects(effects: Array[Effect]) -> void:
	for effect in effects:
		if not effect:
			continue
		
		await effect.execute()
		
	return

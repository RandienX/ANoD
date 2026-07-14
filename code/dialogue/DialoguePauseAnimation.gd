extends AnimationPlayer

@export var dialogue_data: Array[DialogueData]
@export var require_input_to_finish: bool = true

var _has_triggered: bool = false
var _is_ending: bool = false

var dialogue_only = false
var dialogue_index = 0

func _ready() -> void:
	# Validate data early
	if not dialogue_data:
		push_warning("DialogueTriggerArea2D: No DialogueData assigned!")
	else:
		for d in dialogue_data:
			var validation_errors = d.validate()
			if not validation_errors.is_empty():
				for err in validation_errors:
					push_error("DialogueTriggerArea2D: %s" % err)

func _process(_delta: float) -> void:
	if _is_ending:
		stop()

func start_dialogue_id(dialogue_id: int) -> void:
	_has_triggered = true
	pause()
	DialogueInitiator.trigger_start_dialogue(dialogue_data[dialogue_id], self, false, require_input_to_finish)

func _on_dialogue_started(_data: Object) -> void:
	DialogueInitiator._ui_instance.visible = true

func _on_dialogue_ended(node: DialogueNode = DialogueNode.new()) -> void:
	DialogueInitiator._ui_instance.visible = false
	
	if !get_tree().current_scene.completed_dialogues.has(str(self.name + "_" + node.label)):
		get_tree().current_scene.completed_dialogues.append(str(self.name + "_" + node.label))
	
	play()
	
func force_remove_runner():
	if DialogueInitiator._dialogue_runner:
		DialogueInitiator._dialogue_runner.queue_free()
		DialogueInitiator._dialogue_runner = null

func _on_animation_finished(_anim_name: StringName) -> void:
	_is_ending = true

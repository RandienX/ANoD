extends Control

var saving = true

func _ready() -> void:
	$ScrollContainer/VBoxContainer/autosave.saving = false

func save_update() -> void:
	for c in $ScrollContainer/VBoxContainer.get_children():
		if c.name != "autosave":
			c.saving = saving

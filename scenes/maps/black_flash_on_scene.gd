extends ColorRect

func _ready() -> void:
	if has_node("Label"):
		$Label.visible = true
		$Label.text = get_tree().current_scene.room_name
	remove()

func reappear() -> void:
	modulate.a = 0
	var tween = get_tree().create_tween().bind_node(self).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "modulate:a", 1, 0.4)
	await get_tree().create_timer(0.6).timeout
	return

func remove() -> void:
	modulate.a = 1
	print(get_tree().current_scene.room_name)
	var tween = get_tree().create_tween().bind_node(self).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "modulate:a", 0, 0.8)
	await get_tree().create_timer(1.2).timeout
	if has_node("Label"):
		$Label.visible = false
	return

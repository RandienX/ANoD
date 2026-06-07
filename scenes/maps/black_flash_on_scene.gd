extends ColorRect

func _ready() -> void:
	self_modulate.a = 1
	await get_tree().create_timer(0.1).timeout
	var tween = get_tree().create_tween().bind_node(self).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "self_modulate:a", 0, 0.4)

func reappear() -> void:
	self_modulate.a = 0
	var tween = get_tree().create_tween().bind_node(self).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "self_modulate:a", 1, 0.4)
	await get_tree().create_timer(0.6).timeout
	return

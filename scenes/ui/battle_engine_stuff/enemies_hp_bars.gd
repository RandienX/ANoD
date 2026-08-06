extends TextureRect

@export var enemy_slot: BattleEnemySlot
@export var enemy: Entity
var effect_container: GridContainer
const EFFECT_ATLAS_PATH = "res://assets/battleui/status_effects.png"
const EFFECT_TILE_SIZE = 64
const EFFECT_COLS = 4

var previous_hp = 100
var battle_start = false

var hp: int
var mp: int
var max_hp: int
var max_mp: int

var preset_positions: Dictionary[BattleEnemySlot.PosPresets, Vector2] = {
	BattleEnemySlot.PosPresets.FAR_LEFT: Vector2(108, 342),
	BattleEnemySlot.PosPresets.LEFT: Vector2(216, 342),
	BattleEnemySlot.PosPresets.LITTLE_LEFT: Vector2(324, 342),
	BattleEnemySlot.PosPresets.TOP_LITTLE_LEFT: Vector2(324, 150),
	BattleEnemySlot.PosPresets.CENTRE: Vector2(432, 342),
	BattleEnemySlot.PosPresets.TOP_LITTLE_RIGHT: Vector2(540, 150),
	BattleEnemySlot.PosPresets.LITTLE_RIGHT: Vector2(540, 342),
	BattleEnemySlot.PosPresets.RIGHT: Vector2(648, 342),
	BattleEnemySlot.PosPresets.FAR_RIGHT: Vector2(756, 342),
}

func _ready() -> void:
	effect_container = $EffectContainer
	previous_hp = enemy.stats["hp"]
	texture = enemy.portrait
	z_index = enemy_slot.z_index
	
	hp = enemy.stats["hp"]
	mp = enemy.stats["mp"]
	max_hp = enemy.max_stats["hp"]
	max_mp = enemy.max_stats["mp"]
	
	$EffekseerEmitter2D.target_position = texture.get_size() / Vector2(2,2)
	if enemy_slot.connected_to_idx != -1:
		await get_tree().create_timer(0.05).timeout
		get_parent().get_child(enemy_slot.connected_to_idx).ready_connect_stats(enemy)
		$VBoxContainer.visible = false
		$NinePatchRect.visible = false
		$name.visible = false

func _physics_process(_delta: float) -> void:
	if enemy:
		if battle_start and Settings.show_damage_numbers:
			if enemy_slot.connected_to_idx != -1:
				get_parent().get_child(enemy_slot.connected_to_idx).update_connected_stats(enemy)
			check_hp_change()
		
		if enemy_slot.ui_position != Vector2(0, 0):
			global_position = enemy_slot.ui_position
		else:
			@warning_ignore("integer_division")
			global_position = preset_positions[enemy_slot.ui_position_preset] - Vector2(texture.get_width()/2/1.33, texture.get_height()/2)
			@warning_ignore("integer_division")
			global_position = preset_positions[enemy_slot.ui_position_preset] - Vector2(texture.get_width()/2/1.33, texture.get_height()/2)
		
		hp = enemy.stats["hp"]
		mp = enemy.stats["mp"]
		max_hp = enemy.max_stats["hp"]
		max_mp = enemy.max_stats["mp"]
		if enemy_slot.connected_to_idx == -1:
			$VBoxContainer/hp.value = hp
			$VBoxContainer/hp.max_value = max_hp
			$VBoxContainer/mp.value = mp
			$VBoxContainer/mp.max_value = max_mp
			$name.text = enemy.name
			$name/NinePatchRect2.size.x = $name.size.x + 6
		battle_start = true
		
	else:
		visible = false
	update_effects_ui()

func ready_connect_stats(connecting_enemy):
	hp += connecting_enemy.stats["hp"]
	mp += connecting_enemy.stats["mp"]
	
	max_hp += connecting_enemy.max_stats["hp"]
	max_mp += connecting_enemy.max_stats["mp"]
	
func update_connected_stats(connecting_enemy):
	hp += connecting_enemy.stats["hp"]
	mp += connecting_enemy.stats["mp"]
	hp -= connecting_enemy.max_stats["hp"]
	mp -= connecting_enemy.max_stats["mp"]
	
## Updates status effects display for enemy
func update_effects_ui() -> void:
	for child in effect_container.get_children():
		child.queue_free()

	if enemy:
		# Use new status system API
		for status_id in enemy.get_active_status_ids():
			var stacks = enemy.get_status_stacks(status_id)
			var duration = enemy.get_status_duration(status_id)
			var status_data = enemy._statuses.get(status_id)
			
			if status_data and status_data.has("definition"):
				var status_def = status_data["definition"] as StatusDefinition

				# Create icon using status definition's icon if available
				var icon: TextureRect
				if status_def.icon != null:
					icon = create_effect_icon_from_texture(status_def.icon)

				if icon:
					# Add stack count label if stacked
					if stacks > 1:
						var stack_label = Label.new()
						stack_label.text = "x" + str(stacks)
						stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
						stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
						stack_label.add_theme_color_override("font_shadow_color", Color.BLACK)
						stack_label.add_theme_constant_override("shadow_offset_x", 1)
						stack_label.add_theme_constant_override("shadow_offset_y", 1)
						stack_label.add_theme_font_size_override("font_size", 8)
						icon.add_child(stack_label)
						stack_label.set_anchors_preset(Control.PRESET_FULL_RECT)

						# Add duration tooltip
						icon.tooltip_text = "%s\nDuration: %d turn(s)" % [status_def.name if not status_def.name.is_empty() else status_id, duration]

					effect_container.add_child(icon)

## Creates an effect icon from a Texture2D resource
func create_effect_icon_from_texture(tex: Texture2D) -> TextureRect:
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(EFFECT_TILE_SIZE, EFFECT_TILE_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = tex
	return icon

func check_hp_change():
	if enemy.stats["hp"] < previous_hp:
		create_dmg_label(previous_hp-enemy.stats["hp"], Color.WHITE_SMOKE, Color.BLACK)
	elif enemy.stats["hp"] > previous_hp:
		create_dmg_label(enemy.stats["hp"]-previous_hp, Color.LIME_GREEN, Color.CORNSILK)
	previous_hp = enemy.stats["hp"]
		
func create_dmg_label(dmg: int, color: Color, outline: Color):
	var label = Label.new()
	label.label_settings = load("res://scenes/ui/battle_engine_stuff/dmg_label_settings.tres").duplicate_deep()
	label.label_settings.font_color = color
	label.label_settings.outline_color = outline
	label.text = str(dmg)
	label.z_index = z_index + 5
	label.position = texture.get_size() / Vector2(2,2)
	add_child(label)
	var tween = get_tree().create_tween().bind_node(label)
	var x_offset = randi_range(-20, 20)
	var y_offset = randi_range(-10, 40)
	tween.tween_property(label, "position", Vector2(label.position.x + x_offset, label.position.y - y_offset - 25), 0.1)
	await tween.finished
	tween = get_tree().create_tween().bind_node(label)
	tween.tween_property(label, "position", Vector2(label.position.x + x_offset, label.position.y + y_offset + 25), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.5).timeout
	label.queue_free()

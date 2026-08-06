extends Control

## Party Battle Face UI Component
## Displays a party member's battle stats using the partyBattleFace.tscn scene
## Supports both direct Entity resource and BattleTypes.BattleActor wrapper

var party_member: Entity
var effect_container: GridContainer
var hp_label: Label
var mp_label: Label
var hp_bar: ProgressBar
var mp_bar: ProgressBar
const EFFECT_ATLAS_PATH = "res://assets/battleui/status_effects.png"
const EFFECT_TILE_SIZE = 64
const EFFECT_COLS = 4

var previous_hp = 100
var battle_start = false

@onready var vfx_emitter: EffekseerEmitter2D = $EffekseerEmitter2D


func _ready() -> void:
	hp_label = $MarginContainer/GridContainer/HPAMOUNT
	mp_label = $MarginContainer/GridContainer/MPAMOUNT
	hp_bar = $MarginContainer/GridContainer/HPAMOUNT/ProgressBar
	mp_bar = $MarginContainer/GridContainer/MPAMOUNT/ProgressBar
	effect_container = $EffectContainer

## Setup with an Entity resource directly
func setup(data: Entity) -> void:
	party_member = data
	$Sprite2D.texture = party_member.portrait
	if party_member.portrait_rect != Rect2(0,0,0,0):
		$Sprite2D.region_rect = party_member.portrait_rect
	$EffekseerEmitter2D.speed = Settings.battle_speed
	if vfx_emitter:
		vfx_emitter.playing = false
		vfx_emitter.effect = null

func _process(_delta: float) -> void:
	if party_member:
		# Use direct party resource data
		if battle_start and Settings.show_damage_numbers:
			check_hp_change()
		hp_label.text = str(party_member.stats["hp"], "/", party_member.max_stats["hp"])
		mp_label.text = str(party_member.stats["mp"], "/", party_member.max_stats["mp"])
		hp_bar.max_value = party_member.max_stats["hp"]
		mp_bar.max_value = party_member.max_stats["mp"]
		hp_bar.value = party_member.stats["hp"]
		mp_bar.value = party_member.stats["mp"]       
		if party_member.portrait:
			$Sprite2D.texture = party_member.portrait
			$Sprite2D.region_rect = party_member.portrait_rect
		update_effects_ui()
		battle_start = true
		previous_hp = party_member.stats["hp"]

## Updates status effects display from BattleTypes.BattleActor
func update_effects_ui() -> void:
	for child in effect_container.get_children():
		child.queue_free()
	
	if party_member:
		# Use new status system API
		for status_id in party_member.get_active_status_ids():
			var stacks = party_member.get_status_stacks(status_id)
			var duration = party_member.get_status_duration(status_id)
			var status_data = party_member._statuses.get(status_id)
			
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
	if party_member.stats["hp"] < previous_hp:
		create_dmg_label(previous_hp-party_member.stats["hp"], Color.WHITE_SMOKE, Color.BLACK)
	elif party_member.stats["hp"] > previous_hp:
		create_dmg_label(party_member.stats["hp"]-previous_hp, Color.LIME_GREEN, Color.CORNSILK)
		
func create_dmg_label(dmg: int, color: Color, outline: Color):
	var label = Label.new()
	label.label_settings = load("res://scenes/ui/battle_engine_stuff/dmg_label_settings.tres").duplicate_deep()
	label.label_settings.font_color = color
	label.label_settings.outline_color = outline
	label.label_settings.font_size = 12
	label.text = str(dmg)
	label.position = $Sprite2D.texture.get_size() / Vector2(6,2)
	label.z_index = 20
	label.label_settings.font_size *= 2
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

func update_vfx(vfx: VisualEffect) -> void:
	# Add the same safety check that play_vfx has
	if not vfx or not vfx.effect: 
		print("WARNING: update_vfx called with null effect for ", party_member.name)
		return
		
	vfx_emitter.effect = vfx.effect
	vfx_emitter.speed = vfx.speed * Settings.battle_speed * 0.8
	vfx_emitter.color = vfx.color
	vfx_emitter.target_position = vfx_emitter.global_position + vfx.position_offset
	vfx_emitter.orientation = vfx.orientation
	vfx_emitter.flip_h = vfx.flip_h
	vfx_emitter.flip_v = vfx.flip_v
	vfx_emitter.play()
	
	await get_tree().process_frame
	while vfx_emitter.is_playing() and is_instance_valid(vfx_emitter):
		await get_tree().process_frame

extends MarginContainer
class_name SkillBox

var name_label: Label
var mana_label: Label
var hp_label: Label
var tp_label: Label
var can_select

var skill: Skill
var skill_index: int = 0
var affordable: bool = true

func _ready() -> void:
	name_label = $HSplitContainer/name
	mana_label = $HSplitContainer/HBoxContainer/mana_cost
	hp_label = $HSplitContainer/HBoxContainer/hp_cost
	tp_label = $HSplitContainer/HBoxContainer/tp_cost
	mana_label.visible = false
	hp_label.visible = false
	tp_label.visible = false
	
	custom_minimum_size = Vector2(370, 70)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	$NinePatchRect.visible = false
	

func setup(skill_: Skill, index: int, is_affordable: bool):
	skill = skill_
	skill_index = index
	affordable = is_affordable
	
	if skill:
		name_label.text = skill.skill_name
		if skill.mana_cost > 0:
			mana_label.visible = true
			mana_label.text = str(skill.mana_cost) + " MP"
			name_label.custom_minimum_size.x -= 25
			name_label.custom_maximum_size.x -= 25
		if skill.hp_cost > 0:
			hp_label.visible = true
			hp_label.text = str(skill.hp_cost) + " HP"
			name_label.custom_minimum_size.x -= 25
			name_label.custom_maximum_size.x -= 25
		if skill.tp_cost > 0:
			tp_label.visible = true
			tp_label.text = str(skill.tp_cost) + " TP"
			name_label.custom_minimum_size.x -= 25
			name_label.custom_maximum_size.x -= 25
		if affordable:
			modulate = Color(1, 1, 1)
		else:
			modulate = Color(0.5, 0.5, 0.5)
	Global.lower_font(name_label)

func _on_nine_patch_rect_focus_exited() -> void:
	$NinePatchRect.visible = false
	Global.lower_font(name_label)

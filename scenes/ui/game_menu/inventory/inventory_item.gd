extends Control

@export var config: InventoryItemConfig
@export var item: Item
@export var amount: int
@onready var item_display_name = $HBoxContainer/Item/NinePatchRect/ItemName
@onready var item_display_texture = $HBoxContainer/Item/NinePatchRect/ItemTexture
@onready var item_display_amount = $HBoxContainer/Amount/Label
@onready var item_button = $HBoxContainer/Item

var item_type: String
var party_member: Entity

func _ready() -> void:
	# Apply config settings if available
	if config:
		custom_minimum_size = config.min_size
		if item_display_name:
			item_display_name.theme.default_font_size = config.name_font_size
	
	redisplay()
	
func redisplay():
	item_display_name.text = item.item_name
	item_display_name.custom_minimum_size = Vector2(138, 0)
	item_display_texture.texture = item.texture
	item_display_amount.text = "x" + str(amount)
	Global.lower_font($HBoxContainer/Item/NinePatchRect/ItemName)
	
	if amount <= 0:
		queue_free()

func _on_item_pressed() -> void:
	Sfx.stream = load("res://assets/sound/sfx/select.wav")
	Sfx.play()
	$"../../../../../../..".on_item_button_pressed(item, amount)

func _on_delete_pressed() -> void:
	Sfx.stream = load("res://assets/sound/sfx/select.wav")
	Sfx.play()
	amount -= 1
	PlayerStats.remove_item(item)
	redisplay()
	
func _on_delete_mouse_entered() -> void:
	Sfx.stream = load("res://assets/sound/sfx/button_squeak.wav")
	Sfx.play()

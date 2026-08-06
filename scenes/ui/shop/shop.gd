@tool
extends Control
class_name ShopUI
## ShopUI Controller - Main shop scene controller attached to shop.tscn root
## Handles shop data loading, item card instantiation, purchase/sell logic, and dialogue

signal shop_closed()

@onready var currency_label: Label = $HBoxContainer/ColorRect/MarginContainer/VBoxContainer/Currencies
@onready var category_container: GridContainer = $HBoxContainer/ColorRect/MarginContainer/VBoxContainer/ItemCategoryButtons
@onready var items_container: VBoxContainer = $HBoxContainer/ColorRect/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer
@onready var exit_button: Button = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/buttons/VBoxContainer/Exit
@onready var buy_button: Button = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/buttons/VBoxContainer/Buy
@onready var talk_button: Button = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/buttons/VBoxContainer/Talk
@onready var sell_button: Button = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/buttons/VBoxContainer/Sell
@onready var question_container: GridContainer = $"HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/MarginContainer/ScrollContainer/TextContainer"
@onready var dialogue_label: RichTextLabel = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/MarginContainer/ColorRect/RichTextLabel

# === Preloaded Scenes ===
const SHOP_ITEM_CARD_SCENE: PackedScene = preload("res://scenes/ui/shop/shop_item_card.tscn")

# === Export Variables (Editor Integration) ===
@export var shop_data: ShopData
@export var chars_per_second: float = 30.0  # Typewriter speed

# === State Variables ===
var current_filter: Item.ItemType = Item.ItemType.Consumable
var item_cards: Array[ShopItemCard] = []
var sell_cards: Array[ShopItemCard] = []  # Cards for sell tab
var current_mode: String = "buy"  # "buy", "sell", "talk"

# Talk mode state
var talk_option_buttons: Array[Button] = []
var input_blocked: bool = false


func _ready() -> void:
	_connect_signals()
	shop_data = Global.shop_current 
	load_shop(shop_data)
	BackgroundMusic.stream = shop_data.shop_music
	BackgroundMusic.play()
	
## Get items sorted by sort_order
func get_sorted_items(filter_tag: Item.ItemType = Item.ItemType.Consumable) -> Array[ShopItemCard]:
	var result = get_items(filter_tag)
	result.sort_custom(func(a: ShopItem, b: ShopItem): return a.sort_order < b.sort_order)
	return result
	
## Get all items, optionally filtered by tag/category
func get_items(filter_tag: Item.ItemType = Item.ItemType.Consumable) -> Array[ShopItemCard]:
	var filtered: Array[ShopItemCard] = []
	for shop_item in item_cards:
		if shop_item.has_tag(filter_tag):
			filtered.append(shop_item)
	return filtered

func _connect_signals() -> void:
	if exit_button:
		exit_button.pressed.connect(_on_close_button_pressed)
	
	if buy_button:
		buy_button.pressed.connect(_on_buy_tab_pressed)
	
	if talk_button:
		talk_button.pressed.connect(_on_talk_tab_pressed)
	
	if sell_button:
		sell_button.pressed.connect(_on_sell_tab_pressed)

func load_shop(data: ShopData) -> void:
	if not data:
		push_error("ShopUI: Attempted to load null ShopData")
		return
	
	shop_data = data
	_setup_shop_ui()
	_update_currency_display()
	_create_category_buttons()
	_setup_items_grid()

func _setup_shop_ui() -> void:
	if not shop_data:
		return
	
	# Note: shop title and description are not in the current scene structure
	# They could be added to the talk box RichTextLabel if neededs

func _create_category_buttons() -> void:
	for child in category_container.get_children():
		child.queue_free()
	
	if not shop_data:
		return
	
	for category in range(len(Item.ItemType)):
		if category != Item.ItemType.Key:
			var btn = Button.new()
			btn.text = str(Item.ItemType.keys()[category])
			btn.toggle_mode = true
			btn.custom_minimum_size = Vector2(138, 50)
			btn.pressed.connect(_on_category_button_pressed.bind(category))
		
			if category == 2: #Consumable
				btn.button_pressed = true
			
			category_container.add_child(btn)

func _setup_items_grid() -> void:
	item_cards.clear()
	_clear_all_cards()
	
	if not shop_data:
		return
	
	var items = get_sorted_items(current_filter)
	
	for shop_item in shop_data.items:
		if shop_item.item.type == current_filter:
			var card = SHOP_ITEM_CARD_SCENE.instantiate() as ShopItemCard
			
			items_container.add_child(card)
			card.setup(shop_item)
			item_cards.append(card)

func filter_by_tag(tag: Item.ItemType) -> void:
	current_filter = tag
	_setup_items_grid()

func _update_currency_display() -> void:
	if not currency_label:
		return
	
	if not PlayerStats:
		currency_label.text = "Gold:\nShit:\nFazTokens:"
		return
	
	var stats = PlayerStats
	currency_label.text = "Gold: %d\nShit: %d\nFazTokens: %d" % [stats.gold, stats.shit, stats.tokens]

## Add purchased item to player inventory
func _add_item_to_inventory(item: Item, quantity: int) -> void:
	PlayerStats.add_item(item, quantity)

## Refresh all item cards (call after purchase or currency change)
func _refresh_all_cards() -> void:
	for card in item_cards:
		card.refresh()

## Handle category button press
func _on_category_button_pressed(category: Item.ItemType) -> void:
	Sfx.stream = load("res://assets/sound/sfx/select.wav")
	Sfx.play()
	filter_by_tag(category)
	
	# Update button states
	for child in category_container.get_children():
		if child is Button:
			child.button_pressed = (child.text.to_lower() == str(Item.ItemType.keys()[category]).capitalize().to_lower())
			
## Close button handler
func _on_close_button_pressed() -> void:
	Sfx.stream = load("res://assets/sound/sfx/select.wav")
	Sfx.play()
	shop_closed.emit()

## Refresh shop with new data (hot-swap)
func refresh_shop(new_data: ShopData) -> void:
	load_shop(new_data)

func _on_buy_tab_pressed() -> void:
	Sfx.stream = load("res://assets/sound/sfx/select.wav")
	Sfx.play()
	if current_mode == "buy":
		return
	current_mode = "buy"
	_clear_all_cards()
	_setup_items_grid()
	_update_button_states()
	$"HBoxContainer/ColorRect/MarginContainer/VBoxContainer/ItemCategoryButtons".visible = true
	
# ========== SELL TAB ==========

func _on_sell_tab_pressed() -> void:
	Sfx.stream = load("res://assets/sound/sfx/select.wav")
	Sfx.play()
	if current_mode == "sell":
		return
	current_mode = "sell"
	_clear_all_cards()
	_setup_sell_grid()
	_update_button_states()

## Setup the sell grid by pulling items from PlayerStats.inventory
func _setup_sell_grid() -> void:
	for card in sell_cards:
		if is_instance_valid(card):
			card.queue_free()
			sell_cards.clear()

	if not PlayerStats or PlayerStats.inventory.is_empty():
		_show_empty_sell_message()
		return

	for item: Item in PlayerStats.inventory.keys():
		if item == null: continue
		if item.type != Item.ItemType.Key:
			var amount: int = PlayerStats.inventory[item]
			if amount <= 0 or not item:
				continue
			
			var card = _create_sell_card(item, amount)
			if card:
				sell_cards.append(card)

## Create a sell card for an inventory item
func _create_sell_card(item: Item, amount: int) -> ShopItemCard:
	if not SHOP_ITEM_CARD_SCENE:
		push_error("ShopUI: SHOP_ITEM_CARD_SCENE not loaded")
		return null

	var card = SHOP_ITEM_CARD_SCENE.instantiate() as ShopItemCard
	if not card:
		push_error("ShopUI: Failed to instantiate SellItemCard")
		return null
	items_container.add_child(card)
	
	card.setup_for_sell(item, amount)
	card.set_disabled(false)
	return card

## Show a message when inventory is empty
func _show_empty_sell_message() -> void:
	var label = Label.new()
	label.text = "Your inventory is empty.\nNothing to sell!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	items_container.add_child(label)

## Refresh the sell grid after a sale
func _refresh_sell_grid() -> void:
	_clear_all_cards()
	_setup_sell_grid()

# ========= TALK TAB =========

func _on_talk_tab_pressed() -> void:
	Sfx.stream = load("res://assets/sound/sfx/select.wav")
	Sfx.play()
	if current_mode == "talk":
		return
	current_mode = "talk"
	_clear_all_cards()
	_setup_talk_ui()
	_update_button_states()


## Setup the talk UI with dialogue buttons
func _setup_talk_ui() -> void:
	if not question_container:
		push_error("ShopUI: question_container not found - cannot setup talk UI")
		return
	
	for c in question_container.get_children():
		c.queue_free()
	for key in shop_data.talk_responses.keys():
		var button = _create_talk_button(key)
		if button:
			talk_option_buttons.append(button)
			question_container.add_child(button)

## Create a single talk button
func _create_talk_button(option_key: String) -> Button:
	var button = Button.new()
	button.text = option_key
	button.autowrap_mode = TextServer.AUTOWRAP_WORD
	button.pressed.connect(_on_talk_option_selected.bind(option_key))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size.x = 192
	button.custom_maximum_size.x = 192
	return button

## Handle talk option selection
func _on_talk_option_selected(option_key: String) -> void:
	if input_blocked:
		return  # Prevent rapid clicking during typing

	# Disable input during typing
	input_blocked = true
	
	Sfx.stream = load("res://assets/sound/sfx/select.wav")
	Sfx.play()
	
	DialogueInitiator.start_dialogue(shop_data.talk_responses[option_key], false, true)
	
# ============================================================================
# === UTILITY FUNCTIONS ===
# ============================================================================

## Clear all item cards (both buy and sell)
func _clear_all_cards() -> void:
	for c in items_container.get_children():
		c.queue_free()

## Update button states based on current mode
func _update_button_states() -> void:
	if buy_button:
		buy_button.button_pressed = (current_mode == "buy")
		$"HBoxContainer/ColorRect/MarginContainer/VBoxContainer/ItemCategoryButtons".visible = true
	if talk_button:
		talk_button.button_pressed = (current_mode == "talk")
		$"HBoxContainer/ColorRect/MarginContainer/VBoxContainer/ItemCategoryButtons".visible = false
	if sell_button:
		sell_button.button_pressed = (current_mode == "sell")
		$"HBoxContainer/ColorRect/MarginContainer/VBoxContainer/ItemCategoryButtons".visible = false

func _on_exit_pressed() -> void:
	Global.loading = true
	get_tree().change_scene_to_file(Global.current_scene)
	Global.loading = false

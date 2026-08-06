@tool
extends Resource
class_name ShopData
## ShopData Resource - Container for shop inventory configuration
## Holds all ShopItems and metadata for a specific shop instance
## This resource is hot-swapped to change entire shop inventories

@export_group("Shop Identity")
@export var shop_name: String = "Shop"  ## Display name
@export var shop_description: String = ""  
@export var shop_music: AudioStreamMP3

@export_group("Inventory")
@export var items: Array[ShopItem] = []  ## All items available in this shop
@export var currency_type: PlayerStats.CurrencyType

@export_group("Talk Responses")
@export var talk_responses: Dictionary[String, DialogueData] = {
}

	#"Inhale my dong\n enragement child.": "Fuck off.",
	#"Give me free shit": "I am a respectable business if you want free shit i can shit into your hands, still with a price but small.",
	#"Fatherless piece of shit": "Yes. I am fatherless, my papa didn't come back from the K-Mart to get milk, I even bought the milk myself, but he didn't come back... (you see the 6 years expired milk on the shelf)",
	#"What do you think about the\n economical situation of\n Slovakia in 2001?": "The... What!?",

## Get item by its underlying Item resource
func get_item_by_resource(item_res: Item) -> ShopItem:
	for shop_item in items:
		if shop_item.item == item_res:
			return shop_item
	return null

## Check if shop has a specific item
func has_item(item_res: Item) -> bool:
	return get_item_by_resource(item_res) != null

## Duplicate this shop data
func duplicate_shop() -> ShopData:
	var new_shop = ShopData.new()
	new_shop.shop_name = shop_name
	new_shop.shop_description = shop_description
	
	for shop_item in items:
		var new_item = shop_item.duplicate() as ShopItem
		new_shop.items.append(new_item)
	
	return new_shop

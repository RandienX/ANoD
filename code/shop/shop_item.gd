@tool
extends Resource
class_name ShopItem
## ShopItem Resource - Defines an item available for purchase in the shop
## Wraps an Item resource with shop-specific metadata (price, tags)

@export_group("Basic Info")
@export var item: Item  ## The actual Item resource this shop entry represents
@export var price: int = 100  ## Cost to purchase one unit
@export var currency_type: PlayerStats.CurrencyType = PlayerStats.CurrencyType.GOLD  ## Which currency to use

@export_group("Display")
@export var sort_order: int = 0  ## For custom sorting in shop UI

## Check if item can be purchased
func can_purchase() -> bool:
	return _can_afford()

## Internal check if player can afford (assumes PlayerStats autoload exists)
func _can_afford() -> bool:
	if not PlayerStats:
		return false
	var stats = PlayerStats
	return stats.has_currency(price, currency_type)

## Purchase multiple units in bulk
func purchase(quantity: int) -> bool:
	if quantity <= 0:
		return false
	
	if not can_purchase():
		return false
	
	# Check total cost
	var total_cost = price * quantity
	
	var stats = PlayerStats
	if stats.has_currency(total_cost, currency_type):
		stats.deduct_currency(total_cost, currency_type)
		return true
	return false

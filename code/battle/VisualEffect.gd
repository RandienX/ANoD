extends Resource
class_name VisualEffect

enum Target {
	BattleEmitter,
	FullPartyEmitter,
	PartyEmitter,
	FullEnemyEmitter,
	EnemyEmitter,
	All
}

@export var effect: EffekseerEffect:
	set(value):
		effect = value
		# Automatically capture the path when assigned in the inspector
		if value and value.resource_path != "":
			effect_path = value.resource_path
	get:
		return effect

@export var speed: float = 1
@export var on_target: Target
@export var color: Color = Color.WHITE
@export var position_offset: Vector2

@export_category("Transform")
@export var orientation: Vector3
@export var flip_h: bool
@export var flip_v: bool

# Add this to VisualEffect.gd
var effect_path: String = ""

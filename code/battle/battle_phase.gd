@tool
class_name BattlePhase
extends Resource

## A phase in a multi-phase battle

@export_group("Phase Info")
@export var phase_name: String = "Phase 1"
@export_multiline var description: String = ""

@export_group("On Phase Start Effects")
@export var on_start_effects: Array[BattleEffect] = []

@export_group("Phase Settings (Override)")
@export var override_music: bool = false
@export var music_override: AudioStreamMP3
@export var override_background: bool = false
@export var background_override: Texture2D

@export_group("Spawn Reinforcements")
@export var spawn_reinforcements: bool = false
@export var reinforcement_slots: Array[BattleEnemySlot] = []

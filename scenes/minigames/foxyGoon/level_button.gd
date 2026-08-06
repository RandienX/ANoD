extends Button

signal on_pressed(level: FoxyGoonSettings, name: String)

var unlocked: bool = true
var rank: int = FoxyGoon.Ranks.F
@export var level_settings: FoxyGoonSettings

func _ready() -> void:
	on_pressed.connect(Callable(get_tree().current_scene, "start_track"))

func _on_pressed() -> void:
	on_pressed.emit(level_settings, get_child(0).text)

func  _process(delta: float) -> void:
	match rank:
		FoxyGoon.Ranks.F:
			$"Rank".texture = load("res://assets/minigame/foxy_goon/ranks/f.png")
		FoxyGoon.Ranks.D:
			$"Rank".texture = load("res://assets/minigame/foxy_goon/ranks/d.png")
		FoxyGoon.Ranks.C:
			$"Rank".texture = load("res://assets/minigame/foxy_goon/ranks/c.png")
		FoxyGoon.Ranks.B:
			$"Rank".texture = load("res://assets/minigame/foxy_goon/ranks/b.png")
		FoxyGoon.Ranks.A:
			$"Rank".texture = load("res://assets/minigame/foxy_goon/ranks/a.png")
		FoxyGoon.Ranks.S:
			$"Rank".texture = load("res://assets/minigame/foxy_goon/ranks/s.png")
		_:
			$"Rank".texture = null

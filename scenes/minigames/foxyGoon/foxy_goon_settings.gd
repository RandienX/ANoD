extends Resource
class_name FoxyGoonSettings

@export var rank_hp: Dictionary[FoxyGoon.Ranks, float] = {
	FoxyGoon.Ranks.F: 25,
	FoxyGoon.Ranks.D: 50,
	FoxyGoon.Ranks.C: 75,
	FoxyGoon.Ranks.B: 100,
	FoxyGoon.Ranks.A: 150,
	FoxyGoon.Ranks.S: 250,
}

@export var score_rank: Dictionary[FoxyGoon.Ranks, int] = {
	FoxyGoon.Ranks.F: 1000,
	FoxyGoon.Ranks.D: 10000,
	FoxyGoon.Ranks.C: 20000,
	FoxyGoon.Ranks.B: 30000,
	FoxyGoon.Ranks.A: 45000,
	FoxyGoon.Ranks.S: 55000,
}
@export var accuracy_rank: Dictionary[FoxyGoon.Ranks, float] = {
	FoxyGoon.Ranks.F: 0.0,
	FoxyGoon.Ranks.D: 0.5,
	FoxyGoon.Ranks.C: 0.65,
	FoxyGoon.Ranks.B: 0.75,
	FoxyGoon.Ranks.A: 0.83,
	FoxyGoon.Ranks.S: 0.9,
}
@export var miss_rank: Dictionary[FoxyGoon.Ranks, int] = {
	FoxyGoon.Ranks.F: 9999,
	FoxyGoon.Ranks.D: 20,
	FoxyGoon.Ranks.C: 12,
	FoxyGoon.Ranks.B: 7,
	FoxyGoon.Ranks.A: 3,
	FoxyGoon.Ranks.S: 0,
}
@export_range(0.5, 10, 0.1) var speed: float = 1.6
@export var music: AudioStreamMP3
@export var arrow_schematics: Array[ArrowSchematic]

@export var arrow_type_hp: Dictionary[GoonArrow.Type, float] = {
	GoonArrow.Type.NORMAL: 1,
	GoonArrow.Type.BAD: 0.5,
	GoonArrow.Type.INVERT: 1.1,
	GoonArrow.Type.HOLD: 0.2,
}
@export var arrow_type_score: Dictionary[GoonArrow.Type, int] = {
	GoonArrow.Type.NORMAL: 100,
	GoonArrow.Type.BAD: 50,
	GoonArrow.Type.INVERT: 175,
	GoonArrow.Type.HOLD: 25,
}
@export var arrow_type_score_miss_mult: float = 0.5
@export var arrow_type_damage: Dictionary[GoonArrow.Type, float] = {
	GoonArrow.Type.NORMAL: 10,
	GoonArrow.Type.BAD: 5,
	GoonArrow.Type.INVERT: 8,
	GoonArrow.Type.HOLD: 2,
}

@export var song_end_seconds: float
@export var testing_start_pos: float

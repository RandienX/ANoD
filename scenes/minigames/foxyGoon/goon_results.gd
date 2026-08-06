extends GridContainer

var track = Global.current_foxy_trackname
var score = Global.track_score
var accuracy = Global.track_accuracy
var misses = Global.track_miss

var rank_value = 0

func _ready() -> void:
	$"../TrackName".text = "[b][i]" + track
	BackgroundMusic.stream = load("res://assets/minigame/foxy_goon/Saster - FGF Menu Theme.mp3")
	BackgroundMusic.play()
	if track in Global.foxy_data.keys():
		match Global.foxy_data[track][0]:
			FoxyGoon.Ranks.F:
				$"../TrackName/Rank".texture = load("res://assets/minigame/foxy_goon/ranks/f.png")
			FoxyGoon.Ranks.D:
				$"../TrackName/Rank".texture = load("res://assets/minigame/foxy_goon/ranks/d.png")
			FoxyGoon.Ranks.C:
				$"../TrackName/Rank".texture = load("res://assets/minigame/foxy_goon/ranks/c.png")
			FoxyGoon.Ranks.B:
				$"../TrackName/Rank".texture = load("res://assets/minigame/foxy_goon/ranks/b.png")
			FoxyGoon.Ranks.A:
				$"../TrackName/Rank".texture = load("res://assets/minigame/foxy_goon/ranks/a.png")
			FoxyGoon.Ranks.S:
				$"../TrackName/Rank".texture = load("res://assets/minigame/foxy_goon/ranks/s.png")
			_:
				$"../TrackName/Rank".texture = null
				

var scorr = false
var accu = false
var miss = false
func _physics_process(delta: float) -> void:
	if scorr:
		if accu:
			if miss:
				do_rank()
			else:
				miss = lerp_misses(delta)
		else:
			accu = lerp_accuracy(delta)
	else:
		scorr = lerp_score(delta)

func lerp_score(d) -> bool:
	if int($ScoreNum.text) == score:
		for i in Global.current_foxy_track.score_rank.values():
			if score >= i:
				rank_value += 1
		return true
	var scor = lerp(int($ScoreNum.text), score, d)
	$ScoreNum.text = str(ceili(scor))
	return false
	
var acc = 0
func lerp_accuracy(d) -> bool:
	acc = lerpf(acc, accuracy, d)
	if acc >= accuracy - 0.01:
		$AccuracyPercent.text = "%.2f" % [accuracy * 100] + "%"
		for i in Global.current_foxy_track.accuracy_rank.values():
			if accuracy >= i:
				rank_value += 1
		return true
	$AccuracyPercent.text = "%.2f" % [acc * 100] + "%"
	return false
	
func lerp_misses(d) -> bool:
	if int($MissesNum.text) == misses:
		for i in Global.current_foxy_track.score_rank.values():
			if misses >= i:
				rank_value += 1
		return true
	var missd = lerp(int($MissesNum.text), misses, d)
	$MissesNum.text = str(ceili(missd))
	return false
	
func do_rank():
	if rank_value == 18: #S
		$"../TrackName/Rank".texture = load("res://assets/minigame/foxy_goon/ranks/s.png")
		if Global.foxy_data[track][0] <= FoxyGoon.Ranks.S:
			Global.foxy_data[track][0] = FoxyGoon.Ranks.S
	elif rank_value >= 15: #A
		$"../TrackName/Rank".texture = load("res://assets/minigame/foxy_goon/ranks/a.png")
		if Global.foxy_data[track][0] <= FoxyGoon.Ranks.A:
			Global.foxy_data[track][0] = FoxyGoon.Ranks.A
	elif rank_value >= 12: #B
		$"../TrackName/Rank".texture = load("res://assets/minigame/foxy_goon/ranks/b.png")
		if Global.foxy_data[track][0] <= FoxyGoon.Ranks.B:
			Global.foxy_data[track][0] = FoxyGoon.Ranks.B
	elif rank_value >= 9: #C
		$"../TrackName/Rank".texture = load("res://assets/minigame/foxy_goon/ranks/c.png")
		if Global.foxy_data[track][0] <= FoxyGoon.Ranks.C:
			Global.foxy_data[track][0] = FoxyGoon.Ranks.C
	elif rank_value >= 6: #D
		$"../TrackName/Rank".texture = load("res://assets/minigame/foxy_goon/ranks/d.png")
		if Global.foxy_data[track][0] <= FoxyGoon.Ranks.D:
			Global.foxy_data[track][0] = FoxyGoon.Ranks.D
	elif rank_value >= 0: #F
		$"../TrackName/Rank".texture = load("res://assets/minigame/foxy_goon/ranks/f.png")
		if Global.foxy_data[track][0] <= FoxyGoon.Ranks.F:
			Global.foxy_data[track][0] = FoxyGoon.Ranks.F

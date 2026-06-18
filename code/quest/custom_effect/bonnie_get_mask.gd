extends RefCounted

func execute_custom_effect():
	for p:Entity in PlayerStats.party:
		if p.name == "Bonnie":
			p.cannot_use_skills = false
			p.sprite = load("res://assets/spriteframes/bonnie.tres")

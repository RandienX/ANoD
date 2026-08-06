extends Node

#custom dialogue effect for adding in bonnie's skillcasting ability
static func apply(_effect):
	for p in PlayerStats.party:
		if p.name == "Bonnie":
			p.cannot_use_skills = false
			p.level += 1
			p.sprite = load("res://assets/spriteframes/bonnie.tres")
			Global.player_ref.create_party_sprites()

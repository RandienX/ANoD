extends Node
class_name VfxManager

var root: BattleEngine

func setup(broot):
	root = broot
	
var targets: Array[EffekseerEmitter2D] = []
func get_vfx_target(vfx: VisualEffect, targetz, attacker):
	match vfx.on_target:
		VisualEffect.Target.BattleEmitter:
			var emitter = root.get_node("EffekseerEmitter2D")
			if emitter: play_vfx(emitter, vfx)
			
		VisualEffect.Target.FullPartyEmitter:
			if attacker.role == Entity.Role.PARTY:
				for c in root.get_node("Control/gui/HBoxContainer2/party").get_children():
					var emitter = c.get_node("EffekseerEmitter2D")
					if emitter: play_vfx(emitter, vfx)
			else:
				for c in root.get_node("Control/enemy_ui/enemies").get_children():
					var emitter = c.get_node("EffekseerEmitter2D")
					if emitter: play_vfx(emitter, vfx)
				
		VisualEffect.Target.PartyEmitter:
			if attacker.role == Entity.Role.PARTY:
				for t in targetz:
					if t.role == Entity.Role.PARTY:
						get_party_member(t, vfx)
			else:
				for t in targetz:
					if t.role == Entity.Role.ENEMY:
						get_enemy(t, vfx)
							
		VisualEffect.Target.FullEnemyEmitter:
			if attacker.role == Entity.Role.PARTY:
				for c in root.get_node("Control/enemy_ui/enemies").get_children():
					var emitter = c.get_node("EffekseerEmitter2D")
					if emitter: play_vfx(emitter, vfx)
			else:
				for c in root.get_node("Control/gui/HBoxContainer2/party").get_children():
					var emitter = c.get_node("EffekseerEmitter2D")
					if emitter: play_vfx(emitter, vfx)
				
		VisualEffect.Target.EnemyEmitter:
			if attacker.role == Entity.Role.PARTY:
				for t in targetz:
					if t.role == Entity.Role.ENEMY:
						get_enemy(t, vfx)
			else:
				for t in targetz:
					if t.role == Entity.Role.PARTY:
						get_party_member(t, vfx)
							
		VisualEffect.Target.All:
			for c in root.get_node("Control/gui/HBoxContainer2/party").get_children():
				@warning_ignore("confusable_local_declaration")
				var emitter = c.get_node("EffekseerEmitter2D")
				if emitter: c.update_vfx(vfx)
			for c in root.get_node("Control/enemy_ui/enemies").get_children():
				@warning_ignore("confusable_local_declaration")
				var emitter = c.get_node_("EffekseerEmitter2D")
				if emitter: play_vfx(emitter, vfx)
			var emitter = root.get_node("EffekseerEmitter2D")
			if emitter: play_vfx(emitter, vfx)
	return

func play_vfx(target: EffekseerEmitter2D, vfx: VisualEffect):
	if not vfx or not vfx.effect: return
	target.stop()
	target.effect = null
	target.effect = vfx.effect
	
	target.speed = vfx.speed * Settings.battle_speed * 0.8
	target.color = vfx.color
	target.target_position = target.global_position + vfx.position_offset

	target.orientation = vfx.orientation
	target.flip_h = vfx.flip_h
	target.flip_v = vfx.flip_v
	
	target.play()
	await root.get_tree().process_frame
	while target.is_playing() and is_instance_valid(target):
		await root.get_tree().process_frame
		
func get_party_member(party: Object, vfx: VisualEffect):
	for c in root.get_node("Control/gui/HBoxContainer2/party").get_children():
		if c.party_member == party:
			var emitter = c.get_node_or_null("EffekseerEmitter2D")
			if emitter: c.update_vfx(vfx)

func get_enemy(enemy: Object, vfx: VisualEffect):
	for c in root.get_node("Control/enemy_ui/enemies").get_children():
		if c.enemy == enemy:
			var emitter = c.get_node_or_null("EffekseerEmitter2D")
			if emitter: play_vfx(emitter, vfx)

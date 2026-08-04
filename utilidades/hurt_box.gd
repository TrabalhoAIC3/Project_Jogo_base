extends Area2D

@export_enum("Cooldown","HitOnce","DisableHitBox") var HurtBoxType = 0 

@onready var collision = $CollisionShape2D
@onready var DisableTimer = $DisableTimer

signal hurt(damage)

func _on_area_entered(area):
	if area.is_in_group("attack"):
		if not area.get("damage") = null:
			match HurtBoxType:
				0: 
					collision.call_deferred("set","disabled", true)

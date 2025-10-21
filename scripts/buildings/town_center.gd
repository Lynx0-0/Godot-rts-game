# scripts/buildings/town_center.gd
extends StaticBody2D
class_name TownCenter

@export var health := 500

@onready var sprite = $Sprite2D

func _ready():
	add_to_group("town_centers")
	add_to_group("player_buildings")
	
	# Colore distintivo
	sprite.modulate = Color.BLUE
	
	print("Town Center creato")

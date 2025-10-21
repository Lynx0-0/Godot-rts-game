# scripts/buildings/town_center.gd
extends StaticBody2D
class_name TownCenter

## Edificio principale del giocatore.
## Serve come punto di raccolta per i worker e centro di comando.

# ===== COSTANTI =====

## Vita massima del Town Center
const MAX_HEALTH := 500
## Colore del Town Center per identificazione visiva
const BUILDING_COLOR := Color.BLUE

# ===== VARIABILI ESPORTATE =====

## Vita corrente dell'edificio
@export var health := MAX_HEALTH

# ===== RIFERIMENTI NODI =====

@onready var sprite = $Sprite2D

# ===== METODI LIFECYCLE =====

func _ready():
	# Registra l'edificio nei gruppi per facilitare la ricerca
	add_to_group("town_centers")
	add_to_group("player_buildings")

	# Applica colore distintivo per riconoscimento visivo
	sprite.modulate = BUILDING_COLOR

	print("Town Center creato con %d punti vita" % health)

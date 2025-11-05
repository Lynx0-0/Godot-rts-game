# scripts/buildings/base_building.gd
extends StaticBody2D
class_name BaseBuilding

@export var building_name := "Building"
@export var max_health := 500
@export var grid_size := Vector2i(2, 2)  # Dimensione in celle

var current_health: int
var is_player_owned := true

@onready var health_bar = $HealthBar
@onready var name_label = $Label

signal building_destroyed
signal building_damaged(new_health: int)

func _ready():
	current_health = max_health
	name_label.text = building_name
	_update_health_bar()
	
	# Registra nel sistema piazzamento
	BuildingPlacement.register_existing_building(self, grid_size)
	
	add_to_group("buildings")
	if is_player_owned:
		add_to_group("player_buildings")
	else:
		add_to_group("enemy_buildings")

func _update_health_bar():
	if health_bar:
		health_bar.value = float(current_health) / max_health * 100
		health_bar.visible = current_health < max_health

func take_damage(damage: int):
	current_health -= damage
	current_health = max(0, current_health)
	_update_health_bar()
	building_damaged.emit(current_health)
	
	if current_health <= 0:
		_destroy()

func _destroy():
	building_destroyed.emit()
	BuildingPlacement.unregister_building(self, grid_size)
	
	# Animazione distruzione
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

# scripts/units/base_unit_enhanced.gd
extends CharacterBody2D
class_name BaseUnitEnhanced

"""
Versione migliorata di BaseUnit con:
- Movimento fluido senza scacchiera
- Z-ordering automatico per profondità
- Supporto effetti visivi
"""

@export var speed := 150.0
@export var max_health := 100
@export var unit_type := "base"

# Movimento
var current_health: int
var is_selected := false
var target_position := Vector2.ZERO

# Componenti
var movement_component: SmoothMovementComponent

# Riferimenti nodi
@onready var sprite = $Sprite2D
@onready var selection_indicator = $SelectionIndicator
@onready var navigation_agent = $NavigationAgent2D
@onready var health_bar = $HealthBar
@onready var selection_area = $SelectionArea

# Segnali
signal unit_selected
signal unit_deselected
signal arrived_at_destination
signal health_changed(new_health: int)

func _ready():
	current_health = max_health
	_update_health_bar()
	
	# Setup movimento fluido
	_setup_smooth_movement()
	
	# Setup navigazione
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	navigation_agent.navigation_finished.connect(_on_navigation_finished)
	
	# Gruppi
	add_to_group("units")
	add_to_group("player_units")
	
	# Area selezione
	if selection_area:
		selection_area.input_event.connect(_on_selection_area_input)
		selection_area.mouse_entered.connect(_on_mouse_entered)
		selection_area.mouse_exited.connect(_on_mouse_exited)
	
	# Selection indicator
	if selection_indicator:
		selection_indicator.visible = false

func _setup_smooth_movement():
	"""Inizializza componente movimento fluido"""
	movement_component = SmoothMovementComponent.new()
	movement_component.name = "SmoothMovement"
	movement_component.max_speed = speed
	add_child(movement_component)

func _physics_process(delta):
	if movement_component:
		movement_component.physics_update(delta)
	else:
		# Fallback al vecchio sistema se componente manca
		_legacy_movement()

func _legacy_movement():
	"""Sistema movimento base (backup)"""
	if navigation_agent.is_navigation_finished():
		return
	
	var next_position = navigation_agent.get_next_path_position()
	var direction = global_position.direction_to(next_position)
	var new_velocity = direction * speed
	
	navigation_agent.velocity = new_velocity

func _on_velocity_computed(safe_velocity: Vector2):
	if not movement_component:
		velocity = safe_velocity
		move_and_slide()

func move_to_position(pos: Vector2):
	"""Muove l'unità verso una posizione target"""
	target_position = pos
	navigation_agent.target_position = pos

func set_selected(selected: bool):
	is_selected = selected
	
	if selection_indicator:
		selection_indicator.visible = selected
	
	if sprite:
		sprite.modulate = Color(1.2, 1.2, 1.2) if selected else Color.WHITE

func take_damage(damage: int):
	current_health -= damage
	current_health = max(0, current_health)
	_update_health_bar()
	health_changed.emit(current_health)
	
	_flash_damage()
	
	if current_health <= 0:
		_die()

func _update_health_bar():
	if health_bar:
		health_bar.value = float(current_health) / max_health * 100
		health_bar.visible = current_health < max_health

func _flash_damage():
	if not sprite:
		return
		
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE if not is_selected else Color(1.2, 1.2, 1.2), 0.1)

func _die():
	remove_from_group("units")
	remove_from_group("player_units")
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _on_selection_area_input(viewport: Node, event: InputEvent, shape_idx: int):
	pass

func _on_mouse_entered():
	if not is_selected and sprite:
		sprite.modulate = Color(1.1, 1.1, 1.1)

func _on_mouse_exited():
	if not is_selected and sprite:
		sprite.modulate = Color.WHITE

func _on_navigation_finished():
	arrived_at_destination.emit()

# Funzioni di utilità
func is_moving() -> bool:
	if movement_component:
		return movement_component.is_moving()
	return not navigation_agent.is_navigation_finished()

func get_movement_progress() -> float:
	if movement_component:
		return movement_component.get_movement_progress()
	return 1.0 if navigation_agent.is_navigation_finished() else 0.5

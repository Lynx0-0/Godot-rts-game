# scripts/units/base_unit.gd
extends CharacterBody2D
class_name BaseUnit

## Velocità movimento unità
@export var speed := 150.0
## Vita massima
@export var max_health := 100
## Tipo di unità (per distinguere worker, soldier, etc)
@export var unit_type := "base"

# Stato corrente
var current_health: int
var is_selected := false
var is_moving := false
var target_position := Vector2.ZERO

# Riferimenti nodi
@onready var sprite = $Sprite2D
@onready var selection_indicator = $SelectionIndicator
@onready var navigation_agent = $NavigationAgent2D as NavigationAgent2D
@onready var health_bar = $HealthBar
@onready var selection_area = $SelectionArea

# Segnali
signal unit_selected
signal unit_deselected
signal arrived_at_destination
signal health_changed(new_health: int)

func _ready():
	# Inizializza vita
	current_health = max_health
	_update_health_bar()
	
	# Setup navigazione
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		navigation_agent.navigation_finished.connect(_on_navigation_finished)
	
	# Aggiungi ai gruppi
	add_to_group("units")
	add_to_group("player_units")
	
	# Setup area selezione (con controllo di sicurezza)
	if selection_area:
		selection_area.input_event.connect(_on_selection_area_input)
		selection_area.mouse_entered.connect(_on_mouse_entered)
		selection_area.mouse_exited.connect(_on_mouse_exited)
	
	# Setup indicatore selezione
	_setup_selection_indicator()
	
	print("BaseUnit ", name, " inizializzato")

func _setup_selection_indicator():
	"""Setup sicuro dell'indicatore di selezione"""
	if not selection_indicator:
		selection_indicator = ColorRect.new()
		selection_indicator.name = "SelectionIndicator"
		selection_indicator.size = Vector2(40, 40)
		selection_indicator.position = Vector2(-20, -20)
		selection_indicator.color = Color(0, 1, 0, 0.3)
		selection_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(selection_indicator)
	
	selection_indicator.visible = false

func _physics_process(delta):
	if not navigation_agent:
		return
	
	if navigation_agent.is_navigation_finished():
		is_moving = false
		return
	
	# Calcola direzione verso prossimo punto
	var next_position = navigation_agent.get_next_path_position()
	var direction = global_position.direction_to(next_position)
	
	# Imposta velocità desiderata
	var desired_velocity = direction * speed
	navigation_agent.velocity = desired_velocity

func _on_velocity_computed(safe_velocity: Vector2):
	# Applica velocità calcolata dal navigation agent
	velocity = safe_velocity
	move_and_slide()
	
	# Opzionale: ruota sprite verso direzione movimento
	if velocity.length() > 0 and sprite:
		sprite.rotation = velocity.angle() + PI/2

func move_to_position(pos: Vector2):
	"""Muove l'unità verso una posizione target"""
	if not navigation_agent:
		print("NavigationAgent non trovato!")
		return
	
	target_position = pos
	navigation_agent.target_position = pos
	is_moving = true
	print("Unità ", name, " si muove verso ", pos)

func set_selected(selected: bool):
	is_selected = selected
	
	if selection_indicator:
		selection_indicator.visible = selected
	
	if sprite:
		if selected:
			sprite.modulate = Color(1.2, 1.2, 1.2)
		else:
			sprite.modulate = Color.WHITE

func take_damage(damage: int):
	"""Applica danno all'unità"""
	current_health -= damage
	current_health = max(0, current_health)
	_update_health_bar()
	health_changed.emit(current_health)
	
	# Effetto visivo danno
	_flash_damage()
	
	if current_health <= 0:
		_die()

func _update_health_bar():
	"""Aggiorna barra vita"""
	if health_bar:
		health_bar.value = float(current_health) / max_health * 100
		# Nascondi se vita piena
		health_bar.visible = current_health < max_health

func _flash_damage():
	"""Effetto flash rosso quando colpito"""
	if not sprite:
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _die():
	"""Gestisce morte unità"""
	# Rimuovi da gruppi
	remove_from_group("units")
	remove_from_group("player_units")
	
	# Animazione morte (per ora semplice fade)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

# Gestione eventi mouse
func _on_selection_area_input(viewport: Node, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Gestito dal selection system
			pass

func _on_mouse_entered():
	# Highlight quando mouse sopra
	if not is_selected and sprite:
		sprite.modulate = Color(1.1, 1.1, 1.1)

func _on_mouse_exited():
	# Rimuovi highlight
	if not is_selected and sprite:
		sprite.modulate = Color.WHITE

func _on_navigation_finished():
	"""Chiamato quando l'unità arriva a destinazione"""
	is_moving = false
	arrived_at_destination.emit()
	print("Unità ", name, " arrivata a destinazione")

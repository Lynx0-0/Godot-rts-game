# scripts/units/smooth_movement_component.gd
extends Node
class_name SmoothMovementComponent

"""
Componente per movimento fluido e naturale delle unità.
Gestisce accelerazione, decelerazione e path smoothing.
"""

@export var max_speed := 150.0
@export var acceleration := 500.0  # Quanto veloce raggiunge max_speed
@export var deceleration := 700.0  # Quanto veloce si ferma
@export var rotation_speed := 10.0  # Velocità rotazione sprite
@export var path_smoothing := 0.3  # 0-1, più alto = più smooth ma meno preciso
@export var stuck_threshold := 2.0  # Secondi prima di considerare bloccato

var unit: CharacterBody2D
var navigation_agent: NavigationAgent2D

var current_velocity := Vector2.ZERO
var facing_direction := Vector2.DOWN

# Sistema anti-blocco
var stuck_timer := 0.0
var last_position := Vector2.ZERO
var is_stuck := false
var recalc_path_timer := 0.0

func _ready():
	unit = get_parent()
	navigation_agent = unit.get_node("NavigationAgent2D")
	
	if navigation_agent:
		# Configura parametri per movimento fluido e pathfinding migliorato
		navigation_agent.path_desired_distance = 8.0
		navigation_agent.target_desired_distance = 12.0
		navigation_agent.path_max_distance = 50.0  # Aumentato per gestire ostacoli lunghi

		# Abilita smoothing avanzato
		navigation_agent.avoidance_enabled = true
		navigation_agent.radius = 20.0  # Raggio per collision avoidance
		navigation_agent.max_speed = max_speed

		# Parametri avanzati per evitare blocchi
		navigation_agent.path_postprocessing = NavigationPathQueryParameters2D.PATH_POSTPROCESSING_CORRIDORFUNNEL
		navigation_agent.simplify_path = true  # Semplifica path per evitare zig-zag

		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		navigation_agent.navigation_finished.connect(_on_navigation_finished)

	# Inizializza posizione
	last_position = unit.global_position

func physics_update(delta: float):
	"""Chiamato dal _physics_process del parent"""
	if not navigation_agent or navigation_agent.is_navigation_finished():
		# Decelera gradualmente quando arrivato
		_apply_deceleration(delta)
		stuck_timer = 0.0
		is_stuck = false
		return

	# Sistema anti-blocco: rileva se unità ferma troppo a lungo
	_check_if_stuck(delta)

	# Ricalcola path periodicamente se bloccato
	recalc_path_timer += delta
	if is_stuck or recalc_path_timer > 1.0:  # Ogni secondo
		_recalculate_path()
		recalc_path_timer = 0.0

	# Ottieni prossimo punto del path
	var next_position = navigation_agent.get_next_path_position()
	var direction = unit.global_position.direction_to(next_position)

	# Smooth del path: interpola tra direzione corrente e target
	if current_velocity.length() > 0:
		var current_dir = current_velocity.normalized()
		direction = current_dir.lerp(direction, path_smoothing)

	# Calcola velocità target
	var target_velocity = direction * max_speed

	# Accelerazione smooth verso velocità target
	current_velocity = current_velocity.move_toward(target_velocity, acceleration * delta)

	# Imposta velocità al navigation agent per collision avoidance
	if navigation_agent.avoidance_enabled:
		navigation_agent.velocity = current_velocity
	else:
		_apply_velocity()

	# Aggiorna direzione facing (per rotazione sprite)
	if current_velocity.length() > 10:
		facing_direction = facing_direction.lerp(current_velocity.normalized(), rotation_speed * delta)

func _apply_deceleration(delta: float):
	"""Decelera smooth fino a fermarsi"""
	if current_velocity.length() > 1.0:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, deceleration * delta)
		_apply_velocity()
	else:
		current_velocity = Vector2.ZERO
		unit.velocity = Vector2.ZERO

func _on_velocity_computed(safe_velocity: Vector2):
	"""Callback da NavigationAgent con velocità sicura (post collision avoidance)"""
	current_velocity = safe_velocity
	_apply_velocity()

func _apply_velocity():
	"""Applica velocità all'unità"""
	unit.velocity = current_velocity
	unit.move_and_slide()

func get_movement_progress() -> float:
	"""Ritorna progresso 0-1 verso destinazione"""
	if not navigation_agent or navigation_agent.is_navigation_finished():
		return 1.0
	
	var total_distance = unit.global_position.distance_to(navigation_agent.target_position)
	var remaining = navigation_agent.distance_to_target()
	
	if total_distance < 0.1:
		return 1.0
	
	return 1.0 - (remaining / total_distance)

func is_moving() -> bool:
	"""Check se l'unità è in movimento"""
	return current_velocity.length() > 5.0

func get_facing_angle() -> float:
	"""Ottieni angolo facing corrente (per rotazione sprite)"""
	return facing_direction.angle()

# Funzioni di utilità per animazioni
func get_movement_blend() -> Vector2:
	"""
	Ritorna vettore normalizzato per blend tree animazioni.
	X: movimento laterale (-1 sinistra, 1 destra)
	Y: movimento verticale (-1 su, 1 giù)
	"""
	if current_velocity.length() < 5:
		return Vector2.ZERO

	return current_velocity.normalized()

# ===== SISTEMA ANTI-BLOCCO =====

func _check_if_stuck(delta: float):
	"""Rileva se l'unità è bloccata e non si muove"""
	var current_pos = unit.global_position
	var distance_moved = current_pos.distance_to(last_position)

	# Se si è mossa meno di 1 pixel
	if distance_moved < 1.0 and current_velocity.length() > 10:
		stuck_timer += delta
		if stuck_timer >= stuck_threshold:
			is_stuck = true
			print("%s è bloccato! Ricalcolo path..." % unit.name)
	else:
		stuck_timer = 0.0
		is_stuck = false

	last_position = current_pos

func _recalculate_path():
	"""Forza ricalcolo del path"""
	if not navigation_agent:
		return

	var target = navigation_agent.target_position

	# Reset navigation agent
	navigation_agent.target_position = target

	# Se ancora bloccato, prova a muoversi leggermente di lato
	if is_stuck:
		var random_offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		var intermediate_target = unit.global_position + random_offset
		navigation_agent.target_position = intermediate_target
		# Dopo un frame, reimposta target originale
		await unit.get_tree().process_frame
		navigation_agent.target_position = target
		is_stuck = false

func _on_navigation_finished():
	"""Callback quando raggiunge destinazione"""
	stuck_timer = 0.0
	is_stuck = false
	recalc_path_timer = 0.0

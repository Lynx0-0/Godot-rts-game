# scripts/units/base_unit.gd
extends CharacterBody2D
class_name BaseUnit

## Classe base per tutte le unità del gioco.
## Gestisce movimento, selezione, vita e navigazione.
## Da estendere per creare tipi specifici (Worker, Soldier, etc.).

# ===== COSTANTI =====

## Velocità predefinita di movimento (pixel/sec)
const DEFAULT_SPEED := 150.0
## Vita massima predefinita
const DEFAULT_MAX_HEALTH := 100
## Tipo di unità base (da sovrascrivere nelle classi figlie)
const DEFAULT_UNIT_TYPE := "base"
## Dimensione predefinita indicatore selezione
const SELECTION_INDICATOR_SIZE := Vector2(40, 40)
## Colore indicatore selezione
const SELECTION_COLOR := Color(0, 1, 0, 0.3)  # Verde trasparente
## Moltiplicatore luminosità quando selezionato
const SELECTION_BRIGHTNESS := Color(1.2, 1.2, 1.2)
## Moltiplicatore luminosità per hover
const HOVER_BRIGHTNESS := Color(1.1, 1.1, 1.1)
## Durata flash danno (secondi)
const DAMAGE_FLASH_DURATION := 0.1
## Durata animazione morte (secondi)
const DEATH_FADE_DURATION := 0.5

# ===== VARIABILI ESPORTATE =====

## Velocità movimento unità
@export var speed := DEFAULT_SPEED
## Vita massima
@export var max_health := DEFAULT_MAX_HEALTH
## Tipo di unità (per distinguere worker, soldier, etc)
@export var unit_type := DEFAULT_UNIT_TYPE

# ===== STATO CORRENTE =====

## Vita corrente dell'unità
var current_health: int
## Se l'unità è attualmente selezionata
var is_selected := false
## Se l'unità si sta muovendo
var is_moving := false
## Posizione target per il movimento
var target_position := Vector2.ZERO
## Componente per movimento fluido
var movement_component: SmoothMovementComponent

# ===== RIFERIMENTI NODI =====

@onready var sprite = $Sprite2D
@onready var selection_indicator = $SelectionIndicator
@onready var navigation_agent = $NavigationAgent2D as NavigationAgent2D
@onready var health_bar = $HealthBar
@onready var selection_area = $SelectionArea

# ===== SEGNALI =====

## Emesso quando l'unità viene selezionata
signal unit_selected
## Emesso quando l'unità viene deselezionata
signal unit_deselected
## Emesso quando l'unità arriva alla destinazione
signal arrived_at_destination
## Emesso quando la vita dell'unità cambia
signal health_changed(new_health: int)

# ===== METODI LIFECYCLE =====

func _ready():
	# Inizializza vita al massimo
	current_health = max_health
	_update_health_bar()

	# Setup sistema di navigazione
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		navigation_agent.navigation_finished.connect(_on_navigation_finished)

	# Registra l'unità nei gruppi per ricerca rapida
	add_to_group("units")
	add_to_group("player_units")

	# Setup area di selezione con controlli di sicurezza
	if selection_area:
		selection_area.input_event.connect(_on_selection_area_input)
		selection_area.mouse_entered.connect(_on_mouse_entered)
		selection_area.mouse_exited.connect(_on_mouse_exited)

	# Setup indicatore di selezione visivo
	_setup_selection_indicator()

	# Setup movimento fluido
	_setup_smooth_movement()

	print("BaseUnit '%s' (tipo: %s) inizializzato" % [name, unit_type])

func _physics_process(delta):
	if not navigation_agent:
		return

	# Usa componente movimento fluido se disponibile
	if movement_component:
		movement_component.physics_update(delta)
		is_moving = movement_component.is_moving()

		# Ruota sprite verso direzione movimento (smooth)
		if is_moving and sprite:
			var angle = movement_component.get_facing_angle()
			sprite.rotation = angle + PI/2
	else:
		# Fallback: movimento tradizionale (se componente non disponibile)
		if navigation_agent.is_navigation_finished():
			is_moving = false
			return

		# Calcola direzione verso il prossimo punto del percorso
		var next_position = navigation_agent.get_next_path_position()
		var direction = global_position.direction_to(next_position)

		# Imposta velocità desiderata per il navigation agent
		var desired_velocity = direction * speed
		navigation_agent.velocity = desired_velocity

# ===== METODI PUBBLICI =====

## Muove l'unità verso una posizione target.
## [param pos]: La posizione di destinazione
func move_to_position(pos: Vector2) -> void:
	if not navigation_agent:
		push_warning("NavigationAgent non trovato per unità %s!" % name)
		return

	target_position = pos
	navigation_agent.target_position = pos
	is_moving = true
	print("Unità %s si muove verso %v" % [name, pos])

## Imposta lo stato di selezione dell'unità.
## [param selected]: true per selezionare, false per deselezionare
func set_selected(selected: bool) -> void:
	is_selected = selected

	# Mostra/nascondi indicatore di selezione
	if selection_indicator:
		selection_indicator.visible = selected

	# Cambia luminosità sprite
	if sprite:
		sprite.modulate = SELECTION_BRIGHTNESS if selected else Color.WHITE

## Applica danno all'unità.
## [param damage]: Quantità di danno da applicare
func take_damage(damage: int) -> void:
	current_health -= damage
	current_health = max(0, current_health)
	_update_health_bar()
	health_changed.emit(current_health)

	# Effetto visivo di danno
	_flash_damage()

	# Controlla se l'unità è morta
	if current_health <= 0:
		_die()

# ===== METODI PRIVATI =====

## Setup del componente movimento fluido
func _setup_smooth_movement() -> void:
	if not navigation_agent:
		push_warning("NavigationAgent non trovato, movimento fluido non disponibile")
		return

	# Crea e configura componente movimento fluido
	movement_component = SmoothMovementComponent.new()
	movement_component.name = "SmoothMovement"
	movement_component.max_speed = speed
	movement_component.acceleration = 500.0
	movement_component.deceleration = 700.0
	movement_component.path_smoothing = 0.3
	movement_component.rotation_speed = 10.0
	add_child(movement_component)

	print("Movimento fluido attivato per unità %s" % name)

## Setup sicuro dell'indicatore di selezione
func _setup_selection_indicator() -> void:
	if not selection_indicator:
		# Crea indicatore se non esiste
		selection_indicator = ColorRect.new()
		selection_indicator.name = "SelectionIndicator"
		selection_indicator.size = SELECTION_INDICATOR_SIZE
		selection_indicator.position = -SELECTION_INDICATOR_SIZE / 2
		selection_indicator.color = SELECTION_COLOR
		selection_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(selection_indicator)

	selection_indicator.visible = false

## Aggiorna la barra della vita
func _update_health_bar() -> void:
	if not health_bar:
		return

	# Calcola percentuale vita
	health_bar.value = float(current_health) / max_health * 100
	# Nascondi se vita è al massimo
	health_bar.visible = current_health < max_health

## Effetto flash rosso quando l'unità riceve danno
func _flash_damage() -> void:
	if not sprite:
		return

	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, DAMAGE_FLASH_DURATION)
	tween.tween_property(sprite, "modulate", Color.WHITE, DAMAGE_FLASH_DURATION)

## Gestisce la morte dell'unità
func _die() -> void:
	print("Unità %s è morta" % name)

	# Rimuovi da gruppi di gioco
	remove_from_group("units")
	remove_from_group("player_units")

	# Animazione di scomparsa graduale
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, DEATH_FADE_DURATION)
	tween.tween_callback(queue_free)

# ===== CALLBACK NAVIGAZIONE =====

## Chiamato quando la velocità è stata calcolata dal NavigationAgent
func _on_velocity_computed(safe_velocity: Vector2) -> void:
	# Se usiamo movimento fluido, il componente gestisce tutto
	if movement_component:
		return

	# Fallback: movimento tradizionale
	# Applica velocità calcolata
	velocity = safe_velocity
	move_and_slide()

	# Ruota sprite verso direzione movimento
	if velocity.length() > 0 and sprite:
		sprite.rotation = velocity.angle() + PI/2

## Chiamato quando l'unità arriva a destinazione
func _on_navigation_finished() -> void:
	is_moving = false
	arrived_at_destination.emit()
	print("Unità %s arrivata a destinazione" % name)

# ===== CALLBACK EVENTI MOUSE =====

## Gestisce input sull'area di selezione
func _on_selection_area_input(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# La selezione è gestita dal sistema centrale in main.gd
	pass

## Chiamato quando il mouse entra nell'area dell'unità
func _on_mouse_entered() -> void:
	# Applica highlight se non già selezionata
	if not is_selected and sprite:
		sprite.modulate = HOVER_BRIGHTNESS

## Chiamato quando il mouse esce dall'area dell'unità
func _on_mouse_exited() -> void:
	# Rimuovi highlight se non selezionata
	if not is_selected and sprite:
		sprite.modulate = Color.WHITE

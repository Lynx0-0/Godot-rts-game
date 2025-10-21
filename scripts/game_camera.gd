# scripts/game_camera.gd
extends Camera2D
class_name CameraController

## Controller per la camera del gioco con supporto per zoom, pan e movimento.
## Supporta controlli con mouse, tastiera e bordi dello schermo.

# ===== COSTANTI =====

## Velocità predefinita zoom con rotella mouse (frazione per step)
const DEFAULT_ZOOM_SPEED := 0.1
## Zoom minimo (più lontano dalla mappa)
const DEFAULT_MIN_ZOOM := 0.5
## Zoom massimo (più vicino alla mappa)
const DEFAULT_MAX_ZOOM := 3.0
## Velocità movimento camera con tastiera (pixel/sec)
const DEFAULT_PAN_SPEED := 400.0
## Velocità movimento bordi schermo (pixel/sec)
const DEFAULT_EDGE_PAN_SPEED := 300.0
## Margine bordi schermo per attivare pan (pixel)
const DEFAULT_EDGE_MARGIN := 50
## Zoom iniziale per vista isometrica
const INITIAL_ZOOM := Vector2(1.5, 1.5)
## Fattore interpolazione per movimento fluido camera
const SMOOTH_LERP_FACTOR := 0.1

# ===== VARIABILI ESPORTATE =====

## Velocità zoom con rotella mouse
@export var zoom_speed := DEFAULT_ZOOM_SPEED
## Zoom minimo (più lontano)
@export var min_zoom := DEFAULT_MIN_ZOOM
## Zoom massimo (più vicino)
@export var max_zoom := DEFAULT_MAX_ZOOM
## Velocità movimento camera con tastiera
@export var pan_speed := DEFAULT_PAN_SPEED
## Velocità movimento bordi schermo
@export var edge_pan_speed := DEFAULT_EDGE_PAN_SPEED
## Margine per movimento bordi (pixel)
@export var edge_margin := DEFAULT_EDGE_MARGIN

# ===== VARIABILI PRIVATE =====

## Indica se la camera è in modalità pan con mouse centrale
var is_panning := false
## Posizione iniziale del mouse quando inizia il pan
var pan_start_position := Vector2.ZERO

# ===== METODI LIFECYCLE =====

func _ready():
	# Assicura che la camera sia attiva
	enabled = true
	# Imposta zoom iniziale
	zoom = INITIAL_ZOOM

func _unhandled_input(event):
	_handle_zoom_input(event)
	_handle_pan_input(event)
	_handle_pan_motion(event)

func _process(delta):
	_handle_keyboard_pan(delta)
	_handle_edge_panning(delta)

# ===== GESTIONE INPUT =====

## Gestisce input zoom con rotella mouse
func _handle_zoom_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_out()

## Gestisce inizio/fine pan con tasto centrale mouse
func _handle_pan_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_panning = true
				pan_start_position = event.position
			else:
				is_panning = false

## Gestisce movimento camera durante pan con mouse
func _handle_pan_motion(event: InputEvent) -> void:
	if event is InputEventMouseMotion and is_panning:
		# Calcola delta compensando per zoom corrente
		var pan_delta = (pan_start_position - event.position) / zoom.x
		position += pan_delta
		pan_start_position = event.position

## Gestisce movimento camera con tastiera (WASD)
func _handle_keyboard_pan(delta: float) -> void:
	var input_vector = Vector2.ZERO

	# Raccoglie input direzionale
	if Input.is_action_pressed("camera_left"):   # A
		input_vector.x -= 1
	if Input.is_action_pressed("camera_right"):  # D
		input_vector.x += 1
	if Input.is_action_pressed("camera_up"):     # W
		input_vector.y -= 1
	if Input.is_action_pressed("camera_down"):   # S
		input_vector.y += 1

	# Applica movimento normalizzato compensando per zoom
	if input_vector.length() > 0:
		position += input_vector.normalized() * pan_speed * delta / zoom.x

## Gestisce movimento automatico quando il mouse è ai bordi dello schermo
func _handle_edge_panning(delta: float) -> void:
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	var screen_size = viewport.get_visible_rect().size

	var pan_vector = Vector2.ZERO

	# Controlla bordi orizzontali
	if mouse_pos.x < edge_margin:
		pan_vector.x -= 1
	elif mouse_pos.x > screen_size.x - edge_margin:
		pan_vector.x += 1

	# Controlla bordi verticali
	if mouse_pos.y < edge_margin:
		pan_vector.y -= 1
	elif mouse_pos.y > screen_size.y - edge_margin:
		pan_vector.y += 1

	# Applica movimento se c'è input da bordi
	if pan_vector.length() > 0:
		position += pan_vector.normalized() * edge_pan_speed * delta / zoom.x

# ===== METODI PUBBLICI =====

## Aumenta lo zoom (avvicina la camera)
func zoom_in() -> void:
	zoom *= (1.0 + zoom_speed)
	# FIX: Corretto ordine min/max nel clamp (era invertito)
	zoom = zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))

## Diminuisce lo zoom (allontana la camera)
func zoom_out() -> void:
	zoom *= (1.0 - zoom_speed)
	# FIX: Corretto ordine min/max nel clamp (era invertito)
	zoom = zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))

## Centra la camera su una posizione specifica.
## [param pos]: La posizione target
## [param smooth]: Se true, usa interpolazione fluida; se false, movimento istantaneo
func center_on_position(pos: Vector2, smooth: bool = true) -> void:
	if smooth:
		# Movimento fluido con interpolazione
		position = position.lerp(pos, SMOOTH_LERP_FACTOR)
	else:
		# Movimento istantaneo
		position = pos

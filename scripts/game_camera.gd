# scripts/camera/camera_controller.gd
extends Camera2D
class_name CameraController

## Velocità zoom con rotella mouse
@export var zoom_speed := 0.1
## Zoom minimo (più lontano)
@export var min_zoom := 0.5
## Zoom massimo (più vicino) 
@export var max_zoom := 3.0
## Velocità movimento camera
@export var pan_speed := 400.0
## Velocità movimento bordi schermo
@export var edge_pan_speed := 300.0
## Margine per movimento bordi (pixel)
@export var edge_margin := 50

# Variabili interne
var is_panning := false
var pan_start_position := Vector2.ZERO

func _ready():
	# Assicurati che la camera sia attiva
	enabled = true
	# Imposta zoom iniziale per vista isometrica
	zoom = Vector2(1.5, 1.5)
	
func _unhandled_input(event):
	# Gestione zoom con rotella mouse
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_out()
		
		# Pan con tasto centrale mouse
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_panning = true
				pan_start_position = event.position
			else:
				is_panning = false
	
	# Movimento camera durante pan
	if event is InputEventMouseMotion and is_panning:
		var pan_delta = (pan_start_position - event.position) / zoom.x
		position += pan_delta
		pan_start_position = event.position

func _process(delta):
	# Pan con tasti WASD
	var input_vector = Vector2.ZERO
	if Input.is_action_pressed("camera_left"):  # A
		input_vector.x -= 1
	if Input.is_action_pressed("camera_right"): # D
		input_vector.x += 1
	if Input.is_action_pressed("camera_up"):    # W
		input_vector.y -= 1
	if Input.is_action_pressed("camera_down"):  # S
		input_vector.y += 1
	
	# Applica movimento
	if input_vector.length() > 0:
		position += input_vector.normalized() * pan_speed * delta / zoom.x
	
	# Pan con bordi schermo
	_handle_edge_panning(delta)

func _handle_edge_panning(delta):
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	var screen_size = viewport.get_visible_rect().size
	
	var pan_vector = Vector2.ZERO
	
	# Controlla bordi
	if mouse_pos.x < edge_margin:
		pan_vector.x -= 1
	elif mouse_pos.x > screen_size.x - edge_margin:
		pan_vector.x += 1
	
	if mouse_pos.y < edge_margin:
		pan_vector.y -= 1
	elif mouse_pos.y > screen_size.y - edge_margin:
		pan_vector.y += 1
	
	# Applica movimento bordi
	if pan_vector.length() > 0:
		position += pan_vector.normalized() * edge_pan_speed * delta / zoom.x

func zoom_in():
	zoom *= (1 + zoom_speed)
	zoom = zoom.clamp(Vector2(max_zoom, max_zoom), Vector2(min_zoom, min_zoom))
	
func zoom_out():
	zoom *= (1 - zoom_speed)
	zoom = zoom.clamp(Vector2(max_zoom, max_zoom), Vector2(min_zoom, min_zoom))

# Funzione helper per centrare su un punto
func center_on_position(pos: Vector2, smooth: bool = true):
	if smooth:
		# Movimento fluido
		position = position.lerp(pos, 0.1)
	else:
		# Movimento istantaneo
		position = pos

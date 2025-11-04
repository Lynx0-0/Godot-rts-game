# scripts/camera/enhanced_camera.gd
extends Camera2D
class_name EnhancedCameraController

@export var zoom_speed := 0.1
@export var min_zoom := 0.5
@export var max_zoom := 3.0
@export var pan_speed := 400.0
@export var edge_pan_speed := 300.0
@export var edge_margin := 50

# Effetti visivi
@export var enable_depth_effects := true
@export var vignette_intensity := 0.4
@export var blur_intensity := 2.0
@export var center_brightness_boost := 0.3

var is_panning := false
var pan_start_position := Vector2.ZERO

# Nodo per post-processing
var post_process_layer: CanvasLayer
var color_rect: ColorRect
var depth_material: ShaderMaterial

func _ready():
	enabled = true
	zoom = Vector2(1.5, 1.5)
	
	if enable_depth_effects:
		_setup_post_processing()

func _setup_post_processing():
	"""Crea layer per effetti post-processing"""
	post_process_layer = CanvasLayer.new()
	post_process_layer.layer = 128  # Layer alto per essere sopra tutto
	post_process_layer.follow_viewport_enabled = true
	add_child(post_process_layer)
	
	# ColorRect che copre tutto lo schermo
	color_rect = ColorRect.new()
	color_rect.material = ShaderMaterial.new()
	
	# Carica shader
	var shader = load("res://shaders/depth_vignette.gdshader")
	if shader:
		color_rect.material.shader = shader
		depth_material = color_rect.material
		
		# Imposta parametri iniziali
		depth_material.set_shader_parameter("vignette_intensity", vignette_intensity)
		depth_material.set_shader_parameter("blur_amount", blur_intensity)
		depth_material.set_shader_parameter("focus_center", Vector2(0.5, 0.5))
		depth_material.set_shader_parameter("focus_radius", 0.35)
	
	# Imposta dimensioni full screen
	color_rect.anchor_right = 1.0
	color_rect.anchor_bottom = 1.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	post_process_layer.add_child(color_rect)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_out()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_panning = true
				pan_start_position = event.position
			else:
				is_panning = false
	
	if event is InputEventMouseMotion and is_panning:
		var pan_delta = (pan_start_position - event.position) / zoom.x
		position += pan_delta
		pan_start_position = event.position

func _process(delta):
	# Pan con WASD
	var input_vector = Vector2.ZERO
	if Input.is_action_pressed("camera_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("camera_right"):
		input_vector.x += 1
	if Input.is_action_pressed("camera_up"):
		input_vector.y -= 1
	if Input.is_action_pressed("camera_down"):
		input_vector.y += 1
	
	if input_vector.length() > 0:
		position += input_vector.normalized() * pan_speed * delta / zoom.x
	
	_handle_edge_panning(delta)
	
	# Aggiorna effetti visivi in base allo zoom
	if enable_depth_effects and depth_material:
		_update_depth_effects()

func _update_depth_effects():
	"""Aggiorna intensità effetti in base allo zoom"""
	var zoom_factor = zoom.x / 1.5  # Normalizzato rispetto a zoom base
	
	# Più sei zoommato, meno effetto (più dettaglio)
	var adjusted_vignette = vignette_intensity * (2.0 - zoom_factor)
	var adjusted_blur = blur_intensity * (2.0 - zoom_factor)
	
	depth_material.set_shader_parameter("vignette_intensity", clamp(adjusted_vignette, 0.0, 1.0))
	depth_material.set_shader_parameter("blur_amount", clamp(adjusted_blur, 0.0, 5.0))

func _handle_edge_panning(delta):
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position()
	var screen_size = viewport.get_visible_rect().size
	
	var pan_vector = Vector2.ZERO
	
	if mouse_pos.x < edge_margin:
		pan_vector.x -= 1
	elif mouse_pos.x > screen_size.x - edge_margin:
		pan_vector.x += 1
	
	if mouse_pos.y < edge_margin:
		pan_vector.y -= 1
	elif mouse_pos.y > screen_size.y - edge_margin:
		pan_vector.y += 1
	
	if pan_vector.length() > 0:
		position += pan_vector.normalized() * edge_pan_speed * delta / zoom.x

func zoom_in():
	zoom *= (1 + zoom_speed)
	zoom = zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	
func zoom_out():
	zoom *= (1 - zoom_speed)
	zoom = zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))

func center_on_position(pos: Vector2, smooth: bool = true):
	if smooth:
		var tween = create_tween()
		tween.tween_property(self, "position", pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		position = pos

func toggle_depth_effects(enabled: bool):
	"""Abilita/disabilita effetti profondità runtime"""
	enable_depth_effects = enabled
	if post_process_layer:
		post_process_layer.visible = enabled

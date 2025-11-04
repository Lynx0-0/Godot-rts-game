# scripts/ui/minimap.gd
extends Control
class_name Minimap

## Minimappa del gioco con vista dall'alto
## Mostra posizione unità, edifici e risorse

# ===== COSTANTI =====

## Dimensione della minimappa (pixel)
const MINIMAP_SIZE := Vector2(200, 200)
## Colore unità player sulla minimappa
const PLAYER_UNIT_COLOR := Color.GREEN
## Colore edifici player sulla minimappa
const PLAYER_BUILDING_COLOR := Color.BLUE
## Colore risorse sulla minimappa
const RESOURCE_COLOR := Color.YELLOW
## Colore viewport camera (area visibile)
const CAMERA_VIEWPORT_COLOR := Color(1, 1, 1, 0.3)
## Colore bordo minimappa
const BORDER_COLOR := Color(0.2, 0.2, 0.2, 0.8)
## Spessore bordo
const BORDER_WIDTH := 2.0

# ===== VARIABILI ESPORTATE =====

## Bounds della mappa di gioco (area da mostrare)
@export var map_bounds := Rect2(-1000, -1000, 4000, 4000)
## Se mostrare il viewport della camera
@export var show_camera_viewport := true
## Opacità sfondo minimappa
@export var background_opacity := 0.5

# ===== VARIABILI PRIVATE =====

## Riferimento alla camera principale
var main_camera: Camera2D
## Scala per convertire coordinate mondo -> minimappa
var world_to_minimap_scale: Vector2

# ===== RIFERIMENTI NODI =====

@onready var background = $Background
@onready var viewport_container = $ViewportContainer
@onready var sub_viewport = $ViewportContainer/SubViewport
@onready var minimap_camera = $ViewportContainer/SubViewport/MinimapCamera

# ===== METODI LIFECYCLE =====

func _ready():
	# Setup dimensioni
	custom_minimum_size = MINIMAP_SIZE
	size = MINIMAP_SIZE

	if viewport_container:
		viewport_container.size = MINIMAP_SIZE
		viewport_container.custom_minimum_size = MINIMAP_SIZE

	if sub_viewport:
		sub_viewport.size = MINIMAP_SIZE

	# Setup background
	if background:
		background.color = Color(0.1, 0.1, 0.1, background_opacity)
		background.size = MINIMAP_SIZE

	# Calcola scala conversione
	_calculate_scale()

	# Setup camera minimappa
	_setup_minimap_camera()

	# Trova camera principale
	_find_main_camera()

	print("Minimappa inizializzata - Bounds: %v" % map_bounds)

func _process(_delta):
	queue_redraw()

func _draw():
	# Disegna bordo
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, BORDER_WIDTH)

	# Disegna viewport camera principale (area visibile)
	if show_camera_viewport and main_camera:
		_draw_camera_viewport()

	# Disegna icone entità
	_draw_entities()

# ===== SETUP =====

func _calculate_scale():
	"""Calcola fattore di scala mondo -> minimappa"""
	world_to_minimap_scale = MINIMAP_SIZE / map_bounds.size

func _setup_minimap_camera():
	"""Configura camera della minimappa"""
	if not minimap_camera:
		return

	# Posiziona camera al centro della mappa
	minimap_camera.position = map_bounds.get_center()

	# Calcola zoom per far entrare tutta la mappa
	var zoom_x = MINIMAP_SIZE.x / map_bounds.size.x
	var zoom_y = MINIMAP_SIZE.y / map_bounds.size.y
	var zoom_factor = min(zoom_x, zoom_y) * 2.0  # *2 perché zoom in Godot è factor

	minimap_camera.zoom = Vector2(zoom_factor, zoom_factor)
	minimap_camera.enabled = true

func _find_main_camera():
	"""Trova la camera principale della scena"""
	var cameras = get_tree().get_nodes_in_group("main_camera")
	if cameras.size() > 0:
		main_camera = cameras[0]
	else:
		# Fallback: cerca qualsiasi Camera2D
		for node in get_tree().root.get_children():
			if node is Camera2D and node.enabled:
				main_camera = node
				break

	if main_camera:
		print("Minimappa collegata a camera: %s" % main_camera.name)

# ===== DRAWING =====

func _draw_camera_viewport():
	"""Disegna rettangolo che mostra l'area visibile dalla camera"""
	if not main_camera:
		return

	var viewport_size = get_viewport().get_visible_rect().size
	var camera_zoom = main_camera.zoom.x

	# Dimensioni area visibile nel mondo
	var visible_size = viewport_size / camera_zoom

	# Posizione camera nel mondo
	var camera_pos = main_camera.global_position

	# Converti in coordinate minimappa
	var top_left = _world_to_minimap(camera_pos - visible_size / 2.0)
	var bottom_right = _world_to_minimap(camera_pos + visible_size / 2.0)

	var rect = Rect2(top_left, bottom_right - top_left)

	# Disegna rettangolo viewport
	draw_rect(rect, CAMERA_VIEWPORT_COLOR, true)
	draw_rect(rect, Color.WHITE, false, 1.0)

func _draw_entities():
	"""Disegna icone per unità, edifici e risorse"""

	# Disegna unità player (cerchi verdi)
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit) and unit is Node2D:
			var pos = _world_to_minimap(unit.global_position)
			draw_circle(pos, 2, PLAYER_UNIT_COLOR)

	# Disegna edifici (quadrati blu)
	for building in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(building) and building is Node2D:
			var pos = _world_to_minimap(building.global_position)
			draw_rect(Rect2(pos - Vector2(3, 3), Vector2(6, 6)), PLAYER_BUILDING_COLOR, true)

	# Disegna risorse (cerchi gialli)
	for resource in get_tree().get_nodes_in_group("resource_nodes"):
		if is_instance_valid(resource) and resource is Node2D:
			var pos = _world_to_minimap(resource.global_position)
			draw_circle(pos, 2, RESOURCE_COLOR)

# ===== CONVERSIONI =====

func _world_to_minimap(world_pos: Vector2) -> Vector2:
	"""Converte coordinate mondo in coordinate minimappa"""
	var relative_pos = world_pos - map_bounds.position
	return relative_pos * world_to_minimap_scale

func _minimap_to_world(minimap_pos: Vector2) -> Vector2:
	"""Converte coordinate minimappa in coordinate mondo"""
	var relative_pos = minimap_pos / world_to_minimap_scale
	return relative_pos + map_bounds.position

# ===== INPUT =====

func _gui_input(event):
	"""Gestisce click sulla minimappa per muovere camera"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_minimap_click(event.position)

func _handle_minimap_click(click_pos: Vector2):
	"""Muove camera principale alla posizione cliccata"""
	if not main_camera:
		return

	var world_pos = _minimap_to_world(click_pos)

	# Muove camera con smooth
	if main_camera.has_method("center_on_position"):
		main_camera.center_on_position(world_pos, true)
	else:
		main_camera.position = world_pos

	print("Camera spostata a posizione: %v" % world_pos)

# ===== METODI PUBBLICI =====

func set_map_bounds(bounds: Rect2):
	"""Aggiorna i bounds della mappa"""
	map_bounds = bounds
	_calculate_scale()
	_setup_minimap_camera()

func set_main_camera(camera: Camera2D):
	"""Imposta manualmente la camera principale"""
	main_camera = camera
	print("Camera principale impostata: %s" % camera.name)

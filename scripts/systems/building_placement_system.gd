# scripts/systems/building_placement_system.gd
extends Node

## Sistema per piazzamento edifici su griglia
## Gestisce preview, validazione posizione e snap a griglia

# ===== COSTANTI =====

## Dimensione cella griglia (pixel)
const GRID_SIZE := 32
## Colore preview valido (verde trasparente)
const VALID_COLOR := Color(0, 1, 0, 0.5)
## Colore preview invalido (rosso trasparente)
const INVALID_COLOR := Color(1, 0, 0, 0.5)

# ===== VARIABILI =====

var is_placing := false
var current_building_scene: PackedScene = null
var preview_building: Node2D = null
var building_size := Vector2i(1, 1)  # Dimensione in celle (larghezza, altezza)
var placement_valid := false

# Layer per collision check
var occupied_cells: Dictionary = {}  # Vector2i -> bool

# ===== SEGNALI =====

signal building_placed(building: Node2D, grid_position: Vector2i)
signal placement_cancelled

# ===== METODI PUBBLICI =====

func start_placement(building_scene: PackedScene, size: Vector2i = Vector2i(1, 1)):
	"""Inizia modalità piazzamento edificio"""
	if is_placing:
		cancel_placement()

	current_building_scene = building_scene
	building_size = size
	is_placing = true

	# Crea preview
	_create_preview()

	print("Modalità piazzamento attivata - Edificio %dx%d celle" % [size.x, size.y])

func cancel_placement():
	"""Annulla piazzamento corrente"""
	if preview_building:
		preview_building.queue_free()
		preview_building = null

	is_placing = false
	current_building_scene = null
	placement_cancelled.emit()

	print("Piazzamento annullato")

func _process(_delta):
	if is_placing and preview_building:
		_update_preview_position()

func _input(event):
	if not is_placing:
		return

	# Click sinistro: piazza edificio
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if placement_valid:
			_place_building()
		else:
			print("Posizione non valida per piazzamento!")

	# Click destro o ESC: annulla
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_placement()

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_placement()

# ===== METODI PRIVATI =====

func _create_preview():
	"""Crea preview edificio"""
	if not current_building_scene:
		return

	preview_building = current_building_scene.instantiate()

	# Rendi semi-trasparente
	preview_building.modulate = VALID_COLOR

	# Disabilita collisioni del preview
	for child in preview_building.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.disabled = true

	# Aggiungi alla scena
	get_tree().root.add_child(preview_building)

func _update_preview_position():
	"""Aggiorna posizione preview basato su mouse"""
	var mouse_pos = preview_building.get_global_mouse_position()

	# Snap a griglia
	var grid_pos = world_to_grid(mouse_pos)
	var snapped_pos = grid_to_world(grid_pos)

	# Aggiorna posizione preview
	preview_building.global_position = snapped_pos

	# Valida posizione
	placement_valid = _is_placement_valid(grid_pos)

	# Cambia colore basato su validità
	preview_building.modulate = VALID_COLOR if placement_valid else INVALID_COLOR

func _is_placement_valid(grid_pos: Vector2i) -> bool:
	"""Controlla se posizione è valida per piazzamento"""
	# Controlla tutte le celle occupate dall'edificio
	for x in range(building_size.x):
		for y in range(building_size.y):
			var cell = Vector2i(grid_pos.x + x, grid_pos.y + y)

			# Controlla se già occupata
			if occupied_cells.has(cell):
				return false

			# Controlla collision con altri edifici (physics check)
			var world_pos = grid_to_world(cell)
			if _has_collision_at(world_pos):
				return false

	return true

func _has_collision_at(world_pos: Vector2) -> bool:
	"""Controlla se c'è collisione nella posizione"""
	# Query physics space
	var space_state = preview_building.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_point(query, 1)
	return result.size() > 0

func _place_building():
	"""Piazza l'edificio nella posizione corrente"""
	if not current_building_scene or not preview_building:
		return

	var grid_pos = world_to_grid(preview_building.global_position)

	# Crea edificio reale
	var building = current_building_scene.instantiate()
	building.global_position = grid_to_world(grid_pos)

	# Aggiungi alla scena
	get_tree().root.add_child(building)

	# Marca celle come occupate
	for x in range(building_size.x):
		for y in range(building_size.y):
			var cell = Vector2i(grid_pos.x + x, grid_pos.y + y)
			occupied_cells[cell] = true

	# Emetti segnale
	building_placed.emit(building, grid_pos)

	print("Edificio piazzato a griglia %v (world: %v)" % [grid_pos, building.global_position])

	# Pulisci preview
	cancel_placement()

# ===== CONVERSIONI GRIGLIA =====

func world_to_grid(world_pos: Vector2) -> Vector2i:
	"""Converte posizione mondo in coordinate griglia"""
	return Vector2i(
		floori(world_pos.x / GRID_SIZE),
		floori(world_pos.y / GRID_SIZE)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	"""Converte coordinate griglia in posizione mondo (centro cella)"""
	return Vector2(
		grid_pos.x * GRID_SIZE + GRID_SIZE / 2.0,
		grid_pos.y * GRID_SIZE + GRID_SIZE / 2.0
	)

func get_grid_rect(grid_pos: Vector2i, size: Vector2i) -> Rect2i:
	"""Ottiene rettangolo griglia per edificio"""
	return Rect2i(grid_pos, size)

# ===== DEBUG =====

func _draw_grid():
	"""Debug: disegna griglia"""
	# TODO: Implementare rendering griglia per debug
	pass

# ===== REGISTRAZIONE EDIFICI ESISTENTI =====

func register_existing_building(building: Node2D, size: Vector2i):
	"""Registra edificio esistente per occupare celle"""
	var grid_pos = world_to_grid(building.global_position)

	for x in range(size.x):
		for y in range(size.y):
			var cell = Vector2i(grid_pos.x + x, grid_pos.y + y)
			occupied_cells[cell] = true

	print("Edificio registrato: %v (%dx%d celle)" % [grid_pos, size.x, size.y])

func unregister_building(building: Node2D, size: Vector2i):
	"""Rimuove edificio dalla griglia (quando demolito)"""
	var grid_pos = world_to_grid(building.global_position)

	for x in range(size.x):
		for y in range(size.y):
			var cell = Vector2i(grid_pos.x + x, grid_pos.y + y)
			occupied_cells.erase(cell)

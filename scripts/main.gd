# scripts/main.gd
extends Node2D

## Scena principale del gioco RTS.
## Gestisce selezione unità, comandi, input e setup della mappa.

# ===== COSTANTI =====

## Soglia minima per considerare un drag come selezione ad area (pixel)
const MIN_DRAG_THRESHOLD := 10.0
## Raggio massimo per selezionare unità singola (pixel)
const SINGLE_SELECT_RADIUS := 50.0
## Raggio di rilevamento risorsa per comando raccolta (pixel)
const RESOURCE_DETECT_RADIUS := 80.0
## Spaziatura tra unità in formazione (pixel)
const FORMATION_SPACING := 60.0

## Colore box selezione (riempimento)
const SELECTION_BOX_FILL := Color(0.2, 0.8, 0.2, 0.3)
## Colore box selezione (bordo)
const SELECTION_BOX_BORDER := Color(0.2, 1.0, 0.2, 0.8)
## Spessore bordo box selezione (pixel)
const SELECTION_BOX_BORDER_WIDTH := 2.0

## Quantità di risorse da aggiungere con scorciatoie tastiera
const DEBUG_RESOURCE_AMOUNT := 50

# ===== VARIABILI =====

## Array di unità attualmente selezionate
var selected_units: Array[BaseUnit] = []
## Se l'utente sta eseguendo un drag per selezione
var is_dragging := false
## Posizione iniziale del drag
var drag_start := Vector2.ZERO
## Previene inizializzazioni multiple
var setup_completed := false

# ===== RIFERIMENTI NODI =====

@onready var hud = $HUD

# ===== METODI LIFECYCLE =====

func _ready():
	# Previene setup duplicati
	if setup_completed:
		push_warning("Setup già completato, saltando reinizializzazione")
		return

	print("=== Main inizializzato ===")
	_setup_test_map()
	setup_completed = true

func _unhandled_input(event):
	_handle_mouse_input(event)
	_handle_keyboard_input(event)

func _draw():
	if is_dragging:
		_draw_selection_box()

# ===== GESTIONE INPUT =====

## Gestisce input del mouse (click, drag, comandi)
func _handle_mouse_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_world_pos = get_global_mouse_position()

		# Click sinistro: selezione unità
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_selection(mouse_world_pos)
			else:
				_end_selection(mouse_world_pos)

		# Click destro: comanda unità selezionate
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_command_selected_units(mouse_world_pos)

	# Movimento mouse durante drag: aggiorna visualizzazione
	elif event is InputEventMouseMotion and is_dragging:
		queue_redraw()

## Gestisce scorciatoie da tastiera (debug e comandi)
func _handle_keyboard_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		# Debug: aggiungi risorse
		KEY_F:
			ResourceManager.add_resource(ResourceManager.ResourceType.FOOD, DEBUG_RESOURCE_AMOUNT)
		KEY_W:
			ResourceManager.add_resource(ResourceManager.ResourceType.WOOD, DEBUG_RESOURCE_AMOUNT)
		KEY_G:
			ResourceManager.add_resource(ResourceManager.ResourceType.GOLD, DEBUG_RESOURCE_AMOUNT)

		# Debug: spawn worker
		KEY_T:
			_spawn_test_worker()

		# Comandi worker
		KEY_S:
			_stop_selected_workers()
		KEY_R:
			_return_selected_workers()

# ===== RENDERING =====

## Disegna il box di selezione durante il drag
func _draw_selection_box() -> void:
	var current_pos = get_global_mouse_position()
	var rect = Rect2(drag_start, current_pos - drag_start)

	# Riempimento trasparente
	draw_rect(rect, SELECTION_BOX_FILL, true)
	# Bordo colorato
	draw_rect(rect, SELECTION_BOX_BORDER, false, SELECTION_BOX_BORDER_WIDTH)

# ===== GESTIONE SELEZIONE =====

## Inizia una nuova selezione, deselezionando le unità precedenti
func _start_selection(pos: Vector2) -> void:
	# Deseleziona tutte le unità precedentemente selezionate
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()

	# Inizia il drag per selezione
	is_dragging = true
	drag_start = pos
	queue_redraw()

## Completa la selezione, determinando se click singolo o area
func _end_selection(pos: Vector2) -> void:
	if not is_dragging:
		return

	is_dragging = false
	var drag_end = pos
	var selection_rect = Rect2(drag_start, drag_end - drag_start).abs()

	# Determina se click singolo o selezione ad area
	if selection_rect.size.length() < MIN_DRAG_THRESHOLD:
		_select_single_unit(pos)
	else:
		_select_units_in_area(selection_rect)

	# Aggiorna HUD con info unità selezionate
	if hud:
		hud.show_unit_info(selected_units)

	queue_redraw()
	print("Selezionate %d unità" % selected_units.size())

## Seleziona la singola unità più vicina al punto di click
func _select_single_unit(pos: Vector2) -> void:
	var units = get_tree().get_nodes_in_group("units")
	var closest_unit = null
	var min_distance = SINGLE_SELECT_RADIUS

	for unit in units:
		if not is_instance_valid(unit):
			continue

		var distance = unit.global_position.distance_to(pos)
		if distance < min_distance:
			min_distance = distance
			closest_unit = unit

	if closest_unit:
		closest_unit.set_selected(true)
		selected_units.append(closest_unit)

## Seleziona tutte le unità contenute nel rettangolo di selezione
func _select_units_in_area(selection_rect: Rect2) -> void:
	var units = get_tree().get_nodes_in_group("units")

	for unit in units:
		if not is_instance_valid(unit):
			continue

		if selection_rect.has_point(unit.global_position):
			unit.set_selected(true)
			selected_units.append(unit)

# ===== GESTIONE COMANDI UNITÀ =====

## Gestisce comando click destro su unità selezionate
func _command_selected_units(target_pos: Vector2) -> void:
	if selected_units.size() == 0:
		return

	# Controlla se c'è una risorsa vicina al target
	var nearby_resource = _find_resource_near_position(target_pos)

	if nearby_resource:
		# Se c'è una risorsa, comanda i worker di raccoglierla
		_command_workers_gather(nearby_resource)
	else:
		# Altrimenti movimento normale
		_command_units_move(target_pos)

## Trova un nodo risorsa vicino a una posizione
func _find_resource_near_position(pos: Vector2):
	var resource_nodes = get_tree().get_nodes_in_group("resource_nodes")

	for resource in resource_nodes:
		if not is_instance_valid(resource):
			continue

		var distance = resource.global_position.distance_to(pos)
		if distance < RESOURCE_DETECT_RADIUS:
			return resource

	return null

## Comanda i worker selezionati di raccogliere da una risorsa
func _command_workers_gather(resource_node) -> void:
	for unit in selected_units:
		if not is_instance_valid(unit):
			continue

		# Controlla se è un worker e ha il metodo gather
		if unit.unit_type == "worker" and unit.has_method("gather_from_resource"):
			unit.gather_from_resource(resource_node)
			print("Worker %s comandato di raccogliere" % unit.name)

## Comanda le unità di muoversi, singolarmente o in formazione
func _command_units_move(target_pos: Vector2) -> void:
	# Filtra unità valide
	var valid_units: Array[BaseUnit] = []
	for unit in selected_units:
		if is_instance_valid(unit):
			valid_units.append(unit)

	if valid_units.size() == 0:
		return

	if valid_units.size() == 1:
		# Singola unità: movimento diretto
		valid_units[0].move_to_position(target_pos)
	else:
		# Unità multiple: formazione
		_move_units_in_formation(valid_units, target_pos)

## Muove unità in formazione griglia centrata sulla posizione target
func _move_units_in_formation(units: Array[BaseUnit], center_pos: Vector2) -> void:
	var units_per_row = ceil(sqrt(units.size()))

	for i in range(units.size()):
		var row = i / int(units_per_row)
		var col = i % int(units_per_row)

		# Calcola offset dalla posizione centrale
		var offset = Vector2(
			(col - units_per_row * 0.5) * FORMATION_SPACING,
			(row - units_per_row * 0.5) * FORMATION_SPACING
		)

		units[i].move_to_position(center_pos + offset)

# ===== SETUP MAPPA =====

## Crea la mappa di test con edifici, risorse e unità iniziali
func _setup_test_map() -> void:
	print("Creando mappa di test...")

	# Crea Town Center
	_create_town_center(Vector2(200, 200))

	# Crea nodi di risorse sparsi nella mappa
	_create_resource_node(Vector2(400, 150), ResourceManager.ResourceType.WOOD)
	_create_resource_node(Vector2(350, 300), ResourceManager.ResourceType.FOOD)
	_create_resource_node(Vector2(150, 350), ResourceManager.ResourceType.GOLD)
	_create_resource_node(Vector2(500, 250), ResourceManager.ResourceType.WOOD)
	_create_resource_node(Vector2(300, 100), ResourceManager.ResourceType.FOOD)

	# Spawn worker iniziale
	_spawn_initial_worker()

	print("Mappa di test creata con successo!")

## Crea un Town Center alla posizione specificata
func _create_town_center(pos: Vector2) -> void:
	var town_center_scene = preload("res://scenes/buildings/town_center.tscn")
	var town_center = town_center_scene.instantiate()
	add_child(town_center)
	town_center.global_position = pos
	print("Town Center creato a posizione %v" % pos)

## Crea un nodo risorsa alla posizione specificata
func _create_resource_node(pos: Vector2, type: ResourceManager.ResourceType) -> void:
	var resource_scene = preload("res://scenes/environment/resource_node.tscn")
	var resource = resource_scene.instantiate()
	add_child(resource)
	resource.global_position = pos
	resource.resource_type = type

## Spawn del worker iniziale
func _spawn_initial_worker() -> void:
	var worker_scene = preload("res://scenes/units/worker.tscn")
	var worker = worker_scene.instantiate()
	add_child(worker)
	worker.global_position = Vector2(250, 250)
	print("Worker iniziale creato")

# ===== COMANDI DEBUG =====

## Spawn worker di test alla posizione del mouse (debug - tasto T)
func _spawn_test_worker() -> void:
	var worker_scene = preload("res://scenes/units/worker.tscn")
	var worker = worker_scene.instantiate()
	add_child(worker)
	worker.global_position = get_global_mouse_position()
	print("Worker test spawnato alla posizione %v" % worker.global_position)

## Ferma tutti i worker selezionati (debug - tasto S)
func _stop_selected_workers() -> void:
	var stopped_count = 0
	for unit in selected_units:
		if is_instance_valid(unit) and unit.unit_type == "worker":
			unit.stop_all_tasks()
			stopped_count += 1

	print("%d worker fermati" % stopped_count)

## Fai tornare tutti i worker selezionati alla base (debug - tasto R)
func _return_selected_workers() -> void:
	var returned_count = 0
	for unit in selected_units:
		if is_instance_valid(unit) and unit.unit_type == "worker":
			unit.return_to_base()
			returned_count += 1

	print("%d worker comandati di tornare alla base" % returned_count)

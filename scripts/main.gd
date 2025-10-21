# scripts/main.gd
extends Node2D

var selected_units: Array[BaseUnit] = []
var is_dragging := false
var drag_start := Vector2.ZERO
var setup_completed := false  # Previene setup multipli

@onready var hud = $HUD

func _ready():
	if setup_completed:
		print("Setup già completato, saltando...")
		return
	
	print("Main inizializzato - UNICO")
	_setup_test_map()
	setup_completed = true

func _unhandled_input(event):
	if event is InputEventMouseButton:
		var mouse_world_pos = get_global_mouse_position()
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_selection(mouse_world_pos)
			else:
				_end_selection(mouse_world_pos)
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_command_selected_units(mouse_world_pos)
	
	elif event is InputEventMouseMotion and is_dragging:
		queue_redraw()
	
	# Comandi da tastiera
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F:
				ResourceManager.add_resource(ResourceManager.ResourceType.FOOD, 50)
			KEY_W:
				ResourceManager.add_resource(ResourceManager.ResourceType.WOOD, 50)
			KEY_G:
				ResourceManager.add_resource(ResourceManager.ResourceType.GOLD, 50)
			KEY_T:
				_spawn_test_worker()
			KEY_S:
				_stop_selected_workers()
			KEY_R:
				_return_selected_workers()

func _draw():
	if is_dragging:
		var current_pos = get_global_mouse_position()
		var rect = Rect2(drag_start, current_pos - drag_start)
		
		# Box di selezione
		draw_rect(rect, Color(0.2, 0.8, 0.2, 0.3), true)
		draw_rect(rect, Color(0.2, 1.0, 0.2, 0.8), false, 2.0)

func _start_selection(pos: Vector2):
	# Deseleziona tutto
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()
	
	is_dragging = true
	drag_start = pos
	queue_redraw()

func _end_selection(pos: Vector2):
	if not is_dragging:
		return
	
	is_dragging = false
	var drag_end = pos
	var selection_rect = Rect2(drag_start, drag_end - drag_start).abs()
	
	# Click singolo o selezione area?
	if selection_rect.size.length() < 10:
		_select_single_unit(pos)
	else:
		_select_units_in_area(selection_rect)
	
	# Aggiorna HUD
	if hud:
		hud.show_unit_info(selected_units)
	
	queue_redraw()
	print("Selezionate ", selected_units.size(), " unità")

func _select_single_unit(pos: Vector2):
	"""Seleziona singola unità più vicina al click"""
	var units = get_tree().get_nodes_in_group("units")
	var closest_unit = null
	var min_distance = 50.0  # Raggio massimo selezione
	
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

func _select_units_in_area(selection_rect: Rect2):
	"""Seleziona tutte le unità nell'area"""
	var units = get_tree().get_nodes_in_group("units")
	
	for unit in units:
		if not is_instance_valid(unit):
			continue
		
		if selection_rect.has_point(unit.global_position):
			unit.set_selected(true)
			selected_units.append(unit)

func _command_selected_units(target_pos: Vector2):
	"""Gestisce comando click destro"""
	if selected_units.size() == 0:
		return
	
	# Controlla se c'è una risorsa vicina al target
	var nearby_resource = _find_resource_near_position(target_pos)
	
	if nearby_resource:
		# Comanda worker a raccogliere
		_command_workers_gather(nearby_resource)
	else:
		# Movimento normale
		_command_units_move(target_pos)

func _find_resource_near_position(pos: Vector2):
	"""Trova risorsa vicina a una posizione"""
	var resource_nodes = get_tree().get_nodes_in_group("resource_nodes")
	
	for resource in resource_nodes:
		if not is_instance_valid(resource):
			continue
		
		var distance = resource.global_position.distance_to(pos)
		if distance < 80.0:  # Raggio rilevamento risorsa
			return resource
	
	return null

func _command_workers_gather(resource_node):
	"""Comanda worker selezionati di raccogliere"""
	for unit in selected_units:
		if not is_instance_valid(unit):
			continue
		
		# Controllo più sicuro per worker
		if unit.unit_type == "worker":
			if unit.has_method("gather_from_resource"):
				unit.gather_from_resource(resource_node)
				print("Worker comandato di raccogliere")

func _command_units_move(target_pos: Vector2):
	"""Comanda unità di muoversi in formazione"""
	var valid_units: Array[BaseUnit] = []
	
	# Filtra unità valide
	for unit in selected_units:
		if is_instance_valid(unit):
			valid_units.append(unit)
	
	if valid_units.size() == 0:
		return
	
	if valid_units.size() == 1:
		# Singola unità
		valid_units[0].move_to_position(target_pos)
	else:
		# Formazione multipla
		_move_units_in_formation(valid_units, target_pos)

func _move_units_in_formation(units: Array[BaseUnit], center_pos: Vector2):
	"""Muove unità in formazione"""
	var spacing = 60.0
	var units_per_row = ceil(sqrt(units.size()))
	
	for i in range(units.size()):
		var row = i / int(units_per_row)
		var col = i % int(units_per_row)
		
		var offset = Vector2(
			(col - units_per_row * 0.5) * spacing,
			(row - units_per_row * 0.5) * spacing
		)
		
		units[i].move_to_position(center_pos + offset)

# ===== SETUP MAPPA =====

func _setup_test_map():
	"""Crea mappa di test"""
	print("Creando mappa di test...")
	
	# Town Center
	_create_town_center(Vector2(200, 200))
	
	# Risorse
	_create_resource_node(Vector2(400, 150), ResourceManager.ResourceType.WOOD)
	_create_resource_node(Vector2(350, 300), ResourceManager.ResourceType.FOOD)
	_create_resource_node(Vector2(150, 350), ResourceManager.ResourceType.GOLD)
	_create_resource_node(Vector2(500, 250), ResourceManager.ResourceType.WOOD)
	_create_resource_node(Vector2(300, 100), ResourceManager.ResourceType.FOOD)
	
	# Worker iniziale
	_spawn_initial_worker()
	
	print("Mappa creata!")

func _create_town_center(pos: Vector2):
	var town_center_scene = preload("res://scenes/buildings/town_center.tscn")
	var town_center = town_center_scene.instantiate()
	add_child(town_center)
	town_center.global_position = pos
	print("Town Center creato")

func _create_resource_node(pos: Vector2, type: ResourceManager.ResourceType):
	var resource_scene = preload("res://scenes/environment/resource_node.tscn")
	var resource = resource_scene.instantiate()
	add_child(resource)
	resource.global_position = pos
	resource.resource_type = type

func _spawn_initial_worker():
	var worker_scene = preload("res://scenes/units/worker.tscn")
	var worker = worker_scene.instantiate()
	add_child(worker)
	worker.global_position = Vector2(250, 250)
	print("Worker iniziale creato")

func _spawn_test_worker():
	var worker_scene = preload("res://scenes/units/worker.tscn")
	var worker = worker_scene.instantiate()
	add_child(worker)
	worker.global_position = get_global_mouse_position()
	print("Worker test spawnato")

func _stop_selected_workers():
	"""Ferma tutti i worker selezionati"""
	for unit in selected_units:
		if is_instance_valid(unit) and unit.unit_type == "worker":
			unit.stop_all_tasks()
	print("Worker selezionati fermati")

func _return_selected_workers():
	"""Fai tornare tutti i worker selezionati alla base"""
	for unit in selected_units:
		if is_instance_valid(unit) and unit.unit_type == "worker":
			unit.return_to_base()
	print("Worker selezionati tornano alla base")

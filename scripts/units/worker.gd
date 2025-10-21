# scripts/units/worker.gd
extends BaseUnit
class_name Worker

# Variabili Worker
@export var gather_rate := 10
@export var carry_capacity := 50

# Inventario semplice (numeri interi)
var food_carried := 0
var wood_carried := 0
var gold_carried := 0

# Stato worker
var is_gathering := false
var is_returning := false
var target_resource_node = null
var target_town_center = null

# Timer per raccolta
var gather_timer := 0.0
var gather_interval := 1.0  # Raccogli ogni secondo

func _ready():
	super._ready()
	
	# Setup worker specifico
	unit_type = "worker"
	speed = 120.0
	max_health = 75
	current_health = max_health
	
	# Colore distintivo
	if sprite:
		sprite.modulate = Color.YELLOW
	
	print("Worker ", name, " creato")

func _process(delta):
	# Gestisci raccolta se vicino a risorsa
	if is_gathering and target_resource_node:
		_handle_gathering(delta)
	
	# Gestisci deposito se vicino a town center
	if is_returning and target_town_center:
		_handle_depositing()

func _handle_gathering(delta):
	# Controlla se ancora vicino alla risorsa
	if not target_resource_node or not is_instance_valid(target_resource_node):
		stop_gathering()
		return
	
	# Se la risorsa è esaurita, fermati
	if target_resource_node.current_resources <= 0:
		print("Risorsa esaurita, worker si ferma")
		stop_gathering()
		return
	
	var distance = global_position.distance_to(target_resource_node.global_position)
	if distance > 64.0:  # Troppo lontano
		return
	
	# Timer raccolta
	gather_timer += delta
	if gather_timer >= gather_interval:
		gather_timer = 0.0
		_gather_resources()

func _gather_resources():
	if not target_resource_node:
		return
	
	# Calcola spazio disponibile
	var total_carried = food_carried + wood_carried + gold_carried
	var space_available = carry_capacity - total_carried
	
	if space_available <= 0:
		# Inventario pieno - torna al town center
		return_to_base()
		return
	
	# Raccogli risorse dal nodo
	var gathered = min(gather_rate, space_available)
	var actual_gathered = target_resource_node.gather_resource(gathered)
	
	# Aggiungi all'inventario corretto
	match target_resource_node.resource_type:
		ResourceManager.ResourceType.FOOD:
			food_carried += actual_gathered
		ResourceManager.ResourceType.WOOD:
			wood_carried += actual_gathered
		ResourceManager.ResourceType.GOLD:
			gold_carried += actual_gathered
	
	print("Worker raccolse ", actual_gathered, " risorse")
	
	# Controlla se inventario pieno
	total_carried = food_carried + wood_carried + gold_carried
	if total_carried >= carry_capacity:
		return_to_base()

func _handle_depositing():
	if not target_town_center or not is_instance_valid(target_town_center):
		stop_returning()
		return
	
	var distance = global_position.distance_to(target_town_center.global_position)
	if distance > 80.0:  # Troppo lontano
		return
	
	# Deposita tutto
	if food_carried > 0:
		ResourceManager.add_resource(ResourceManager.ResourceType.FOOD, food_carried)
		food_carried = 0
	
	if wood_carried > 0:
		ResourceManager.add_resource(ResourceManager.ResourceType.WOOD, wood_carried)
		wood_carried = 0
	
	if gold_carried > 0:
		ResourceManager.add_resource(ResourceManager.ResourceType.GOLD, gold_carried)
		gold_carried = 0
	
	print("Worker depositato risorse!")
	
	# NUOVO: Torna automaticamente alla risorsa se esiste ancora
	if target_resource_node and is_instance_valid(target_resource_node):
		if target_resource_node.current_resources > 0:
			print("Worker torna automaticamente a raccogliere")
			is_returning = false
			is_gathering = true
			move_to_position(target_resource_node.global_position)
			return
	
	# Se non c'è risorsa, fermati
	stop_returning()

# Comandi pubblici
func gather_from_resource(resource_node):
	"""Inizia a raccogliere da una risorsa"""
	target_resource_node = resource_node
	is_gathering = true
	is_returning = false
	
	# Muoviti verso la risorsa
	move_to_position(resource_node.global_position)
	print("Worker va a raccogliere risorsa")

func return_to_base():
	"""Torna al town center più vicino"""
	var town_centers = get_tree().get_nodes_in_group("town_centers")
	if town_centers.size() == 0:
		print("Nessun town center trovato!")
		return
	
	# Trova il più vicino
	var closest_tc = null
	var min_distance = INF
	
	for tc in town_centers:
		var distance = global_position.distance_to(tc.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_tc = tc
	
	if closest_tc:
		target_town_center = closest_tc
		is_returning = true
		is_gathering = false
		move_to_position(closest_tc.global_position)
		print("Worker torna al town center")

func stop_gathering():
	"""Ferma raccolta"""
	is_gathering = false
	target_resource_node = null

func stop_returning():
	"""Ferma ritorno"""
	is_returning = false
	target_town_center = null

func stop_all_tasks():
	"""Ferma tutti i task"""
	stop_gathering()
	stop_returning()
	print("Worker fermato completamente")

# Metodi helper
func get_total_carried() -> int:
	return food_carried + wood_carried + gold_carried

func get_carry_space() -> int:
	return carry_capacity - get_total_carried()

func is_inventory_full() -> bool:
	return get_total_carried() >= carry_capacity

func is_inventory_empty() -> bool:
	return get_total_carried() == 0

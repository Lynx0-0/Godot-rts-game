# scripts/units/worker.gd
extends BaseUnit
class_name Worker

## Unità lavoratrice che raccoglie risorse e le porta al Town Center.
## Può raccogliere cibo, legno e oro da nodi di risorse nel mondo di gioco.

# ===== COSTANTI =====

## Quantità di risorse raccolte per intervallo
const DEFAULT_GATHER_RATE := 10
## Capacità massima inventario
const DEFAULT_CARRY_CAPACITY := 50
## Intervallo tra raccolte (secondi)
const GATHER_INTERVAL := 1.0
## Distanza massima per raccogliere da un nodo risorsa (pixel)
const GATHER_DISTANCE := 64.0
## Distanza massima per depositare al Town Center (pixel)
const DEPOSIT_DISTANCE := 80.0
## Velocità specifica worker
const WORKER_SPEED := 120.0
## Vita massima worker
const WORKER_MAX_HEALTH := 75
## Colore distintivo worker
const WORKER_COLOR := Color.YELLOW

# ===== VARIABILI ESPORTATE =====

## Quantità di risorse raccolte ogni secondo
@export var gather_rate := DEFAULT_GATHER_RATE
## Capacità massima di trasporto
@export var carry_capacity := DEFAULT_CARRY_CAPACITY

# ===== INVENTARIO =====

## Quantità di cibo trasportato
var food_carried := 0
## Quantità di legno trasportato
var wood_carried := 0
## Quantità di oro trasportato
var gold_carried := 0

# ===== STATO WORKER =====

## Se il worker sta raccogliendo risorse
var is_gathering := false
## Se il worker sta tornando al Town Center
var is_returning := false
## Riferimento al nodo risorsa target
var target_resource_node = null
## Riferimento al Town Center target
var target_town_center = null

# ===== TIMER =====

## Timer interno per la raccolta periodica
var gather_timer := 0.0

# ===== METODI LIFECYCLE =====

func _ready():
	super._ready()

	# Configura proprietà specifiche del worker
	unit_type = "worker"
	speed = WORKER_SPEED
	max_health = WORKER_MAX_HEALTH
	current_health = max_health

	# Applica colore distintivo
	if sprite:
		sprite.modulate = WORKER_COLOR

	print("Worker %s creato e pronto al lavoro" % name)

func _process(delta):
	# Gestisce raccolta se vicino a una risorsa
	if is_gathering and target_resource_node:
		_handle_gathering(delta)

	# Gestisce deposito se vicino al Town Center
	if is_returning and target_town_center:
		_handle_depositing()

# ===== METODI PRIVATI - GESTIONE STATO =====

## Gestisce la logica di raccolta risorse
func _handle_gathering(delta: float) -> void:
	# Verifica validità del nodo risorsa
	if not target_resource_node or not is_instance_valid(target_resource_node):
		stop_gathering()
		return

	# Controlla se la risorsa è esaurita
	if target_resource_node.current_resources <= 0:
		print("Risorsa esaurita, worker %s si ferma" % name)
		stop_gathering()
		return

	# Verifica distanza dal nodo risorsa
	var distance = global_position.distance_to(target_resource_node.global_position)
	if distance > GATHER_DISTANCE:
		return  # Troppo lontano per raccogliere

	# Aggiorna timer e raccogli quando raggiunge l'intervallo
	gather_timer += delta
	if gather_timer >= GATHER_INTERVAL:
		gather_timer = 0.0
		_gather_resources()

## Raccoglie risorse dal nodo target
func _gather_resources() -> void:
	if not target_resource_node:
		return

	# Calcola spazio disponibile nell'inventario
	var space_available = get_carry_space()

	if space_available <= 0:
		# Inventario pieno - torna al Town Center
		return_to_base()
		return

	# Determina quantità da raccogliere
	var to_gather = min(gather_rate, space_available)
	var actual_gathered = target_resource_node.gather_resource(to_gather)

	# Aggiungi all'inventario appropriato
	match target_resource_node.resource_type:
		ResourceManager.ResourceType.FOOD:
			food_carried += actual_gathered
		ResourceManager.ResourceType.WOOD:
			wood_carried += actual_gathered
		ResourceManager.ResourceType.GOLD:
			gold_carried += actual_gathered

	print("Worker %s ha raccolto %d di %s" % [name, actual_gathered, ResourceManager.ResourceType.keys()[target_resource_node.resource_type]])

	# Se inventario pieno, torna alla base
	if is_inventory_full():
		return_to_base()

## Gestisce deposito risorse al Town Center
func _handle_depositing() -> void:
	# Verifica validità del Town Center
	if not target_town_center or not is_instance_valid(target_town_center):
		stop_returning()
		return

	# Verifica distanza dal Town Center
	var distance = global_position.distance_to(target_town_center.global_position)
	if distance > DEPOSIT_DISTANCE:
		return  # Troppo lontano per depositare

	# Deposita tutte le risorse trasportate
	if food_carried > 0:
		ResourceManager.add_resource(ResourceManager.ResourceType.FOOD, food_carried)
		food_carried = 0

	if wood_carried > 0:
		ResourceManager.add_resource(ResourceManager.ResourceType.WOOD, wood_carried)
		wood_carried = 0

	if gold_carried > 0:
		ResourceManager.add_resource(ResourceManager.ResourceType.GOLD, gold_carried)
		gold_carried = 0

	print("Worker %s ha depositato risorse al Town Center" % name)

	# Ritorna automaticamente alla risorsa se esiste ancora
	if target_resource_node and is_instance_valid(target_resource_node):
		if target_resource_node.current_resources > 0:
			print("Worker %s torna automaticamente a raccogliere" % name)
			is_returning = false
			is_gathering = true
			move_to_position(target_resource_node.global_position)
			return

	# Se non c'è più risorsa, fermati
	stop_returning()

# ===== METODI PUBBLICI - COMANDI =====

## Comanda il worker di raccogliere da un nodo risorsa.
## [param resource_node]: Il nodo risorsa da cui raccogliere
func gather_from_resource(resource_node) -> void:
	target_resource_node = resource_node
	is_gathering = true
	is_returning = false

	# Muoviti verso la risorsa
	move_to_position(resource_node.global_position)
	print("Worker %s si dirige verso la risorsa" % name)

## Comanda il worker di tornare al Town Center più vicino
func return_to_base() -> void:
	var town_centers = get_tree().get_nodes_in_group("town_centers")
	if town_centers.size() == 0:
		push_warning("Nessun Town Center trovato per worker %s!" % name)
		return

	# Trova il Town Center più vicino
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
		print("Worker %s torna al Town Center" % name)

## Ferma la raccolta di risorse
func stop_gathering() -> void:
	is_gathering = false
	target_resource_node = null

## Ferma il ritorno al Town Center
func stop_returning() -> void:
	is_returning = false
	target_town_center = null

## Ferma tutti i task del worker
func stop_all_tasks() -> void:
	stop_gathering()
	stop_returning()
	print("Worker %s fermato completamente" % name)

# ===== METODI HELPER =====

## Ottiene la quantità totale di risorse trasportate.
## [return]: Somma di tutte le risorse nell'inventario
func get_total_carried() -> int:
	return food_carried + wood_carried + gold_carried

## Ottiene lo spazio disponibile nell'inventario.
## [return]: Capacità rimanente
func get_carry_space() -> int:
	return carry_capacity - get_total_carried()

## Controlla se l'inventario è pieno.
## [return]: true se pieno, false altrimenti
func is_inventory_full() -> bool:
	return get_total_carried() >= carry_capacity

## Controlla se l'inventario è vuoto.
## [return]: true se vuoto, false altrimenti
func is_inventory_empty() -> bool:
	return get_total_carried() == 0

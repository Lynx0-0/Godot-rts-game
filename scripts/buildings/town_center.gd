# scripts/buildings/town_center.gd
extends BaseBuilding
class_name TownCenter

## Town Center - Edificio principale per produzione unità e deposito risorse

# ===== PROPRIETÀ SPECIFICHE =====

@export var rally_point_offset := Vector2(100, 0)

# ===== VARIABILI PRODUZIONE =====

var production_queue: Array[Dictionary] = []  # {unit_type: String, time_left: float}
var current_production: Dictionary = {}  # Produzione corrente

# ===== SEGNALI =====

signal unit_produced(unit: Node2D)
signal production_started(unit_type: String)

# ===== INIT =====

func _ready():
	# IMPORTANTE: Chiama _ready del parent
	super._ready()
	
	# Override proprietà specifiche
	building_name = "Town Center"
	max_health = 1000
	current_health = max_health
	grid_size = Vector2i(3, 3)
	
	print("Town Center inizializzato a posizione: ", global_position)

# ===== PROCESSO =====

func _process(delta):
	if current_production.is_empty() and not production_queue.is_empty():
		_start_next_production()
	
	if not current_production.is_empty():
		_update_production(delta)

# ===== PRODUZIONE UNITÀ =====

func train_unit(unit_type: String, cost: Dictionary, production_time: float) -> bool:
	"""Avvia produzione unità se ci sono risorse"""
	
	# Controlla risorse
	if not ResourceManager.can_afford(cost):
		print("❌ Risorse insufficienti per %s" % unit_type)
		return false
	
	# Spendi risorse
	for resource_type in cost:
		ResourceManager.spend_resource(resource_type, cost[resource_type])
	
	# Aggiungi a coda
	var production_data = {
		"unit_type": unit_type,
		"time_left": production_time,
		"total_time": production_time
	}
	
	production_queue.append(production_data)
	
	print("✅ %s aggiunto a coda produzione (posizione %d)" % [unit_type, production_queue.size()])
	
	production_started.emit(unit_type)
	
	return true

func _start_next_production():
	"""Inizia prossima produzione dalla coda"""
	if production_queue.is_empty():
		return
	
	current_production = production_queue.pop_front()
	print("🏭 Iniziata produzione: %s (%.1fs)" % [
		current_production.unit_type,
		current_production.time_left
	])

func _update_production(delta: float):
	"""Aggiorna timer produzione corrente"""
	current_production.time_left -= delta
	
	if current_production.time_left <= 0:
		_complete_current_production()

func _complete_current_production():
	"""Completa produzione unità corrente"""
	var unit_type = current_production.unit_type
	
	_spawn_unit(unit_type)
	
	current_production.clear()
	
	print("✅ Produzione completata: %s" % unit_type)

func _spawn_unit(unit_type: String):
	"""Spawna unità al rally point"""
	var unit_scene_path = "res://scenes/units/%s.tscn" % unit_type.to_lower()
	
	if not ResourceLoader.exists(unit_scene_path):
		print("❌ ERRORE: Scena %s non trovata!" % unit_scene_path)
		return
	
	var unit_scene = load(unit_scene_path)
	var unit = unit_scene.instantiate()
	
	# Aggiungi alla scena principale
	get_tree().root.get_node("Main").add_child(unit)
	
	# Posiziona al rally point
	unit.global_position = global_position + rally_point_offset
	
	unit_produced.emit(unit)
	
	print("🎯 Unità spawnata: %s a %v" % [unit_type, unit.global_position])

# ===== GESTIONE RALLY POINT =====

func set_rally_point(world_pos: Vector2):
	"""Imposta nuovo rally point"""
	rally_point_offset = world_pos - global_position
	print("📍 Rally point impostato: %v" % rally_point_offset)

func get_rally_point_position() -> Vector2:
	"""Ottiene posizione mondiale rally point"""
	return global_position + rally_point_offset

# ===== INFO DEBUG =====

func get_production_info() -> String:
	"""Info produzione per debug"""
	var info = "Production Queue:\n"
	
	if not current_production.is_empty():
		info += "  Current: %s (%.1fs left)\n" % [
			current_production.unit_type,
			current_production.time_left
		]
	
	for i in production_queue.size():
		var prod = production_queue[i]
		info += "  %d. %s (%.1fs)\n" % [i + 1, prod.unit_type, prod.time_left]
	
	return info

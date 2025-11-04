# scripts/systems/isometric_depth_manager.gd
extends Node

"""
Gestisce automaticamente lo z-ordering di tutte le entità sulla mappa
per creare corretta sovrapposizione in vista isometrica.
"""

@export var update_frequency := 0.1  # Aggiorna ogni 0.1 secondi
var update_timer := 0.0

# Tutti i nodi che devono essere ordinati
var tracked_nodes: Array[Node2D] = []

func _ready():
	# Trova automaticamente tutti gli oggetti che necessitano z-ordering
	_register_all_entities()
	
	# Connetti segnali per nuovi nodi aggiunti
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

func _process(delta):
	update_timer += delta
	if update_timer >= update_frequency:
		_update_z_ordering()
		update_timer = 0.0

func _register_all_entities():
	"""Registra tutte le entità esistenti"""
	for node in get_tree().get_nodes_in_group("units"):
		if node is Node2D:
			tracked_nodes.append(node)
	
	for node in get_tree().get_nodes_in_group("buildings"):
		if node is Node2D:
			tracked_nodes.append(node)
	
	for node in get_tree().get_nodes_in_group("resources"):
		if node is Node2D:
			tracked_nodes.append(node)

func _on_node_added(node: Node):
	"""Aggiunge automaticamente nuovi nodi ai gruppi tracciati"""
	if node is Node2D:
		if node.is_in_group("units") or node.is_in_group("buildings") or node.is_in_group("resources"):
			if node not in tracked_nodes:
				tracked_nodes.append(node)

func _on_node_removed(node: Node):
	"""Rimuove nodi eliminati"""
	if node in tracked_nodes:
		tracked_nodes.erase(node)

func _update_z_ordering():
	"""
	Aggiorna z_index basato sulla posizione Y.
	In isometrica, oggetti più "in basso" (Y maggiore) 
	devono essere disegnati sopra quelli più "in alto".
	"""
	for node in tracked_nodes:
		if is_instance_valid(node):
			# Formula: z_index = Y_position per sorting corretto
			# Dividi per 10 per avere valori più gestibili
			node.z_index = int(node.global_position.y / 10.0)

func force_update():
	"""Forza aggiornamento immediato (utile dopo spawn unità)"""
	_update_z_ordering()

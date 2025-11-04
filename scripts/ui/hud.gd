# scripts/ui/hud.gd
extends CanvasLayer

## Interfaccia utente principale del gioco.
## Mostra risorse del giocatore e informazioni sulle unità selezionate.

# ===== COSTANTI =====

## Posizione del pannello risorse
const RESOURCE_PANEL_POS := Vector2(10, 10)
## Posizione del pannello info unità
const UNIT_INFO_PANEL_POS := Vector2(10, 500)
## Dimensione del pannello info unità
const UNIT_INFO_PANEL_SIZE := Vector2(300, 150)

# ===== RIFERIMENTI UI - RISORSE =====

@onready var food_amount = $ResourcePanel/HBoxContainer/FoodContainer/FoodAmount
@onready var wood_amount = $ResourcePanel/HBoxContainer/WoodContainer/WoodAmount
@onready var gold_amount = $ResourcePanel/HBoxContainer/GoldContainer/GoldAmount

# ===== RIFERIMENTI UI - INFO UNITÀ =====

@onready var unit_info_panel = $UnitInfoPanel
@onready var unit_name_label = $UnitInfoPanel/VBoxContainer/UnitName
@onready var health_bar = $UnitInfoPanel/VBoxContainer/HealthBar
@onready var unit_stats = $UnitInfoPanel/VBoxContainer/UnitStats

# ===== RIFERIMENTI UI - MINIMAPPA =====

@onready var minimap = $Minimap

# ===== MAPPING RISORSE -> UI =====

## Mappa tipo risorsa a label UI corrispondente (riduce codice ripetitivo)
var resource_labels: Dictionary

# ===== METODI LIFECYCLE =====

func _ready():
	print("HUD inizializzato")

	# Setup mapping risorse -> labels
	_setup_resource_labels()

	# Connetti segnali risorse con controllo di sicurezza
	if ResourceManager:
		ResourceManager.resource_changed.connect(_on_resource_changed)

	# Setup posticipato per evitare errori di timing
	call_deferred("_deferred_setup")

# ===== METODI PRIVATI - SETUP =====

## Setup mapping tra tipi di risorse e label UI
func _setup_resource_labels() -> void:
	resource_labels = {
		ResourceManager.ResourceType.FOOD: food_amount,
		ResourceManager.ResourceType.WOOD: wood_amount,
		ResourceManager.ResourceType.GOLD: gold_amount
	}

## Setup posticipato per evitare errori di timing
func _deferred_setup() -> void:
	_update_all_resources()
	if unit_info_panel:
		unit_info_panel.visible = false
	_setup_ui_positions()
	_setup_minimap()

## Posiziona i pannelli UI nelle posizioni corrette
func _setup_ui_positions() -> void:
	$ResourcePanel.position = RESOURCE_PANEL_POS
	unit_info_panel.position = UNIT_INFO_PANEL_POS
	unit_info_panel.size = UNIT_INFO_PANEL_SIZE

## Configura la minimappa con la camera principale
func _setup_minimap() -> void:
	if not minimap:
		return

	# Trova la camera principale nella scena
	var main_camera = get_tree().root.find_child("game_camera", true, false)
	if main_camera:
		minimap.set_main_camera(main_camera)
		print("Minimappa collegata alla camera principale")
	else:
		push_warning("Camera principale non trovata per minimappa")

## Aggiorna tutti i display delle risorse
func _update_all_resources() -> void:
	for resource_type in resource_labels:
		var amount = ResourceManager.get_resource_amount(resource_type)
		resource_labels[resource_type].text = str(amount)

# ===== CALLBACK SEGNALI =====

## Chiamato quando una risorsa cambia (ridotto codice ripetitivo con mapping)
func _on_resource_changed(type: ResourceManager.ResourceType, amount: int) -> void:
	if type in resource_labels:
		resource_labels[type].text = str(amount)

# ===== METODI PUBBLICI =====

## Mostra le informazioni delle unità selezionate nel pannello.
## [param units]: Array di unità selezionate
func show_unit_info(units: Array) -> void:
	# Nascondi pannello se nessuna unità selezionata
	if units.size() == 0:
		unit_info_panel.visible = false
		return

	unit_info_panel.visible = true
	var unit = units[0]  # Mostra info della prima unità

	# Aggiorna informazioni base
	_update_basic_unit_info(unit)

	# Aggiorna statistiche specifiche per tipo
	var stats_text = _build_unit_stats_text(unit)
	unit_stats.text = stats_text

# ===== METODI PRIVATI - INFO UNITÀ =====

## Aggiorna le informazioni base dell'unità (nome, vita)
func _update_basic_unit_info(unit) -> void:
	unit_name_label.text = unit.unit_type.capitalize()
	health_bar.max_value = unit.max_health
	health_bar.value = unit.current_health

## Costruisce il testo delle statistiche per l'unità
func _build_unit_stats_text(unit) -> String:
	var stats = []

	# Statistiche comuni a tutte le unità
	stats.append("Velocità: %d" % unit.speed)
	stats.append("Vita: %d/%d" % [unit.current_health, unit.max_health])

	# Statistiche specifiche per worker
	if unit.unit_type == "worker":
		stats.append("")  # Linea vuota
		stats.append("--- WORKER ---")
		stats.append("Capacità: %d" % unit.carry_capacity)

		# Informazioni inventario
		var total_carried = unit.get_total_carried()
		stats.append("Trasporta: %d/%d" % [total_carried, unit.carry_capacity])

		# Dettaglio risorse trasportate
		if unit.food_carried > 0:
			stats.append("  Cibo: %d" % unit.food_carried)
		if unit.wood_carried > 0:
			stats.append("  Legno: %d" % unit.wood_carried)
		if unit.gold_carried > 0:
			stats.append("  Oro: %d" % unit.gold_carried)

		# Stato corrente del worker
		stats.append("")
		stats.append("Stato: " + _get_worker_status(unit))

	return "\n".join(stats)

## Ottiene lo stato corrente del worker come stringa
func _get_worker_status(worker) -> String:
	if worker.is_gathering:
		return "Raccogliendo"
	elif worker.is_returning:
		return "Tornando alla base"
	else:
		return "Inattivo"

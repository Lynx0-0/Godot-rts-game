# scripts/ui/hud.gd
extends CanvasLayer

# Riferimenti UI
@onready var food_amount = $ResourcePanel/HBoxContainer/FoodContainer/FoodAmount
@onready var wood_amount = $ResourcePanel/HBoxContainer/WoodContainer/WoodAmount
@onready var gold_amount = $ResourcePanel/HBoxContainer/GoldContainer/GoldAmount

@onready var unit_info_panel = $UnitInfoPanel
@onready var unit_name_label = $UnitInfoPanel/VBoxContainer/UnitName
@onready var health_bar = $UnitInfoPanel/VBoxContainer/HealthBar
@onready var unit_stats = $UnitInfoPanel/VBoxContainer/UnitStats

func _ready():
	print("HUD inizializzato")
	
	# Connetti segnali risorse (con controllo di sicurezza)
	if ResourceManager:
		ResourceManager.resource_changed.connect(_on_resource_changed)
	
	# Setup iniziale
	call_deferred("_deferred_setup")

func _deferred_setup():
	"""Setup posticipato per evitare errori di timing"""
	_update_all_resources()
	if unit_info_panel:
		unit_info_panel.visible = false
	_setup_ui_positions()

func _setup_ui_positions():
	# Posiziona pannelli
	$ResourcePanel.position = Vector2(10, 10)
	unit_info_panel.position = Vector2(10, 500)
	unit_info_panel.size = Vector2(300, 150)

func _update_all_resources():
	# Aggiorna display risorse
	food_amount.text = str(ResourceManager.get_resource_amount(ResourceManager.ResourceType.FOOD))
	wood_amount.text = str(ResourceManager.get_resource_amount(ResourceManager.ResourceType.WOOD))
	gold_amount.text = str(ResourceManager.get_resource_amount(ResourceManager.ResourceType.GOLD))

func _on_resource_changed(type, amount):
	# Aggiorna singola risorsa
	match type:
		ResourceManager.ResourceType.FOOD:
			food_amount.text = str(amount)
		ResourceManager.ResourceType.WOOD:
			wood_amount.text = str(amount)
		ResourceManager.ResourceType.GOLD:
			gold_amount.text = str(amount)

func show_unit_info(units: Array):
	# Mostra info unità selezionate
	if units.size() == 0:
		unit_info_panel.visible = false
		return
	
	unit_info_panel.visible = true
	var unit = units[0]
	
	# Info base
	unit_name_label.text = unit.unit_type.capitalize()
	health_bar.max_value = unit.max_health
	health_bar.value = unit.current_health
	
	# Stats specifici
	var stats_text = "Velocità: " + str(unit.speed) + "\n"
	stats_text += "Vita: " + str(unit.current_health) + "/" + str(unit.max_health) + "\n"
	
	# Info worker
	if unit.unit_type == "worker":
		stats_text += "\n--- WORKER ---\n"
		stats_text += "Capacità: " + str(unit.carry_capacity) + "\n"
		
		# Inventario
		var total = unit.food_carried + unit.wood_carried + unit.gold_carried
		stats_text += "Trasporta: " + str(total) + "/" + str(unit.carry_capacity) + "\n"
		
		if unit.food_carried > 0:
			stats_text += "Cibo: " + str(unit.food_carried) + "\n"
		if unit.wood_carried > 0:
			stats_text += "Legno: " + str(unit.wood_carried) + "\n"
		if unit.gold_carried > 0:
			stats_text += "Oro: " + str(unit.gold_carried) + "\n"
		
		# Stato
		if unit.is_gathering:
			stats_text += "Stato: Raccogliendo\n"
		elif unit.is_returning:
			stats_text += "Stato: Tornando\n"
		else:
			stats_text += "Stato: Inattivo\n"
	
	unit_stats.text = stats_text

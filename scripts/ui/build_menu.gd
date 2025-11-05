# scripts/ui/build_menu.gd
extends Panel

@onready var town_center_btn = $VBoxContainer/TownCenterButton
@onready var barracks_btn = $VBoxContainer/BarracksButton
@onready var cancel_btn = $VBoxContainer/CancelButton

# Definizioni edifici
const BUILDINGS = {
	"town_center": {
		"scene": "res://scenes/buildings/town_center.tscn",
		"name": "Town Center",
		"size": Vector2i(3, 3),
		"cost": {
			ResourceManager.ResourceType.FOOD: 200,
			ResourceManager.ResourceType.WOOD: 300,
			ResourceManager.ResourceType.GOLD: 100
		}
	},
	"barracks": {
		"scene": "res://scenes/buildings/barracks.tscn",
		"name": "Barracks",
		"size": Vector2i(2, 2),
		"cost": {
			ResourceManager.ResourceType.WOOD: 150,
			ResourceManager.ResourceType.GOLD: 50
		}
	}
}

func _ready():
	town_center_btn.pressed.connect(_on_town_center_pressed)
	barracks_btn.pressed.connect(_on_barracks_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	
	# Connetti segnali sistema piazzamento
	BuildingPlacement.building_placed.connect(_on_building_placed)
	BuildingPlacement.placement_cancelled.connect(_on_placement_cancelled)
	
	visible = false

func show_menu():
	visible = true
	_update_button_states()

func hide_menu():
	visible = false

func _update_button_states():
	"""Disabilita bottoni se risorse insufficienti"""
	town_center_btn.disabled = not ResourceManager.can_afford(
		BUILDINGS["town_center"]["cost"]
	)
	barracks_btn.disabled = not ResourceManager.can_afford(
		BUILDINGS["barracks"]["cost"]
	)

func _on_town_center_pressed():
	_start_building("town_center")

func _on_barracks_pressed():
	_start_building("barracks")

func _start_building(building_key: String):
	var building_data = BUILDINGS[building_key]
	
	# Controlla costi
	if not ResourceManager.can_afford(building_data["cost"]):
		print("Risorse insufficienti per %s!" % building_data["name"])
		return
	
	# Avvia modalità piazzamento
	var scene = load(building_data["scene"])
	BuildingPlacement.start_placement(scene, building_data["size"])
	
	hide_menu()
	print("Modalità piazzamento %s attivata" % building_data["name"])

func _on_building_placed(building, grid_pos):
	"""Quando edificio piazzato, dedurre costi"""
	# Trova quale edificio era
	for key in BUILDINGS:
		var building_data = BUILDINGS[key]
		if building is TownCenter and key == "town_center":
			_deduct_costs(building_data["cost"])
			break
		# Aggiungi altri controlli per altri edifici

func _deduct_costs(costs: Dictionary):
	"""Sottrae costi risorse"""
	for resource_type in costs:
		ResourceManager.spend_resource(resource_type, costs[resource_type])

func _on_placement_cancelled():
	print("Piazzamento annullato")

func _on_cancel_pressed():
	if BuildingPlacement.is_placing:
		BuildingPlacement.cancel_placement()
	hide_menu()

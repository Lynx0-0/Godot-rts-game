# scripts/autoloads/resource_manager.gd
extends Node

enum ResourceType { FOOD, WOOD, GOLD }

var resources = {
	ResourceType.FOOD: 200,
	ResourceType.WOOD: 200,
	ResourceType.GOLD: 100
}

signal resource_changed(type: ResourceType, amount: int)

func _ready():
	print("ResourceManager inizializzato")

func add_resource(type: ResourceType, amount: int):
	if amount <= 0:
		return
	
	resources[type] += amount
	resource_changed.emit(type, resources[type])
	print("Aggiunto ", amount, " di ", ResourceType.keys()[type])

func spend_resource(type: ResourceType, amount: int) -> bool:
	if amount <= 0:
		return false
	
	if resources[type] >= amount:
		resources[type] -= amount
		resource_changed.emit(type, resources[type])
		print("Speso ", amount, " di ", ResourceType.keys()[type])
		return true
	
	print("Risorse insufficienti: ", ResourceType.keys()[type])
	return false

func get_resource_amount(type: ResourceType) -> int:
	return resources.get(type, 0)

func can_afford(costs: Dictionary) -> bool:
	for resource_type in costs:
		if resources.get(resource_type, 0) < costs[resource_type]:
			return false
	return true

func get_all_resources() -> Dictionary:
	return resources.duplicate()

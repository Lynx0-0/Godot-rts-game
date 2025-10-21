# scripts/environment/resource_node.gd
extends StaticBody2D
class_name ResourceNode

@export var resource_type: ResourceManager.ResourceType = ResourceManager.ResourceType.WOOD
@export var max_resources := 1000
@export var current_resources := 1000

@onready var sprite = $Sprite2D
@onready var amount_label = $ResourceAmount

func _ready():
	add_to_group("resource_nodes")
	_update_display()
	_set_sprite_color()

func _set_sprite_color():
	# Colore basato su tipo risorsa
	match resource_type:
		ResourceManager.ResourceType.FOOD:
			sprite.modulate = Color.GREEN
		ResourceManager.ResourceType.WOOD:
			sprite.modulate = Color(0.6, 0.3, 0.1)  # Marrone
		ResourceManager.ResourceType.GOLD:
			sprite.modulate = Color.GOLD

func gather_resource(amount: int) -> int:
	# Raccogli risorsa e ritorna quantità effettiva
	var gathered = min(amount, current_resources)
	current_resources -= gathered
	_update_display()
	
	if current_resources <= 0:
		_deplete_node()
	
	return gathered

func _update_display():
	amount_label.text = str(current_resources)
	
	# Cambia opacità
	var opacity = float(current_resources) / float(max_resources)
	sprite.modulate.a = max(0.3, opacity)

func _deplete_node():
	# Nodo esaurito
	print("Risorsa esaurita!")
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)

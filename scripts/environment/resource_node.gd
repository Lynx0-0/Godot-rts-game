# scripts/environment/resource_node.gd
extends StaticBody2D
class_name ResourceNode

## Nodo di risorsa raccoglibile nel mondo di gioco.
## Può contenere cibo, legno o oro e viene raccolto dai worker.

# ===== COSTANTI =====

## Quantità massima predefinita di risorse per nodo
const DEFAULT_MAX_RESOURCES := 1000
## Opacità minima quando la risorsa è quasi esaurita
const MIN_OPACITY := 0.3
## Durata dell'animazione di scomparsa (in secondi)
const DEPLETION_FADE_DURATION := 1.0

## Colori per i diversi tipi di risorse
const RESOURCE_COLORS := {
	ResourceManager.ResourceType.FOOD: Color.GREEN,
	ResourceManager.ResourceType.WOOD: Color(0.6, 0.3, 0.1),  # Marrone
	ResourceManager.ResourceType.GOLD: Color.GOLD
}

# ===== VARIABILI ESPORTATE =====

## Tipo di risorsa contenuta in questo nodo
@export var resource_type: ResourceManager.ResourceType = ResourceManager.ResourceType.WOOD
## Quantità massima di risorse
@export var max_resources := DEFAULT_MAX_RESOURCES
## Quantità corrente di risorse disponibili
@export var current_resources := DEFAULT_MAX_RESOURCES

# ===== RIFERIMENTI NODI =====

@onready var sprite = $Sprite2D
@onready var amount_label = $ResourceAmount

# ===== METODI LIFECYCLE =====

func _ready():
	# Registra il nodo nel gruppo per facilitare la ricerca
	add_to_group("resource_nodes")

	# Setup visivo iniziale
	_update_display()
	_set_sprite_color()

# ===== METODI PUBBLICI =====

## Raccoglie una quantità di risorsa da questo nodo.
## [param amount]: La quantità richiesta da raccogliere
## [return]: La quantità effettivamente raccolta (può essere minore se le risorse sono insufficienti)
func gather_resource(amount: int) -> int:
	var gathered = min(amount, current_resources)
	current_resources -= gathered
	_update_display()

	if current_resources <= 0:
		_deplete_node()

	return gathered

# ===== METODI PRIVATI =====

## Imposta il colore dello sprite in base al tipo di risorsa
func _set_sprite_color() -> void:
	if resource_type in RESOURCE_COLORS:
		sprite.modulate = RESOURCE_COLORS[resource_type]
	else:
		push_warning("Tipo di risorsa sconosciuto: %d" % resource_type)

## Aggiorna la visualizzazione della quantità e dell'opacità
func _update_display() -> void:
	# Aggiorna testo con quantità corrente
	amount_label.text = str(current_resources)

	# Calcola e applica opacità basata su risorse rimanenti
	var opacity_ratio = float(current_resources) / float(max_resources)
	sprite.modulate.a = max(MIN_OPACITY, opacity_ratio)

## Gestisce l'esaurimento completo della risorsa
func _deplete_node() -> void:
	print("Risorsa %s esaurita alla posizione %v" % [ResourceManager.ResourceType.keys()[resource_type], global_position])

	# Animazione di scomparsa graduale
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, DEPLETION_FADE_DURATION)
	tween.tween_callback(queue_free)

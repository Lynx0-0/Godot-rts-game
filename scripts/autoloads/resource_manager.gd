# scripts/autoloads/resource_manager.gd
extends Node

## Sistema di gestione globale delle risorse del giocatore.
## Gestisce raccolta, spesa e monitoraggio di cibo, legno e oro.

## Tipi di risorse disponibili nel gioco
enum ResourceType {
	FOOD,  ## Cibo per unità
	WOOD,  ## Legno per costruzioni
	GOLD   ## Oro per unità avanzate
}

# ===== COSTANTI =====

## Quantità iniziali di risorse all'avvio del gioco
const INITIAL_FOOD := 200
const INITIAL_WOOD := 200
const INITIAL_GOLD := 100

# ===== VARIABILI =====

## Dizionario che contiene le quantità correnti di ogni risorsa
var resources = {
	ResourceType.FOOD: INITIAL_FOOD,
	ResourceType.WOOD: INITIAL_WOOD,
	ResourceType.GOLD: INITIAL_GOLD
}

# ===== SEGNALI =====

## Emesso quando una risorsa cambia quantità
signal resource_changed(type: ResourceType, amount: int)

# ===== METODI LIFECYCLE =====

func _ready():
	print("ResourceManager inizializzato con risorse: Cibo=%d, Legno=%d, Oro=%d" % [INITIAL_FOOD, INITIAL_WOOD, INITIAL_GOLD])

# ===== METODI PUBBLICI =====

## Aggiunge una quantità di risorsa al pool del giocatore.
## [param type]: Il tipo di risorsa da aggiungere
## [param amount]: La quantità da aggiungere (deve essere > 0)
func add_resource(type: ResourceType, amount: int) -> void:
	if amount <= 0:
		push_warning("Tentativo di aggiungere quantità non valida: %d" % amount)
		return

	resources[type] += amount
	resource_changed.emit(type, resources[type])
	print("Aggiunto %d di %s (Totale: %d)" % [amount, ResourceType.keys()[type], resources[type]])

## Spende una quantità di risorsa dal pool del giocatore.
## [param type]: Il tipo di risorsa da spendere
## [param amount]: La quantità da spendere (deve essere > 0)
## [return]: true se la risorsa è stata spesa con successo, false se non ci sono risorse sufficienti
func spend_resource(type: ResourceType, amount: int) -> bool:
	if amount <= 0:
		push_warning("Tentativo di spendere quantità non valida: %d" % amount)
		return false

	if resources[type] >= amount:
		resources[type] -= amount
		resource_changed.emit(type, resources[type])
		print("Speso %d di %s (Rimanente: %d)" % [amount, ResourceType.keys()[type], resources[type]])
		return true

	print("Risorse insufficienti: richiesto %d di %s, disponibile %d" % [amount, ResourceType.keys()[type], resources[type]])
	return false

## Ottiene la quantità corrente di una risorsa specifica.
## [param type]: Il tipo di risorsa da controllare
## [return]: La quantità corrente della risorsa
func get_resource_amount(type: ResourceType) -> int:
	return resources.get(type, 0)

## Controlla se il giocatore può permettersi un set di costi.
## [param costs]: Dizionario con formato {ResourceType: amount}
## [return]: true se tutte le risorse sono sufficienti, false altrimenti
func can_afford(costs: Dictionary) -> bool:
	for resource_type in costs:
		if resources.get(resource_type, 0) < costs[resource_type]:
			return false
	return true

## Ottiene una copia di tutte le risorse correnti.
## [return]: Dizionario con tutte le risorse {ResourceType: amount}
func get_all_resources() -> Dictionary:
	return resources.duplicate()

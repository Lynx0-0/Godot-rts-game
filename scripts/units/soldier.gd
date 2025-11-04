# scripts/units/soldier.gd
extends BaseUnit
class_name Soldier

## Unità da combattimento con sistema di stamina, morale e combattimento

# ===== COSTANTI =====

## Danno base del soldato
const DEFAULT_ATTACK_DAMAGE := 15
## Raggio attacco (pixel)
const DEFAULT_ATTACK_RANGE := 80.0
## Tempo tra attacchi (secondi)
const DEFAULT_ATTACK_COOLDOWN := 1.5
## Raggio rilevamento nemici (pixel)
const DEFAULT_DETECTION_RANGE := 150.0
## Stamina massima
const DEFAULT_MAX_STAMINA := 100.0
## Consumo stamina per attacco
const STAMINA_ATTACK_COST := 10.0
## Recupero stamina per secondo (quando non combatte)
const STAMINA_RECOVERY_RATE := 5.0
## Soglia stanchezza (riduce prestazioni)
const FATIGUE_THRESHOLD := 30.0
## Morale iniziale
const DEFAULT_MORALE := 100.0
## Raggio influenza morale (pixel)
const MORALE_INFLUENCE_RADIUS := 100.0
## Bonus morale vicino città
const MORALE_CITY_BONUS := 20.0
## Raggio bonus città (pixel)
const CITY_BONUS_RADIUS := 150.0

# ===== VARIABILI ESPORTATE =====

@export var attack_damage := DEFAULT_ATTACK_DAMAGE
@export var attack_range := DEFAULT_ATTACK_RANGE
@export var attack_cooldown := DEFAULT_ATTACK_COOLDOWN
@export var detection_range := DEFAULT_DETECTION_RANGE
@export var team := "player"  # "player" o "enemy"

# ===== VARIABILI COMBATTIMENTO =====

var current_target: BaseUnit = null
var can_attack := true
var attack_timer := 0.0
var is_in_combat := false
var combat_time := 0.0  # Tempo totale in combattimento

# ===== SISTEMA STAMINA =====

var max_stamina := DEFAULT_MAX_STAMINA
var current_stamina := DEFAULT_MAX_STAMINA
var is_fatigued := false

# ===== SISTEMA MORALE =====

var morale := DEFAULT_MORALE
var is_surrounded := false
var nearby_allies := 0
var nearby_enemies := 0
var ally_deaths_witnessed := 0
var near_city := false

# ===== SEGNALI =====

signal stamina_changed(new_stamina: float)
signal morale_changed(new_morale: float)
signal entered_combat
signal exited_combat
signal target_killed(target: BaseUnit)

# ===== RIFERIMENTI UI =====

@onready var stamina_bar = get_node_or_null("StaminaBar")
@onready var morale_indicator = get_node_or_null("MoraleIndicator")

# ===== METODI LIFECYCLE =====

func _ready():
	super._ready()  # Chiama _ready() della classe base
	unit_type = "soldier"

	# Aggiungi a gruppo soldati
	add_to_group("soldiers")

	# Setup colore distintivo
	if sprite:
		sprite.modulate = Color.RED if team == "player" else Color.DARK_RED

	# Connetti segnali per UI
	stamina_changed.connect(_on_stamina_changed)
	morale_changed.connect(_on_morale_changed)

	# Setup UI iniziale
	_update_ui()

	print("Soldier '%s' (team: %s) pronto al combattimento" % [name, team])

func _physics_process(delta):
	super._physics_process(delta)  # Movimento base

	# Update combattimento
	_update_combat(delta)

	# Update stamina
	_update_stamina(delta)

	# Update morale
	_update_morale(delta)

	# Rilevamento nemici
	if not current_target or not is_instance_valid(current_target):
		_find_nearest_enemy()

func _process(delta):
	# Update timer attacco
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

# ===== SISTEMA COMBATTIMENTO =====

func _update_combat(delta: float):
	"""Aggiorna logica combattimento"""
	# Se ha target valido
	if current_target and is_instance_valid(current_target):
		var distance = global_position.distance_to(current_target.global_position)

		# Se nel raggio di attacco
		if distance <= attack_range:
			# Ferma movimento
			if navigation_agent:
				navigation_agent.target_position = global_position

			# Attacca se può
			if can_attack and current_stamina >= STAMINA_ATTACK_COST:
				_perform_attack()

			# Segna come in combattimento
			if not is_in_combat:
				is_in_combat = true
				combat_time = 0.0
				entered_combat.emit()

			combat_time += delta

		else:
			# Insegui target se fuori range
			if navigation_agent:
				navigation_agent.target_position = current_target.global_position
	else:
		# Nessun target, esci da combattimento
		if is_in_combat:
			is_in_combat = false
			exited_combat.emit()
		combat_time = 0.0

func _perform_attack():
	"""Esegue un attacco sul target corrente"""
	if not current_target or not is_instance_valid(current_target):
		return

	# Calcola danno effettivo (ridotto se affaticato o morale basso)
	var damage = attack_damage
	var fatigue_multiplier = 1.0 if not is_fatigued else 0.7
	var morale_multiplier = morale / 100.0

	damage = int(damage * fatigue_multiplier * morale_multiplier)

	# Applica danno
	if current_target.has_method("take_damage"):
		current_target.take_damage(damage)
		print("%s attacca %s per %d danni" % [name, current_target.name, damage])

	# Consuma stamina
	current_stamina -= STAMINA_ATTACK_COST
	stamina_changed.emit(current_stamina)

	# Reset cooldown
	can_attack = false
	attack_timer = attack_cooldown

	# Effetto visivo attacco (flash)
	_flash_attack()

	# Controlla se target è morto
	if current_target.current_health <= 0:
		target_killed.emit(current_target)
		current_target = null

func _flash_attack():
	"""Effetto visivo durante attacco"""
	if not sprite:
		return

	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.1)

func _find_nearest_enemy():
	"""Trova il nemico più vicino nel raggio di rilevamento"""
	var enemy_team = "enemy" if team == "player" else "player"
	var all_units = get_tree().get_nodes_in_group("units")
	var nearest_enemy: BaseUnit = null
	var min_distance = detection_range

	for unit in all_units:
		if not is_instance_valid(unit):
			continue

		# Skip se stesso
		if unit == self:
			continue

		# Controlla se è nemico
		var is_enemy = false
		if unit is Soldier:
			is_enemy = unit.team != team
		elif team == "enemy":
			# Nemici attaccano anche worker player
			is_enemy = unit.is_in_group("player_units")

		if is_enemy:
			var distance = global_position.distance_to(unit.global_position)
			if distance < min_distance:
				min_distance = distance
				nearest_enemy = unit

	if nearest_enemy:
		current_target = nearest_enemy

# ===== SISTEMA STAMINA =====

func _update_stamina(delta: float):
	"""Aggiorna stamina del soldato"""
	if is_in_combat:
		# In combattimento: no recupero automatico
		pass
	else:
		# Fuori combattimento: recupera stamina
		current_stamina += STAMINA_RECOVERY_RATE * delta
		current_stamina = min(current_stamina, max_stamina)
		stamina_changed.emit(current_stamina)

	# Controlla affaticamento
	var was_fatigued = is_fatigued
	is_fatigued = current_stamina < FATIGUE_THRESHOLD

	if is_fatigued and not was_fatigued:
		print("%s è affaticato!" % name)
	elif not is_fatigued and was_fatigued:
		print("%s ha recuperato" % name)

# ===== SISTEMA MORALE =====

func _update_morale(delta: float):
	"""Aggiorna morale del soldato basato su vari fattori"""
	var base_morale = DEFAULT_MORALE
	var morale_modifiers = 0.0

	# 1. Conta alleati e nemici vicini
	_count_nearby_units()

	# 2. Bonus/Malus basato su compagni vicini
	morale_modifiers += nearby_allies * 2.0  # +2 morale per alleato vicino
	morale_modifiers -= nearby_enemies * 3.0  # -3 morale per nemico vicino

	# 3. Malus se circondato
	if is_surrounded:
		morale_modifiers -= 30.0
		print("%s è circondato! Morale ridotto" % name)

	# 4. Malus inferiorità numerica
	if nearby_enemies > nearby_allies * 2:
		morale_modifiers -= 20.0

	# 5. Malus per morti alleati assistiti
	morale_modifiers -= ally_deaths_witnessed * 5.0

	# 6. Bonus se vicino alla città
	if _is_near_city():
		morale_modifiers += MORALE_CITY_BONUS
		near_city = true
	else:
		near_city = false

	# 7. Malus se stanco
	if is_fatigued:
		morale_modifiers -= 15.0

	# 8. Malus combattimento prolungato
	if combat_time > 30.0:  # Più di 30 secondi in combattimento
		morale_modifiers -= 10.0

	# Calcola morale finale
	var target_morale = base_morale + morale_modifiers
	target_morale = clamp(target_morale, 0.0, 150.0)  # 0-150%

	# Interpola smooth verso target morale
	morale = lerp(morale, target_morale, delta * 0.5)
	morale_changed.emit(morale)

	# Se morale troppo basso, possibility di fuga (TODO future)
	if morale < 20.0:
		print("%s ha morale molto basso!" % name)

func _count_nearby_units():
	"""Conta alleati e nemici vicini per calcolo morale"""
	nearby_allies = 0
	nearby_enemies = 0

	var all_units = get_tree().get_nodes_in_group("units")
	var enemies_around = []

	for unit in all_units:
		if not is_instance_valid(unit) or unit == self:
			continue

		var distance = global_position.distance_to(unit.global_position)
		if distance > MORALE_INFLUENCE_RADIUS:
			continue

		# Determina se alleato o nemico
		var is_ally = false
		var is_enemy = false

		if unit is Soldier:
			is_ally = unit.team == team
			is_enemy = unit.team != team
		elif team == "player":
			# Player soldier: worker player sono alleati
			is_ally = unit.is_in_group("player_units")

		if is_ally:
			nearby_allies += 1
		elif is_enemy:
			nearby_enemies += 1
			enemies_around.append(unit)

	# Determina se circondato (nemici da più direzioni)
	is_surrounded = _check_if_surrounded(enemies_around)

func _check_if_surrounded(enemies: Array) -> bool:
	"""Controlla se il soldato è circondato da nemici"""
	if enemies.size() < 3:
		return false

	# Calcola angoli dei nemici rispetto al soldato
	var angles = []
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var direction = global_position.direction_to(enemy.global_position)
		angles.append(direction.angle())

	# Ordina angoli
	angles.sort()

	# Controlla se ci sono nemici in direzioni opposte (spread > 180°)
	for i in range(angles.size()):
		var next_i = (i + 1) % angles.size()
		var angle_diff = abs(angles[next_i] - angles[i])
		if angle_diff > PI:  # 180 gradi
			return true

	return false

func _is_near_city() -> bool:
	"""Controlla se vicino a edifici/worker (città)"""
	# Controlla edifici
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if not is_instance_valid(building):
			continue

		# Solo edifici player danno bonus morale a soldier player
		if team == "player" and building.is_in_group("player_buildings"):
			var distance = global_position.distance_to(building.global_position)
			if distance < CITY_BONUS_RADIUS:
				return true

	# Controlla worker vicini (presenza civile)
	var workers = get_tree().get_nodes_in_group("units")
	for worker in workers:
		if not is_instance_valid(worker):
			continue

		if worker.unit_type == "worker" and team == "player":
			var distance = global_position.distance_to(worker.global_position)
			if distance < CITY_BONUS_RADIUS:
				return true

	return false

func witness_ally_death():
	"""Chiamato quando vede morire un alleato vicino"""
	ally_deaths_witnessed += 1
	morale -= 10.0  # Impatto immediato sul morale
	morale_changed.emit(morale)
	print("%s ha visto morire un alleato! Morale ridotto" % name)

# ===== OVERRIDE METODI BASE =====

func _die():
	"""Override metodo morte per notificare alleati vicini"""
	# Notifica alleati vicini
	var nearby_soldiers = get_tree().get_nodes_in_group("soldiers")
	for soldier in nearby_soldiers:
		if not is_instance_valid(soldier) or soldier == self:
			continue

		if soldier is Soldier and soldier.team == team:
			var distance = global_position.distance_to(soldier.global_position)
			if distance < MORALE_INFLUENCE_RADIUS:
				soldier.witness_ally_death()

	# Morte normale
	super._die()

# ===== METODI PUBBLICI =====

func get_stamina_percentage() -> float:
	"""Ritorna stamina in percentuale 0-100"""
	return (current_stamina / max_stamina) * 100.0

func get_morale_percentage() -> float:
	"""Ritorna morale in percentuale (può superare 100)"""
	return morale

func force_attack(target: BaseUnit):
	"""Forza attacco su target specifico"""
	current_target = target

func stop_combat():
	"""Ferma combattimento"""
	current_target = null
	is_in_combat = false
	exited_combat.emit()

# ===== UI UPDATE =====

func _on_stamina_changed(new_stamina: float):
	"""Callback quando stamina cambia"""
	_update_ui()

func _on_morale_changed(new_morale: float):
	"""Callback quando morale cambia"""
	_update_ui()

func _update_ui():
	"""Aggiorna barre UI"""
	if stamina_bar:
		stamina_bar.value = current_stamina
		stamina_bar.max_value = max_stamina
		# Cambia colore in base a stamina
		if is_fatigued:
			stamina_bar.modulate = Color.ORANGE
		else:
			stamina_bar.modulate = Color.GREEN

	if morale_indicator:
		morale_indicator.text = "%d%%" % int(morale)
		# Cambia colore in base a morale
		if morale > 80:
			morale_indicator.modulate = Color.GREEN
		elif morale > 50:
			morale_indicator.modulate = Color.YELLOW
		elif morale > 30:
			morale_indicator.modulate = Color.ORANGE
		else:
			morale_indicator.modulate = Color.RED

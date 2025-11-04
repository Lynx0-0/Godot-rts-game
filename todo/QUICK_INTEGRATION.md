# ⚡ INTEGRAZIONE RAPIDA - Copy/Paste Ready

Se hai fretta e vuoi integrare velocemente, usa questi snippet pronti.

---

## 🏃 MODIFICA BASE_UNIT.GD (5 minuti)

### 1. Aggiungi in cima al file:
```gdscript
# Dopo extends CharacterBody2D
var movement_component: SmoothMovementComponent
```

### 2. Modifica _ready(), aggiungi ALLA FINE:
```gdscript
func _ready():
    # ... tutto il tuo codice esistente ...
    
    # AGGIUNGI QUESTE RIGHE:
    # Setup movimento fluido
    movement_component = SmoothMovementComponent.new()
    movement_component.name = "SmoothMovement"
    movement_component.max_speed = speed
    movement_component.acceleration = 500.0
    movement_component.deceleration = 700.0
    movement_component.path_smoothing = 0.3
    add_child(movement_component)
    
    # Configura NavigationAgent per movimento fluido
    if navigation_agent:
        navigation_agent.path_desired_distance = 10.0
        navigation_agent.target_desired_distance = 15.0
        navigation_agent.avoidance_enabled = true
        navigation_agent.radius = 20.0
        navigation_agent.max_speed = speed
```

### 3. SOSTITUISCI _physics_process() con:
```gdscript
func _physics_process(delta):
    # Usa componente movimento fluido se disponibile
    if movement_component:
        movement_component.physics_update(delta)
    else:
        # Fallback al vecchio sistema
        if navigation_agent.is_navigation_finished():
            return
        
        var next_position = navigation_agent.get_next_path_position()
        var direction = global_position.direction_to(next_position)
        var new_velocity = direction * speed
        navigation_agent.velocity = new_velocity
```

### 4. Mantieni la tua _on_velocity_computed() COSÌ COM'È
```gdscript
# NON MODIFICARE - funziona già
func _on_velocity_computed(safe_velocity: Vector2):
    if not movement_component:  # Solo se non hai componente
        velocity = safe_velocity
        move_and_slide()
```

**FATTO! Base_unit ora ha movimento fluido.** ✅

---

## 🎥 SETUP CAMERA CON EFFETTI (3 minuti)

### Opzione A: Sostituisci Script Completo
1. Apri `scenes/camera/game_camera.tscn`
2. Nel nodo Camera2D, Inspector → Script
3. Click icona script → "Change Script"
4. Seleziona `enhanced_camera.gd`
5. Nell'Inspector, abilita: `Enable Depth Effects = ON`

### Opzione B: Modifica Script Esistente
Se vuoi mantenere tuo camera_controller.gd, aggiungi:

```gdscript
# In cima al file
var post_process_layer: CanvasLayer
var depth_material: ShaderMaterial

# In _ready(), ALLA FINE:
func _ready():
    # ... tuo codice esistente ...
    
    # AGGIUNGI:
    _setup_post_processing()

# AGGIUNGI questa funzione nuova:
func _setup_post_processing():
    post_process_layer = CanvasLayer.new()
    post_process_layer.layer = 128
    post_process_layer.follow_viewport_enabled = true
    add_child(post_process_layer)
    
    var color_rect = ColorRect.new()
    color_rect.material = ShaderMaterial.new()
    
    var shader = load("res://shaders/depth_vignette.gdshader")
    if shader:
        color_rect.material.shader = shader
        depth_material = color_rect.material
        depth_material.set_shader_parameter("vignette_intensity", 0.4)
        depth_material.set_shader_parameter("blur_amount", 2.0)
        depth_material.set_shader_parameter("focus_center", Vector2(0.5, 0.5))
        depth_material.set_shader_parameter("focus_radius", 0.35)
    
    color_rect.anchor_right = 1.0
    color_rect.anchor_bottom = 1.0
    color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    post_process_layer.add_child(color_rect)
```

**FATTO! Camera ha effetti shader.** ✅

---

## 📐 SETUP Z-ORDERING (2 minuti)

### 1. Aggiungi Autoload:
```
Project → Project Settings → Autoload
Path: res://scripts/systems/isometric_depth_manager.gd
Name: DepthManager
Singleton: ✓ ON
Click "Add"
```

### 2. Verifica Gruppi Unità
Nel tuo base_unit.gd, _ready(), assicurati ci sia:
```gdscript
add_to_group("units")
```

Se hai edifici, nel loro _ready():
```gdscript
add_to_group("buildings")
```

**FATTO! Z-ordering automatico attivo.** ✅

---

## 🧪 TEST VELOCE

### Testa Movimento:
1. F5 per avviare
2. Seleziona unità
3. Click destro varie posizioni
4. **Verifica**:
   - Unità accelera smooth (non snap istantaneo)
   - Decelera gradualmente all'arrivo
   - Path curvi invece di angoli netti

### Testa Effetti:
1. Osserva bordi schermo
2. **Verifica**:
   - Vignette scura ai bordi (leggera)
   - Centro più definito
3. Zoom in/out con scroll
4. **Verifica**: Effetti si adattano

### Testa Z-Ordering:
1. Muovi 2+ unità una davanti/dietro altra (in Y)
2. **Verifica**: Quella più "bassa" (Y maggiore) copre quella più "alta"

---

## 🎛️ TUNING RAPIDO PARAMETRI

### Movimento Troppo Lento?
Nel codice dove aggiungi SmoothMovementComponent:
```gdscript
movement_component.max_speed = 200.0  # Era 150
movement_component.acceleration = 800.0  # Era 500
```

### Movimento Troppo Veloce?
```gdscript
movement_component.max_speed = 100.0
movement_component.acceleration = 300.0
```

### Path Troppo Rigido?
```gdscript
movement_component.path_smoothing = 0.5  # Era 0.3 (0=netto, 1=molto smooth)
```

### Effetti Troppo Intensi?
Nel codice setup shader (o in Inspector se usi enhanced_camera):
```gdscript
depth_material.set_shader_parameter("vignette_intensity", 0.2)  # Era 0.4
depth_material.set_shader_parameter("blur_amount", 1.0)  # Era 2.0
```

### Effetti Troppo Leggeri?
```gdscript
depth_material.set_shader_parameter("vignette_intensity", 0.6)
depth_material.set_shader_parameter("blur_amount", 3.5)
```

---

## 🐛 FIX PROBLEMI COMUNI

### Problema: "SmoothMovementComponent not found"
**Fix**: Assicurati file sia in `res://scripts/units/smooth_movement_component.gd`

### Problema: Shader non carica
**Fix**: 
1. Verifica path: `res://shaders/depth_vignette.gdshader`
2. Controlla Console per errori compilazione shader

### Problema: Movimento ancora a scatti
**Fix**:
1. Apri scene base_unit.tscn
2. Seleziona nodo NavigationAgent2D
3. In Inspector:
   - Path Desired Distance: 10
   - Target Desired Distance: 15
   - Avoidance Enabled: ✓ ON
   - Max Speed: 150

### Problema: DepthManager non funziona
**Fix**:
1. Project Settings → Autoload
2. Verifica "DepthManager" sia nella lista
3. Singleton deve essere ✓ ON
4. Riavvia progetto (Project → Reload Project)

### Problema: Performance basse
**Fix**:
1. Disabilita collision avoidance:
   ```gdscript
   navigation_agent.avoidance_enabled = false
   ```
2. Oppure disabilita shader:
   ```gdscript
   # In camera, in _ready():
   # _setup_post_processing()  # ← Commenta questa riga
   ```

---

## 🎯 CHECKLIST 5 MINUTI

- [ ] ✅ Copiato smooth_movement_component.gd in scripts/units/
- [ ] ✅ Modificato base_unit.gd → aggiunti snippet movimento
- [ ] ✅ Copiato depth_vignette.gdshader in shaders/
- [ ] ✅ Modificato camera (sostituito script O aggiunto codice)
- [ ] ✅ Copiato isometric_depth_manager.gd in scripts/systems/
- [ ] ✅ Aggiunto DepthManager in Autoload
- [ ] ✅ Testato - funziona?

**Se tutti ✅**: Congratulazioni! Sistema attivo! 🎉  
**Se problemi**: Vedi fix sopra o leggi SETUP_GUIDE completo

---

## 🚀 NEXT STEPS

Ora che hai base funzionante:

1. **Tuning Fine**:
   - Sperimenta con parametri (velocità, blur, vignette)
   - Trova il balance perfetto per tuo gioco

2. **Estensioni**:
   - Aggiungi particle effects (polvere) su movimento
   - Implementa unit formations più complesse
   - Camera shake su eventi

3. **Ottimizzazione**:
   - Se >50 unità, considera batch update
   - LOD per shader (disabilita quando zoommato out)
   - Spatial partitioning per collision avoidance

**Ma prima godi il movimento fluido!** 😎

---

## 💡 PRO TIPS

### Tip 1: Debug Pathfinding
Abilita visualizzazione navigation mesh:
```
Debug → Visible Collision Shapes (F4)
```

### Tip 2: Test Formazioni
Nel main.gd, quando muovi gruppo unità, sperimenta con spacing:
```gdscript
var spacing = 80.0  # Era 60, prova valori diversi
```

### Tip 3: Effetto Più Drammatico
Per effetto miniworld più evidente:
```gdscript
depth_material.set_shader_parameter("vignette_intensity", 0.7)
depth_material.set_shader_parameter("blur_amount", 4.0)
depth_material.set_shader_parameter("focus_radius", 0.25)  # Focus più stretto
```

### Tip 4: Toggle Effetti Runtime
Aggiungi binding input (Project Settings → Input Map):
```
Nome: toggle_effects
Key: T
```

Poi in camera script:
```gdscript
func _input(event):
    if event.is_action_pressed("toggle_effects"):
        if post_process_layer:
            post_process_layer.visible = !post_process_layer.visible
```

---

## 📊 RISULTATO ATTESO

**Prima**: ●─→●─→● (movimento rigido, snap a posizioni)  
**Dopo**: ●~~~→●~~~→● (movimento fluido con curve)

**Prima**: Tutto schermo stesso focus  
**Dopo**: Centro nitido, bordi sfocati (miniworld effect)

**Prima**: Z-ordering casuale  
**Dopo**: Sovrapposizione corretta dinamica

---

**Hai tutto! Ora implementa e divertiti!** 🎮✨

# 🎮 GUIDA SETUP: Movimento Fluido + Effetti Profondità Isometrica

## 📋 PANORAMICA SISTEMA

Questo sistema risolve il problema del movimento "a scacchiera" e aggiunge senso di profondità attraverso:

1. **Movimento Fluido**: Accelerazione/decelerazione naturale, path smoothing
2. **Effetti Visivi**: Vignette, blur bordi, contrasto centrale (effetto "miniworld")
3. **Z-Ordering Automatico**: Sovrapposizione corretta oggetti in base a profondità
4. **Collision Avoidance**: Unità evitano ostacoli e altre unità

## 🔧 STEP 1: Setup Files

### Crea struttura cartelle:
```
project/
├── shaders/
│   └── depth_vignette.gdshader
├── scripts/
│   ├── camera/
│   │   └── enhanced_camera.gd
│   ├── systems/
│   │   └── isometric_depth_manager.gd
│   └── units/
│       ├── smooth_movement_component.gd
│       └── base_unit_enhanced.gd
```

### 1.1 Copia Files
- **depth_vignette.gdshader** → `res://shaders/`
- **enhanced_camera.gd** → `res://scripts/camera/`
- **isometric_depth_manager.gd** → `res://scripts/systems/`
- **smooth_movement_component.gd** → `res://scripts/units/`
- **base_unit_enhanced.gd** → `res://scripts/units/`

---

## 🎥 STEP 2: Setup Camera con Effetti

### 2.1 Modifica game_camera.tscn
1. Apri `scenes/camera/game_camera.tscn`
2. Cambia script da `camera_controller.gd` a `enhanced_camera.gd`
3. Nell'inspector, configura:
   ```
   Enable Depth Effects: ✓ ON
   Vignette Intensity: 0.4
   Blur Intensity: 2.0
   Center Brightness Boost: 0.3
   ```

### 2.2 Testa Effetti
- **F5** per avviare
- Gli effetti dovrebbero applicarsi automaticamente
- **Toggle runtime**: Premi `T` (aggiungi binding in Input Map)

**Troubleshooting**:
- Se non vedi effetti: Verifica che shader sia in `res://shaders/depth_vignette.gdshader`
- Se crash: Controlla console per errori shader

---

## 🏃 STEP 3: Setup Movimento Fluido

### 3.1 Aggiorna BaseUnit Scene
1. Apri `scenes/units/base_unit.tscn`
2. **Opzione A** (Migrazione completa):
   - Cambia script a `base_unit_enhanced.gd`
   
3. **Opzione B** (Modifiche manuali al tuo base_unit.gd):
   
   **Aggiungi in _ready():**
   ```gdscript
   # Setup smooth movement
   var movement_comp = SmoothMovementComponent.new()
   movement_comp.name = "SmoothMovement"
   movement_comp.max_speed = speed
   movement_comp.acceleration = 500.0
   movement_comp.deceleration = 700.0
   movement_comp.path_smoothing = 0.3
   add_child(movement_comp)
   ```
   
   **Sostituisci _physics_process():**
   ```gdscript
   func _physics_process(delta):
       var movement_comp = get_node_or_null("SmoothMovement")
       if movement_comp:
           movement_comp.physics_update(delta)
   ```

### 3.2 Configura NavigationAgent2D
Nel tuo base_unit.tscn, seleziona NavigationAgent2D e configura:
```
Path Desired Distance: 10
Target Desired Distance: 15
Path Max Distance: 30
Avoidance Enabled: ✓ ON
Radius: 20
Max Speed: 150
```

---

## 📐 STEP 4: Setup Z-Ordering Automatico

### 4.1 Aggiungi come Autoload
1. **Project → Project Settings → Autoloads**
2. **Add**: 
   - Path: `res://scripts/systems/isometric_depth_manager.gd`
   - Name: `DepthManager`
   - Singleton: ✓ ON

### 4.2 Aggiungi Gruppi alle Entità
Nel _ready() di ogni entità (unità, edifici, risorse):
```gdscript
# Per unità
add_to_group("units")

# Per edifici
add_to_group("buildings")

# Per nodi risorse
add_to_group("resources")
```

**Il DepthManager troverà automaticamente questi gruppi!**

---

## 🧪 STEP 5: Testing e Tuning

### 5.1 Test Movimento
1. Avvia gioco
2. Seleziona unità
3. Click destro in vari punti
4. **Verifica**:
   - ✅ Accelerazione smooth (non istantanea)
   - ✅ Decelerazione graduale all'arrivo
   - ✅ Path curvi invece di angoli netti
   - ✅ Unità evitano collisioni tra loro

### 5.2 Test Z-Ordering
1. Muovi unità una dietro l'altra (in "profondità" Y)
2. **Verifica**: Unità più "basse" (Y maggiore) sono disegnate sopra

### 5.3 Test Effetti Visivi
1. Osserva bordi schermo
2. **Verifica**:
   - ✅ Vignette scura ai bordi
   - ✅ Leggero blur periferico
   - ✅ Centro più luminoso e contrastato
3. **Zoom in/out**: Effetti si adattano al livello zoom

---

## ⚙️ STEP 6: Tuning Parametri

### Movimento Troppo Lento/Veloce?
In `smooth_movement_component.gd`:
```gdscript
@export var max_speed := 150.0        # ← Aumenta/diminuisci
@export var acceleration := 500.0      # ← Velocità "ramp up"
@export var deceleration := 700.0      # ← Velocità "ramp down"
```

### Path Troppo Rigido/Morbido?
```gdscript
@export var path_smoothing := 0.3  # 0.0-1.0
# 0.0 = path netto, angoli duri
# 0.5 = buon bilanciamento
# 1.0 = molto smooth, può sembrare "pigro"
```

### Effetti Troppo Intensi?
In `enhanced_camera.gd`:
```gdscript
@export var vignette_intensity := 0.4  # 0.0-1.0
@export var blur_intensity := 2.0      # 0.0-5.0
```

**Valori consigliati**:
- **Sottile**: vignette=0.2, blur=1.0
- **Moderato**: vignette=0.4, blur=2.0 ← **Default**
- **Intenso**: vignette=0.6, blur=3.5

---

## 🎨 STEP 7: Ottimizzazioni Performance

### 7.1 Ridurre Update Z-Ordering
In `isometric_depth_manager.gd`:
```gdscript
@export var update_frequency := 0.1  # Secondi tra update
# 0.05 = molto smooth, CPU intensive
# 0.1 = buon bilanciamento ← Default
# 0.2 = leggero, ma possibili glitch visivi
```

### 7.2 Disabilitare Collision Avoidance (se troppe unità)
Se hai >50 unità e lag:
```gdscript
# In smooth_movement_component.gd
navigation_agent.avoidance_enabled = false  # ← Metti false
```

### 7.3 LOD per Effetti Shader
Disabilita effetti quando zoommato molto out:
```gdscript
# In enhanced_camera.gd, in _process()
if zoom.x < 0.7:
    color_rect.visible = false  # Disabilita shader
else:
    color_rect.visible = true
```

---

## 🐛 TROUBLESHOOTING

### Problema: Unità si muovono a scatti
**Soluzione**:
1. Verifica NavigationRegion2D sia "baked"
2. Aumenta `path_smoothing` a 0.5
3. Controlla FPS (se <30 fps, ottimizza altro)

### Problema: Unità si sovrappongono male
**Soluzione**:
1. Verifica `DepthManager` sia in Autoloads
2. Controlla che unità abbiano gruppo "units"
3. Riduci `update_frequency` a 0.05

### Problema: Effetti shader non visibili
**Soluzione**:
1. Verifica path shader: `res://shaders/depth_vignette.gdshader`
2. Controlla console per errori compilazione shader
3. Prova shader semplice di test

### Problema: Performance basse
**Soluzione**:
1. Disabilita blur shader (`blur_amount = 0`)
2. Aumenta `update_frequency` DepthManager
3. Disabilita `avoidance_enabled` se molte unità

---

## 🎯 RISULTATO ATTESO

**Movimento**:
- ✅ Fluido, naturale, senza "snap" a griglia
- ✅ Accelerazione/decelerazione smooth
- ✅ Path curvi invece di zig-zag

**Effetti Visivi**:
- ✅ Bordi scuri e sfocati (miniworld effect)
- ✅ Centro luminoso e definito
- ✅ Senso di profondità di campo

**Z-Ordering**:
- ✅ Unità/edifici sovrapposti correttamente
- ✅ Nessun "pop" visivo quando si muovono

---

## 📚 PROSSIMI PASSI CONSIGLIATI

1. **Particle Effects** per unità in movimento (polvere, ombre)
2. **Camera Shake** quando unità combattono
3. **Parallax Background** per layer sfondo
4. **Minimap** con visuale dinamica
5. **Fog of War** con shader simile a depth vignette

---

## 📖 RIFERIMENTI CODICE

**Sistema Completo**:
- `depth_vignette.gdshader` - Post-processing shader
- `enhanced_camera.gd` - Camera con effetti
- `isometric_depth_manager.gd` - Z-ordering automatico
- `smooth_movement_component.gd` - Movimento fluido
- `base_unit_enhanced.gd` - Unità con tutti i sistemi integrati

**Best Practices**:
- Movimento: Sempre usare NavigationAgent2D per pathfinding
- Z-ordering: Basato su global_position.y
- Effetti: Applicare a livello camera (post-process)
- Performance: Batch update invece di per-frame

# 🎨 DIAGRAMMI SISTEMA - Movimento Fluido Isometrico

## 🧠 ARCHITETTURA SISTEMA

```
┌─────────────────────────────────────────────────────────────┐
│                    ENHANCED CAMERA                           │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Post-Processing Layer (CanvasLayer 128)               │ │
│  │  └─ ColorRect (FullScreen) + Depth Shader            │ │
│  │      • Vignette Effect                                │ │
│  │      • Depth Blur                                     │ │
│  │      • Center Brightness Boost                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Camera Controls:                                            │
│  • WASD Pan                                                  │
│  • Mouse Edge Pan                                            │
│  • Scroll Zoom (aggiusta intensità effetti)                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              ISOMETRIC DEPTH MANAGER                         │
│              (Autoload Singleton)                            │
│                                                              │
│  Ogni 0.1s:                                                  │
│  • Trova tutti nodi in gruppi: "units", "buildings",        │
│    "resources"                                               │
│  • Per ogni nodo:                                            │
│      z_index = int(global_position.y / 10)                   │
│                                                              │
│  Risultato: Oggetti più "bassi" (Y grande) disegnati sopra  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    BASE UNIT                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         SMOOTH MOVEMENT COMPONENT                      │ │
│  │                                                        │ │
│  │  Input: target_position                               │ │
│  │           ↓                                            │ │
│  │  [NavigationAgent2D]                                  │ │
│  │      • Calcola path                                   │ │
│  │      • Evita ostacoli                                 │ │
│  │      • Path smoothing                                 │ │
│  │           ↓                                            │ │
│  │  [Smooth Velocity]                                    │ │
│  │      • Accelerazione graduale                         │ │
│  │      • Decelerazione smooth                           │ │
│  │      • Interpolazione direzione                       │ │
│  │           ↓                                            │ │
│  │  [CharacterBody2D.move_and_slide()]                   │ │
│  │      • Movimento fisico fluido                        │ │
│  │      • Collision detection                            │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Componenti Visivi:                                          │
│  • Sprite2D (modulate per selezione)                        │
│  • SelectionIndicator                                        │
│  • HealthBar                                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 FLUSSO MOVIMENTO UNITÀ

```
PLAYER CLICK DESTRO
        │
        ▼
   [main.gd]
   _move_selected_units()
        │
        ├─ Singola unità: target_pos esatto
        │
        └─ Multiple unità: calcola formazione
                │
                ▼
        ┌───────────────┐
        │  Base Unit    │
        │ move_to_pos() │
        └───────┬───────┘
                │
                ▼
   ┌────────────────────────────┐
   │ NavigationAgent2D          │
   │ target_position = pos      │
   └────────────┬───────────────┘
                │
                ▼ (ogni frame)
   ┌────────────────────────────────────┐
   │ SmoothMovementComponent            │
   │ physics_update()                   │
   ├────────────────────────────────────┤
   │ 1. Get next_path_position          │
   │ 2. Calculate direction             │
   │ 3. Smooth path interpolation       │
   │ 4. Accelerate to target_velocity   │
   │ 5. Apply to navigation_agent       │
   └────────────┬───────────────────────┘
                │
                ▼
   ┌────────────────────────────┐
   │ Collision Avoidance        │
   │ (se enabled)               │
   │ • Detecta altre unità      │
   │ • Calcola safe_velocity    │
   └────────────┬───────────────┘
                │
                ▼
   ┌────────────────────────────┐
   │ CharacterBody2D            │
   │ velocity = safe_velocity   │
   │ move_and_slide()           │
   └────────────────────────────┘
                │
                ▼
   ┌────────────────────────────┐
   │ UNITÀ SI MUOVE FLUIDA!     │
   └────────────────────────────┘
```

---

## 🌊 SMOOTH MOVEMENT: COSA SUCCEDE

### MOVIMENTO TRADIZIONALE (A SCATTI):
```
Frame 1:  velocity = 0        ●────────── target
Frame 2:  velocity = 150      ●────────── (snap istantaneo)
Frame 3:  velocity = 150      ──●──────── 
...
Frame 20: velocity = 150      ─────────●─ (vicino a target)
Frame 21: velocity = 0        ──────────● (stop brusco)
```

### MOVIMENTO SMOOTH (FLUIDO):
```
Frame 1:  velocity = 0        ●────────── target
Frame 2:  velocity = 30       ●────────── (accelera)
Frame 3:  velocity = 60       ●────────── 
Frame 4:  velocity = 90       ─●────────── 
Frame 5:  velocity = 120      ─●────────── 
Frame 6:  velocity = 150      ──●─────────  (max speed)
...
Frame 18: velocity = 150      ──────●──── (decelerazione inizia)
Frame 19: velocity = 120      ───────●─── 
Frame 20: velocity = 80       ────────●── 
Frame 21: velocity = 40       ─────────●─ 
Frame 22: velocity = 10       ──────────● 
Frame 23: velocity = 0        ──────────● (stop smooth)
```

**Differenze Chiave**:
- ✅ Accelerazione graduale (5-6 frame)
- ✅ Decelerazione anticipata (basata su distanza)
- ✅ Velocity interpolation tra frame
- ✅ Path smoothing (curve invece di angoli)

---

## 🎭 Z-ORDERING ISOMETRICO

### PROBLEMA SENZA Z-ORDERING:
```
Vista dall'alto (Y crescente = verso basso schermo):

Y=100  [Unità A] 🟦         ← Disegnata prima
Y=200  [Unità B] 🟨         ← Disegnata dopo

Rendering:
  🟦 (Layer 0)
  🟨 (Layer 0)

SBAGLIATO: Unità B copre sempre Unità A!
```

### SOLUZIONE CON DEPTH MANAGER:
```
Y=100  [Unità A] 🟦  z_index = 100/10 = 10
Y=200  [Unità B] 🟨  z_index = 200/10 = 20

Rendering order (dal basso all'alto):
  🟦 (z_index 10)  ← Disegnata prima
  🟨 (z_index 20)  ← Disegnata sopra

CORRETTO: Unità più "bassa" copre quella più "alta"!
```

### MOVIMENTO DINAMICO:
```
Frame 1:
  Unità A (Y=100, z=10) 🟦
  Unità B (Y=200, z=20) 🟨
  Render: 🟦🟨 ✓

Frame 50 (A si muove verso il basso):
  Unità A (Y=250, z=25) 🟦
  Unità B (Y=200, z=20) 🟨
  Render: 🟨🟦 ✓ (ordine invertito automaticamente!)
```

---

## 🎨 SHADER VIGNETTE: ANATOMIA

```
┌────────────────────────────────────────────┐
│              SCHERMO GIOCO                 │
│                                            │
│  ┌──────────────────────────────────────┐ │
│  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ │ ← Vignette
│  │ ▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓▓ │ │   scura
│  │ ▓▓░                            ░▓▓ │ │
│  │ ▓▓░    ┌──────────────────┐    ░▓▓ │ │
│  │ ▓▓░    │   FOCUS AREA     │    ░▓▓ │ │ ← Centro
│  │ ▓▓░    │   (Sharp)        │    ░▓▓ │ │   nitido
│  │ ▓▓░    │   High Contrast  │    ░▓▓ │ │
│  │ ▓▓░    │   +20% Bright    │    ░▓▓ │ │
│  │ ▓▓░    └──────────────────┘    ░▓▓ │ │
│  │ ▓▓░                            ░▓▓ │ │
│  │ ▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓▓ │ │ ← Gradiente
│  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ │   smooth
│  └──────────────────────────────────────┘ │
│                                            │
└────────────────────────────────────────────┘

PARAMETRI SHADER:
• vignette_intensity: 0.4 (quanto scuro ai bordi)
• focus_center: (0.5, 0.5) (centro schermo)
• focus_radius: 0.35 (raggio area nitida)
• blur_amount: 2.0 (intensità blur periferico)
```

### EFFETTO SU ZOOM:
```
ZOOM OUT (zoom.x = 0.5):
┌────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │  Effetto INTENSO
│ ▓▓░░░░░░░░░░░░░░░░░░░░░░▓▓ │  (vedi più mappa,
│ ▓▓░    [Piccola area]  ░▓▓ │   focus più stretto)
│ ▓▓░░░░░░░░░░░░░░░░░░░░░░▓▓ │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
└────────────────────────────┘

ZOOM IN (zoom.x = 2.5):
┌────────────────────────────┐
│ ▓░                       ░▓ │  Effetto LEGGERO
│ ░                         ░ │  (vedi dettagli,
│                             │   serve meno effetto)
│ ░                         ░ │
│ ▓░                       ░▓ │
└────────────────────────────┘
```

---

## ⚡ PERFORMANCE COMPARISON

### SISTEMA BASE (Tuo Attuale):
```
_physics_process() ogni frame (60 FPS):
  ├─ NavigationAgent: calcola path ────────── 0.3ms
  ├─ Velocity = direction * speed ───────── 0.01ms
  └─ move_and_slide() ────────────────────── 0.1ms
  TOTALE per unità: ~0.41ms
  
  Con 100 unità: 41ms (24 FPS) ❌ Lag!
```

### SISTEMA SMOOTH:
```
_physics_process() ogni frame (60 FPS):
  ├─ NavigationAgent: calcola path ────────── 0.3ms
  ├─ Path smoothing (lerp) ──────────────── 0.05ms
  ├─ Accelerazione (move_toward) ────────── 0.02ms
  ├─ Collision avoidance (se abilitato) ──── 0.5ms
  └─ move_and_slide() ────────────────────── 0.1ms
  TOTALE per unità: ~0.97ms
  
  Con 100 unità: 97ms (10 FPS) ❌❌ Troppo!
```

### OTTIMIZZAZIONE:
```
Disabilita avoidance per unità distanti:
  
  IF distanza_da_camera > 500px:
      avoidance_enabled = false
      path_smoothing = 0.1 (meno smooth)
  ELSE:
      avoidance_enabled = true
      path_smoothing = 0.3
  
  TOTALE per unità vicina: 0.97ms
  TOTALE per unità lontana: 0.47ms
  
  Con 100 unità (20 vicine, 80 lontane):
    (20 × 0.97) + (80 × 0.47) = 57ms (17 FPS)
    ✅ Giocabile ma non ottimale
    
  Con batch update (update 10 unità per frame):
    5.7ms per frame (175+ FPS) ✅✅ Perfetto!
```

---

## 🎮 INPUT → OUTPUT COMPLETO

```
PLAYER ACTION: Click destro su posizione (800, 600)
        │
        ▼
┌───────────────────────────────────────────────────┐
│ main.gd: _move_selected_units((800, 600))        │
│ • selected_units = [Unit1, Unit2, Unit3]         │
│ • Calcola formazione 3x1                          │
│   Unit1: (780, 600)                               │
│   Unit2: (800, 600)                               │
│   Unit3: (820, 600)                               │
└────────────────┬──────────────────────────────────┘
                 │
    ┌────────────┴────────────┬────────────────┐
    ▼                         ▼                ▼
[Unit1]                   [Unit2]          [Unit3]
pos=(100,100)            pos=(120,100)    pos=(140,100)
    │                         │                │
    ▼                         ▼                ▼
move_to_position()       move_to_position()  ...
target=(780,600)         target=(800,600)
    │                         │
    ▼                         ▼
NavigationAgent2D        NavigationAgent2D
calcola path             calcola path
    │                         │
    ▼ (ogni frame)            ▼
┌──────────────────────────────────────────────┐
│ SmoothMovementComponent.physics_update()    │
│                                              │
│ Frame 1:  vel=0 → 30    (accelera)          │
│ Frame 2:  vel=30 → 60                       │
│ Frame 3:  vel=60 → 90                       │
│ ...                                          │
│ Frame 6:  vel=150       (max_speed)         │
│ ...                                          │
│ Frame 45: Vicino target, inizia decelera    │
│ Frame 50: vel=0, ARRIVED! ✓                 │
└──────────────┬───────────────────────────────┘
               │
               ▼ (mentre si muove, ogni 0.1s)
┌──────────────────────────────────────────────┐
│ DepthManager: aggiorna z_index              │
│                                              │
│ Unit1: Y=350 → z_index=35                   │
│ Unit2: Y=360 → z_index=36 (disegnato sopra) │
│ Unit3: Y=340 → z_index=34 (disegnato sotto) │
└──────────────────────────────────────────────┘
               │
               ▼ (rendering)
┌──────────────────────────────────────────────┐
│ EnhancedCamera: applica post-processing     │
│                                              │
│ • Vignette ai bordi                         │
│ • Blur periferico                           │
│ • Boost contrasto centro                    │
│                                              │
│ RISULTATO: Movimento fluido con senso       │
│           di profondità "miniworld"!        │
└──────────────────────────────────────────────┘
```

---

## 📊 CONFRONTO VISIVO

### PRIMA (Sistema Attuale):
```
Movimento:
  ●─────→●─────→●  (snap a griglia, angoli netti)

Z-Ordering:
  Unità sempre stesso ordine, overlap sbagliato

Visuale:
  Tutto uguale nitidezza, nessun focus
```

### DOPO (Sistema Nuovo):
```
Movimento:
  ●~~~→●~~~→●  (curve smooth, accelerazione fluida)

Z-Ordering:
  Unità cambiano ordine rendering dinamicamente

Visuale:
  ▓▓░  Centro nitido  ░▓▓  Bordi sfocati
  ↑ Effetto miniworld/diorama
```

---

## 🔧 COMPONENTI MODULARI

Il sistema è progettato per essere **modulare**:

```
┌─────────────────────────────────────────┐
│ PUOI USARE INDIPENDENTEMENTE:           │
├─────────────────────────────────────────┤
│ ☐ Solo Smooth Movement                  │
│   (movimento fluido, no effetti)        │
│                                         │
│ ☐ Solo Camera Effetti                   │
│   (vignette/blur, no smooth movement)   │
│                                         │
│ ☐ Solo Depth Manager                    │
│   (z-ordering, resto invariato)         │
│                                         │
│ ☑ Tutto Insieme                         │
│   (esperienza completa!) ← Consigliato  │
└─────────────────────────────────────────┘
```

**Raccomandazione**: Inizia con **Smooth Movement** + **Depth Manager**,  
poi aggiungi **Camera Effetti** se piacciono!

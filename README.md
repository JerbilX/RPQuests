# RPQuest

Addon nativo para **The Elder Scrolls Online** (`APIVersion: 101051`) que permite crear, completar y compartir **misiones personalizadas (Roleplay / Custom Quests)** sin depender de ninguna librería externa.

---

## Características Principales

- **Pestaña propia en el Diario Nativo (`J`):** Integrada directamente en la barra superior de modos del Diario de Misiones (`ZO_QuestJournal_Keyboard`).
- **Creación y Edición Completa (`Create Quest`):**
  - Define **Título**, **Descripción / Historia** y **Tamaño del área de búsqueda** (`Pequeña`, `Mediana`, `Grande`).
- **Objetivos y Cantidades Inferidos bajo Retícula (`Keybind`):**
  - Apunta a cualquier NPC vivo y presiona la tecla asignada en *Controles -> RPQuest*:
    - Si apuntas y capturas a distintos NPCs con nombre, todos quedan registrados como objetivos exclusivos de la misión.
    - Si apuntas y capturas a un mismo tipo de NPC varias veces (ej. `Imp` 3 veces), se acumula automáticamente como `Imp x3`.
- **Marca de Área de Búsqueda en el Mapa Mundial (`M`):**
  - Cuando tienes una misión custom activa, se dibuja en el mapa un círculo amplio de exploración (usando el shader circular nativo `ZO_PinBlob`) desplazado con un **offset aleatorio fijo** respecto a la posición exacta del NPC. Así el objetivo siempre se encuentra dentro del círculo, pero nunca en su centro exacto.
  - Al completar o desactivar la misión, el círculo desaparece automáticamente del mapa.
- **Detección en Combate y Avisos Nativos:**
  - Al eliminar al objetivo dentro del área/zona de la misión, avanza el contador con aviso central en pantalla (`CENTER_SCREEN_ANNOUNCE`) y sonido oficial de misión completada (`SOUNDS.QUEST_COMPLETED`).
- **Mini-Tracker en el HUD:**
  - Muestra la misión custom activa en el margen derecho de la pantalla durante el juego (clic izquierdo abre el Diario; clic derecho abre el área en el Mapa).
- **Compartición por Código (`RPQ1:...`):**
  - Genera un código compacto con suma de verificación (`CRC16`) listo para copiar (`Ctrl+C`) y pasar a otro jugador para que lo importe desde la misma pestaña.
- **Persistencia por Personaje:**
  - Cada personaje gestiona su propia lista de misiones y progreso mediante `ZO_SavedVars:NewCharacterIdSettings`.
- **Localización Configurable (`lang/`):**
  - Detecta automáticamente el idioma del cliente (`es` Castellano / `en` Inglés) con fallback determinista y arquitectura extensible mediante archivos adicionales en `lang/`.

---

## Requisitos y Dependencias

- **Librerías externas:** Ninguna (`Zero-Dependency`).
- **SavedVariables:** `RPQuest_SavedVariables`

---

## Controles y Comandos Slash (`SLASH_COMMANDS`)

### Atajos de Teclado (`Ajustes -> Controles -> RPQuest`)
- **Seleccionar Objetivo bajo Retícula (NPC):** Captura el NPC vivo al que estás apuntando para el borrador de la misión.
- **Abrir / Cerrar Pestaña de Misiones Custom:** Abre directamente el Diario en la pestaña de `RPQuest`.

### Comandos de Chat
| Comando | Argumentos | Descripción |
| :--- | :--- | :--- |
| `/rpquest` | *(ninguno)* | Abre o cierra la pestaña de Misiones Custom en el Diario. |
| `/rpquest` | `capture` / `target` | Captura el NPC actualmente apuntado con la retícula. |
| `/rpquest` | `map` | Abre el Mapa Mundial centrado en el área de búsqueda de la misión activa. |

---

## Estructura del Proyecto

```text
RPQuest/
├── RPQuest.txt              # Manifiesto oficial para ESO
├── RPQuest.lua              # Punto de entrada y ciclo EVENT_ADD_ON_LOADED
├── Bindings.xml             # Definición de atajos de teclado nativos
├── lang/
│   ├── en.lua               # Diccionario en Inglés (Base / Fallback)
│   └── es.lua               # Diccionario en Castellano
├── src/
│   ├── Constants.lua        # Constantes, radios y metadatos
│   ├── Locale.lua           # Selector de idioma del cliente e i18n
│   ├── ShareCodec.lua       # Codificador/decodificador RPQ1 con CRC16
│   ├── QuestRepository.lua  # CRUD por personaje y cálculo de offset del círculo
│   ├── Announcements.lua    # Mensajes CENTER_SCREEN_ANNOUNCE y alertas
│   ├── TargetCapture.lua    # Captura de NPC bajo retícula y coordenadas de mapa
│   ├── CombatTracker.lua    # Seguimiento de bajas (EVENT_COMBAT_EVENT)
│   ├── WorldMapArea.lua     # Círculo de búsqueda nativo en ZO_WorldMap
│   └── JournalTab.lua       # Pestaña e interfaz completa en el Diario de Misiones
├── docs/adr/                # Registros de Decisiones de Arquitectura (MADR)
└── tests/
    ├── run.lua              # Suite de pruebas unitarias herméticas (LuaJIT)
    └── mocks/               # Mocks de EsoUI
```

---

## Desarrollo y Verificación

Ejecutar la suite de pruebas unitarias:
```bash
luajit tests/run.lua
```

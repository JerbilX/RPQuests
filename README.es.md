# RPQuest

[![Build](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml/badge.svg)](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml)
![Version](https://img.shields.io/badge/version-1.0.0-blue)
![ESO API](https://img.shields.io/badge/ESO%20API-101051-orange)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![Languages](https://img.shields.io/badge/i18n-EN%20%7C%20ES-informational)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

[English](README.md) | **Español**

Addon nativo y **sin dependencias externas** (`Zero-Dependency`) para **The Elder Scrolls Online** (`APIVersion: 101051`) que permite crear, jugar, completar y compartir **misiones personalizadas de rol (Roleplay / Custom Quests)** directamente dentro de la interfaz oficial del juego.

---

## Características Principales

- **Integración Nativa en el Diario (`J`):** Agrega la pestaña **RPQuest** dentro del Diario de Misiones (`ZO_QuestJournal_Keyboard`) separando las listas de misiones **En preparación** (creadas por ti) y **Recibidas** (activas/jugables).
- **Captura de NPCs bajo Retícula:** Apunta a cualquier NPC vivo y presiona tu atajo de teclado (o `/rpquest capture`). Capturar varias veces un mismo tipo de NPC se acumula automáticamente (ej. `Imp x3`); distintos NPCs con nombre se registran como objetivos individuales.
- **Puntos de Descubrimiento Ocultos:** Registra coordenadas de exploración en el mundo (`Keybind` o `/rpquest discovery`) con radio configurable (`Pequeño`, `Mediano`, `Grande`) sin mostrar spoilers en el mapa ni en la brújula.
- **Condición Opcional de Sigilo:** Permite exigir que los objetivos se completen sin ser detectado en combate.
- **Área de Búsqueda en el Mapa Mundial (`M`):** Dibuja un círculo aproximado (`ZO_PinBlob`) usando un offset aleatorio determinista y fijo: el objetivo siempre está dentro del círculo, pero nunca en el centro exacto. Desaparece automáticamente al completar o desactivar la misión.
- **Seguimiento en Combate, Exploración y Avisos Nativos:** Detecta bajas (`EVENT_COMBAT_EVENT`) y proximidad a puntos de descubrimiento, mostrando avisos `CENTER_SCREEN_ANNOUNCE` y sonidos oficiales (`SOUNDS.QUEST_COMPLETED`).
- **Mini-Tracker en el HUD:** Muestra la misión activa en pantalla (clic izquierdo abre el Diario; clic derecho centra el Mapa Mundial en el área de búsqueda).
- **Compartición y Validación por Código (`RPQ1` / `RPQC1`):**
  - Exporta misiones en códigos compactos con suma de verificación `CRC16` (`RPQ1:...`) listos para copiar y compartir.
  - Al completar una misión, genera un código de validación de entrega (`RPQC1:...`) para demostrarle al creador que fue completada.
- **Persistencia por Personaje y Auto-Localización:** Guarda el progreso por personaje con `ZO_SavedVars:NewCharacterIdSettings` y detecta automáticamente el idioma del cliente (`es` / `en`).

---

## Instalación

1. Descarga la última versión publicada (o clona este repositorio).
2. Extrae la carpeta `RPQuest` dentro de tu directorio de AddOns de ESO:
   - **Windows:** `Documentos\Elder Scrolls Online\live\AddOns\RPQuest\`
   - **macOS:** `~/Documents/Elder Scrolls Online/live/AddOns/RPQuest/`
   - **Linux (Steam/Proton):** `<SteamLibrary>/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns/RPQuest/`
3. Verifica que `RPQuest.txt` quede directamente dentro de `AddOns/RPQuest/RPQuest.txt`.
4. Inicia ESO y activa **RPQuest** en el menú de **Add-Ons**. No requiere librerías adicionales.

---

## Guía Rápida

1. **Crear una Misión (Quest Master):**
   - Abre el Diario de Misiones (`J`) y entra en la pestaña **RPQuest** (o escribe `/rpquest`).
   - Pulsa **Crear Misión**, define **Título**, **Descripción / Historia**, tamaño del **Área de búsqueda** (`Pequeña`, `Mediana`, `Grande`) y opcionalmente activa **No ser detectado**.
   - En el mundo, apunta a NPCs y usa el atajo **Capturar Objetivo** (`/rpquest capture`), o párate en un lugar y usa **Capturar Punto de Descubrimiento** (`/rpquest discovery`).
2. **Compartir con Jugadores:**
   - Selecciona la misión preparada y copia el código `RPQ1:...` generado.
   - Los jugadores pegan ese código en el campo **Importar** dentro de su pestaña **RPQuest**.
3. **Jugar y Verificar:**
   - Activa la misión recibida para ver el mini-tracker en el HUD y el área en el Mapa Mundial.
   - Al completar todos los objetivos, copia el código de entrega `RPQC1:...` generado para confirmar la finalización.

---

## Controles y Comandos Slash

### Atajos de Teclado (`Ajustes -> Controles -> RPQuest`)
| Acción | Descripción |
| :--- | :--- |
| **Capturar Objetivo bajo Retícula** | Registra el NPC vivo apuntado con la retícula en el borrador de la misión. |
| **Capturar Punto de Descubrimiento** | Registra tu posición actual como un objetivo de descubrimiento oculto. |
| **Abrir / Cerrar Pestaña RPQuest** | Abre o cierra el Diario directamente en la pestaña de **RPQuest**. |

### Comandos de Chat
| Comando | Argumentos | Descripción |
| :--- | :--- | :--- |
| `/rpquest` | *(ninguno)* | Abre o cierra la pestaña de **RPQuest** en el Diario de Misiones. |
| `/rpquest` | `capture` / `target` | Captura el NPC actualmente apuntado con la retícula. |
| `/rpquest` | `discovery` / `point` | Captura tu posición actual como punto de descubrimiento oculto. |
| `/rpquest` | `map` | Abre el Mapa Mundial centrado en el área de búsqueda de la misión activa. |

---

## Requisitos y Compatibilidad

- **Versión del Juego:** The Elder Scrolls Online (`APIVersion: 101051`)
- **Librerías Externas:** Ninguna (`Zero-Dependency`)
- **SavedVariables:** `RPQuest_SavedVariables` (por personaje)
- **Idiomas Soportados:** Español (`es`), Inglés (`en`)

---

## Estructura del Proyecto y Desarrollo

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
│   ├── ShareCodec.lua       # Codificador/decodificador RPQ1 / RPQC1 con CRC16
│   ├── QuestRepository.lua  # CRUD por personaje y cálculo de offset del círculo
│   ├── Announcements.lua    # Mensajes CENTER_SCREEN_ANNOUNCE y alertas
│   ├── TargetCapture.lua    # Captura de NPC bajo retícula y puntos de descubrimiento
│   ├── CombatTracker.lua    # Seguimiento de bajas y sigilo (EVENT_COMBAT_EVENT)
│   ├── DiscoveryTracker.lua # Sondeo de proximidad a puntos de descubrimiento ocultos
│   ├── WorldMapArea.lua     # Círculo de búsqueda nativo en ZO_WorldMap
│   └── JournalTab.lua       # Pestaña en el Diario de Misiones y mini-tracker HUD
├── docs/adr/                # Registros de Decisiones de Arquitectura (MADR)
└── tests/
    ├── run.lua              # Suite de pruebas unitarias herméticas (LuaJIT)
    └── mocks/               # Mocks de EsoUI
```

### Ejecutar Pruebas Unitarias
```bash
luajit tests/run.lua
```

---

## Licencia

Este proyecto está licenciado bajo **GNU General Public License v3.0** — consulta [LICENSE](LICENSE) para más detalles.

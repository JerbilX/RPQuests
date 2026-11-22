# RPQuest

[![Build](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml/badge.svg)](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml)
![Version](https://img.shields.io/badge/version-1.5.1-blue)
![ESO API](https://img.shields.io/badge/ESO%20API-101051-orange)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![Languages](https://img.shields.io/badge/i18n-EN%20%7C%20ES-informational)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

[English](README.md) | **Español**

Addon nativo y **sin dependencias externas** (`Zero-Dependency`) para **The Elder Scrolls Online** (`APIVersion: 101051`) que permite crear, jugar, completar y compartir **misiones personalizadas de rol (Roleplay / Custom Quests)** directamente dentro de la interfaz oficial del juego.

---

## Características Principales

- **Integración Nativa en el Diario (`J`):** Agrega la pestaña **RPQuest** dentro del Diario de Misiones (`ZO_QuestJournal_Keyboard`) separando las listas de misiones **En preparación** (creadas por ti) y **Recibidas** (activas/jugables).
- **Captura de NPCs bajo Retícula:** Apunta a cualquier NPC vivo y presiona tu atajo de teclado (o `/rpquest capture`). Capturar varias veces un mismo tipo de NPC se acumula automáticamente (ej. `Imp x3`); distintos NPCs con nombre se registran como objetivos individuales, con condiciones opcionales de ubicación (`Requerida` / `No requerida`) y mensajes personalizados al eliminarlos.
- **Puntos de Descubrimiento Ocultos:** Registra coordenadas de exploración en el mundo (`Keybind` o `/rpquest discovery`) con radio configurable (`Pequeño`, `Mediano`, `Grande`) sin mostrar spoilers en el mapa ni en la brújula.
- **Condición Opcional de Sigilo:** Permite exigir que los objetivos se completen sin ser detectado en combate.
- **Área de Búsqueda en el Mapa Mundial (`M`):** Dibuja un círculo aproximado (`ZO_PinBlob`) usando un offset aleatorio determinista y fijo: el objetivo siempre está dentro del círculo, pero nunca en el centro exacto. Desaparece automáticamente al completar o desactivar la misión.
- **Inyección de Diálogos en NPCs Nativos:** Asocia líneas de diálogo personalizadas y opciones de respuesta del jugador por NPC a NPCs nativos de ESO (mediante captura por retícula o nombre), inyectadas en la ventana de interacción nativa sin alterar las opciones originales del NPC.
- **Seguimiento en Combate, Exploración y Avisos Nativos:** Detecta bajas (`EVENT_COMBAT_EVENT`) y proximidad a puntos de descubrimiento, mostrando avisos `CENTER_SCREEN_ANNOUNCE` y sonidos oficiales (`SOUNDS.QUEST_COMPLETED`).
- **Mini-Tracker en el HUD:** Muestra la misión activa en pantalla (clic izquierdo abre el Diario; clic derecho centra el Mapa Mundial en el área de búsqueda).
- **Flujo 100% por Correo In-Game 1-a-1 (Sin Copiar/Pegar):**
  - Asigna un único destinatario (`@Cuenta`) (y opcionalmente el nombre del personaje **Para (Personaje)**) directamente en el editor de la misión preparada y envíala con un clic (dividiendo automáticamente misiones largas en hasta 6 correos / ~4.000 caracteres mediante `RPQP` sobre serialización interna `ShareCodec`; funciona dentro del mismo megaserver, p. ej. PC-NA con PC-NA o PC-EU con PC-EU). Los nombres de personaje `De:` y `Para:` se muestran debajo del estado en el detalle de la misión.
  - **Ingesta Automática en Pendientes:** Los correos de misión entrantes se importan automáticamente en la sección **Pendientes** del jugador con una alerta visible y botones de **Aceptar** / **Rechazar** directamente en el Diario.
  - **Reportes Automáticos de Completado y Rechazo:** Al completar o rechazar una misión recibida, RPQuest envía automáticamente el resultado (`RPQC1`) al Quest Master y actualiza el estado de la misión preparada (`Borrador` / `Enviada` / `Completada` / `Rechazada`).
- **Persistencia Account-Wide y Auto-Localización:** Guarda misiones y progreso a nivel de cuenta con `ZO_SavedVars:NewAccountWide` (alineado con el correo account-wide de ESO, con migración automática no destructiva desde datos por personaje) y detecta automáticamente el idioma del cliente (`es` / `en`).

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
   - Pulsa **Crear Misión**, usa las secciones colapsables del formulario para definir **Título**, **Descripción / Historia**, tamaño del **Área de búsqueda** (`Pequeña`, `Mediana`, `Grande`), opcionalmente activar **No ser detectado** y configurar líneas de **Diálogo de NPC**.
   - En el mundo, apunta a NPCs y usa el atajo **Capturar Objetivo** (`/rpquest capture`), o párate en un lugar y usa **Capturar Punto de Descubrimiento** (`/rpquest discovery`).
2. **Enviar al Jugador (Correo 1-a-1):**
   - Define el destinatario `@Cuenta` (y opcionalmente el personaje destinatario) en el editor de la misión y pulsa **Enviar Misión** desde el detalle de la misión preparada.
   - El jugador recibe una alerta y ve la misión en **Pendientes** dentro de su pestaña **RPQuest** para **Aceptar** o **Rechazar**.
   - **Mismo idioma requerido:** Las misiones deben jugarse en un cliente del juego con el mismo idioma que el creador para que coincidan los nombres de NPCs y diálogos.
3. **Jugar y Reporte Automático:**
   - Al aceptar la misión se activan inmediatamente el mini-tracker del HUD, el área en el Mapa Mundial y los diálogos inyectados en NPCs.
   - Al completar (o rechazar) la misión, RPQuest envía automáticamente el resultado por correo al Quest Master y actualiza su estado.

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
- **SavedVariables:** `RPQuest_SavedVariables` (por cuenta / account-wide)
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
│   ├── BinaryCodec.lua      # Primitivas binarias Base85, Base64Url, LZSS y Varint
│   ├── ShareCodec.lua       # Serialización de misiones/resultados RPQ3 / RPQ2 / RPQ1 y RPQC1
│   ├── MailInbox.lua        # Escaneo de bandeja, reensamblado RPQP e ingesta de correos
│   ├── MailTransport.lua    # Envío y recepción de misiones y reportes por correo in-game
│   ├── QuestDraftStore.lua  # Estado de borrador de creación y normalización de objetivos
│   ├── QuestRepository.lua  # CRUD account-wide, migración y cálculo de offset del círculo
│   ├── Announcements.lua    # Mensajes CENTER_SCREEN_ANNOUNCE y alertas
│   ├── TargetCapture.lua    # Captura de NPC bajo retícula y puntos de descubrimiento
│   ├── CombatTracker.lua    # Seguimiento de bajas y sigilo (EVENT_COMBAT_EVENT)
│   ├── DiscoveryTracker.lua # Sondeo de proximidad a puntos de descubrimiento ocultos
│   ├── DialogueInjector.lua # Inyección de diálogos en NPCs nativos
│   ├── WorldMapArea.lua     # Círculo de búsqueda nativo en ZO_WorldMap
│   ├── JournalWidgets.lua   # Helpers de widgets UI y formato reutilizables para JournalTab
│   ├── JournalDetailPane.lua# Panel de detalle de misión y actualización de acciones
│   ├── JournalEditorPane.lua# Panel editor multi-sección para misiones preparadas
│   ├── JournalMailSendPane.lua# Panel de envío por correo in-game y progreso de transporte
│   └── JournalTab.lua       # Coordinador de la pestaña en el Diario de Misiones
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

## Transparencia de IA y Créditos

- **Autor:** [JerbilX](https://github.com/JerbilX)
- **Uso de IA (AI Disclosure):** Durante el desarrollo se utilizaron asistentes de programación con IA para apoyar la redacción de código Lua, refactorización, localización, documentación y pruebas unitarias. Todo el diseño funcional, decisiones de arquitectura, pruebas dentro del juego y revisión final fueron dirigidos y verificados por el autor.

---

## Licencia

Este proyecto está licenciado bajo **GNU General Public License v3.0** — consulta [LICENSE](LICENSE) para más detalles.

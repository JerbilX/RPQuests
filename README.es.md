# RPQuest

[![Build](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml/badge.svg)](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml)
![Version](https://img.shields.io/badge/version-1.6.0-blue)
![ESO API](https://img.shields.io/badge/ESO%20API-101051-orange)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![Languages](https://img.shields.io/badge/i18n-EN%20%7C%20ES-informational)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

[English](README.md) | **Español**

Addon nativo y **sin dependencias externas** (`Zero-Dependency`) para **The Elder Scrolls Online** (`APIVersion: 101051`) que permite crear, jugar, completar y compartir **misiones personalizadas de rol (Roleplay / Custom Quests)** directamente dentro de la interfaz oficial del juego.

---

## Características Principales

- **Integración Nativa en el Diario (`J`):** Agrega la pestaña **RPQuest** dentro del Diario de Misiones (`ZO_QuestJournal_Keyboard`) con secciones en acordeón exclusivo para ofertas **Pendientes**, **Misiones** activas, **Completadas**, **Preparando** (borradores sin enviar) y **Enviadas** (contratos enviados con estado en vivo y resultados al completar).
- **Captura de NPCs bajo Retícula:** Apunta a cualquier NPC vivo y presiona tu atajo de **Capturar Objetivo bajo Retícula**. Capturar varias veces un mismo tipo de NPC se acumula automáticamente (ej. `Imp x3`); distintos NPCs con nombre se registran como objetivos individuales, con condiciones opcionales de ubicación (`Requerida` / `No requerida`), selector de objetivo `Opcional` (habilita completar manualmente la misión al cumplir los obligatorios) y mensajes personalizados al eliminarlos.
- **Puntos de Descubrimiento Ocultos:** Registra coordenadas de exploración en el mundo mediante tu atajo **Capturar Punto de Descubrimiento** con radio configurable (`Pequeño`, `Mediano`, `Grande`) sin mostrar spoilers en el mapa ni en la brújula.
- **Condición Opcional de Sigilo:** Permite exigir que los objetivos se completen sin ser detectado en combate.
- **Área de Búsqueda en el Mapa Mundial (`M`):** Dibuja un círculo aproximado (`ZO_PinBlob`) usando un offset aleatorio determinista y fijo: el objetivo siempre está dentro del círculo, pero nunca en el centro exacto. Desaparece automáticamente al completar o desactivar la misión.
- **Inyección de Diálogos en NPCs Nativos:** Asocia líneas de diálogo personalizadas y opciones de respuesta del jugador por NPC a NPCs nativos de ESO (mediante captura por retícula o nombre), inyectadas en la ventana de interacción nativa sin alterar las opciones originales del NPC.
- **Seguimiento en Combate, Exploración y Avisos Nativos:** Detecta bajas (`EVENT_COMBAT_EVENT`) y proximidad a puntos de descubrimiento, mostrando avisos `CENTER_SCREEN_ANNOUNCE` y sonidos oficiales (`SOUNDS.QUEST_COMPLETED`).
- **Mini-Tracker en el HUD:** Muestra la misión activa en pantalla (clic izquierdo abre el Diario; clic derecho centra el Mapa Mundial en el área de búsqueda).
- **Flujo 100% por Correo In-Game 1-a-1 (Sin Copiar/Pegar):**
  - Asigna un único destinatario (`@Cuenta`) (y opcionalmente el nombre del personaje **Para (Personaje)**) directamente en el editor de la misión preparada y envíala con un clic (dividiendo automáticamente misiones largas en hasta 6 correos / ~4.000 caracteres mediante `RPQP` sobre serialización interna `ShareCodec`; funciona dentro del mismo megaserver, p. ej. PC-NA con PC-NA o PC-EU con PC-EU). Los nombres de personaje `De:` y `Para:` se muestran debajo del estado en el detalle de la misión.
  - **Ingesta Automática en Pendientes:** Los correos de misión entrantes se importan automáticamente en la sección **Pendientes** del jugador con una alerta visible y botones de **Aceptar** / **Rechazar** directamente en el Diario.
  - **Reportes Automáticos de Aceptación, Completado y Rechazo:** Al aceptar, completar o rechazar una misión recibida, RPQuest envía automáticamente el resultado (`RPQC1`) al Quest Master y actualiza el estado de la misión preparada (`Borrador` / `Enviada` / `Aceptada` / `Completada` / `Rechazada`).
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
   - Abre el Diario de Misiones (`J`) y entra en la pestaña **RPQuest** (o pulsa tu atajo **Abrir / Cerrar Pestaña RPQuest**).
   - Pulsa **Crear Misión**, usa las secciones colapsables del formulario para definir **Título**, **Descripción / Historia**, tamaño del **Área de búsqueda** (`Pequeña`, `Mediana`, `Grande`), opcionalmente activar **No ser detectado** y configurar líneas de **Diálogo de NPC**.
   - En el mundo, apunta a NPCs y usa el atajo **Capturar Objetivo**, o párate en un lugar y usa **Capturar Punto de Descubrimiento**.
2. **Enviar al Jugador (Correo 1-a-1):**
   - Define el destinatario `@Cuenta` (y opcionalmente el personaje destinatario) en el editor de la misión y pulsa **Enviar Misión** desde el detalle de la misión preparada.
   - El jugador recibe una alerta y ve la misión en **Pendientes** dentro de su pestaña **RPQuest** para **Aceptar** o **Rechazar**.
   - **Mismo idioma requerido:** Las misiones deben jugarse en un cliente del juego con el mismo idioma que el creador para que coincidan los nombres de NPCs y diálogos.
3. **Jugar y Reporte Automático:**
   - Al aceptar la misión se activan inmediatamente el mini-tracker del HUD, el área en el Mapa Mundial y los diálogos inyectados en NPCs.
   - Al aceptar, completar o rechazar la misión, RPQuest envía automáticamente el resultado por correo al Quest Master, moviendo el contrato a la sección **Enviadas** con su estado en vivo (`Enviada`, `Aceptada`, `Rechazada`, `Completada`) y resultados de finalización (como `No detectado` frente a `Detectado` y objetivos opcionales).

---

## Guía de Uso

### 1. Roles: Quest Master vs. Jugador
- **Quest Master (Creador):** Redacta misiones personalizadas en **Preparando**, captura objetivos NPC o puntos de descubrimiento en el mundo, configura reglas opcionales o diálogos y envía contratos por correo in-game. Una vez enviados, sigue su estado en vivo y los resultados finales en **Enviadas**.
- **Jugador (Destinatario):** Recibe ofertas de misión en **Pendientes**, revisa la descripción y elige **Aceptar** o **Rechazar**. Las misiones activas se siguen automáticamente en el mundo y los resultados se envían por correo de vuelta al Quest Master sin copiar ni pegar nada.

### 2. Secciones del Diario (Acordeón Exclusivo)
La pestaña **RPQuest** dentro del Diario de Misiones (`J`) usa un acordeón exclusivo: al expandir una sección, las demás se colapsan para mantener la lista ordenada:
- **Pendientes:** Ofertas entrantes esperando que las **Aceptes** o **Rechaces**.
- **Misiones:** Tus misiones aceptadas y activas. Selecciona una misión para ver objetivos, activar/desactivar el seguimiento o completarla manualmente cuando todos los objetivos obligatorios estén cumplidos.
- **Completadas:** Archivo de las misiones que ya terminaste, incluyendo el resultado final de sigilo y objetivos opcionales.
- **Preparando:** Borradores de misiones sin enviar que estás creando o editando como Quest Master.
- **Enviadas:** Contratos que ya enviaste por correo a jugadores, mostrando su estado en vivo (`Enviada`, `Aceptada`, `Rechazada`, `Completada`) y los resultados automáticos al finalizar (como `No detectado` frente a `Detectado` y objetivos opcionales).

### 3. Bloques de Construcción de Misiones
- **Objetivos (Eliminación de NPCs):** Apunta a cualquier NPC vivo y pulsa tu atajo de **Capturar Objetivo bajo Retícula**. Capturar varias veces un mismo nombre de NPC se acumula (ej. `Imp x3`); distintos NPCs con nombre se registran como objetivos separados. Para cada objetivo puedes alternar una condición de **Ubicación** (`Requerida` en la zona/subzona capturada o `No requerida`), añadir un mensaje personalizado al eliminarlo o marcarlo como **Opcional** (permitiendo completar la misión cuando todos los obligatorios estén listos).
- **Puntos de Descubrimiento Ocultos:** Párate en un punto de exploración y pulsa tu atajo de **Capturar Punto de Descubrimiento**. Puedes configurar el radio de detección (`Pequeño`, `Mediano` o `Grande`). Los puntos permanecen ocultos en el mapa y la brújula para evitar spoilers.
- **Sigilo (`No detectado`):** Activa **No detectado (Opcional)** en el editor para desafiar al jugador a completar la misión sin ser detectado en combate. La misión registra si permaneció `No detectado` o fue `Detectado` y lo reporta al Quest Master.
- **Área de Búsqueda en el Mapa Mundial (`M`):** Muestra un círculo aproximado en el Mapa Mundial usando un desplazamiento aleatorio fijo para que el objetivo quede dentro del círculo sin revelar su centro exacto. El círculo desaparece automáticamente al completar o desactivar la misión.
- **Diálogos de NPC:** Abre diálogo (`E`) con hasta 3 NPCs nativos de ESO para capturarlos en la sección **Diálogos de NPC** de la misión y redacta una opción de respuesta del jugador y la réplica del NPC para cada uno. Cuando el jugador hable con esos NPCs, tu línea personalizada se inyectará de forma nativa sin modificar las opciones originales del juego.

### 4. Flujo por Correo In-Game (Automático)
- **Envío:** Ingresa la `@Cuenta` destinataria (y opcionalmente el nombre del personaje) en el editor de la misión y pulsa **Enviar Misión**. Ambos jugadores deben estar en el mismo megaserver (ej. PC-NA o PC-EU) y usar el mismo idioma de cliente. Las misiones largas se dividen automáticamente en hasta 6 partes (`RPQP`) y se reensamblan al llegar.
- **Aviso de Llegada:** Cuando llega un correo de misión, RPQuest lo importa automáticamente y muestra un aviso en pantalla alertando al jugador de que tiene una nueva misión en **Pendientes**.
- **Aceptar y Rechazar:** Pulsar **Aceptar** activa la misión, el mini-tracker del HUD, el área en el Mapa Mundial y los diálogos de NPC, y notifica al Quest Master. Pulsar **Rechazar** declina la oferta y avisa al Quest Master.
- **Reporte de Finalización:** Cuando el jugador completa todos los objetivos (o completa manualmente una misión con solo objetivos opcionales pendientes), RPQuest envía automáticamente el reporte (`RPQC1`) al Quest Master y actualiza el contrato en **Enviadas**.

---

## Controles (`Ajustes -> Controles -> RPQuest`)

| Acción | Descripción |
| :--- | :--- |
| **Capturar Objetivo bajo Retícula** | Registra el NPC vivo apuntado con la retícula en el borrador de la misión. |
| **Capturar Punto de Descubrimiento** | Registra tu posición actual como un objetivo de descubrimiento oculto. |
| **Abrir / Cerrar Pestaña RPQuest** | Abre o cierra el Diario directamente en la pestaña de **RPQuest**. |

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
│   ├── ShareCodec.lua       # Serialización de misiones/resultados RPQ3 y RPQC1
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

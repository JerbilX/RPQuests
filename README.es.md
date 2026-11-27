# RPQuest

[![Build](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml/badge.svg)](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml)
![Version](https://img.shields.io/badge/version-1.12.0-blue)
![ESO API](https://img.shields.io/badge/ESO%20API-101051-orange)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![Languages](https://img.shields.io/badge/i18n-EN%20%7C%20DE%20%7C%20ES%20%7C%20FR%20%7C%20JP%20%7C%20RU%20%7C%20ZH-informational)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Q7W02BAKN7)

[English](README.md) | **Español**

Addon nativo y **sin dependencias externas** (`Zero-Dependency`) para **The Elder Scrolls Online** (`APIVersion: 101051`) que permite crear, jugar, completar y compartir **misiones personalizadas de rol (Roleplay / Custom Quests)** directamente dentro de la interfaz oficial del juego.

---

## Características Principales

- **Integración Nativa en el Diario (`J`):** Agrega la pestaña **RPQuests** dentro del Diario de Misiones (`QUEST_JOURNAL_KEYBOARD`) con secciones en acordeón exclusivo para ofertas **Pendientes**, **Misiones** activas, **Completadas**, **Preparando** (borradores sin enviar) y **Enviadas** (contratos enviados con estado en vivo y resultados al completar) —manteniendo siempre una sección activa expandida cuando existen misiones y recordando la última sección abierta y misión seleccionada entre sesiones—, además de los atajos nativos del Diario para **Mostrar en mapa** y **Abandonar**.
- **Captura de NPCs y Jugadores para Duelo bajo Retícula:** Apunta a cualquier NPC vivo (u otro jugador para un objetivo de duelo) y presiona tu atajo **Seleccionar Objetivo bajo Retícula (NPC)**. Capturar varias veces un mismo objetivo se acumula automáticamente (ej. `Imp x3` o `Jugador (Duelo) x2`); distintos objetivos se gestionan individualmente desde el selector desplegable de objetivos en el editor (con botones para eliminar el objetivo o todos), **Tamaño del área en el mapa** por objetivo (`Diminuta` / `Pequeña` / `Mediana` / `Grande` / `Enorme`), casilla **Objetivo opcional** (habilita completar manualmente la misión al cumplir los obligatorios), sección **Ubicación** por objetivo (**Requerida** dentro de `Diminuta` / `Pequeña` / `Mediana` / `Grande` / `Enorme` (`8m` / `23m` / `39m` / `54m` / `70m`) u opcional —eliminar un objetivo con ubicación **Requerida** fuera de su radio marca la misión como `Fallida`), y dos campos opcionales de mensaje (**Al eliminar objetivo** y **Al cumplir ubicación**).
- **Puntos de Descubrimiento Ocultos:** Párate en un lugar de exploración y pulsa el botón de icono **+** (**Agregar punto**) en el acordeón **Puntos de Descubrimiento Ocultos (Opcional)** del editor con un selector desplegable de radio (`Diminuta` / `Pequeña` / `Mediana` / `Grande` / `Enorme` — `8m`, `23m`, `39m`, `54m`, `70m`), casilla **Obligatorio** por punto (`[Req]` en el selector), botones de flecha arriba/abajo para reordenar puntos, casilla **Orden secuencial (desbloquear puntos uno a uno)** (que evalúa y muestra en el mapa cada punto del jugador en orden tras descubrir el anterior, mientras los creadores siguen viendo todos) y un **Mensaje del Punto de Descubrimiento** obligatorio. Los creadores ven automáticamente áreas púrpura en el mapa (con índice y resumen del mensaje en el tooltip), mientras que para el jugador permanecen ocultas por defecto con la casilla opcional sin spoilers **Descubrimiento** en **MARCAS DEL MAPA**.
- **Condición de Sigilo (Desactivado / Opcional / Obligatorio) y Mensaje al Completar:** Elige mediante un menú desplegable si no ser detectado por el sistema de Justicia (sin recompensa, infamia ni robo fallido dentro del área de misión) está **Desactivado**, es **Opcional** (registra la detección sin fallar) u **Obligatorio** (falla la misión inmediatamente si te detectan), y configura opcionalmente un **Mensaje al completar (Opcional)** mostrado al finalizar.
- **Iconos de Misión:** Asigna opcionalmente un icono (**Mano Negra**, **Buscar** o **Robar**) en el editor de misiones para identificar visualmente la temática en la lista del diario, el detalle y las misiones compartidas.
- **Áreas de Búsqueda, Ubicación y Descubrimiento en el Mapa Mundial (`M`):** Soporta círculos de búsqueda verde esmeralda por objetivo en el Mapa Mundial (`ZO_WorldMap_GetPinManager():AddCustomPin`) con pulso inicial breve, offset aleatorio determinista y fijo, y escalado automático en mapas de ciudad o subzona, círculos naranja suave opcionales de ubicación capturada (ambas capas desaparecen individualmente al completar cada objetivo) y círculos púrpura para puntos de descubrimiento (visibles automáticamente para el creador en Edición/Preparando/Enviadas y ocultos por defecto para el jugador, desapareciendo cada punto al ser descubierto). En el acordeón de **Ajustes de la Misión** del editor, **Recomendar al jugador no mostrar marcas en el mapa** (activado por defecto en borradores nuevos) muestra **Mostrar marcas en el mapa: no recomendado** dentro de **DETALLES DE LA MISIÓN**; para el jugador, la sección **MARCAS DEL MAPA** muestra las casillas aplicables (**Áreas de búsqueda**, **Ubicación** y **Descubrimiento**, apagadas por defecto) para controlarlas de forma independiente por misión (**Mostrar en mapa** sigue disponible siempre que haya un mapa/área definida). Al alejar el zoom hacia una zona padre o el mapa de Tamriel, muestra un área de referencia mediana en verde esmeralda con pulso inicial y desplazamiento determinista (manteniendo el objetivo dentro sin revelar su punto exacto) y se oculta automáticamente al volver al mapa del objetivo o al completar/desactivar la misión.
- **Inyección de Diálogos en NPCs Nativos y Objetivos:** Abre diálogo (`E`) con hasta 4 NPCs nativos de ESO y pulsa **+ Último NPC** en el editor para asociar líneas de diálogo personalizadas, opciones de respuesta del jugador por NPC y una casilla opcional **Obligatorio** por NPC (`[Req]`), inyectadas en la ventana de interacción nativa sin alterar las opciones originales del NPC. La ejecución del diálogo persiste entre recargas en SavedVariables, muestra progreso sin spoilers en **OBJETIVOS** y completa automáticamente las misiones solo de diálogo (`0` objetivos de combate, `0` descubrimientos, `>= 1` diálogos) al hablar con todos los NPCs configurados.
- **Seguimiento en Combate, Duelos, Exploración y Avisos Nativos:** Detecta bajas (`EVENT_COMBAT_EVENT`), victorias en duelo (`EVENT_DUEL_FINISHED`) y proximidad a puntos de descubrimiento, mostrando avisos `CENTER_SCREEN_ANNOUNCE` y sonidos oficiales (`SOUNDS.QUEST_COMPLETED`), además de un **brillo dorado/ámbar en el borde de la brújula** (`ZO_Compass`) al estar dentro del área de búsqueda o ubicación exacta de un objetivo pendiente de la misión activa (independientemente de los toggles del mapa y excluyendo puntos de descubrimiento ocultos).
- **Pruebas Locales para Quest Master, Reinicio y Migración:** Prueba cualquier misión en **Preparando** o **Enviadas** localmente con **Probar** / **Dejar de probar**, reinicia una misión preparada, `Fallida` o tutorial con **Reiniciar**, o actualiza esquemas antiguos con **Migrar**.
- **Paquete Tutorial Progresivo Integrado (Daggerfall):** Quienes instalan el addon por primera vez comienzan con **Tutorial I** en **Pendientes** (diálogo pacífico junto a la ermita de Daggerfall), desbloqueando **Tutorial II** (rastro secuencial + sigilo opcional) y **Tutorial III** (contrato de combate obligatorio + opcional) uno a uno al completar cada paso. Los tres son totalmente opcionales (no se re-inyectan si se abandonan o eliminan, ni envían correos) y pueden clonarse en **Preparando** con **Copiar** como plantillas editables o rejugarse con **Reiniciar**.
- **Flujo 100% por Correo In-Game 1-a-1 (Sin Copiar/Pegar):**
  - Asigna un único destinatario (`@Cuenta`) (y opcionalmente **Para (Personaje)** o el selector **De (Personaje)** entre los personajes de tu cuenta) en el editor de la misión preparada y pulsa **Enviar Misión** desde el detalle de la misión —enviando directamente si ya hay `@Cuenta` configurada en el editor, o abriendo el panel de envío por correo con un **Mensaje de Roleplay opcional** y contador en vivo de 1–6 partes mediante `RPQP` sobre `ShareCodec` si no hay destinatario (funciona dentro del mismo megaserver, p. ej. PC-NA con PC-NA, y ESO impide enviarse correos a la propia cuenta). Los nombres de personaje `De:` y `Para:` se muestran debajo de `Estado:` en el detalle de la misión (conservando el personaje remitente elegido al recibir el correo).
  - **Ingesta Automática en Pendientes:** Los correos de misión entrantes se importan automáticamente en la sección **Pendientes** del jugador con una alerta visible y botones de **Aceptar** / **Rechazar** directamente en el Diario (los correos en idioma incompatible se rechazan automáticamente con una alerta de error).
  - **Reportes Automáticos de Aceptación, Completado, Fallo y Rechazo:** Al aceptar, completar, fallar o rechazar una misión recibida, RPQuest envía automáticamente el resultado (`RPQC1`) al Quest Master y actualiza la resolución de la misión `Enviada` (`Aceptada` / `Completada` / `Fallida` / `Rechazada`) manteniendo separado su ciclo de vida (`Borrador` / `Enviada` / `Recibida`).
- **Persistencia Account-Wide y Auto-Localización:** Guarda misiones, progreso, la última sección abierta y la misión seleccionada a nivel de cuenta con `ZO_SavedVars:NewAccountWide` (alineado con el correo account-wide de ESO, con migración automática no destructiva desde datos por personaje) y detecta automáticamente los 7 idiomas oficiales del cliente de ESO (`en`, `de`, `es`, `fr`, `jp`, `ru`, `zh`).

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
   - Abre el Diario de Misiones (`J`) y entra en la pestaña **RPQuests** (o pulsa tu atajo **Abrir / Cerrar Pestaña de Misiones Custom**).
   - Pulsa **+ Nueva** (lo que crea inmediatamente un borrador **Nueva Misión** en **Preparando** y lo abre en el editor), usa las secciones en acordeón animado exclusivo del formulario (con navegación entre campos mediante `Tab` / `Shift+Tab`) para definir **Título**, **Descripción / Trasfondo:**, **Icono de la Misión** (*Ninguno*, *Mano Negra*, *Buscar* o *Robar*), **Tamaño del área en el mapa** por objetivo, **Objetivo opcional**, **Ubicación** y los mensajes opcionales **Al eliminar objetivo** / **Al cumplir ubicación** en **Objetivo (NPC) y Área de Búsqueda**, además de **Mensaje al completar (Opcional)**, **Condición de Sigilo** (`Desactivado`, `Opcional` u `Obligatorio`) y **Recomendar al jugador no mostrar marcas en el mapa** en **Ajustes de la Misión**, y líneas de **Diálogos con NPCs**.
   - En el mundo, apunta a NPCs y usa el atajo **Seleccionar Objetivo bajo Retícula (NPC)**, o párate en un lugar y pulsa el botón de icono **+** (**Agregar punto**) en **Puntos de Descubrimiento Ocultos (Opcional)** (cada punto requiere un **Mensaje del Punto de Descubrimiento**). Los cambios en curso se conservan automáticamente al cambiar de misión o cerrar el diario, o pulsa **Guardar Borrador** para guardar y finalizar la edición (las misiones *free-form* o solo con diálogos sin objetivos NPC ni puntos de descubrimiento también pueden probarse y enviarse; usa **Abandonar** en la barra inferior de atajos para eliminar un borrador).
2. **Enviar al Jugador (Correo 1-a-1):**
   - Define el destinatario `@Cuenta` (y opcionalmente **Para (Personaje)**) en el editor, guarda la misión y pulsa **Enviar Misión** desde el detalle de la misión preparada.
   - El jugador recibe una alerta y ve la misión en **Pendientes** dentro de su pestaña **RPQuests** para **Aceptar** o **Rechazar**.
   - **Mismo idioma requerido:** Las misiones deben jugarse en un cliente del juego con el mismo idioma que el creador para que coincidan los nombres de NPCs y diálogos; los correos con idioma incompatible se rechazan automáticamente.
3. **Jugar y Reporte Automático:**
   - Al aceptar la misión se activan inmediatamente el seguimiento y los diálogos inyectados en NPCs; las marcas en el mapa permanecen apagadas por defecto y pueden activarse de forma independiente por misión en **MARCAS DEL MAPA** (**Áreas de búsqueda** / **Ubicación** / **Descubrimiento**).
   - Al aceptar, completar, fallar o rechazar la misión, RPQuest envía automáticamente el resultado por correo al Quest Master, manteniendo el contrato en **Enviadas** con su resolución en vivo (`Enviada`, `Aceptada`, `Rechazada`, `Completada`, `Fallida`) y resultados de finalización/fallo (como `No detectado` frente a `Detectado` y objetivos opcionales).

---

## Guía de Uso

### 1. Roles: Quest Master vs. Jugador
- **Quest Master (Creador):** Redacta misiones personalizadas en **Preparando**, captura objetivos NPC o puntos de descubrimiento en el mundo, las prueba localmente con **Probar**, configura reglas opcionales o diálogos y envía contratos por correo in-game. Una vez enviados, sigue su estado en vivo y los resultados finales en **Enviadas**.
- **Jugador (Destinatario):** Recibe ofertas de misión en **Pendientes**, revisa la descripción y elige **Aceptar** o **Rechazar**. Las misiones activas se siguen automáticamente en el mundo y los resultados se envían por correo de vuelta al Quest Master sin copiar ni pegar nada.

### 2. Secciones del Diario (Acordeón Exclusivo)
La pestaña **RPQuests** dentro del Diario de Misiones (`J`) usa un acordeón exclusivo: al expandir una sección, las demás se colapsan para mantener la lista ordenada (una sección activa permanece siempre expandida mientras existan misiones, y la última sección abierta y misión seleccionada se conservan entre sesiones):
- **Pendientes:** Ofertas entrantes esperando que las **Aceptes** o **Rechaces**.
- **Misiones:** Tus misiones aceptadas y activas (incluyendo misiones `Fallidas` que pueden reiniciarse con **Reiniciar**). Selecciona una misión para ver **DETALLES DE LA MISIÓN** y **TAREAS**, alternar las casillas aplicables de **MARCAS DEL MAPA** (**Áreas de búsqueda** / **Ubicación** / **Descubrimiento**), activar/desactivar el seguimiento, ir al mapa (**Mostrar en mapa**), **Abandonar** o completarla manualmente con **Completar** (en misiones *free-form* puras sin objetivos/descubrimientos/diálogos o cuando los objetivos obligatorios estén cumplidos; omitir un descubrimiento o diálogo **Obligatorio** al resolver falla la misión).
- **Completadas:** Archivo de las misiones que ya terminaste, incluyendo el resultado final de sigilo y objetivos opcionales.
- **Preparando:** Borradores de misiones sin enviar que estás creando o editando como Quest Master. También puedes copiar cualquier misión de **Preparando** o **Enviadas** hacia **Preparando** para crear un nuevo borrador editable, probarla localmente (**Probar**) o actualizar esquemas antiguos (**Migrar**).
- **Enviadas:** Contratos que ya enviaste por correo a jugadores, mostrando `De:` / `Para:`, su ciclo de vida y resolución en vivo (`Enviada`, `Aceptada`, `Rechazada`, `Completada`, `Fallida`) y los resultados automáticos al finalizar o fallar (como `No detectado` frente a `Detectado` y objetivos opcionales).

### 3. Bloques de Construcción de Misiones
- **Objetivos (Eliminación de NPCs y Duelos con Jugadores):** Apunta a cualquier NPC vivo o a otro jugador y pulsa tu atajo **Seleccionar Objetivo bajo Retícula (NPC)**. Los jugadores se registran como objetivos de duelo (`EVENT_DUEL_FINISHED`, contabilizando victorias locales y rendiciones del oponente e ignorando derrotas). Capturar varias veces un mismo nombre se acumula (ej. `Imp x3`); distintos objetivos se gestionan desde el selector desplegable de objetivos (con botones para eliminar el objetivo seleccionado o todos). Para cada objetivo puedes definir **Tamaño del área en el mapa** (`Diminuta` / `Pequeña` / `Mediana` / `Grande` / `Enorme`), marcar la casilla **Objetivo opcional** (permitiendo completar la misión cuando todos los obligatorios estén listos), configurar **Ubicación** (**Capturar Ubic.**, radio `Diminuta` / `Pequeña` / `Mediana` / `Grande` / `Enorme` (`8m` / `23m` / `39m` / `54m` / `70m`) y casilla **Requerida** —desmarcada es opcional/en cualquier lugar, marcada falla la misión si se elimina fuera del radio), y escribir mensajes opcionales **Al eliminar objetivo** y **Al cumplir ubicación**.
- **Puntos de Descubrimiento Ocultos:** Párate en un punto de exploración y pulsa el botón de icono **+** (**Agregar punto**) en el acordeón **Puntos de Descubrimiento Ocultos (Opcional)**. Puedes configurar el radio de detección (`Diminuta` / `Pequeña` / `Mediana` / `Grande` / `Enorme` — `8m`, `23m`, `39m`, `54m` o `70m`), marcar puntos como **Obligatorio** (`[Req]`), reordenarlos con los botones de flecha arriba/abajo, activar **Orden secuencial (desbloquear puntos uno a uno)** para que los puntos bloqueados queden ocultos e inactivos hasta descubrir el anterior, y debes escribir un **Mensaje del Punto de Descubrimiento** antes de guardar, probar o enviar. Los puntos permanecen ocultos en el mapa y la brújula por defecto para el jugador para evitar spoilers (los creadores ven las áreas de descubrimiento en púrpura automáticamente y los jugadores pueden activar **Descubrimiento** en **MARCAS DEL MAPA**).
- **Sigilo (`No detectado`) y Mensaje al Completar:** Usa el selector **Condición de Sigilo** en el editor (`Desactivado`, `Opcional` u `Obligatorio`) para registrar el sigilo como objetivo secundario o hacer que la misión falle inmediatamente al ser detectado, y añade opcionalmente un **Mensaje al completar (Opcional)**.
- **Áreas de Búsqueda, Ubicación y Descubrimiento en el Mapa Mundial (`M`):** Muestra círculos aproximados de búsqueda por objetivo usando un desplazamiento aleatorio fijo (con escalado automático en mapas de ciudad o subzona) y círculos naranja suave opcionales de ubicación capturada; los círculos desaparecen por objetivo al completar cada uno (así como al completar o desactivar la misión). Las tres capas (Áreas de búsqueda, Ubicación y Descubrimiento) están apagadas por defecto para el jugador y pueden activarse de forma independiente por misión en **MARCAS DEL MAPA** (mientras que **Mostrar marcas en el mapa: no recomendado** aparece en **DETALLES DE LA MISIÓN** si el Master marcó **Recomendar al jugador no mostrar marcas en el mapa**); **Mostrar en mapa** (**M**) permanece disponible siempre que haya mapa/área definida.
- **Diálogos con NPCs:** Abre diálogo (`E`) con hasta 4 NPCs nativos de ESO y pulsa **+ Último NPC** para capturarlos en la sección **Diálogos con NPCs** de la misión, marca opcionalmente cada diálogo como **Obligatorio** (`[Req]`) y redacta una opción de respuesta del jugador y la réplica del NPC para cada uno. Cuando el jugador hable con esos NPCs, tu línea personalizada se inyectará de forma nativa sin modificar las opciones originales del juego; el progreso persiste entre recargas, se muestra en **OBJETIVOS** y las misiones solo de diálogo se completan automáticamente al ejecutarlos todos.

### 4. Flujo por Correo In-Game (Automático)
- **Envío:** Ingresa la `@Cuenta` destinataria (y opcionalmente **Para (Personaje)**) en el editor, guarda y pulsa **Enviar Misión** en el detalle de la misión. Cuando `@Cuenta` ya está configurada en el editor, pulsar **Enviar Misión** envía directamente; si no hay destinatario, se abre el panel de envío por correo con un campo de **Mensaje de Roleplay opcional** y contador en vivo de partes (1–6 partes mediante `RPQP`). Ambos jugadores deben estar en el mismo megaserver (ej. PC-NA o PC-EU) y usar el mismo idioma de cliente, y ESO impide enviarse correos a la propia cuenta.
- **Aviso de Llegada y Apertura Automática:** Cuando llega un correo de misión, RPQuest lo importa automáticamente y muestra un aviso en pantalla alertando al jugador de que tiene una nueva misión en **Pendientes** (o lo rechaza con alerta de error si el idioma no coincide con el cliente). Por defecto, **Abrir automáticamente el diario RPQuests al recibir una misión nueva** está activado para abrir la pestaña **RPQuests** y seleccionar la misión recién recibida (se omite si estás en combate), y puede desactivarse en la parte inferior del panel de la lista de misiones.
- **Aceptar y Rechazar:** Pulsar **Aceptar** activa la misión y los diálogos de NPC (las marcas del mapa permanecen desactivadas por defecto hasta activarlas en el detalle), y notifica al Quest Master. Pulsar **Rechazar** declina la oferta y avisa al Quest Master.
- **Reporte de Finalización y Fallo:** Cuando el jugador completa todos los objetivos (o completa manualmente una misión *free-form* o con solo objetivos opcionales pendientes) o falla una condición obligatoria (como sigilo, ubicación o un descubrimiento/diálogo **Obligatorio** omitido al resolver), RPQuest envía automáticamente el reporte (`RPQC1`) al Quest Master y actualiza la resolución del contrato en **Enviadas**.
- **Sincronización de Perfil de Mundo:** Pulsa **Compartir Perfil de Mundo** en la parte superior de la lista de misiones para enviar tu snapshot compacto (`RPQW1`) de DLCs de `@Cuenta` y POIs descubiertos del `Personaje` a un `@Master`; los reportes de aceptación y finalización también adjuntan el perfil actualizado silenciosamente si cabe en el límite de 700 caracteres.

---

## Controles (`Ajustes -> Controles -> RPQuest - Misiones Personalizadas`)

| Acción | Descripción |
| :--- | :--- |
| **Seleccionar Objetivo bajo Retícula (NPC)** | Registra el NPC vivo apuntado con la retícula en el borrador de la misión. |
| **Abrir / Cerrar Pestaña de Misiones Custom** | Abre o cierra el Diario directamente en la pestaña de **RPQuests**. |

---

## Requisitos y Compatibilidad

- **Versión del Juego:** The Elder Scrolls Online (`APIVersion: 101051`)
- **Librerías Externas:** Ninguna (`Zero-Dependency`)
- **SavedVariables:** `RPQuest_SavedVariables` (por cuenta / account-wide)
- **Idiomas Soportados:** Inglés (`en`), Alemán (`de`), Español (`es`), Francés (`fr`), Japonés (`jp`), Ruso (`ru`), Chino Simplificado (`zh`)

---

## Estructura del Proyecto y Desarrollo

```text
RPQuest/
├── RPQuest.txt                  # Manifiesto oficial para ESO
├── RPQuest.lua                  # Punto de entrada y ciclo EVENT_ADD_ON_LOADED
├── Bindings.xml                 # Definición de atajos de teclado nativos
├── readme.txt                   # Readme de texto plano para el paquete ESOUI
├── LICENSE                      # Licencia GNU General Public License v3.0
├── lang/
│   ├── en.lua                   # Diccionario en Inglés (Base / Fallback)
│   ├── de.lua                   # Diccionario en Alemán
│   ├── es.lua                   # Diccionario en Castellano
│   ├── fr.lua                   # Diccionario en Francés
│   ├── jp.lua                   # Diccionario en Japonés
│   ├── ru.lua                   # Diccionario en Ruso
│   └── zh.lua                   # Diccionario en Chino Simplificado
├── src/
│   ├── Constants.lua            # Constantes, radios y metadatos
│   ├── Locale.lua               # Selector de idioma del cliente e i18n
│   ├── BinaryCodec.lua          # Primitivas binarias Base85, Base64Url, LZSS y Varint
│   ├── ShareCodec.lua           # Serialización de misiones/resultados/perfil RPQ3, RPQC1 y RPQW1
│   ├── WorldProfile.lua         # Escáner y códec de bitmask de DLCs por cuenta y POIs por personaje
│   ├── MailInbox.lua            # Escaneo de bandeja, reensamblado RPQP e ingesta de correos
│   ├── MailTransport.lua        # Envío y recepción de misiones y reportes por correo in-game
│   ├── QuestDraftStore.lua      # Estado de borrador de creación y normalización de objetivos
│   ├── QuestMigration.lua       # Migración no destructiva de SavedVars y esquemas de misiones
│   ├── QuestRepository.lua      # CRUD account-wide, almacenamiento y seguimiento en runtime
│   ├── TutorialQuest.lua        # Paquete tutorial progresivo de 3 misiones en Daggerfall
│   ├── Announcements.lua        # Mensajes CENTER_SCREEN_ANNOUNCE y alertas
│   ├── TargetCapture.lua        # Captura de NPC bajo retícula y puntos de descubrimiento
│   ├── CombatTracker.lua        # Seguimiento de bajas y sigilo (EVENT_COMBAT_EVENT)
│   ├── DiscoveryTracker.lua     # Sondeo de proximidad a puntos de descubrimiento ocultos
│   ├── DialogueInjector.lua     # Inyección de diálogos en NPCs nativos
│   ├── WorldMapArea.lua         # Áreas de búsqueda y zoom-out verde esmeralda, círculos de ubicación naranja y descubrimiento púrpura en ZO_WorldMap
│   ├── CompassAreaGlow.lua      # Brillo dorado/ámbar en el borde de la brújula dentro de áreas activas
│   ├── JournalWidgets.lua       # Helpers de widgets UI y formato reutilizables para JournalTab
│   ├── JournalDetailPane.lua    # Panel de detalle de misión y actualización de acciones
│   ├── JournalEditorSections.lua# Constructores de secciones acordeón y campos del editor
│   ├── JournalEditorPane.lua    # Panel editor multi-sección: layout y actualización
│   ├── JournalMailSendPane.lua  # Panel de envío por correo in-game y progreso de transporte
│   └── JournalTab.lua           # Coordinador de la pestaña en el Diario de Misiones
├── scripts/
│   ├── bump-version.sh          # Incremento sincronizado de versión SemVer
│   ├── check-esoui.sh           # Validación de cumplimiento ESOUI y términos retirados
│   └── package.sh               # Empaquetado ZIP limpio
├── docs/
│   ├── esoui-description.bbcode # Descripción BBCode para la página de ESOUI
│   ├── roadmap-references.md    # Notas de referencia de UX y funcionalidades
│   └── adr/                     # Registros de Decisiones de Arquitectura (MADR)
└── tests/
    ├── run.lua                  # Ejecutor de pruebas unitarias herméticas (LuaJIT)
    ├── mocks/                   # Mocks de EsoUI
    └── suites/                  # Suites modulares de pruebas unitarias
```

### Ejecutar Pruebas Unitarias
```bash
luajit tests/run.lua
./scripts/check-esoui.sh
```

---

## Transparencia de IA y Créditos

- **Autor:** [JerbilX](https://github.com/JerbilX)
- **Uso de IA (AI Disclosure):** Durante el desarrollo se utilizaron asistentes de programación con IA para apoyar la redacción de código Lua, refactorización, localización, documentación y pruebas unitarias. Todo el diseño funcional, decisiones de arquitectura, pruebas dentro del juego y revisión final fueron dirigidos y verificados por el autor.
- **Soporte:** [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Q7W02BAKN7)

---

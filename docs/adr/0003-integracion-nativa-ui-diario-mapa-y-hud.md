---
status: accepted
date: 2026-11-18
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0003 - Integración Nativa de UI: Pestaña en Diario, Área en Mapa Mundial y HUD Tracker

## Contexto y Planteamiento del Problema
El usuario requiere que:
1. La lista de misiones custom y todas sus operaciones (Crear, Editar, Importar código, Compartir código, Reiniciar, Eliminar) se muestren dentro de la misma ventana de las misiones estándar de ESO, pero en su propia pestaña.
2. Al tener una misión activa, aparezca en el mapa una marca de área grande como si fuera una misión del juego (para buscar al objetivo en esa ubicación sin marcar su punto exacto), ocultándose al completarse o desactivarse.
3. Exista feedback visual/auditivo al progresar y completar la misión (`CENTER_SCREEN_ANNOUNCE` + sonidos nativos) y un pequeño tracker en el HUD para la misión activa.
4. No se implemente lógica en la brújula superior (*compass*) para evitar los problemas visuales de templates internos C++.

## Impulsores de la Decisión (Decision Drivers)
* **Integración No Destructiva en el Diario (`ZO_QuestJournal_Keyboard`):** Uso de `ZO_SceneFragmentBar` (`QUEST_JOURNAL_KEYBOARD.tabs:Add(...)`) y `ZO_PostHook` en `OnShowing` sin romper las pestañas nativas (`Quests` y `Rumors`).
* **Renderizado Nativo de Área en `ZO_WorldMap`:** Uso del sistema nativo de pines de área de `ZO_WorldMapPins_Manager` (`ZO_PinBlob` con shader `HALO`) sin icono puntual en el centro (`texture = ""`, `showsPinAndArea = false`), logrando el círculo translúcido exacto de las misiones del juego.
* **Cero Círculos Huérfanos:** El área del mapa solo debe renderizarse cuando el mapa abierto en `ZO_WorldMap` coincide estrictamente con el `mapId` donde fue capturado el objetivo y la misión está activa e incompleta.

## Opciones Consideradas
* **Opción 1: Crear controles manuales de textura sobre `ZO_WorldMapContainer` y calcular zoom/pan a mano.**
  * *Pro:* Control manual sobre el control XML.
  * *Contra:* Altísima propensión a desincronización durante el zoom/pan de `ZO_WorldMap`, errores de escala y círculos huérfanos al cambiar de mapa.
* **Opción 2: Utilizar `ZO_WorldMapPins_Manager:AddCustomPin` con `radius > 0` y `ZO_PinBlob` nativo + Pestaña en `QUEST_JOURNAL_KEYBOARD.tabs` (Elegida).**
  * *Pro:* `ZO_MapPin:SetLocation(x, y, radius)` adquiere automáticamente un `ZO_PinBlob` del pool oficial del mapa, lo escala dinámicamente con `mapHeight` en cada zoom/resize y oculta el icono central cuando `showsPinAndArea` es falso. Además, integra tooltips nativos al pasar el mouse sobre el área de búsqueda.
  * *Contra:* Requiere refrescar el pin personalizado ante cambios de misión activa, completado o cambio de mapa.

## Decisión Adoptada
Opción elegida: **"Opción 2: Utilizar `ZO_WorldMapPins_Manager:AddCustomPin` con `radius > 0` y `ZO_PinBlob` nativo + Pestaña en `QUEST_JOURNAL_KEYBOARD.tabs`"**, porque delega en el motor C++/Lua de `ZO_WorldMap` el escalado por zoom, el recorte de bordes y el shader circular `HALO` idéntico a las misiones oficiales.

### Especificaciones de los Subsistemas UI
1. **Pestaña en el Diario (`src/JournalTab.lua`):**
   * Crea un panel `TopLevelControl` anclado a `ZO_QuestJournal` (siguiendo `ZO_RightPanelFootPrint`) envuelto en un `ZO_FadeSceneFragment`.
   * Se registra en `QUEST_JOURNAL_KEYBOARD.tabs` (`ZO_SceneFragmentBar`) mediante `ZO_PostHook(QUEST_JOURNAL_KEYBOARD, "OnShowing", ...)`.
   * Columna izquierda: Contador de misiones, filtros/secciones claramente diferenciadas para misiones **Activas / En Curso** y **Completadas**, y botones de barra de herramientas (**+ Nueva**, **Importar Código**).
   * Columna derecha: Vista multipropósito según el modo activo:
     * **Modo Detalle:** Título, estado, zona/mapa, descripción narrativa, progreso del objetivo (`current / required`), barra de código para compartir (`Ctrl+C`), y botones de acción (Activar/Desactivar, Ver en Mapa, Editar, Reiniciar, Compartir, Eliminar).
     * **Modo Editor (Crear / Editar):** Inputs para Título, Descripción, selector de cantidad de bajas ($1..N$), selector de tamaño de área de búsqueda (Pequeña, Mediana, Grande), estado del objetivo capturado con tecla bajo retícula y botón Guardar / Cancelar.
     * **Modo Importar:** Campo de entrada para pegar el código `RPQ1:...` recibido de otro jugador y botón para validar e importar.
2. **Área de Búsqueda en Mapa Mundial (`src/WorldMapArea.lua`):**
   * Registra el pin personalizado `RPQUEST_SEARCH_AREA_PIN` en `ZO_WorldMap_GetPinManager():AddCustomPin(...)`.
   * En el `layoutCallback`: verifica que exista una misión activa, que `not activeQuest.completed`, que `not ZO_WorldMapPins_Manager.IsCurrentMapGlobal()` y que `GetCurrentMapId() == activeQuest.mapId`. Si todo se cumple, invoca `pinManager:CreatePin(pinTypeId, pinTag, activeQuest.areaCenterX, activeQuest.areaCenterY, activeQuest.areaRadius)`.
   * Incluye función `ShowQuestOnMap(quest)` que abre el mapa mundial (`MAIN_MENU_KEYBOARD:ShowCategory(MENU_CATEGORY_MAP)`), navega al `mapId` de la misión (`SetMapToMapId(quest.mapId)`) y centra la vista en el área (`ZO_WorldMap_PanToNormalizedPosition`).
3. **Avisos y HUD Tracker (`src/Announcements.lua` y `src/HudTracker.lua`):**
   * `Announcements`: Emite avisos `CENTER_SCREEN_ANNOUNCE` con `SOUNDS.QUEST_OBJECTIVE_INCREMENT` al avanzar bajas y `CSA_CATEGORY_LARGE_TEXT` + `SOUNDS.QUEST_COMPLETED` al completar la misión.
   * `HudTracker`: Ventana ligera vinculada a `HUD_SCENE` y `HUD_UI_SCENE` mediante `ZO_HUDFadeSceneFragment`, ubicada en el margen derecho debajo o junto al tracker nativo, mostrando el título de la misión custom activa y el progreso `Eliminar <NPC>: X/Y` (con clic derecho o botón para abrir en el Diario o ver en el Mapa).

### Consecuencias
* **Positivas:**
  * Apariencia y comportamiento 100% integrados con el diseño visual de Elder Scrolls Online.
  * Cero riesgo de errores UV en la brújula ni círculos en mapas equivocados.
* **Negativas / Trade-offs:**
  * Enfoque prioritario en la interfaz de Teclado (`QUEST_JOURNAL_KEYBOARD`), manteniendo seguridad ante modo Gamepad.

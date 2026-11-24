---
status: accepted
date: 2026-11-20
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0006 - Puntos de Descubrimiento Ocultos y Detección por Proximidad

## Contexto y Planteamiento del Problema
En `RPQuest`, las misiones actuales se centran en objetivos de combate dentro de un área de búsqueda visible en el mapa (`WorldMapArea`). Para misiones de investigación, rastreo o roleplay narrativo, el creador necesita poder definir **puntos de descubrimiento ocultos** (sin pin ni área visible para el jugador) que disparen un mensaje narrativo contextual cuando el personaje llega físicamente al lugar indicado.

## Impulsores de la Decisión (Decision Drivers)
* **Ocultamiento Total al Jugador:** No registrar ni renderizar pins en `ZO_WorldMap_GetPinManager()` para los puntos de descubrimiento; las ubicaciones y mensajes pendientes tampoco deben mostrarse en la vista de detalle de misiones recibidas (`RECEIVED`).
* **Cero Interferencia con el Mapa:** La detección en segundo plano no debe llamar nunca a `SetMapToPlayerLocation()` para no alterar el mapa que el jugador esté consultando.
* **Eficiencia de Recursos:** El polling de posición solo debe estar activo cuando la misión activa tiene puntos de descubrimiento pendientes sin descubrir.
* **Flexibilidad de Diseño:** Soportar misiones puras de descubrimiento (sin objetivos de combate), misiones solo de combate, y misiones mixtas.
* **Ergonomía de Autoría:** Permitir capturar puntos in-situ desde el formulario del editor (`+ Point Here` en la sección *Hidden Discovery Points*) con mensaje narrativo obligatorio y selector de radio (`Small` / `Medium` / `Large`).

> **Enmienda (2026-11-24, Issue #294):** Se retiró el keybind independiente `RPQUEST_CAPTURE_DISCOVERY` y el comando `/rpquest discovery` para consolidar la captura exclusivamente en el formulario del editor, ya que cada punto requiere redactar su mensaje narrativo en el lugar. Se reemplazaron los botones `8m` / `15m` / `30m` por un `ZO_ComboBox` estandarizado (`Small` / `Medium` / `Large`) y se eliminó el relleno genérico `DEFAULT_DISCOVERY_MSG`, exigiendo mensaje no vacío antes de guardar, probar o enviar la misión.
>
> **Enmienda (2026-11-24, Issue #298):** Se matiza el principio de ocultamiento en mapa mediante visibilidad diferenciada por rol (`RPQUEST_DISCOVERY_AREA_PIN` en color púrpura `DISCOVERY_AREA_COLOR` con `pinTypeOnResizeCallback`):
> * **Creador (modo Edición / Borrador y misiones Preparadas/Enviadas):** visualiza automáticamente todos los puntos configurados con tooltip que incluye radio en metros y resumen del mensaje.
> * **Jugador receptor (Play mode):** los puntos permanecen ocultos por defecto (`showDiscoveryAreas = false` en `SavedVariables.settings`, nunca serializado en `ShareCodec`), pudiendo activarse localmente desde el detalle de la misión. Al activarse, solo muestra puntos pendientes (`not discovered`), se refresca automáticamente al dispararse `DISCOVERY_TRIGGERED`, y su tooltip sin spoilers muestra únicamente `Discovery Point #<N>`.

## Decisión Adoptada
1. **Modelo de Dominio (`Constants.lua` y `QuestRepository.lua`):**
   * Cada misión puede incluir `discoveries = { { zoneId, worldX, worldY, worldZ, mapId, x, y, radius, message, discovered }, ... }`.
   * Radios predefinidos en unidades de mundo ESO (cm): `SMALL = 800` (8 m), `MEDIUM = 1500` (15 m), `LARGE = 3000` (30 m).
   * Una misión es válida si tiene al menos un objetivo de combate **o** al menos un punto de descubrimiento. Se considera completada cuando todos sus objetivos de combate (si hay) y todos sus puntos de descubrimiento (si hay) están completos.
2. **Motor de Proximidad (`src/DiscoveryTracker.lua`):**
   * Usa `EVENT_MANAGER:RegisterForUpdate("RPQuest_DiscoveryTracker", 750, ...)` de forma condicional: se activa únicamente cuando la misión activa tiene puntos con `discovered == false` y se desregistra inmediatamente en caso contrario.
   * Consulta `GetUnitWorldPosition("player")` (`zoneId, worldX, worldY, worldZ`) y evalúa la distancia horizontal 2D `sqrt((px - dx)^2 + (pz - dz)^2) <= radius` cuando `zoneId` coincide.
   * Al disparar un punto, persiste `discovered = true` (evitando repeticiones) y notifica mediante `Announcements:AnnounceDiscovery` (CSA + mensaje en chat + sonido sutil).
3. **Serialización (`ShareCodec.lua`):**
   * Se agrega el campo opcional 14 al payload `RPQ1` con la lista de descubrimientos codificada (`~` entre atributos, `;` entre puntos), manteniendo compatibilidad retroactiva con códigos `RPQ1` de 11–13 campos.

## Consecuencias
* **Positivas:**
  * Permite crear misiones narrativas y de rastreo sin pistas visuales en mapa ni brújula.
  * Consumo nulo de CPU/updates cuando no hay descubrimientos pendientes.
* **Negativas / Trade-offs:**
  * Los códigos `RPQ1` con muchos puntos de descubrimiento largos serán proporcionalmente más extensos, aunque dentro de los límites de `EditControl`.

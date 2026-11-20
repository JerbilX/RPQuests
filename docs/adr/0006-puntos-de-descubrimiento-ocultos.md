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
* **Ergonomía de Autoría:** Permitir capturar puntos in-situ mediante keybind (`RPQUEST_CAPTURE_DISCOVERY`), comando `/rpquest discovery` o botón directo en el editor.

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

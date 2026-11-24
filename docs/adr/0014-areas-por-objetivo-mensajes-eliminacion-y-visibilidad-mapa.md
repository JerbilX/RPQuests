---
status: accepted
date: 2026-11-24
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0014 - Áreas de Búsqueda por Objetivo, Mensajes de Eliminación en 3 Estados y Visibilidad en Mapa

## Contexto y Planteamiento del Problema
Tras la adopción de objetivos múltiples (`ADR-0004`) y el renderizado nativo de áreas en el mapa (`ADR-0003`), el modelo de datos v2 mantenía limitaciones estructurales:
1. **Área de búsqueda global única:** `areaCenterX`, `areaCenterY` y `areaRadius` residían a nivel de misión, impidiendo que cada objetivo tenga su propia área de búsqueda en el mapa cuando existen múltiples objetivos dispersos en una misma zona/mapa.
2. **Imposición unilateral de ocultación en mapa:** El booleano `hideMapArea` ocultaba de forma forzosa las marcas del mapa al jugador receptor, sin distinguir entre una recomendación narrativa del Master y la potestad local del jugador para decidir qué capas cartográficas visualizar.
3. **Mensajes de eliminación ambiguos y restricción geográfica implícita:** `target.customMessage` no distinguía entre una eliminación general, una eliminación dentro de una ubicación requerida o un fallo fuera de ella. Además, cuando un objetivo no tenía ubicación requerida (`locationRequired == false`), las bajas seguían restringidas al círculo de búsqueda del mapa en lugar de contar en cualquier parte de Tamriel.

## Impulsores de la Decisión (Decision Drivers)
* **Un único mapa por misión con áreas independientes por objetivo:** Mantener un único `mapId` / `zoneId` / `mapName` por misión para evitar saltos entre mapas distintos, pero trasladar `areaCenterX`, `areaCenterY` y `areaRadius` a cada entrada de `targets[]`.
* **Recomendación del Master vs. Potestad del Jugador:** El creador emite una recomendación (`recommendHideMapAreas`, `true` por defecto en borradores nuevos), mientras que el jugador controla localmente `showSearchAreas` y `showLocationAreas` (ambas `false` por defecto, nunca serializadas en `ShareCodec`).
* **Exclusividad mutua de los 3 estados de eliminación:** Garantizar comportamiento determinista según `locationRequired` y la posición del jugador respecto a la ubicación capturada.
* **Evolución limpia bajo ADR-0013:** Aislar la compatibilidad en `QuestMigration` (`v2 -> v3`) y `ShareCodec` (`RPQ3` con bits libres en `tFlags`) manteniendo retrocompatibilidad con códigos previos.

## Opciones Consideradas
* **Opción 1: Mantener área global única y agregar overrides parciales en runtime.**
  * *Pro:* Menor cambio inicial en `ShareCodec`.
  * *Contra:* Genera inconsistencia entre el área global y las ubicaciones individuales, perpetúa deuda técnica en trackers/UI y contradice ADR-0013.
* **Opción 2: Esquema v3 con áreas por objetivo, recomendación `recommendHideMapAreas`, preferencias locales del jugador y mensajes en 3 estados (Elegida).**
  * *Pro:* Modelo limpio y uniforme en `targets[]`, separación clara entre intención narrativa del Master y preferencias locales del jugador, y migración determinista `v2 -> v3`.
  * *Contra:* Requiere migrar registros v2 y extender `RPQ3` usando bits libres de `tFlags` (`16`, `32`, `64`).

## Decisión Adoptada
Opción elegida: **"Opción 2: Esquema v3 con áreas por objetivo, recomendación `recommendHideMapAreas`, preferencias locales del jugador y mensajes en 3 estados"**, enmendando los aspectos correspondientes de `ADR-0003` y `ADR-0004`:

1. **Esquema v3 y Migración (`v2 -> v3`):**
   * `Addon.Constants.QUEST_SCHEMA.CURRENT_VERSION` pasa a `3`.
   * Cada entrada de `targets[]` incorpora `areaCenterX`, `areaCenterY`, `areaRadius`, `customMessageInLocation` y `customMessageOutsideLocation` (junto a `customMessage`).
   * `recommendHideMapAreas` reemplaza la semántica de `hideMapArea` (valor por defecto `true` en borradores nuevos; la migración `v2 -> v3` preserva el valor previo de `hideMapArea`).
   * Se agregan preferencias locales en `SavedVariables.settings`: `showSearchAreas = false`, `showLocationAreas = false` y (enmienda Issue #298) `showDiscoveryAreas = false` (nunca serializadas en `ShareCodec`).
2. **Códec `RPQ3` (`ShareCodec`):**
   * Usa los bits libres de `tFlags` (`16`: área de búsqueda por objetivo, `32`: `customMessageInLocation`, `64`: `customMessageOutsideLocation`) manteniendo decodificación retrocompatible con payloads `RPQ1`, `RPQ2` y `RPQ3` previos.
3. **Lógica de Combate y Anuncios:**
   * `locationRequired == false` (sin ubicación o con ubicación opcional): no valida mapa/zona/área al matar; el kill cuenta en cualquier lugar de Tamriel y solo puede dispararse `customMessage`.
   * `locationRequired == true` con ubicación capturada: dentro de `IsPlayerInsideTargetLocation` cuenta progreso y dispara `customMessageInLocation` (nunca `customMessage`); fuera falla la misión y muestra `customMessageOutsideLocation` (fallback a `ALERT_QUEST_FAILED_LOCATION`).

### Consecuencias
* **Positivas:**
  * Cada objetivo posee su propia área de búsqueda y mensajes diferenciados sin fragmentar la misión en múltiples mapas.
  * El jugador conserva el control local sobre qué círculos ve en el mapa, respetando la recomendación por defecto del Master.
  * Cero pérdida de datos en misiones v2 existentes ni en códigos compartidos anteriormente.
* **Negativas / Trade-offs:**
  * Los módulos de UI/mapa (`WorldMapArea`, `JournalDetailPane`, `JournalEditorSections`, `JournalEditorPane`) deben mantener compatibilidad transitoria con los campos v3 hasta completar sus mejoras dedicadas.

> **Enmienda (2026-11-24, Issue #298):** Se extiende el modelo de capas cartográficas opcionales para el jugador incorporando `showDiscoveryAreas = false` (por defecto oculto, nunca serializado en `ShareCodec`) junto a `showSearchAreas` y `showLocationAreas`, con toggle independiente en `JournalDetailPane` y renderizado en `WorldMapArea` (`RPQUEST_DISCOVERY_AREA_PIN` púrpura) para puntos de descubrimiento pendientes en Play mode o todos los puntos configurados para el creador.

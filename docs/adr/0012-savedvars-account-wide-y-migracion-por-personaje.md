---
status: accepted
date: 2026-11-22
decision-makers: [JerbilX, Antigravity]
supersedes: ["0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md"]
superseded-by: []
---

# 0012 - Persistencia Account-Wide en SavedVars y Migración No Destructiva desde Personaje

## Contexto y Planteamiento del Problema
En `ADR-0001` se definió la persistencia de `RPQuest_SavedVariables` mediante `ZO_SavedVars:NewCharacterIdSettings(...)`, aislando misiones, borradores y registros de envío/recepción por `characterId`. Sin embargo, el sistema de correo in-game de *The Elder Scrolls Online* (`MailTransport`) opera a nivel de cuenta (`@DisplayName`), no por personaje.

Cuando un Quest Master crea y envía una misión desde el Personaje A y posteriormente inicia sesión con el Personaje B al recibir el correo de aceptación, rechazo o completado, el addon en el Personaje B no encuentra la misión preparada en sus `SavedVariables` y no puede actualizar su estado ni registrar la entrega (`deliveries`).

*(Nota: Las decisiones de `ADR-0001` sobre arquitectura modular zero-dependency, namespace único `RPQuest` y sistema de localización `lang/` + `src/Locale.lua` permanecen vigentes sin cambios).*

## Impulsores de la Decisión (Decision Drivers)
* **Alineación con el Correo Account-Wide de ESO:** Los correos de misiones (`RPQP` / `RPQC1` / `RPQ3`) llegan a la bandeja compartida de la cuenta `@DisplayName`; el repositorio de misiones debe ser accesible desde cualquier personaje de la misma cuenta.
* **Migración No Destructiva (Zero Data Loss):** Los jugadores con misiones preparadas, recibidas o borradores existentes en `SavedVariables` por personaje no deben perder su progreso al actualizar el addon.
* **Idempotencia y Resolución de Colisiones:** La migración puede consolidar múltiples personajes de una misma cuenta sin duplicar misiones ni colisionar en `quest.id`.

## Opciones Consideradas
* **Opción 1: Mantener `NewCharacterIdSettings` y leer tablas de otros personajes manualmente.**
  * *Pro:* Mantiene aislamiento por personaje para misiones recibidas.
  * *Contra:* Obliga a manipular manualmente estructuras internas de `ZO_SavedVars` en cada lectura/escritura de `QuestRepository`, rompe el contrato estándar de `ZO_SavedVars` y complica la sincronización de `nextId` y `ingestedMailIds`.
* **Opción 2: Migrar a `ZO_SavedVars:NewAccountWide` con migración automática no destructiva (Elegida).**
  * *Pro:* Usa el mecanismo nativo `ZO_SavedVars:NewAccountWide` (`$AccountWide`), resuelve de raíz la trazabilidad de correos entre personajes de la misma cuenta y permite migrar de forma limpia e idempotente los buckets `[characterId]` existentes sin borrarlos.
  * *Contra:* Las misiones recibidas, `activeQuestId` y `settings` pasan a ser compartidos entre personajes de la cuenta (comportamiento esperado y documentado; `ExportCompletionCode` / `ExportRejectionCode` siguen leyendo `GetUnitName("player")` dinámicamente según el personaje activo).

## Decisión Adoptada
Opción elegida: **"Opción 2: Migrar a `ZO_SavedVars:NewAccountWide` con migración automática no destructiva"**, porque alinea la persistencia del addon con el modelo account-wide del correo de ESO utilizando la API oficial de EsoUI.

### Especificaciones de Implementación
1. **Inicialización Account-Wide (`RPQuest.lua`):** Reemplazar `ZO_SavedVars:NewCharacterIdSettings(svName, svVersion, nil, defaults)` por `ZO_SavedVars:NewAccountWide(svName, svVersion, nil, defaults)`.
2. **Migración Idempotente (`QuestRepository:MigrateCharacterSavedVars`):**
   * Al inicializar, inspeccionar `_G[svName]["Default"][GetDisplayName()]` en busca de tablas de personajes (`charKey ~= "$AccountWide"`) que aún no figuren en `savedVars.migratedCharacterIds`.
   * Priorizar el `GetCurrentCharacterId()` activo y luego el resto de `characterId` en orden determinista.
   * Clonar profundamente misiones (`quests`), reasignar `id` únicamente si existe colisión en `$AccountWide` (manteniendo `nextId` actualizado), fusionar `ingestedMailIds`, y adoptar `settings`, `draft` (si el borrador destino está vacío) y `activeQuestId` (si aún no hay misión activa).
   * Registrar `savedVars.migratedCharacterIds[charKey] = true` sin eliminar los datos originales por personaje (respaldo no destructivo).
3. **Contexto de Personaje y `activeQuestId`:**
   * `activeQuestId` es compartido en `$AccountWide`; `GetActiveQuest()` valida que la misión exista y no esté completada, fallida ni en estado `offered`.
   * El nombre del personaje que completa o rechaza una misión se obtiene dinámicamente vía `GetUnitName("player")` en el momento de exportar el resultado.

### Consecuencias
* **Positivas:**
  * Los Quest Masters pueden enviar misiones desde cualquier personaje y procesar respuestas desde cualquier otro personaje de la misma cuenta.
  * Cero pérdida de datos para usuarios existentes gracias a la migración automática no destructiva.
* **Negativas / Trade-offs:**
  * El estado `activeQuestId` y la lista de misiones son compartidos entre alts de la misma cuenta.

---
status: accepted
date: 2026-11-24
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0015 - Separación Ortogonal entre Ciclo de Vida de Misión y Estado de Resolución

## Contexto y Planteamiento del Problema
Tras `ADR-0005` (separación de misiones en preparación y juego) y `ADR-0011` (flujo 1-a-1 por correo), el modelo de datos v3 mezclaba dos dimensiones conceptualmente distintas en un único estado derivado (`QuestRepository:GetPreparedQuestStatus` junto con `QUEST_ROLE`, `QUEST_STATUS`, `quest.completed` y `quest.failed`):
1. **Ciclo de vida / origen (`lifecycle`):** Si la misión es un borrador local sin enviar (`draft`), una misión ya despachada a un destinatario (`sent`), o una misión recibida de otro jugador (`received`).
2. **Estado de resolución (`resolution`):** El resultado de la misión (`accepted`, `rejected`, `completed`, `failed`, o `nil` cuando aún está pendiente de respuesta o en borrador).

Esta mezcla provocaba tres problemas concretos:
* `GetPreparedQuestStatus` devolvía `"accepted"`, `"rejected"` o `"completed"` en lugar de preservar que la misión seguía en ciclo `sent`, ocultando el estado de envío bajo el resultado.
* El protocolo de resultados `RPQC1` (`ShareCodec` / `MailTransport` / `MailInbox`) no contemplaba el reporte del estado `failed` desde el receptor hacia el Quest Master emisor.
* Las pruebas locales del GM (`Test Quest` / `Reset`) sobre misiones `draft` o `sent` podían contaminar la semántica de estado remoto al compartir los mismos flags booleanos (`completed`, `failed`).

## Impulsores de la Decisión (Decision Drivers)
* **Ortogonalidad estricta:** Separar `lifecycle` (`draft` | `sent` | `received`) de `resolution` (`nil` | `accepted` | `rejected` | `completed` | `failed`), garantizando por invariante que `draft` siempre tenga `resolution = nil`.
* **Retrocompatibilidad bajo `ADR-0013`:** Evolucionar el esquema de misiones mediante `CURRENT_VERSION = 4` y `QuestMigration.SCHEMA_MIGRATORS[3]` (`v3 -> v4`) sin pérdida de datos en `SavedVariables`.
* **Reporte completo de resultados en `RPQC1`:** Incorporar el resultado `failed` en el códec de resultados y el transporte por correo manteniendo compatibilidad con códigos previos (`"0"` rechazado, `"1"` completado, `"2"` aceptado).
* **Aislamiento de pruebas locales del GM:** Permitir que `Test Quest` y `Reset` muten los flags locales de ejecución (`completed`, `failed`, `wasDetected`) sin alterar `lifecycle` ni la `resolution` remota de misiones `draft` o `sent`.

## Opciones Consideradas
* **Opción 1: Ampliar `GetPreparedQuestStatus` con `"failed"` manteniendo el modelo plano.**
  * *Pro:* Menor cambio inicial en `Constants.lua`.
  * *Contra:* Mantiene acoplados origen y resultado, perpetúa la pérdida de visibilidad de `Sent` y complica el aislamiento de pruebas locales del GM.
* **Opción 2: Separar ortogonalmente `lifecycle` y `resolution` en esquema v4 y extender `RPQC1` con flag `"3"` (`failed`) (Elegida).**
  * *Pro:* Modelo de dominio explícito, invariantes claras (`draft` sin resolución), migración determinista `v3 -> v4`, reporte completo de fallos por correo y aislamiento limpio de pruebas locales del GM.
  * *Contra:* Requiere actualizar `QuestRepository`, `QuestDraftStore`, `ShareCodec`, `MailTransport`, `MailInbox`, UI del diario y las 7 localizaciones.

## Decisión Adoptada
Opción elegida: **"Opción 2: Separar ortogonalmente `lifecycle` y `resolution` en esquema v4 y extender `RPQC1` con flag `"3"` (`failed`)"**:

1. **Modelo de Dominio y Esquema v4 (`src/Constants.lua`, `src/QuestMigration.lua`):**
   * `QUEST_SCHEMA.CURRENT_VERSION` se incrementa a `4`.
   * Se definen `QUEST_LIFECYCLE` (`DRAFT = "draft"`, `SENT = "sent"`, `RECEIVED = "received"`) y `QUEST_RESOLUTION` (`ACCEPTED = "accepted"`, `REJECTED = "rejected"`, `COMPLETED = "completed"`, `FAILED = "failed"`).
   * Se conservan `QUEST_ROLE` y `QUEST_STATUS` sincronizados para compatibilidad con filtros existentes e importación.
   * `QuestMigration.SCHEMA_MIGRATORS[3]` (`v3 -> v4`) deriva `lifecycle`, sincroniza `role`, deriva `resolution` (garantizando `nil` en `draft`) e inicializa `failureReported`.
2. **APIs Ortogonales y Aislamiento GM (`src/QuestRepository.lua`, `src/QuestDraftStore.lua`):**
   * Se reemplaza `GetPreparedQuestStatus` por `GetQuestLifecycle(quest)`, `GetQuestResolution(quest)`, `IsPreparedQuest(quest)` e `IsOfferedQuest(quest)`.
   * `FinalizeCompletedQuest`, `FinalizeFailedQuest` y `ResetQuest` solo mutan `quest.resolution` cuando `lifecycle == "received"`; en misiones `draft` o `sent` solo actualizan los flags locales de prueba (`completed`, `failed`, `wasDetected`), preservando intacta la resolución remota.
   * Al cambiar `recipientAccount` en una misión `sent`, `QuestDraftStore` restablece `lifecycle = "draft"` y `resolution = nil`.
3. **Protocolo `RPQC1` y Correo de Fallo (`src/ShareCodec.lua`, `src/MailTransport.lua`, `src/MailInbox.lua`):**
   * `ShareCodec:EncodeResultCode` / `EncodeFailure` emite `resultFlag = "3"` para `"failed"` (incluyendo `stealthFlag` cuando `stealthMode ~= "disabled"` y `wasDetected ~= nil`); `DecodeCompletion` mapea `"3"` a `resultType = "failed"` y `failed = true`.
   * `MailTransport` escucha `"QUEST_FAILED"` en misiones `received` y envía automáticamente un correo con prefijo `[RPQuest:Failed] ` si `autoSendCompletionMail` está activo y `not failureReported`.
   * `MailInbox` procesa `[RPQuest:Failed] ` antes que el fallback de rechazo, actualiza `lastResult` y `resolution = "failed"` en la misión `sent` (sin permitir que un `accepted` tardío sobrescriba un estado terminal).
4. **UI y Localización (`src/JournalTab.lua`, `src/JournalDetailPane.lua`, `lang/*.lua`):**
   * Las filas de `Sent` y la vista de detalle muestran simultáneamente el ciclo de vida (`Sent` / `Received` / `Draft`) y la resolución (`Pending`, `Accepted`, `Rejected`, `Completed`, `Failed`).

### Consecuencias
* **Positivas:**
  * Visibilidad clara de ciclo de vida y resolución en toda la UI sin estados ambiguos.
  * Trazabilidad completa del ciclo receptor -> emisor incluyendo fallos de misión.
  * Pruebas locales del GM seguras sobre borradores y misiones enviadas.
* **Negativas / Trade-offs:**
  * Incremento de versión de esquema a v4 y necesidad de mantener sincronizados `role`/`status` heredados durante la transición.

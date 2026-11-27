---
status: accepted
date: 2026-11-26
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
amends:
  - docs/adr/0006-puntos-de-descubrimiento-ocultos.md
  - docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
---

# 0018 - Ejes de Condición de Victoria, Modo Free-Form, Objetivos Requeridos y Descubrimiento Secuencial

## Contexto y Planteamiento del Problema
Originalmente `RPQuest` exigía que toda misión jugable o enviable contara con al menos un objetivo de combate/duelo (`targets`) o un punto de descubrimiento (`discoveries`), tratando los diálogos con NPCs (`ADR-0007`) como elementos puramente opcionales cuyo estado visto (`seenDialogues`) solo vivía en memoria volátil de sesión.

En sesiones reales de roleplay guiado o narrativo surgen cuatro necesidades que el esquema previo no cubría:
1. **Misiones *free-form* puras y misiones solo de diálogos:** Contratos puramente interpretativos (`0` targets, `0` discoveries, `0` dialogues) que el jugador resuelve manualmente según lo acordado en rol, o misiones investigativas compuestas únicamente por conversaciones con NPCs (`0` targets, `0` discoveries, `>= 1` dialogues).
2. **Condiciones `required` en descubrimientos y diálogos:** Análogo a `locationRequired` en `targets` (`ADR-0014`) y `stealthMode = "required"`, el autor necesita poder marcar puntos de descubrimiento o diálogos específicos como obligatorios de modo que omitirlos al cerrar la misión provoque su fallo (`failed`), mientras que los no marcados permanecen opcionales.
3. **Orden secuencial de descubrimientos (`sequentialDiscoveries`):** En mundo abierto, un jugador puede tropezar accidentalmente con el punto final de una cadena de pistas antes de visitar los anteriores.
4. **Persistencia local de ejecución de diálogos (`executed`):** Si el jugador recarga la interfaz (`/reloadui`) o cierra sesión a mitad de una investigación, el progreso de diálogos ejecutados debe conservarse en `SavedVariables` sin transmitirse como estado precompletado al compartir o clonar la misión.

## Impulsores de la Decisión (Decision Drivers)
* **Flexibilidad Narrativa Completa:** Soportar los 3 ejes mecánicos (`targets`, `discoveries`, `dialogues`) en cualquier combinación, además del modo *free-form* puro (`0 / 0 / 0`), sin sobreingeniería ni motores de scripting complejos.
* **Semántica Uniforme de Fallo vs. Opcionalidad:** Alinear `required` en `discoveries[i]` y `dialogues[i]` con la resolución ortogonal `completed` / `failed` y el reporte automático `RPQC1` establecidos en `ADR-0015`.
* **Evolución Determinista de Esquema (`ADR-0013`):** Migrar sin pérdida de datos todas las misiones existentes en `SavedVariables` (`v1..v5` -> `v6`, dado que `ADR-0014` Issue #322 ya asignó `CURRENT_VERSION = 5`).
* **Retrocompatibilidad y Presupuesto de Correo (`ADR-0008`, `ADR-0016`):** Extender `ShareCodec` (`RPQ3` y la firma canónica `BuildQuestPayloadString` / `RPQC1`) sin invalidar códigos ni firmas previas y manteniendo el peor caso `4/10/4` dentro del presupuesto estricto de `<= 6` correos (`<= 4,104` caracteres).

## Opciones Consideradas
* **Opción 1: Árboles o grafos de etapas condicionales arbitrarias.**
  * *Pro:* Permite dependencias ramificadas complejas entre cualquier par de objetivos.
  * *Contra:* Viola YAGNI, multiplica la complejidad del editor, excede fácilmente el presupuesto de correo `RPQ3` y dificulta la comprensión para autores y jugadores.
* **Opción 2: Tres ejes de victoria bien definidos + modo *free-form* + flags booleanos ortogonales (`required`, `sequentialDiscoveries`, `executed`) sobre el modelo actual (Elegida).**
  * *Pro:* Cubre misiones *free-form*, investigativas por diálogo, rutas secuenciales de pistas y requisitos estrictos con mínimo impacto en UI, almacenamiento y tamaño binario (`<= 3` bytes adicionales en el peor caso de `RPQ3`).
  * *Contra:* El orden guiado de descubrimientos es lineal (`1..N`) cuando `sequentialDiscoveries == true`, suficiente para pistas encadenadas en RP.

## Decisión Adoptada
Opción elegida: **"Opción 2: Tres ejes de victoria bien definidos + modo *free-form* + flags booleanos ortogonales (`required`, `sequentialDiscoveries`, `executed`)"**, enmendando `ADR-0006` y `ADR-0007` en lo relativo a obligatoriedad de objetivos y estado de diálogos:

1. **Los 3 Ejes de Victoria y Modo *Free-Form*:**
   * **`HasPlayableObjectives(quest)`:** Toda tabla de misión válida es activable, enviable y exportable incluso con `0` targets y `0` discoveries (con o sin `dialogues`).
   * **Ejes primarios de victoria:**
     1. **Combate / Duelo (`targets`):** Bajas de NPCs o duelos contra jugadores (`optional == false` obligatorios; `optional == true` habilita completado manual tras cumplir los obligatorios o autocompletado al cumplir todos).
     2. **Descubrimiento (`discoveries`):** Puntos de proximidad ocultos (`discovered == true`), combinables con `targets` o como eje único.
     3. **Diálogo (`dialogues`):** Cuando la misión tiene `0` targets y `0` discoveries pero `>= 1` diálogos, la ejecución de todos los diálogos (`executed == true`) actúa como condición de victoria automática; en misiones con `targets` o `discoveries`, los diálogos acompañan la narrativa sin bloquear el cierre salvo que estén marcados como `required = true`.
   * **Modo *Free-Form* Puro (`0` targets, `0` discoveries, `0` dialogues):** La misión no se autocompleta sola; el jugador la finaliza manualmente mediante la acción **"Complete Quest"** según el acuerdo de rol con el Quest Master.
2. **Semántica de `required` (`boolean`, default `false`) en `discoveries[i]` y `dialogues[i]`:**
   * Los ítems con `required == false` (valor por defecto) son opcionales frente al fallo: no impiden cerrar manualmente una misión con objetivos opcionales ni provocan fallo al resolverse el eje principal.
   * Si al momento de intentar completar la misión (automática o manualmente) existe algún `discovery` con `required == true` y `discovered == false`, o algún `dialogue` con `required == true` y `executed == false`, la misión transiciona a **`failed`** (`FinalizeFailedQuest` + notificación y reporte `RPQC1` según `ADR-0015`).
3. **Modo Secuencial de Descubrimientos (`sequentialDiscoveries`, `boolean`, default `false`):**
   * Propiedad a nivel de misión preservada en borradores, copias (`DuplicateQuest` / `MigratePreparedQuest`), `ResetQuest` y `ShareCodec`.
   * Cuando `sequentialDiscoveries == true`, el punto `discoveries[i]` solo queda desbloqueado (evaluable en `DiscoveryTracker` y visible en `WorldMapArea` en modo jugador) cuando `i == 1` o `discoveries[i - 1].discovered == true`.
4. **Estado de Ejecución de Diálogos (`executed`, `boolean`, default `false` en `dialogues[i]`):**
   * Persistido localmente en `SavedVariables` dentro de cada entrada `quest.dialogues[i]`.
   * Se restablece siempre a `false` en `ResetQuest`, al clonar/cargar/guardar borradores o duplicar misiones (`CloneDialoguesList`) y al decodificar/importar una misión (`ShareCodec` nunca serializa progreso local `executed`).
5. **Esquema `v6` (`v5 -> v6`) y Serialización (`ShareCodec` / `BinaryCodec`):**
   * Dado que `ADR-0014` (Issue #322) ya incrementó `QUEST_SCHEMA.CURRENT_VERSION` a `5` (`SCHEMA_MIGRATORS[4]`), se incrementa `QUEST_SCHEMA.CURRENT_VERSION` a `6` y se añade `QuestMigration.SCHEMA_MIGRATORS[5]` (`v5 -> v6`), inicializando de forma no destructiva `quest.sequentialDiscoveries`, `discovery.required`, `dialogue.required` y `dialogue.executed` como booleanos (`false` por defecto).
   * **Binario `RPQ3`:** Extiende el byte opcional `extFlags` con el bit 2 (`4`: `sequentialDiscoveries == true`), bit 3 (`8`: bitset compacto `BinaryCodec:WriteBitset` para `discoveries[i].required`) y bit 4 (`16`: bitset compacto para `dialogues[i].required`). Si todos los flags nuevos están en `false`, añade `0` bytes; en el peor caso (`10` discoveries + `4` dialogues requeridos) añade solo `3` bytes crudos, manteniendo holgadamente el tope de `6` correos (`ADR-0016`).
   * **Payload canónico (`BuildQuestPayloadString` / `ComputeQuestSignature`):** Solo añade sufijos `~1` en descubrimientos/diálogos con `required == true` y campos finales cuando `sequentialDiscoveries == true`, preservando intactas las firmas `RPQC1` de todas las misiones previas cuyos flags por defecto son `false`, y permitiendo firmar misiones *free-form* y solo de diálogos.

### Consecuencias
* **Positivas:**
  * Habilita contratos puramente interpretativos, investigaciones guiadas por NPCs y cadenas secuenciales de pistas sobre una base de datos uniforme.
  * Cero pérdida de datos en `SavedVariables` y 100% de retrocompatibilidad con códigos `RPQ3` y comprobantes `RPQC1` anteriores.
* **Negativas / Trade-offs:**
  * Incremento de versión de esquema a `v6` y ocupación de los bits 2, 3 y 4 de `extFlags` en `RPQ3` (quedando aún libres los bits 5, 6 y 7 para extensiones futuras).

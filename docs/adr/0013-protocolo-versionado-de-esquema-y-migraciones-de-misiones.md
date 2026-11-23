---
status: accepted
date: 2026-11-23
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0013 - Protocolo Estándar de Versionado de Esquema y Migraciones de Misiones

## Contexto y Planteamiento del Problema
`RPQuest` evoluciona rápidamente incorporando nuevas mecánicas en el modelo de misión (p. ej. modos de sigilo, iconos, resultados condicionales por ubicación, diálogos dependientes y flujo cooperativo). Mantener soporte para múltiples formatos históricos disperso a lo largo de la lógica de negocio (`CombatTracker`, `DiscoveryTracker`, `DialogueInjector`, `JournalDetailPane`, `JournalEditorSections`) introduce condicionales heredados, complejidad accidental y riesgo de regresiones.

Al mismo tiempo, existen dos contextos distintos donde conviven versiones anteriores de misiones:
1. **Persistencia local (`SavedVariables`):** Misiones ya creadas (`PREPARED`) o recibidas (`RECEIVED`) antes de una actualización del addon.
2. **Frontera de red/correo (`ShareCodec` / `MailTransport`):** Correos `RPQ1`/`RPQ2`/`RPQ3` enviados antes de actualizar el addon o por jugadores con otra versión reciente.

## Impulsores de la Decisión (Decision Drivers)
* **Runtime Limpio y Único:** El código de negocio, trackers y UI deben operar exclusivamente contra el esquema vigente (`CURRENT_SCHEMA_VERSION`), sin arrastrar ramas *legacy* en runtime.
* **Cero Pérdida de Datos:** Los autores no deben perder misiones ya redactadas (`PREPARED`) ni los jugadores (`RECEIVED`) deben ver interrumpidas sus misiones activas tras actualizar el addon.
* **Resiliencia en Correo In-Game:** `ShareCodec:DecodeQuest` debe poder ingerir formatos de versiones previas sin obligar a que remitente y destinatario actualicen en el mismo instante.
* **Claridad ante Cambios *Breaking*:** Cuando un cambio futuro requiera datos obligatorios imposibles de inferir automáticamente, el autor debe poder migrar su misión de forma segura en el editor sin perder el trabajo previo.

## Opciones Consideradas
* **Opción 1: Retrocompatibilidad dispersa en cada módulo de runtime.**
  * *Pro:* No requiere versión explícita en el registro de misión.
  * *Contra:* Cada nueva feature multiplica las ramas condicionales en trackers, códec y UI, elevando la deuda técnica y el riesgo de bugs.
* **Opción 2: Marcar toda misión de versión anterior como "inválida" y exigir migración manual en UI.**
  * *Pro:* Fuerza la actualización explícita de cada registro.
  * *Contra:* Genera fricción innecesaria ante cambios deterministas y rompe misiones `RECEIVED` en jugadores que no tienen acceso al editor.
* **Opción 3: Esquema versionado (`schemaVersion`) con pipeline automático en frontera de entrada + fallback manual para cambios *breaking* (Elegida).**
  * *Pro:* Aísla la compatibilidad en un único punto (`QuestMigrations`), mantiene el runtime 100% limpio contra el esquema actual, migra sin fricción las misiones deterministas y protege las `RECEIVED`, reservando el estado "Requiere migrar" únicamente para misiones `PREPARED` con cambios *breaking* no inferibles.
  * *Contra:* Requiere incrementar `CURRENT_SCHEMA_VERSION` y añadir un paso `vN -> vN+1` cada vez que cambie el esquema de misión.

## Decisión Adoptada
Opción elegida: **"Opción 3: Esquema versionado (`schemaVersion`) con pipeline automático en frontera de entrada + fallback manual para cambios *breaking*"**, estableciendo el siguiente protocolo estándar para toda evolución futura del modelo de misión:

1. **Versión Explícita de Esquema (`schemaVersion`):**
   * Toda misión persistida en `SavedVariables` y todo borrador/registro normalizado declara su `schemaVersion` entero (asumiendo `1` para registros históricos sin el campo).
   * `Constants` define `CURRENT_SCHEMA_VERSION` como única fuente de verdad del formato soportado por el runtime.
2. **Pipeline Secuencial en la Frontera de Entrada (`QuestMigrations`):**
   * Al cargar `SavedVariables` (`QuestRepository:Initialize`) y al decodificar un payload en `ShareCodec:DecodeQuest`, el registro pasa por un pipeline determinista e idempotente de migradores secuenciales (`v1 -> v2 -> ... -> vCurrent`).
   * Toda transformación determinista (renombrado de campos, conversión de booleanos a enums, valores por defecto seguros) se resuelve automáticamente en este paso, de modo que el resto del addon nunca consume esquemas antiguos.
3. **Fallback Manual para Cambios *Breaking* (`needsMigration`):**
   * Si una versión introduce un cambio verdaderamente incompatible (*breaking*) que no puede inferirse automáticamente para una misión en `PREPARED`, el migrador marca la misión con `needsMigration = true` (bloqueando su envío o prueba directa) y la UI ofrece la acción **"Migrar"**.
   * Al pulsar **"Migrar"**, se crea una copia actualizada al esquema vigente (análogo a `DuplicateQuest`) y se abre en el editor conservando título, descripción y datos compatibles para que el autor complete los campos nuevos sin perder su trabajo.
4. **Frontera del Códec de Compartición (`ShareCodec`):**
   * `ShareCodec:EncodeQuest` emite siempre el formato vigente más reciente.
   * `ShareCodec:DecodeQuest` mantiene lectura de versiones de protocolo anteriores (`RPQ1`, `RPQ2`, `RPQ3`, ...) únicamente para reconstruir el registro base y entregarlo inmediatamente al pipeline de migración hacia `CURRENT_SCHEMA_VERSION`.

### Consecuencias
* **Positivas:**
  * Desacopla la evolución del modelo de datos respecto a trackers, UI y lógica de juego.
  * Evita fricción para jugadores (`RECEIVED`) y autores en actualizaciones incrementales, manteniendo una salida segura y sin pérdida de datos ante cambios *breaking*.
* **Negativas / Trade-offs:**
  * Cada cambio de esquema requiere añadir su función de migración `vN -> vN+1` y su prueba unitaria correspondiente en `tests/`.

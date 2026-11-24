---
status: accepted
date: 2026-11-24
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
amends:
  - docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
  - docs/adr/0009-transporte-correo-multiparte-rpqp.md
  - docs/adr/0011-flujo-solo-correo-1-a-1-y-eliminacion-codigos-manuales.md
---

# 0016 - Límites Unificados de Texto y Entidades con Presupuesto Estricto de Correo (6 Partes)

## Contexto y Planteamiento del Problema
Tras consolidar el transporte 100% por correo in-game (`ADR-0009`, `ADR-0011`), toda misión creada en el editor debe poder serializarse con `ShareCodec` (`RPQ3`) y transmitirse mediante `MailTransport` dentro del tope de **6 correos multiparte** (`MAX_MAIL_PARTS = 6`, `6 * (700 - 16) = 4,104` caracteres útiles para `roleMessage + "\n\n" + RPQ3`).

Sin embargo:
1. Los límites de caracteres (`SetMaxInputChars`) estaban dispersos como literales en `src/JournalEditorSections.lua` y `src/JournalMailSendPane.lua` (`90`, `400`, `64`, `160`, `100`, `300`, `140`, `700`) sin fuente única de verdad en `src/Constants.lua`.
2. Solo `DIALOGUE.MAX_NPCS` (`3` según `ADR-0007`) tenía tope de entidades, mientras que Objetivos (`targets`) y Puntos de Descubrimiento (`discoveries`) carecían de límite máximo.
3. `ShareCodec` (`PackTargetsBlock` y `EncodeTargetsList`) serializaba mensajes de eliminación inactivos (`customMessage` cuando `locationRequired == true`, o `customMessageInLocation`/`customMessageOutsideLocation` cuando `locationRequired == false`), desperdiciando bytes del presupuesto de correo.

## Impulsores de la Decisión (Decision Drivers)
* **Garantía de Envío en Peor Caso:** Una misión al 100% de sus límites de texto y entidades con cadenas incompresibles (entropía máxima) más el mensaje de rol máximo debe caber en `<= 6` correos (`<= 4,104` caracteres).
* **Consistencia de UI y Dominio:** Unificar los topes de entidades (`4 / 4 / 4`) y centralizar `TEXT_LIMITS` en `src/Constants.lua`, eliminando literales `3` en `JournalEditorPane` y `lang/*.lua`.
* **Retrocompatibilidad Total:** Misiones guardadas o recibidas previamente que superen los nuevos topes deben seguir cargando, decodificándose y ejecutándose sin pérdida ni corrupción silenciosa de datos.

## Decisión Adoptada
1. **Topes Unificados en `src/Constants.lua`:**
   * Entidades: `TARGET.MAX_TARGETS = 4`, `DISCOVERY.MAX_POINTS = 4`, `DIALOGUE.MAX_NPCS = 4` (enmienda `ADR-0007` elevando de `3` a `4` NPCs de diálogo).
   * Longitudes de texto (`Addon.Constants.TEXT_LIMITS`):
     * `TITLE = 80`
     * `DESCRIPTION = 250`
     * `ACCOUNT_NAME = 64`
     * `CHARACTER_NAME = 64`
     * `SHORT_MESSAGE = 100` (unificado para mensajes de eliminación por objetivo, mensajes de descubrimiento y mensaje de finalización; mejora además la legibilidad en banners `CSA_CATEGORY_SMALL_TEXT`)
     * `DIALOGUE_OPTION = 60`
     * `DIALOGUE_RESPONSE = 150`
     * `MAIL_ROLE_MESSAGE = 300`
2. **Validación en Dominio y Badges Dinámicos:**
   * `QuestDraftStore` y `TargetCapture` aplican `MAX_TARGETS`, `MAX_POINTS` y `MAX_NPCS` al capturar o agregar nuevas entradas, emitiendo alertas localizadas (`ALERT_TARGET_LIMIT`, `ALERT_DISCOVERY_LIMIT`, `ALERT_DIALOGUE_LIMIT`) en los 7 idiomas. Capturar nuevamente un objetivo ya existente incrementa `requiredCount` sin consumir un nuevo slot.
   * `JournalEditorPane` (`GetSectionBadge`) renderiza dinámicamente `[%d/%d]` para Objetivos, Descubrimientos y Diálogos usando `Addon.Constants`.
3. **Poda de Mensajes Inactivos en `ShareCodec`:**
   * `PackTargetsBlock` y `EncodeTargetsList` solo serializan `customMessage` cuando `locationRequired == false`, y solo serializan `customMessageInLocation` / `customMessageOutsideLocation` cuando `locationRequired == true`. `UnpackTargetsBlock` conserva lectura retrocompatible.
4. **Nota sobre Locales UTF-8 Multi-Byte (`ru`, `jp`, `zh`, acentos):**
   * `EditBox:SetMaxInputChars` en EsoUI limita caracteres Unicode (codepoints), mientras que `BinaryCodec` / `ShareCodec` y `SendMail` operan sobre bytes UTF-8. En textos reales de roleplay, la compresión LZSS compensa el sobrecosto de bytes multi-byte en idiomas CJK/cirílicos; en el caso extremo de texto CJK/cirílico completamente aleatorio e incompresible, el contador dinámico de `JournalMailSendPane` (`MAIL_CHAR_COUNTER_OVER`) advierte al autor antes de enviar.

## Consecuencias
* **Positivas:**
  * Garantía matemática verificada por test automatizado: peor caso ASCII incompresible (`4/4/4` con `locationRequired = true` y todos los campos al 100% + `MAIL_ROLE_MESSAGE = 300`) cabe en `6/6` correos (`<= 4,104` caracteres).
  * Cero valores mágicos de longitud o capacidad repartidos en UI y localización.
* **Negativas / Trade-offs:**
  * Se reducen algunas longitudes máximas de texto respecto a los antiguos topes arbitrarios (ej. descripción de `400` a `250`, mensaje de rol de `700` a `300`), mitigado por la claridad narrativa y la garantía de entrega por correo.

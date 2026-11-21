---
status: accepted
date: 2026-11-21
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0008 - Códec Compacto RPQ3 (Empaquetado Binario + LZSS + Base85 Seguro)

## Contexto y Planteamiento del Problema
El códec `RPQ2` (`src/ShareCodec.lua`) serializa la misión en texto plano ASCII delimitado por `|`, `;` y `~` con escapes porcentuales y lo codifica en Base64Url (+33.3% de expansión). Con la incorporación de condiciones de ubicación y mensajes personalizados por objetivo (Issue #99) y futuras extensiones narrativas, los códigos `RPQ2` pueden superar el límite de 2.000 caracteres de Discord.

## Impulsores de la Decisión (Decision Drivers)
* **Zero-Dependency (ADR-0001):** Implementación 100% en Lua 5.1 puro (sin librerías externas ni `bit` C-extensions requeridas).
* **Compactación >= 45%:** Reducir significativamente la longitud final de los códigos frente a `RPQ2`.
* **Seguridad en Discord y ESO:** El alfabeto final debe ser imprimible ASCII y evitar delimitadores del sobre (`:`), caracteres de formato Markdown de Discord (`*`, `_`, `~`, `` ` ``, `|`, `>`, `\`) y tokens de formato de EsoUI (`|`, `<`, `>`).
* **Retrocompatibilidad y Estabilidad de `RPQC1`:** `DecodeQuest` debe seguir leyendo `RPQ1` y `RPQ2`, y `ComputeQuestSignature` debe mantener el determinismo de los comprobantes `RPQC1`.

## Decisión Adoptada
Se adopta el formato `RPQ3:<HEX_CRC16>:<PAYLOAD_BASE85>` como códec por defecto en `ShareCodec:EncodeQuest`, manteniendo `RPQ1` y `RPQ2` en `DecodeQuest`:

1. **Empaquetado Binario Compacto:**
   * Coordenadas normalizadas (`[0, 1]`): cuantizadas a `uint16` (`0..65535`, 2 bytes big-endian, error máximo `<= 0.00001`).
   * Enteros sin signo: varint LEB128 (`uvarint`); enteros con signo (`worldX`, `worldY`, `worldZ`): ZigZag + LEB128 (`svarint`).
   * Flags y presencia de bloques opcionales (`requireUndetected`, `hideMapArea`, `targets`, `discoveries`, `dialogues`, `completionMessage`, `clue`, `language`): empaquetados en bitmasks de 1 byte omitiendo bloques vacíos.
   * Cadenas UTF-8: longitud en `uvarint` seguida de bytes crudos sin escape porcentual.
2. **Compresión LZSS Byte-Aligned:**
   * Byte de cabecera de modo: `0x00` (binario crudo si no hubo ahorro) o `0x01` (flujo LZSS).
   * Bloques de 1 byte de flags (LSB a MSB para 8 tokens): literal (1 byte) o referencia `(offset 1..4096, length 3..18)` codificada en 2 bytes.
3. **Codificación Base85 Segura para Discord:**
   * Alfabeto de 85 caracteres imprimibles (`0-9A-Za-z!$%&+,-./;=?@^{}()[]#'"`), excluyendo espacios, `:`, `|`, `<`, `>`, `*`, `_`, `~`, `` ` `` y `\`.
   * Expansión fija de +25% (4 bytes -> 5 caracteres, con truncamiento estándar `k + 1` para bloques finales de `k = 1..3` bytes).
   * Checksum `CRC16` calculado sobre el binario comprimido antes de Base85.
4. **Estabilidad de `ComputeQuestSignature` / `RPQC1`:**
   * `ComputeQuestSignature` conserva la serialización canónica de `BuildQuestPayloadString` para no invalidar firmas ni comprobantes `RPQC1` existentes.

## Consecuencias
* **Positivas:**
  * Reducción superior al 45%–55% en longitud de caracteres respecto a `RPQ2` en misiones medianas y grandes.
  * Códigos seguros para copiar y pegar en Discord sin activar formato Markdown accidental.
  * Retrocompatibilidad total con códigos `RPQ1` y `RPQ2` y sin impacto en `RPQC1`.
* **Negativas / Trade-offs:**
  * Mayor complejidad interna en `ShareCodec.lua`, mitigada con pruebas unitarias exhaustivas de round-trip, LZSS, varints negativos, UTF-8 y payloads corruptos.

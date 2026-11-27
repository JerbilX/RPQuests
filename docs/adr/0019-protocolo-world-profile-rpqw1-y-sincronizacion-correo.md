---
status: accepted
date: 2026-11-27
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0019 - Protocolo RPQW1 de Perfil de Mundo y Sincronización por Correo

## Contexto y Planteamiento del Problema
En misiones creadas por un Master y enviadas a otros jugadores, el autor puede ubicar objetivos o puntos de descubrimiento en zonas de DLC/Capítulo que el jugador aún no posee, o en zonas donde el personaje receptor no tiene santuarios/POIs descubiertos. Sin conocer el estado de acceso del jugador, el Master no puede anticipar bloqueos de acceso ni problemas de desplazamiento.
Se requiere una capa base ligera que capture el perfil de zonas y POIs del jugador, lo transporte de forma compacta dentro del límite nativo de 700 caracteres de correo de ESO (`MAIL_MAX_BODY_CHARACTERS`) y lo persista en el Master separando datos por `@Cuenta` y por `Personaje`.

## Impulsores de la Decisión (Decision Drivers)
* **Zero-Dependency y Rendimiento In-Game:** Captura y codificación en `< 5 ms` usando únicamente APIs nativas de EsoUI (`GetNumZones`, `IsZoneCollectibleLocked`, `IsESOPlusSubscriber`, `GetNumPOIs`, `GetPOIMapInfo`), sin polling en `OnUpdate`.
* **Compactación < 200 caracteres Base85:** El snapshot debe caber holgadamente junto a comprobantes `RPQC1` (~65 caracteres) dentro de un único correo de 700 caracteres.
* **Modelo Híbrido Cuenta / Personaje:** El acceso a DLCs y el estado ESO+ pertenecen a la `@Cuenta`, mientras que los POIs descubiertos pertenecen a cada `Personaje` sin sobrescribir el historial de otros personajes de la misma cuenta.
* **Ingesta Silenciosa:** Los correos de perfil y los piggybacks no deben generar misiones pendientes ni ruido visual en la bandeja del Master.

## Opciones Consideradas
* **Opción A: Protocolo binario compacto `RPQW1` (LZSS + Base85) + correo `[RPQuest:Profile]` y piggyback en reportes `RPQC1`**
  * *Pro:* Payload típico < 200 caracteres Base85; cabe en un solo correo `[RPQuest:Accepted]` / `[RPQuest:Done]` sin partes `RPQP`; separación limpia `@Cuenta` / `Personaje` en `SavedVariables`.
  * *Contra:* Asume que los índices `zoneIndex` y `poiIndex` son deterministas entre clientes del mismo parche de ESO.
* **Opción B: Envío de listas de `zoneId` y `poiIndex` en texto plano JSON/CSV por correo multiparte `RPQP`**
  * *Pro:* Legible sin decodificador binario.
  * *Contra:* Supera ampliamente los 700 caracteres, requiere múltiples correos por cada actualización y añade latencia/spam al buzón.

## Decisión Adoptada
Opción elegida: **"Opción A (`RPQW1` + correo dedicado + piggyback silencioso)"**:

1. **Formato `RPQW1:<HEX_CRC16>:<PAYLOAD_BASE85>` (`src/WorldProfile.lua`, `src/BinaryCodec.lua`, `src/ShareCodec.lua`):**
   * Cabecera binaria: `version` (`uint8 = 1`), `flags` (`uint8`, bit 0 = `esoPlus`), `characterName` (`WriteStr`), `numZones` (`uvarint`), `dlcMask` (`WriteBitset` de `numZones` bits donde bit = `1` indica zona desbloqueada `not IsZoneCollectibleLocked(zoneIndex)`), `totalPois` (`uvarint`) y `poiMask` (`WriteBitset` de `totalPois` bits donde bit = `1` indica POI descubierto).
   * Compresión `BinaryCodec:CompressLZSS` + checksum `CRC16` + codificación `BinaryCodec:Base85Encode` (alfabeto seguro de ADR-0008).
2. **Persistencia Híbrida en `QuestRepository` (`savedVars.worldProfiles[accountName]`):**
   * Estructura por cuenta: `{ dlcMask = <base85>, esoPlus = <bool>, updatedAt = <timestamp>, characters = { [charName] = { poiMask = <base85>, updatedAt = <timestamp> } } }`.
   * Las máscaras `dlcMask` y `poiMask` se almacenan en Base85 ASCII imprimible para garantizar serialización segura en `RPQuest_SavedVariables`, preservando los demás personajes de `characters` al actualizar uno.
3. **Transporte e Ingesta (`src/MailTransport.lua`, `src/MailInbox.lua`, UI):**
   * Correo dedicado `[RPQuest:Profile] <Character>` con envío manual desde el botón **"Share World Profile"** en el diario y auto-ingesta silenciosa + borrado automático del correo en el Master.
   * Piggyback automático de `RPQW1` en `[RPQuest:Accepted]` y `[RPQuest:Done]` siempre que `code .. "\n" .. profileCode` no supere `GetMaxBodyLength()` (700 caracteres).

## Consecuencias
* **Positivas:**
  * Snapshot completo de DLCs y POIs en < 200 caracteres Base85 y < 5 ms de captura.
  * Cero tráfico adicional cuando el jugador acepta o completa misiones (piggyback gratuito dentro del reporte existente).
  * Base sólida para futuras validaciones de compatibilidad de zonas/POIs en el editor del Master.
* **Negativas / Trade-offs:**
  * La interpretación posicional de `dlcMask` y `poiMask` depende de que Master y Jugador ejecuten la misma versión/parche de ESO.

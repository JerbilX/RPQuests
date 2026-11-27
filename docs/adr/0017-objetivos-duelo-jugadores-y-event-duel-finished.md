---
status: accepted
date: 2026-11-26
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0017 - Objetivos de Duelo contra Jugadores y `EVENT_DUEL_FINISHED`

## Contexto y Planteamiento del Problema
Originalmente `RPQuest` (`ADR-0002`) restringía la captura bajo retícula exclusivamente a NPCs hostiles o atacables (`not IsUnitPlayer("reticleover")`), registrando el progreso mediante `EVENT_COMBAT_EVENT` (`ACTION_RESULT_DIED` / `ACTION_RESULT_DIED_XP`). Sin embargo, en duelos amistosos entre jugadores de ESO no se produce la muerte real de la unidad ni se disparan esos resultados de combate, impidiendo crear misiones de rol con objetivos de duelo PvP.

## Impulsores de la Decisión (Decision Drivers)
* **Compatibilidad con la API oficial de EsoUI:** Usar `EVENT_DUEL_FINISHED` y el enum `DuelResult` (`DUEL_RESULT_WON`, `DUEL_RESULT_FORFEIT`) sin dependencias externas.
* **Retrocompatibilidad del códec `RPQ3` y persistencia:** Preservar el formato binario `RPQ3` y las misiones existentes en `SavedVariables` sin migraciones disruptivas ni bytes adicionales por objetivo.
* **Separación limpia entre NPCs y duelos:** Evitar que una muerte en PvE/Cyrodiil cuente como duelo o que un duelo cuente para un NPC homónimo.

## Opciones Consideradas
* **Opción 1: Reutilizar el modelo de objetivos actual sin distinguir jugadores de NPCs.**
  * *Pro:* No requiere campo adicional en `targets[]` ni flag en el códec.
  * *Contra:* Al compartir la misión por correo (`RPQ3`), el receptor no sabría si el objetivo es de duelo, `CombatTracker` tendría que registrar `EVENT_DUEL_FINISHED` para cualquier misión, y la UI mostraría `"Eliminar a <jugador>"` en lugar de duelo.
* **Opción 2: Añadir `targets[].isPlayer` (boolean) y codificarlo en el bit 7 (`128`) de `tFlags` en `RPQ3` (Elegida).**
  * *Pro:* Cero bytes adicionales en `PackTargetsBlock` (el bit 7 de `tFlags` estaba libre), retrocompatibilidad total con códigos `RPQ3` previos (`0` = NPC), registro bajo demanda de `EVENT_DUEL_FINISHED` únicamente cuando hay objetivos de duelo pendientes, y formato específico en UI (`OBJECTIVE_DUEL_FORMAT`).
  * *Contra:* Consume el último bit libre de `tFlags` en `PackTargetsBlock` (futuras propiedades por objetivo requerirán un byte extendido).

## Decisión Adoptada
Opción elegida: **"Opción 2: Añadir `targets[].isPlayer` y codificarlo en el bit 7 (`128`) de `tFlags` en `RPQ3`"**:
1. **`TargetCapture`:** Permite capturar jugadores bajo retícula (`IsUnitPlayer("reticleover")`) siempre que no sean el jugador local (`not AreUnitsEqual("reticleover", "player")`) ni estén muertos (`not IsUnitDead("reticleover")`), omitiendo la comprobación de hostilidad/reacción de NPCs y marcando `isPlayer = true`.
2. **`CombatTracker`:** Registra `EVENT_DUEL_FINISHED` solo cuando la misión activa tiene al menos un objetivo pendiente con `isPlayer == true`. Contabiliza victoria local cuando `(duelResult == DUEL_RESULT_WON and wasLocalPlayersResult == true)` o `(duelResult == DUEL_RESULT_FORFEIT and wasLocalPlayersResult == false)`, normalizando `opponentCharacterName` e ignorando derrotas o rendiciones propias.
3. **`ShareCodec`:** Serializa `isPlayer` en el bit 7 (`128`) de `tFlags` dentro de `PackTargetsBlock` / `UnpackTargetsBlock`.

### Consecuencias
* **Positivas:**
  * Soporte nativo de objetivos de duelo entre jugadores con compartición por correo `RPQ3` intacta.
  * Cero impacto en misiones existentes y cero sobrecarga de eventos cuando no hay objetivos de duelo activos.
* **Negativas / Trade-offs:**
  * Se ocupa el bit 7 de `tFlags`; si en el futuro se agregan más flags por objetivo en `RPQ3`, deberá introducirse un byte de flags extendido opcional.

---
status: accepted
date: 2026-11-21
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0010 - Compartición de Misiones en Grupo y Registro de Objetivos Compartidos

## Contexto y Planteamiento del Problema
En RPQuest, cuando dos o más jugadores en grupo juegan una misma misión personalizada, no existe una acción directa en el Diario para compartir la misión con el grupo (análogo al keybind del Quest Journal vanilla) ni un mecanismo unificado para registrar objetivos compartidos (descubrimientos y bajas) realizados por compañeros de grupo.

## Impulsores de la Decisión (Decision Drivers)
* **Solo APIs Públicas (Zero-Dependency):** Prohibido depender de `SendChatMessage` (`private`) o librerías externas.
* **Paridad UX con el Diario Vanilla:** Exponer un keybind de "Compartir" (`UI_SHORTCUT_TERTIARY` / `SI_QUEST_JOURNAL_SHARE`) en `keybindStripDescriptor` visible cuando `IsUnitGrouped("player")` y haya una misión seleccionada en el detalle.
* **Sin Ruido Visual ni Spam:** Evitar abusar de `PingMap` o abrir diálogos modales en combate.

## Opciones Consideradas
* **Opción 1: Transporte de código `RPQ3` por `PingMap` o `StartChatInput` en `/group`.**
  * *Contra:* `SendChatMessage` es `private` (requiere interacción manual en chat) y `PingMap` genera pings visibles con rate-limiting.
* **Opción 2: Keybind "Compartir con Grupo" vía `MailTransport` (`RPQ3`) + Tracking de Grupo en `CombatTracker` y `DiscoveryTracker` (Aceptada).**
  * *Pro:* 100% API pública, reutiliza la infraestructura `RPQ3` + `MailTransport` con `@DisplayName` obtenido de `GetGroupUnitTagByIndex` + `GetUnitDisplayName`, y permite aceptar desde la bandeja de RPQuest (o auto-aceptar).
  * *Pro:* Los objetivos de descubrimiento y combate se sincronizan pasivamente mientras los miembros del grupo estén en rango/zona.
  * *Contra:* El correo in-game tiene una latencia de entrega de pocos segundos dentro del mismo megaserver y no sincroniza diálogos NPC ni bajas ocurridas fuera del rango de *combat log* de ESO (~60 m).

## Decisión
1. **Keybind en `JournalTab.lua`:** Agregar `shareWithGroupDescriptor` (`UI_SHORTCUT_TERTIARY`) en `keybindStripDescriptor`, visible cuando `IsUnitGrouped("player")` y hay misión seleccionada en vista detalle, que recopila los `@DisplayName` del grupo (excluyendo `"player"`) mediante `MailTransport:GetGroupMemberDisplayNames()` y envía la misión con `MailTransport:ShareQuestWithGroup(quest)`.
2. **Objetivos Compartidos en Grupo:**
   * **`DiscoveryTracker.lua`:** En `OnUpdateTick()`, además de `"player"`, evaluar `GetUnitWorldPosition(unitTag)` para cada miembro del grupo en la misma zona cuando `IsUnitGrouped("player")`.
   * **`CombatTracker.lua`:** Mantener `COMBAT_UNIT_TYPE_GROUP` y, cuando la baja proviene de un miembro del grupo (`sourceType == COMBAT_UNIT_TYPE_GROUP`), evaluar también la posición de los miembros del grupo (`GetUnitWorldPosition` para `targetLocation`) al validar la ubicación del objetivo.

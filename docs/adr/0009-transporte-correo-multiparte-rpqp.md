---
status: accepted
date: 2026-11-21
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0009 - Transporte de Correo Multi-Parte (RPQP) y Fallback RPQ3

## Contexto y Planteamiento del Problema
El sistema de correo nativo de ESO (`SendMail`) impone un límite estricto de 700 caracteres por cuerpo de mensaje (`MAIL_MAX_BODY_CHARACTERS`). Aunque el códec `RPQ3` (ADR-0008) compacta significativamente el payload, misiones con múltiples objetivos, diálogos o un mensaje de rol superan los 700 caracteres e impiden el envío por correo in-game.

## Impulsores de la Decisión (Decision Drivers)
* **Retrocompatibilidad:** Misiones de `<= 700` caracteres deben seguir enviándose en un único correo con el formato `[RPQuest] <Title>` sin cambios.
* **Zero-Dependency y 100% In-Game:** Mantener el flujo asíncrono por correo nativo de ESO sin depender de canales de chat visibles ni herramientas externas.
* **Límite Anti-Spam:** Evitar inundar el buzón o disparar límites de `SendMail` con envíos masivos.

## Decisión Adoptada
1. **Protocolo Multi-Parte `RPQP` en `MailTransport.lua`:**
   * Cuando `roleMessage + "\n\n" + questCode` (o `questCode` solo) supera `maxLen` (`700` chars), se divide el cuerpo completo en `N` fragmentos secuenciales (`1 <= N <= MAX_MAIL_PARTS`, con `MAX_MAIL_PARTS = 6`, ~4.000 caracteres útiles).
   * Cada parte se envía como un correo con:
     * Asunto: `[RPQuest <part>/<total>] <Title>`
     * Cuerpo: `RPQP:<txId>:<part>/<total>\n<chunk>` (donde `<txId>` es un identificador hexadecimal corto por envío).
   * Los correos se despachan secuencialmente mediante `_sendQueue` esperando `EVENT_MAIL_SEND_SUCCESS` entre cada envío.
2. **Reensamblado en Bandeja de Entrada (`ScanInbox` / `OnMailReadable`):**
   * Las partes recibidas se agrupan por `(senderDisplayName, txId, total)`.
   * Mientras falten partes, la bandeja muestra el estado parcial (`partsReceived/total`) sin habilitar `Accept` (pero permitiendo `Reject` para descartar/limpiar partes huérfanas).
   * Al recibir todas las partes `1..total`, se concatenan los fragmentos en orden, se extrae `roleMessage` y `questCode` con `ParseQuestMailBody`, y se decodifica como una única misión en `_receivedMails` asociando todos los `mailIds` del grupo para borrado/descarte atómico.
3. **Fallback Rápido `RPQ3` en UI:**
   * Si una misión excede `MAX_MAIL_PARTS` (o el usuario prefiere compartir por Discord), el panel de envío ofrece un botón **Copy RPQ3 Code** que muestra y selecciona el código `RPQ3` listo para `Ctrl+C`.

## Consecuencias
* **Positivas:**
  * Permite enviar misiones de hasta ~4.000 caracteres (~5.7x el límite nativo) de forma transparente por correo in-game.
  * Mantiene 1 correo único para misiones pequeñas (`<= 700` chars).
* **Negativas / Trade-offs:**
  * Misiones extremadamente largas (> ~4.000 chars) siguen requiriendo copia manual `RPQ3` vía Discord, mitigado con el botón de fallback en el mismo panel.

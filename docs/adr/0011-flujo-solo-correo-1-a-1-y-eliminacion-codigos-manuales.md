---
status: accepted
date: 2026-11-21
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0011 - Flujo 100% por Correo In-Game (1-a-1) y Eliminación de Códigos Manuales en UI

## Contexto y Planteamiento del Problema
En versiones previas de RPQuest existían múltiples canales paralelos para compartir y validar misiones: copia/pegado manual de códigos `RPQ3` / `RPQC1` en la UI, bandeja manual de correo (`_receivedMails`), envío por lotes a 1–4 destinatarios y compartición en grupo. Esto añadía fricción para los jugadores, duplicaba pantallas en `JournalTab` y generaba problemas de sincronización.

## Impulsores de la Decisión (Decision Drivers)
* **UX Nativa Sin Fricción:** El jugador debe recibir misiones directamente en su lista de misiones (`Pending`) y poder aceptarlas o rechazarlas con un clic sin copiar ni pegar cadenas externas.
* **Flujo Predecible 1-a-1 (1 Master -> 1 Jugador):** Cada misión preparada se asigna a un único destinatario `@Account` desde el editor y muestra claramente su estado (`Draft` / `Sent` / `Completed` / `Rejected`).
* **Reportes Automáticos Bidireccionales:** Tanto la finalización como el rechazo de una misión se notifican automáticamente al Master por correo interno (`RPQC1`) sin intervención manual.

## Opciones Consideradas
* **Opción 1: Mantener UI híbrida (correo + cajas manuales de copiar/pegar `RPQ3` / `RPQC1`).**
  * *Contra:* Mantiene paneles y botones redundantes (`BuildImportPane`, `BuildMailInboxPane`, `shareEdit`, `deliveryEdit`, `validateEdit`, `btnCopyMailCode`) que confunden al usuario y duplican rutas de código.
* **Opción 2: UX 100% por correo in-game con `ShareCodec` como capa interna de serialización (Aceptada).**
  * *Pro:* Elimina toda fricción manual en `JournalTab`, unifica el ciclo de vida en `OFFERED -> ACTIVE -> COMPLETED / REJECTED`, y conserva `ShareCodec` (`RPQ3` / `RPQC1`) internamente para `MailTransport` (`RPQP` multiparte).
  * *Contra:* Requiere que ambos jugadores pertenezcan al mismo megaserver (PC-NA o PC-EU) para el transporte por correo in-game.

## Decisión
1. **Ingesta Automática (`OFFERED`):** `MailTransport` ingesta automáticamente los correos válidos de misión en `QuestRepository` con estado `OFFERED` (con deduplicación por `sourceMailId`), mostrando los botones **Aceptar** y **Rechazar** directamente en el detalle de `JournalTab`.
2. **Reportes Automáticos (`COMPLETED` / `REJECTED`):** Al completar o rechazar una misión recibida de un Master, `MailTransport` envía automáticamente un correo `RPQC1` (`[RPQuest:Done]` o `[RPQuest:Rejected]`) al remitente original, que el Master procesa automáticamente actualizando `lastResult` en la misión preparada.
3. **UI Solo-Correo en `JournalTab`:** Se retiran `BuildImportPane`, `BuildMailInboxPane`, `shareEdit`, `deliveryEdit`, `validateEdit` y `btnCopyMailCode`. `ShareCodec` permanece exclusivamente como capa interna de serialización para `MailTransport`.

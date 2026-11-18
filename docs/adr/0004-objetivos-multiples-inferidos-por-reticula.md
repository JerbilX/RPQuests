---
status: accepted
date: 2026-11-18
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0004 - Objetivos Múltiples y Cantidad de Bajas Inferida por Captura de Retícula

## Contexto y Planteamiento del Problema
Durante la validación en el cliente de Elder Scrolls Online de la pestaña de misiones custom en el Diario (`ZO_QuestJournal`), se identificó que:
1. Manejar la cantidad de bajas (`Kills Required`) mediante un control numérico manual en la interfaz impide definir misiones con varios NPCs específicos con nombre y obliga al usuario a ajustar contadores manualmente en lugar de seleccionarlos de forma natural en el mundo.
2. Los controles `CT_EDITBOX` creados dinámicamente mediante `WINDOW_MANAGER:CreateControl` requieren habilitar explícitamente eventos de ratón (`SetMouseEnabled(true)`), edición (`SetEditEnabled(true)`) y toma de foco (`OnMouseDown -> TakeFocus()`) para ser editables en EsoUI.

## Impulsores de la Decisión (Decision Drivers)
* **Selección Inmersiva por Retícula:** La definición de objetivos y sus cantidades debe surgir exclusivamente de los NPCs que el jugador apunta y captura con la tecla asignada (`RPQUEST_CAPTURE_TARGET`).
* **Soporte Dual (NPCs con Nombre y Enemigos Genéricos):**
  * Si el jugador apunta y captura a dos NPCs con nombres distintos, los objetivos de la misión son esos dos exclusivamente (`1` cada uno).
  * Si el jugador apunta y captura a un mismo tipo de NPC (ej. `Imp`) 3 veces, el objetivo se acumula automáticamente como `Imp x3` (`requiredCount = 3`).
* **Compatibilidad con `ShareCodec` (`RPQ1`):** El protocolo de compartición por código debe serializar y reconstruir la lista de objetivos inferidos manteniendo retrocompatibilidad con códigos de un único objetivo.

## Opciones Consideradas
* **Opción 1: Mantener un único objetivo por misión y el selector manual `Kills Required` en el Editor.**
  * *Pro:* Estructura plana de un solo string.
  * *Contra:* Descartada por requerimiento explícito del Arquitecto; no permite misiones con múltiples objetivos con nombre ni inferencia directa desde la retícula.
* **Opción 2: Inferir una lista agregada de objetivos (`targets`) desde las capturas de retícula y eliminar el control manual `Kills Required` del Editor (Elegida).**
  * *Pro:* Elimina fricción de UI, soporta tanto objetivos múltiples con nombre como acumulación automática (`Imp x3`) al capturar repetidamente, y mantiene un área de búsqueda cartográfica unificada con offset.
  * *Contra:* Requiere iterar sobre `quest.targets` al registrar bajas en `CombatTracker` y al renderizar el progreso en Diario, HUD Tracker y Mapa.

## Decisión Adoptada
Opción elegida: **"Opción 2: Inferir una lista agregada de objetivos (`targets`) desde las capturas de retícula y eliminar el control manual `Kills Required` del Editor"**, porque alinea el modelo de dominio con el flujo natural de selección en el mundo de ESO y simplifica el formulario de creación (`Create Quest`).

### Especificaciones Técnicas
1. **Acumulación e Inferencia en `QuestRepository:SetDraftCapturedTarget`:**
   * Cada captura válida bajo retícula normaliza el nombre del NPC (`cleanName`).
   * Si en `draft.targets` ya existe una entrada con el mismo nombre (comparación case-insensitive), se incrementa su `requiredCount = requiredCount + 1`.
   * Si no existe, se agrega `{ name = cleanName, currentCount = 0, requiredCount = 1, targetX = x, targetY = y }` a `draft.targets`.
   * El centro del área de búsqueda (`areaCenterX`, `areaCenterY`) se calcula aplicando el offset determinista sobre el centroide de los objetivos capturados en el mapa.
2. **Condición de Progreso y Completado (`RecordTargetEliminated`):**
   * Al morir un NPC dentro del área de búsqueda de la misión activa, se busca en `activeQuest.targets` el objetivo cuyo nombre coincida y aún tenga `currentCount < requiredCount`.
   * Se incrementa su `currentCount` en `1`. La misión pasa a `completed = true` únicamente cuando **todos** los objetivos de `activeQuest.targets` alcanzan su `requiredCount`.
3. **Interactividad de `EditControl` y UI del Editor (`JournalTab`):**
   * Todos los `CT_EDITBOX` creados en `CreateEditBoxWithBackdrop` activan `SetMouseEnabled(true)`, `SetEditEnabled(true)` y handlers `OnMouseDown` (`TakeFocus()`), `OnEscape` (`LoseFocus()`) y `OnTextChanged` sincronizado con el borrador.
   * Se retira el selector manual `Kills Required` de la vista del editor, se añade la visualización de la lista de objetivos inferidos (ej. `Imp x3`, `Capitán Pirata`) junto con un botón para limpiar la selección de objetivos si se desea re-capturar, y el botón de confirmación se renombra a `Create Quest` (`Crear Misión`).

### Consecuencias
* **Positivas:**
  * Los campos de título y descripción son 100% editables con clic y teclado en el cliente real de ESO.
  * El jugador puede armar misiones de asesinato múltiple o caza por cantidad simplemente apuntando y pulsando la tecla de captura en el mundo.
* **Negativas / Trade-offs:**
  * Se mantiene sincronizado `quest.targetName`, `quest.currentCount` y `quest.requiredCount` como resumen agregado del modelo para preservar retrocompatibilidad con llamadas e inspecciones existentes.

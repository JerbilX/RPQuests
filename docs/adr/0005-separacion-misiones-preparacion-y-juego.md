---
status: accepted
date: 2026-11-18
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0005 - Separación de Misiones en Preparación (Autoría) y Para Jugar (Recibidas)

## Contexto y Planteamiento del Problema
Hasta ahora todas las misiones en `RPQuest` (tanto las creadas localmente por el autor/GM para enviar como las importadas vía código `RPQ1:...`) se almacenaban y listaban juntas en la columna izquierda de `JournalTab`, diferenciadas únicamente por su estado `completed`. Esto generaba tres problemas:
1. Mezcla visual entre misiones en construcción y misiones recibidas para jugar.
2. Al guardar una misión nueva, esta se activaba automáticamente en el HUD y mapa del autor.
3. Quien recibía una misión por código podía editarla libremente.

## Impulsores de la Decisión (Decision Drivers)
* **Claridad de Flujo sin Saturar la Barra Nativa:** Mantener una sola pestaña de `RPQuest` en `QUEST_JOURNAL_KEYBOARD.tabs` pero separar claramente los dos contextos dentro de la columna izquierda.
* **Prueba Previa Segura (GM Workflow):** El autor debe poder probar localmente (activar, ver área en mapa, matar objetivos y reiniciar) una misión en preparación antes de generar/enviar su código `RPQ1:...`.
* **Integridad de Misiones Recibidas:** Quien importa una misión para jugar no debe poder editar su título, descripción, objetivos ni área.
* **Compatibilidad Retroactiva:** No romper el formato `RPQ1:...` de `ShareCodec` ni las misiones ya guardadas en `RPQuest_SavedVariables`.

## Opciones Consideradas
* **Opción 1: Selector de 2 sub-vistas (`Para Jugar` / `En Preparación`) en la columna izquierda de `JournalTab` (Elegida).**
  * *Pro:* Separa completamente las listas aprovechando el espacio de `MAX_VISIBLE_ROWS`, permite acciones específicas por rol en el panel de detalle y no agrega pestañas extra en el Diario nativo de ESO.
  * *Contra:* Requiere un clic para alternar entre vistas.
* **Opción 2: Lista única con 3 secciones (Activas, En Preparación, Completadas).**
  * *Pro:* Cero clics para ver todo.
  * *Contra:* Compite por las 14 filas visibles y mantiene mezclados ambos contextos.
* **Opción 3: Dos pestañas independientes en `QUEST_JOURNAL_KEYBOARD.tabs`.**
  * *Pro:* Separación total a nivel de escena.
  * *Contra:* Ocupa espacio adicional en la barra superior nativa del Diario de ESO.

## Decisión Adoptada
Opción elegida: **Separación de roles en modelo de datos (`QUEST_ROLE`) + Árbol Colapsable Player-First en la columna izquierda de `JournalTab`** (evolución de la Opción 2 alineada con el `ZO_Tree` nativo de ESO).

1. **Modelo de Datos (`src/Constants.lua` y `src/QuestRepository.lua`):**
   * Se incorpora el campo `role` en cada misión con valores `QUEST_ROLE.PREPARED` (`"prepared"`) y `QUEST_ROLE.RECEIVED` (`"received"`).
   * `SaveDraft()` al crear una nueva misión la guarda con `role = "prepared"` y **no** la asigna como `activeQuestId`.
   * `ImportQuestFromCode()` guarda la misión con `role = "received"`.
   * En `QuestRepository:Initialize()`, toda misión existente sin `role` válido migra por defecto a `"received"`.
   * `LoadQuestIntoDraft(questId)` rechaza misiones `"received"` devolviendo `nil, ERR_CANNOT_EDIT_RECEIVED`.
   * `ShareCodec` (`RPQ1:...`) no cambia su payload: el rol es local al cliente.
2. **Interfaz de Diario (`src/JournalTab.lua`):**
   * La barra superior prioriza el flujo del jugador con **Importar** como acción principal y **+ Nueva** a su lado para el máster.
   * La columna izquierda utiliza categorías colapsables con los iconos nativos de árbol de ESO (`tree_open_up.dds` / `tree_closed_up.dds`):
     * **MISIONES (`N`)** (expandida por defecto): misiones recibidas e incompletas.
     * **COMPLETADAS (`K`)** (colapsada por defecto, oculta si `K == 0`): misiones recibidas ya completadas.
     * **PREPARANDO (`M`)** (colapsada por defecto, oculta si `M == 0`): misiones en preparación del máster; se expande automáticamente al crear una nueva misión.
   * En **PREPARANDO**: el detalle muestra el botón de activación etiquetado como **Probar / Dejar de probar**, junto con **Ver en Mapa**, **Compartir**, **Editar**, **Reiniciar** y **Eliminar**.
   * En **MISIONES / COMPLETADAS**: el detalle oculta el botón **Editar** y reancla **Reiniciar** y **Eliminar** para no dejar huecos visuales.

## Consecuencias
* **Positivas:**
  * Flujo limpio para autores/GMs (crear -> probar -> reiniciar si hace falta -> compartir código) y para jugadores (importar -> jugar sin alterar la misión).
  * Cero cambios de protocolo en `ShareCodec`.
* **Negativas / Trade-offs:**
  * Misiones creadas antes de esta versión aparecerán inicialmente en *Para Jugar* tras la migración por defecto.

---
status: accepted
date: 2026-11-20
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0007 - Diálogos de RPQuest Inyectados en NPCs Nativos y Área en Mapa Opcional

## Contexto y Planteamiento del Problema
`RPQuest` permite crear misiones de combate, sigilo y puntos de descubrimiento ocultos, pero no integra diálogos propios dentro de la ventana nativa de interacción con NPCs de Elder Scrolls Online (`EVENT_CHATTER_BEGIN`). En misiones de investigación o roleplay, poder preguntar a NPCs existentes del mundo (mercaderes, guardias, banqueros, NPCs de ambientación con `[E]`) por una pista compartida —y opcionalmente ocultar el área de búsqueda en el mapa— convierte la interacción con el mundo en parte de la narrativa sin bloquear la progresión.

## Impulsores de la Decisión (Decision Drivers)
* **Integración Nativa Segura:** En `EsoUI`, `ZO_SharedInteraction:HandleChatterOptionClicked` ejecuta directamente cualquier `optionIndex` de tipo `function` sin invocar `SelectChatterOption` al servidor.
* **Cero Keybinds Extra ni Escritura Manual de Nombres:** Capturar automáticamente el último NPC con el que se abrió interacción nativa (`EVENT_CHATTER_BEGIN`), registrando nombre normalizado y `zoneId`, para añadirlo con un clic en el formulario.
* **Opcionalidad Narrativa:** Hablar con los NPCs configurados (0 a 3 por misión) es opcional y no bloquea el cumplimiento ni la finalización de la misión.
* **Área en Mapa Opcional (`hideMapArea`):** Permitir ocultar el pin de área en `WorldMapArea` cuando el creador desee que el jugador investigue mediante diálogos.
* **Compatibilidad Retroactiva:** Extender `ShareCodec` a `RPQ2` manteniendo lectura completa de códigos `RPQ1`.

## Decisión Adoptada
1. **Modelo de Dominio (`Constants.lua` y `QuestRepository.lua`):**
   * Se añade `DIALOGUE.MAX_NPCS = 3` en `Constants.lua` y `SHARE_CODEC.PREFIX = "RPQ2"` (`LEGACY_PREFIX = "RPQ1"`, `VERSION = 2`).
   * Cada misión y el borrador incorporan:
     * `clue` (string): pista compartida (ej. `"el contrabandista"`).
     * `hideMapArea` (boolean, por defecto `false`): cuando es `true`, `WorldMapArea` no dibuja el área de búsqueda.
     * `dialogues` (lista de 0 a 3 entradas `{ npcName, zoneId, response }`): NPCs con interacción nativa y su respuesta ante la pista.
   * `QuestRepository` mantiene en memoria de sesión `lastInteractedNpc = { name, zoneId }` actualizado desde `DialogueInjector` al dispararse `EVENT_CHATTER_BEGIN`.
2. **Motor de Inyección de Diálogos (`src/DialogueInjector.lua`):**
   * Registra `EVENT_CHATTER_BEGIN` para capturar el último NPC interactuado (`GetUnitName("interact")` normalizado + `zoneId` vía `GetUnitWorldPosition("player")` o fallback de zona).
   * Envuelve `PopulateChatterOptions`, `PopulateChatterOption` y `FinalizeChatterOptions` sobre `ZO_Interaction` (teclado) y `ZO_GamepadInteraction` (gamepad, si existe) para inyectar la opción `"Preguntar por <pista>"` (`CHATTER_TALK_CHOICE`) justo antes de `CHATTER_GOODBYE`, respetando `MAX_CHATTER_OPTIONS`.
   * Solo inyecta opciones para la **misión activa** (`completed == false`) cuyo `clue` no esté vacío y cuyo NPC coincida en `npcName` normalizado (y `zoneId` si es `> 0`).
   * Al seleccionarse la opción, la función callback actualiza el texto del cuerpo de la ventana de diálogo (`TargetAreaBodyText` en teclado / `textControl` en gamepad) con la respuesta configurada del NPC, sin cerrar la ventana ni llamar a `SelectChatterOption`.
3. **Serialización (`ShareCodec.lua`):**
   * `RPQ2` añade al payload los campos 15 (`clue`), 16 (`hideMapArea`: `"1"`/`"0"`) y 17 (`dialogues` codificados como `npcName~zoneId~response` separados por `;`).
   * `DecodeQuest` acepta tanto `RPQ2` como `RPQ1` (rellenando valores por defecto para misiones `RPQ1`).
4. **Limitaciones Conocidas:**
   * Solo funciona con NPCs que abren ventana de interacción nativa (`[E]` / `EVENT_CHATTER_BEGIN`); los NPCs que solo responden con *bark* sin ventana no disparan `EVENT_CHATTER_BEGIN`.
   * La inyección es estrictamente *client-side* para quienes tengan `RPQuest` e importen la misión.
   * Si un NPC ya alcanza el tope nativo `MAX_CHATTER_OPTIONS`, la opción de `RPQuest` no se inyecta para no desbordar los controles del motor.

## Consecuencias
* **Positivas:**
  * Enriquece las misiones de rol e investigación reutilizando NPCs vivos del mundo sin UI invasiva.
  * Mantiene compatibilidad total con códigos `RPQ1` existentes y con ambos modos de entrada (teclado y gamepad).
* **Negativas / Trade-offs:**
  * Depende de los nombres de NPC localizados en el cliente del jugador (`GetUnitName("interact")`), por lo que creador y jugador deben usar el mismo idioma de cliente si el NPC tiene traducción distinta.

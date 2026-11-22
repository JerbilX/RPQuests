---
status: superseded by ADR-0012
date: 2026-11-18
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: ["0012-savedvars-account-wide-y-migracion-por-personaje.md"]
---

# 0001 - Arquitectura Modular Zero-Dependency, Persistencia por Personaje e Internacionalización

## Contexto y Planteamiento del Problema
Se requiere construir el addon `RPQuest` para Elder Scrolls Online (EsoUI) permitiendo crear, gestionar, completar y compartir misiones personalizadas de rol (RP). Una versión anterior del proyecto (`ESORPQuestAddon`) sufrió alto acoplamiento monolítico y regresiones en el juego al retirar librerías de terceros (`LibMapPins`, `CustomCompassPins`, `LibDeflate`), donde las pruebas unitarias pasaban sobre mocks permisivos pero el cliente real fallaba.

Es necesario definir una arquitectura desde cero (*Greenfield*) que opere de forma 100% nativa sobre el motor EsoUI (`APIVersion 101051`), con separación estricta de responsabilidades, persistencia aislada por personaje y soporte multi-idioma configurable mediante archivos dedicados.

## Impulsores de la Decisión (Decision Drivers)
* **Cero Librerías Externas:** Prohibición absoluta de dependencias de terceros (`## DependsOn:`); uso exclusivo de APIs documentadas de EsoUI.
* **Desacoplamiento y Modularidad:** Separación clara entre capa de dominio/estado (`QuestRepository`, `ShareCodec`), captura/eventos (`TargetCapture`, `CombatTracker`) y presentación (`JournalTab`, `WorldMapArea`, `HudTracker`, `Announcements`).
* **Aislamiento por Personaje:** Cada personaje del jugador debe poseer su propia lista de misiones custom y progreso independiente.
* **Internacionalización Configurable:** Soporte nativo para Español (`es`) e Inglés (`en`) según el idioma activo del juego, extensible mediante archivos adicionales en `lang/`.

## Opciones Consideradas
* **Opción 1: Reutilizar y limpiar la base de código anterior (`ESORPQuestAddon`).**
  * *Pro:* Aprovecha fragmentos de interfaz ya escritos.
  * *Contra:* Arrastra acoplamiento implícito, cálculos de coordenadas heredados de librerías eliminadas y estructuras monolíticas difíciles de mantener.
* **Opción 2: Arquitectura Greenfield modular bajo el namespace único `RPQuest` (Elegida).**
  * *Pro:* Diseño limpio con contratos explícitos entre módulos, cero polución del espacio global `_G`, persistencia por personaje mediante `ZO_SavedVars:NewCharacterIdSettings` y localización desacoplada en `lang/en.lua` y `lang/es.lua`.
  * *Contra:* Requiere implementar todos los módulos desde cero, mitigado con una suite de pruebas unitarias hermética y validación estática con `eso_validate_addon`.

## Decisión Adoptada
Opción elegida: **"Opción 2: Arquitectura Greenfield modular bajo el namespace único `RPQuest`"**, porque garantiza bajo acoplamiento, alta cohesión y alineación 100% fiel con los contratos nativos de EsoUI sin arrastrar deuda técnica.

### Especificaciones Arquitectónicas
1. **Namespace Único (`RPQuest`):** Ningún módulo declara símbolos globales fuera de `RPQuest` (excepto las funciones de `Bindings.xml` prefijadas o invocadas como métodos de `RPQuest`).
2. **Persistencia por Personaje:** Inicialización mediante `ZO_SavedVars:NewCharacterIdSettings("RPQuest_SavedVariables", 1, nil, defaults)` dentro del ciclo `EVENT_ADD_ON_LOADED`.
3. **Sistema de Localización (`lang/` + `src/Locale.lua`):**
   * `lang/en.lua` define el diccionario base completo en inglés.
   * `lang/es.lua` define la traducción completa al castellano.
   * `src/Locale.lua` detecta el idioma activo del cliente mediante `GetCVar("language.2")` (con fallback seguro a `"en"` si el cliente está en un idioma no soportado o falta alguna clave) y registra las cadenas de `Bindings.xml` vía `ZO_CreateStringId`.

### Consecuencias
* **Positivas:**
  * Módulos pequeños, cohesivos y verificables de forma aislada.
  * Agregar un nuevo idioma en el futuro solo requiere añadir `lang/<codigo>.lua` al manifiesto.
  * Aislamiento total de misiones y progreso entre distintos personajes de una misma cuenta.
* **Negativas / Trade-offs:**
  * La ausencia de librerías externas de compresión exige un códec propio ligero en Lua puro (documentado en `ADR-0002`).

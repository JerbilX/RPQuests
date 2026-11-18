---
name: eso-addon-development
description: >-
  Canonical engineering guide and workflow for Elder Scrolls Online (ESO / EsoUI) addon development in Lua and XML. Read this skill before starting any task, API lookup, scaffolding, UI design, testing, or code change in an ESO addon project.
---

# Elder Scrolls Online (ESO) Addon Engineering

Guía rectora para el desarrollo de addons en Lua y XML sobre el motor de interfaz de ZeniMax Online Studios (**EsoUI**). Emplea divulgación progresiva con referencias detalladas en `references/`.

---

## 1. Jerarquía de Consulta de API y Fuentes de Verdad

Para resolver dudas sobre funciones, eventos, controles XML, constantes, texturas, sonidos o implementaciones nativas de ZOS, sigue este orden:

### Nivel 1 — Contexto Local del Addon
* El código del proyecto define la arquitectura interna del addon.
* Los mocks locales en `tests/mocks/` son emulaciones de soporte para pruebas unitarias en Lua/LuaJIT; **nunca son la fuente de verdad de la API de EsoUI**.

### Nivel 2 — Servidor MCP (`eso-mcp-server` / `eso-addon-suite`)
El servidor MCP indexa la documentación oficial (`ESOUIDocumentation.txt`), el árbol completo de código fuente de `esoui`, las cadenas `SI_*`, texturas `.dds` y sonidos `SOUNDS.*`. **Prioriza siempre las herramientas del MCP antes de buscar en archivos crudos o en la web:**

1. **API, Eventos, Constantes y Controles XML:**
   * `eso_search_api(query, category="all", limit=25)`: Búsqueda general filtrable por `all`, `function`, `constant`, `event`, `object`, `xml`.
   * `eso_get_function(name, object_name=None)`: Firma exacta, parámetros, retornos y cadena de herencia de métodos UI (`Control` -> `ButtonControl`, etc.).
   * `eso_get_event(event_name)`: Firma del callback y tipos de parámetros de cualquier `EVENT_*`.
   * `eso_get_constant(name)` y `eso_get_enum(category_name)`: Inspección de constantes y familias de enums (`ItemType`, `SpecializedItemType`, `EquipType`, etc.).
   * `eso_get_ui_control(control_name, include_inherited=True)`: Especificación completa de controles XML (`Control`, `TopLevelControl`, `Backdrop`, `Button`, `Label`, `EditBox`, etc.), atributos válidos y elementos hijos permitidos.
   * `eso_search_strings(query, by_text_only=False, limit=25)`: Mapeo entre identificadores `SI_*` y su texto en inglés.
   * `eso_api_stats()`: Versión activa de API (`APIVersion`) y estado del índice.

2. **Código Fuente Oficial de ZOS (`esoui`):**
   * `eso_search_ui_source(query, file_pattern=None, subpath=None, limit=25, is_regex=False, case_sensitive=False)`: Busca patrones, managers (`QUEST_JOURNAL_MANAGER`, `SCENE_MANAGER`), escenas o templates XML en el código oficial de EsoUI.
   * `eso_get_ui_source(file_path, symbol=None, start_line=None, end_line=None, max_lines=200)`: Lee la implementación real de ZOS.
     * **Regla de paginación:** Pide rangos acotados (`start_line`/`end_line`, `max_lines`) o indica `symbol` para no saturar el contexto ni truncar la salida JSON.
   * `eso_get_ui_modules()`: Lista los módulos principales del árbol `esoui`.

3. **Catálogos de Texturas e Iconos (`.dds`) y Sonidos (`SOUNDS.*`):**
   * `eso_search_textures(query, category=None, limit=25)` y `eso_get_texture_categories()`: Localiza rutas canónicas `/esoui/art/...` para iconos, bordes, fondos y botones.
   * `eso_search_sounds(query, category=None, limit=25)` y `eso_get_sound_categories()`: Localiza constantes válidas `SOUNDS.*` para feedback auditivo con `PlaySound(SOUNDS.XXX)`.

4. **Scaffolding, Linting Estático y Empaquetado:**
   * `eso_scaffold_addon(...)`: Genera la estructura inicial canónica de un addon (`.txt`/`.addon`, `.lua`, `.xml` opcional y `tests/run.lua`).
   * `eso_scaffold_test_harness(addon_path, target_dir=None, overwrite=False)`: Genera o actualiza `tests/mocks/eso_ui_mock.lua` con mocks herméticos de EsoUI.
   * `eso_lint_code(code, addon_namespace=None, file_path=None)`: Audita código Lua contra la API oficial (detecta funciones/eventos/constantes inexistentes o deprecadas, errores en `SOUNDS.*` y polución del namespace global `_G`).
   * `eso_lint_xml(xml_content, file_path=None)`: Audita layouts XML (`GuiXml`) verificando tags, jerarquía de contenedores (`<Controls>`, `<Dimensions>`, `<Anchor>`) y tipos de atributos.
   * `eso_validate_addon(addon_path, addon_namespace=None)`: Ejecuta validación estática integral sobre todos los archivos `.lua` y `.xml` del addon.
   * `eso_package_addon(addon_path, output_dir=None, zip_name=None, validate_first=True)`: Empaqueta el addon en un archivo `.zip` limpio y compatible con Minion/ESOUI.

5. **Inspección de `SavedVariables` (Solo Lectura):**
   * `eso_savedvars_inspect`, `eso_savedvars_get_account_wide`, `eso_savedvars_get_character`, `eso_savedvars_query`.

### Nivel 3 — Fallback de Archivos Locales y Web
* **Archivos Locales:** Si en algún entorno el servidor MCP no estuviera disponible o se necesitara lectura directa en el workspace, utiliza `eso_init_project_references()` para aprovisionar `references/` localmente.
* **Búsqueda Web (Último Recurso):** Reservada únicamente cuando una librería de terceros (ej. `LibAddonMenu-2.0`, `LibMapPins`, `LibChatMessage`) o un detalle externo no figure en el índice de `esoui` del MCP.

---

## 2. Guardrails Operativos y Circuit Breaker

* **Edición Quirúrgica (`edit_file` obligatorio sobre archivos existentes):** Al modificar archivos `.lua` o `.xml` existentes, utiliza **siempre `edit_file`** sobre los bloques o funciones afectadas. Queda **prohibido usar `write_file` (`Overwrite: true`) para reescribir un archivo existente completo**, ya que desperdicia miles de tokens de salida y arriesga introducir regresiones o errores tipográficos en código que no debía tocarse.
* **Invocación Nativa del MCP (`call_mcp_tool`) y Cero Sobre-Exploración:**
  * Invoca las herramientas `eso_*` directamente mediante `call_mcp_tool` (`ServerName: "eso-addon-suite_eso-mcp-server"`), evitando lanzar subprocesos `python3 -c` por terminal (`run_command`).
  * **Búsqueda Guiada por Hipótesis y Corte Temprano:** Antes de usar `eso_search_ui_source`, formula qué sistema o template de EsoUI buscas. En cuanto una consulta confirme la firma de la API o el template XML buscado, **corta la exploración y pasa directamente a implementar el cambio** sin seguir inspeccionando archivos no relacionados.
* **Circuit Breaker ante Búsquedas Fallidas (Stop & Ask):**
  * Puedes utilizar libremente todas las herramientas del MCP necesarias cuando cada llamada aporte información válida al flujo (buscar API -> inspeccionar fuente -> validar con linter).
  * Sin embargo, si realizas **3 búsquedas consecutivas sin éxito** intentando encontrar una función, evento o símbolo que no aparece en el índice, **detente y consulta al usuario** en lugar de adivinar firmas o entrar en un bucle de pruebas ciegas.
  * **Prohibido inventar APIs:** Nunca asumas que existe una función `Get*`/`Set*` o evento `EVENT_*` sin verificar su firma en el MCP.
* **Validación Obligatoria Post-Edición y Empaquetado Único:**
  * Tras crear o modificar archivos `.lua` o `.xml`, ejecuta `eso_validate_addon` (o `eso_lint_code` / `eso_lint_xml`) y la suite de pruebas directamente con **`luajit tests/run.lua`** (no pruebes `lua` antes si el entorno usa LuaJIT).
  * En iteraciones de UI/UX donde el usuario está probando en vivo dentro del juego (`/reloadui`), aplica los cambios y pasa los tests primero para que el usuario valide in-game; ejecuta `eso_package_addon` una sola vez al cerrar/empaquetar la entrega.

---

## 3. Referencias Especializadas

Lee estos documentos cuando trabajes en la arquitectura del código, interfaz XML, pruebas o empaquetado:

| Dominio | Contenido | Referencia |
| :--- | :--- | :--- |
| **Arquitectura Lua y UI** | Aislamiento de namespace (`_G`), ciclo `EVENT_ADD_ON_LOADED`, `SavedVariables`, `ZO_PreHook`/`ZO_PostHook`, rendimiento/GC, centralización en `Constants.lua` y jerarquía `CT_TOPLEVELCONTROL`. | [references/lua-architecture.md](references/lua-architecture.md) |
| **Testing, Build y Empaquetado** | Sincronización de manifiesto y `README.md`, uso de `@BUILD_VERSION@`, empaquetado con `eso_package_addon`, prevalencia de EsoUI sobre mocks y estándares del arnés de pruebas (`tests/run.lua`). | [references/build-and-packaging.md](references/build-and-packaging.md) |

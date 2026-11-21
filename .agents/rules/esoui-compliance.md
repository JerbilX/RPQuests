---
trigger: always_on
---

# Regla de Compliance ESOUI (RPQuest)

Estándares obligatorios de desarrollo, localización, verificación y auditoría (`pr-reviewer`) para prevenir regresiones de moderación en ESOUI / *Baertram Addon Check*. Esta regla complementa a [release-and-docs.md](./release-and-docs.md).

## 1. Estándares de Código Lua y API EsoUI

1. **Verificación previa contra `eso-mcp-server`:**
   - Antes de usar cualquier constante, enum, evento (`EVENT_*`), sonido (`SOUNDS.*`), textura o API de EsoUI nueva, verificar su existencia y firma exacta mediante `eso-mcp-server` (`eso_search_api`, `eso_get_function`, `eso_get_event`, `eso_get_constant`, `eso_get_enum`).
   - Al introducir un nuevo global oficial de EsoUI en `RPQuest.lua` o `src/*.lua`, registrarlo en `.luacheckrc` (`read_globals`, o `globals` si el addon muta sus campos).

2. **Cero guardas redundantes `if <ESO_GLOBAL> then` en producción:**
   - Prohibido agregar guardas de existencia sobre APIs o globales estándar de ESO (ej. `if GetUnitName then`, `if not GetUnitWorldPosition then`, `if zo_callLater then`, `if zo_strformat then`) en `RPQuest.lua` o `src/*.lua`.
   - Todos los *stubs* y *mocks* del entorno ESO para pruebas herméticas pertenecen exclusivamente a `tests/` (`tests/run.lua` y `tests/mocks/`).

3. **Referencia local al namespace en cada archivo Lua:**
   - Todo archivo `.lua` del addon (`RPQuest.lua`, `src/*.lua` y `lang/*.lua`) debe inicializar y capturar localmente el namespace del addon al inicio:
     ```lua
     RPQuest = RPQuest or {}
     local Addon = RPQuest -- o `local RPQuest = RPQuest` en lang/*.lua
     ```

4. **Uso estricto de `pcall` / `xpcall`:**
   - Evitar envolver llamadas estándar de formateo o APIs de EsoUI en `pcall(` o `xpcall(`.
   - Solo se permite si existe una justificación técnica explícita documentada en la misma línea con `-- allow-pcall`.

## 2. Localización y Manifiesto (`RPQuest.txt`)

- Mantener `RPQuest.txt` cargando únicamente:
  ```text
  lang/en.lua
  lang/$(language).lua
  ```
- Nunca hardcodear archivos de idiomas secundarios (como `lang/es.lua`, `lang/de.lua`, `lang/fr.lua`) en `RPQuest.txt`; `src/Locale.lua` debe garantizar el *fallback* seguro al inglés.

## 3. Transparencia de IA y Documentación de Release

- En toda release (y al modificar documentación principal), verificar que la sección **AI Disclosure & Credits** esté presente en los cuatro archivos:
  - `docs/esoui-description.bbcode`
  - `README.md`
  - `README.es.md`
  - `readme.txt`
- Respetar las reglas de [release-and-docs.md](./release-and-docs.md) para `docs/esoui-description.bbcode` (bloque `[SIZE="4"][COLOR="DarkRed"][B]Notice:[/B][/COLOR]` destacado y cero slash commands).

## 4. Checklist Obligatorio Pre-PR y en `pr-reviewer`

Antes de abrir un Pull Request hacia `dev` (y durante toda auditoría `pr-reviewer`):

- [ ] `luajit tests/run.lua` pasa con 0 fallos.
- [ ] `./scripts/check-esoui.sh` pasa todas las validaciones (guardas ESO, `pcall`, referencias locales `RPQuest`, manifiesto `RPQuest.txt`, `AI Disclosure`, `Notice`/sin slash commands en BBCode y `./scripts/package.sh`).
- [ ] `luacheck .` pasa con 0 errores y 0 advertencias (verificado localmente si está instalado y/o en CI).
- [ ] `eso_validate_addon` (MCP) ejecutado sobre los archivos modificados sin nuevos errores ni APIs inexistentes.

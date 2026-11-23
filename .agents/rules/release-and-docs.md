---
trigger: always_on
---

# Mantenimiento de READMEs y Versiones (RPQuest)

1. **Sincronización de Documentación en Tareas (`feat` / `ui` / Estructura):**
   - Al agregar o modificar funcionalidades visibles para el usuario, atajos de teclado o módulos en `src/` / `lang/`, actualizar **`README.md`** y **`README.es.md`** en el mismo PR (secciones de características, guía rápida y estructura del proyecto).
   - Si cambian las instrucciones de instalación o uso general del paquete ESOUI, actualizar también `readme.txt`.

2. **Checklist Obligatorio al Promover `dev` -> `main` (`vX.Y.Z`):**
   - Ejecutar `./scripts/bump-version.sh --dry-run` para calcular automáticamente el próximo SemVer según Conventional Commits desde el último tag `v*` (o usar `./scripts/bump-version.sh --version X.Y.Z` / `major|minor|patch` si se requiere override manual), y luego `./scripts/bump-version.sh` para actualizar de forma sincronizada `RPQuest.txt` (`## Version:` y sufijo `(vX.Y.Z)` en `## Description:`), `src/Constants.lua` (`METADATA.VERSION`) y los badges `![Version](https://img.shields.io/badge/version-X.Y.Z-blue)` en **`README.md`** y **`README.es.md`**.
   - Confirmar que todas las funcionalidades nuevas incluidas desde el último tag estén documentadas en ambos READMEs y en **`docs/esoui-description.bbcode`**.
   - **Tag SemVer obligatorio (`vX.Y.Z`) sobre `main`:** El workflow `.github/workflows/release.yml` (GitHub Release + publicación automática en ESOUI.com) se dispara exclusivamente al pushear un tag `v*` sobre `main`. Nunca omitir la creación y push del tag `vX.Y.Z` tras el merge a `main`, ni ejecutar `workflow_dispatch` en modo live (`dry_run=false`) desde `dev` (los tags de `main` no son ancestros de `dev`).
   - Tras crear el tag `vX.Y.Z` sobre `main` (y antes de volver a `dev`), ejecutar `./scripts/package.sh` para regenerar la distribución local en `dist/RPQuest-X.Y.Z.zip` (el script limpia versiones anteriores automáticamente).
   - **Sincronizar `main` de vuelta a `dev` tras el tag:** Al volver a `dev`, ejecutar `git merge --ff-only main` (o `git merge main` si `dev` ya avanzó) y pushear `dev`, para que el merge commit etiquetado con `vX.Y.Z` sea ancestro directo de `dev`.
   - **Consulta del último release estable:** Nunca usar `git describe --tags --abbrev=0` estando en `dev` para determinar la última versión estable; usar `git describe --tags --abbrev=0 origin/main` o `git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n 1`.
   - Nota: `scripts/package.sh` calcula e inyecta automáticamente `## AddOnVersion:` (desde `git rev-list --count HEAD`) y usa `## Version:` desde el tag exacto `vX.Y.Z` cuando `HEAD` está sobre un tag (en `main`), o desde `RPQuest.txt` (por ejemplo `1.5.0-dev`) en `dev` y ramas de trabajo. Al iniciar un nuevo ciclo en `dev`, actualizar `RPQuest.txt`, `src/Constants.lua` (`METADATA.VERSION`) y los badges a `X.Y.Z-dev`; antes de promover a `main`, limpiar el sufijo `-dev` a `X.Y.Z`.

3. **Descripción y Changelog Público en ESOUI y GitHub (Sin Slash Commands / Inglés por defecto):**
   - Al redactar o actualizar **`docs/esoui-description.bbcode`**, **`README.md`**, **`README.es.md`** o **`readme.txt`**, **nunca incluir slash commands** (como `/rpquest` o `/rpq`); documentar únicamente los **keybinds** (`Settings -> Controls -> RPQuest`).
   - **Aviso de desarrollo activo destacado:** Conservar siempre en **`docs/esoui-description.bbcode`**, inmediatamente debajo del título, el bloque `[SIZE="4"][COLOR="DarkRed"][B]Notice:[/B][/COLOR] ...[/SIZE]` con tamaño grande (`SIZE="4"` o superior) para que sobresalga respecto al texto normal.
   - **Títulos de commits y PRs en inglés:** El workflow `.github/workflows/release.yml` genera el changelog de ESOUI a partir de `git log "${PREV_TAG}..HEAD" --no-merges --pretty=format:"- %s"`, y GitHub Release lo genera desde los títulos de PR. Por lo tanto, todos los títulos de commits (`git commit`) y de Pull Requests (`gh pr create`) deben redactarse en **inglés** para que el changelog público salga en inglés por defecto.

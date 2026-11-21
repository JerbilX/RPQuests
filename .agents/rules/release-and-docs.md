---
trigger: always_on
---

# Mantenimiento de READMEs y Versiones (RPQuest)

1. **Sincronización de Documentación en Tareas (`feat` / `ui` / Estructura):**
   - Al agregar o modificar funcionalidades visibles para el usuario, atajos de teclado, comandos slash o módulos en `src/` / `lang/`, actualizar **`README.md`** y **`README.es.md`** en el mismo PR (secciones de características, guía rápida y estructura del proyecto).
   - Si cambian las instrucciones de instalación o uso general del paquete ESOUI, actualizar también `readme.txt`.

2. **Checklist Obligatorio al Promover `dev` -> `main` (`vX.Y.Z`):**
   - Verificar que los badges `![Version](https://img.shields.io/badge/version-X.Y.Z-blue)` en **`README.md`** y **`README.es.md`** coincidan con la versión SemVer `X.Y.Z` a publicar.
   - Confirmar que todas las funcionalidades nuevas incluidas desde el último tag estén documentadas en ambos READMEs y en **`docs/esoui-description.bbcode`**.
   - **Tag SemVer obligatorio (`vX.Y.Z`) sobre `main`:** El workflow `.github/workflows/release.yml` (GitHub Release + publicación automática en ESOUI.com) se dispara exclusivamente al pushear un tag `v*` sobre `main`. Nunca omitir la creación y push del tag `vX.Y.Z` tras el merge a `main`, ni ejecutar `workflow_dispatch` en modo live (`dry_run=false`) desde `dev` (los tags de `main` no son ancestros de `dev`).
   - Tras crear el tag `vX.Y.Z` sobre `main` (y antes de volver a `dev`), ejecutar `./scripts/package.sh` para regenerar la distribución local en `dist/RPQuest-X.Y.Z.zip` (el script limpia versiones anteriores automáticamente).
   - Nota: `scripts/package.sh` calcula e inyecta automáticamente `## Version:` (desde el tag `vX.Y.Z`) y `## AddOnVersion:` (desde `git rev-list --count HEAD`) en el `.zip` de release, por lo que no es necesario editar manualmente `RPQuest.txt` en cada release salvo que se quiera mantener sincronizado su valor base.

3. **Descripción y Changelog Público en ESOUI (BBCode / Inglés por defecto):**
   - Al redactar o actualizar **`docs/esoui-description.bbcode`** (formato BBCode), **nunca incluir slash commands** (como `/rpquest` o `/rpq`); documentar únicamente los **keybinds** (`Settings -> Controls -> RPQuest`).
   - **Títulos de commits y PRs en inglés:** El workflow `.github/workflows/release.yml` genera el changelog de ESOUI a partir de `git log "${PREV_TAG}..HEAD" --no-merges --pretty=format:"- %s"`, y GitHub Release lo genera desde los títulos de PR. Por lo tanto, todos los títulos de commits (`git commit`) y de Pull Requests (`gh pr create`) deben redactarse en **inglés** para que el changelog público salga en inglés por defecto.

---
status: accepted
date: 2026-11-18
decision-makers: [JerbilX, Antigravity]
supersedes: []
superseded-by: []
---

# 0002 - Modelo de Dominio, Captura con Offset Cartográfico y Códec de Compartición

## Contexto y Planteamiento del Problema
Una misión personalizada en `RPQuest` necesita almacenar título, descripción, el objetivo (NPC) capturado mediante tecla bajo la retícula (`reticleover`), la cantidad de bajas requeridas ($1..N$), la ubicación donde fue capturado y una marca de área en el mapa cuyo centro esté desplazado aleatoriamente respecto a la posición exacta del NPC (para que el jugador deba buscar al objetivo dentro del círculo en lugar de ir al centro exacto). Además, las misiones deben poder compartirse entre jugadores mediante un código de texto copiable/importable sin usar librerías externas.

## Impulsores de la Decisión (Decision Drivers)
* **Precisión Cartográfica sin Librerías:** Usar exclusivamente los identificadores y coordenadas normalizadas del mapa nativo de EsoUI (`GetCurrentMapId()`, `SetMapToPlayerLocation()`, `GetMapPlayerPosition("player")`).
* **Exploración Inmersiva (Offset del Área):** El objetivo real debe quedar siempre contenido dentro del área circular del mapa, pero nunca en su centro geométrico exacto.
* **Compartición Autónoma por Código:** Serialización determinista en Lua 5.1 puro compatible con los límites de longitud de `EditControl` y del chat/portapapeles de ESO, incluyendo verificación de integridad (checksum).

## Opciones Consideradas
* **Opción 1: Guardar solo la posición del NPC y calcular un offset aleatorio distinto cada vez que se abre el mapa.**
  * *Pro:* Menos campos en el modelo de datos.
  * *Contra:* El círculo se movería en cada apertura del mapa, permitiendo triangular el centro real o confundiendo al jugador; además, al compartir la misión cada jugador vería un círculo distinto.
* **Opción 2: Persistir la posición real y el centro del área con offset aleatorio fijo generado al guardar la misión + Códec `RPQ1` con CRC16 (Elegida).**
  * *Pro:* El área de búsqueda es inmutable para esa misión (tanto para el creador como para quien recibe el código compartido), garantiza geométricamente que el objetivo está dentro del radio y permite validar que la muerte ocurra en la zona/área esperada.
  * *Contra:* Agrega dos coordenadas normalizadas (`areaCenterX`, `areaCenterY`) y el radio (`areaRadius`) al payload compartido, lo cual representa apenas ~18 bytes adicionales.

## Decisión Adoptada
Opción elegida: **"Opción 2: Persistir la posición real y el centro del área con offset aleatorio fijo generado al guardar la misión + Códec `RPQ1` con CRC16"**, porque asegura determinismo visual y funcional tanto local como al compartir misiones por código.

### 1. Cálculo Geométrico del Offset Fijo del Círculo
Al capturar un objetivo en $(x_t, y_t) \in (0, 1)^2$ con un radio normalizado $R \in \{R_{\text{small}}, R_{\text{medium}}, R_{\text{large}}\}$:
1. Se elige una distancia radial aleatoria $d \in [0.25 \cdot R, \, 0.65 \cdot R]$ y un ángulo aleatorio $\theta \in [0, 2\pi)$.
2. El centro del círculo de búsqueda se fija en:
   $$x_c = \text{clamp}(x_t + d \cos\theta, \, R, \, 1 - R), \quad y_c = \text{clamp}(y_t + d \sin\theta, \, R, \, 1 - R)$$
3. Como $d \le 0.65 \cdot R < R$, el punto real $(x_t, y_t)$ queda garantizadamente dentro del círculo de radio $R$ centrado en $(x_c, y_c)$, pero desplazado de su centro.

### 2. Reglas de Captura y Condición de Victoria
* **Captura (`TargetCapture`):** Verifica `DoesUnitExist("reticleover")`, que no sea jugador (`not IsUnitPlayer("reticleover")`), que no esté muerto (`not IsUnitDead("reticleover")`) y que sea atacable o válido. Sincroniza el mapa con `SetMapToPlayerLocation()` y captura `mapId = GetCurrentMapId()`, `zoneId = GetUnitZoneIndex("player")` / `GetZoneId(...)`, `mapName = GetMapName()` y `GetMapPlayerPosition("player")`.
* **Eliminación (`CombatTracker`):** Filtra `EVENT_COMBAT_EVENT` para resultados de muerte (`ACTION_RESULT_DIED` y `ACTION_RESULT_DIED_XP`), normaliza el nombre de `targetName` con `zo_strformat("<<C:1>>", ...)` sin sufijos de género y verifica pertenencia a la zona/mapa y radio de búsqueda antes de incrementar `currentCount` hasta `requiredCount`.

### 3. Protocolo de Serialización (`ShareCodec`)
* Formato de cadena: `RPQ1:<HEX_CRC16>:<PAYLOAD_BASE64URL>` (o codificación hexadecimal/escape imprimible ASCII 7-bit segura para `EditControl`).
* Al importar un código, se valida el prefijo `RPQ1:`, se recalcula el CRC16 sobre el payload y se reconstruye una nueva misión en estado activa (`completed = false`, cada entrada de `targets` con `currentCount = 0`) conservando título, descripción, objetivos y coordenadas del área de búsqueda.
* **Enmienda (Issue #18):** Como no existían versiones publicadas previas a `targets[]`, se eliminaron los campos planos legacy (`targetName`, `currentCount`, `requiredCount`) del modelo y del payload `RPQ1` (ahora de 11 campos con `targets` como única fuente de verdad).

### Consecuencias
* **Positivas:**
  * Experiencia de búsqueda idéntica a las misiones de exploración nativas de ESO.
  * Códigos de compartición compactos, a prueba de errores de copiado parcial gracias al checksum CRC16.
* **Negativas / Trade-offs:**
  * Por seguridad del cliente de ESO (`CopyToClipboard` es API privada), la exportación presenta el código pre-seleccionado (`SelectAll()` + `TakeFocus()`) en un campo de texto dedicado dentro del Diario para copiar con `Ctrl+C`.

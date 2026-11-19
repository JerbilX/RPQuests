-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

RPQuest = RPQuest or {}
RPQuest.Locales = RPQuest.Locales or {}

RPQuest.Locales["es"] = {
    -- Keybindings
    SI_KEYBINDINGS_CATEGORY_RPQUEST = "RPQuest - Misiones Personalizadas",
    SI_BINDING_NAME_RPQUEST_CAPTURE_TARGET = "Seleccionar Objetivo bajo Retícula (NPC)",
    SI_BINDING_NAME_RPQUEST_TOGGLE_JOURNAL = "Abrir / Cerrar Pestaña de Misiones Custom",

    -- Tab & General
    TAB_TITLE = "Misiones Custom",
    HEADER_QUEST_LIST = "MISIONES CUSTOM (%d)",
    SECTION_ACTIVE_QUESTS = "MISIONES (%d)",
    SECTION_PREPARED_QUESTS = "PREPARANDO (%d)",
    SECTION_COMPLETED_QUESTS = "COMPLETADAS (%d)",
    EMPTY_QUEST_LIST = "No hay misiones aún. Pulsa 'Importar' para recibir una o '+ Nueva' para crearla.",

    -- Buttons
    BTN_NEW_QUEST = "+ Nueva",
    BTN_IMPORT_CODE = "Importar",
    BTN_ACTIVATE = "Activar",
    BTN_DEACTIVATE = "Desactivar",
    BTN_TEST_QUEST = "Probar",
    BTN_STOP_TEST = "Dejar de probar",
    BTN_SHOW_ON_MAP = "Ver en Mapa",
    BTN_EDIT = "Editar",
    BTN_RESET = "Reiniciar",
    BTN_SHARE = "Compartir",
    BTN_DELETE = "Eliminar",
    BTN_SAVE = "Crear Misión",
    BTN_CLEAR_TARGETS = "Limpiar Objetivos",
    BTN_CANCEL = "Cancelar",
    BTN_CONFIRM_IMPORT = "Importar Misión",
    BTN_RADIUS_SMALL = "Pequeña",
    BTN_RADIUS_MEDIUM = "Mediana",
    BTN_RADIUS_LARGE = "Grande",

    -- Detail View
    STATUS_ACTIVE = "Estado: |c33FF33Activa (En Seguimiento)|r",
    STATUS_AVAILABLE = "Estado: |cE8D5A0Disponible|r",
    STATUS_COMPLETED = "Estado: |c00CCFFCompletada|r",
    LABEL_LOCATION = "Ubicación: %s",
    LABEL_UNKNOWN_LOCATION = "Ubicación desconocida",
    LABEL_DESCRIPTION_HEADER = "HISTORIA Y DESCRIPCIÓN",
    LABEL_NO_DESCRIPTION = "Sin descripción adicional.",
    LABEL_OBJECTIVE_HEADER = "OBJETIVOS",
    OBJECTIVE_KILL_FORMAT = "• Eliminar a %s: %d / %d",
    OBJECTIVE_COMPLETED_SUFFIX = " |c33FF33(Completado)|r",
    LABEL_SHARE_CODE_HEADER = "CÓDIGO PARA COMPARTIR (Pulsa Ctrl+C para copiar):",

    -- Editor View (Create / Edit)
    EDITOR_CREATE_TITLE = "CREAR NUEVA MISIÓN CUSTOM",
    EDITOR_EDIT_TITLE = "EDITAR MISIÓN CUSTOM",
    LABEL_INPUT_TITLE = "Título de la Misión:",
    DEFAULT_QUEST_TITLE = "Misión Custom #%d",
    LABEL_INPUT_DESCRIPTION = "Descripción / Trasfondo:",
    LABEL_INPUT_COMPLETION_MSG = "Mensaje al Completar (Opcional):",
    LABEL_TARGET_SECTION = "Objetivo (NPC) y Área de Búsqueda:",
    TARGET_CAPTURED_FORMAT = "Objetivo: |c33FF33%s|r (%s)",
    TARGET_NOT_CAPTURED = "|cFFAA33Apunta a un NPC vivo y pulsa la tecla de captura.|r",
    LABEL_AREA_SIZE = "Tamaño del área en el mapa:",

    -- Import View
    IMPORT_VIEW_TITLE = "IMPORTAR MISIÓN POR CÓDIGO",
    IMPORT_INSTRUCTIONS = "Pega debajo el código de misión (RPQ1:...) compartido por otro jugador:",

    -- Alerts & Announcements
    ALERT_NO_RETICLE_TARGET = "RPQuest: No hay ningún objetivo bajo la retícula.",
    ALERT_INVALID_TARGET_PLAYER = "RPQuest: No se puede seleccionar a otro jugador como objetivo.",
    ALERT_INVALID_TARGET_DEAD = "RPQuest: El objetivo bajo la retícula ya está muerto.",
    ALERT_INVALID_TARGET_FRIENDLY = "RPQuest: El objetivo seleccionado no es atacable.",
    ALERT_TARGET_CAPTURED = "RPQuest: Objetivo capturado -> %s (%s)",
    ALERT_QUEST_SAVED = "RPQuest: Misión creada -> %s",
    ALERT_QUEST_DELETED = "RPQuest: Misión eliminada.",
    ALERT_QUEST_RESET = "RPQuest: Progreso de la misión reiniciado.",
    ALERT_QUEST_IMPORTED = "RPQuest: Misión importada -> %s",
    ALERT_SHARE_READY = "RPQuest: ¡Código seleccionado! Pulsa Ctrl+C para copiarlo.",
    ERR_MISSING_TARGET = "Captura primero al menos un objetivo NPC con la tecla bajo la retícula.",
    ERR_INVALID_CODE = "El código de misión es inválido o está incompleto.",
    ERR_CANNOT_EDIT_RECEIVED = "Las misiones recibidas para jugar no se pueden editar.",
    CSA_QUEST_PROGRESS = "%s: %d / %d",
    CSA_QUEST_COMPLETED = "Misión Completada: %s",

    -- Map
    MAP_TOOLTIP_HEADER = "RPQuest: %s",
    MAP_TOOLTIP_OBJECTIVE = "Área de búsqueda: Eliminar a %s (%d/%d)",
}

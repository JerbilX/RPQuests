-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

RPQuest = RPQuest or {}
RPQuest.Locales = RPQuest.Locales or {}

RPQuest.Locales["en"] = {
    -- Keybindings
    SI_KEYBINDINGS_CATEGORY_RPQUEST = "RPQuest - Custom Quests",
    SI_BINDING_NAME_RPQUEST_CAPTURE_TARGET = "Capture Target Under Reticle (NPC)",
    SI_BINDING_NAME_RPQUEST_TOGGLE_JOURNAL = "Open / Close Custom Quests Tab",

    -- Tab & General
    TAB_TITLE = "Custom Quests",
    HEADER_QUEST_LIST = "CUSTOM QUESTS (%d)",
    SECTION_ACTIVE_QUESTS = "QUESTS (%d)",
    SECTION_PREPARED_QUESTS = "PREPARING (%d)",
    SECTION_COMPLETED_QUESTS = "COMPLETED (%d)",
    EMPTY_QUEST_LIST = "No custom quests yet. Click 'Import' to receive one or '+ New' to create one.",

    -- Buttons
    BTN_NEW_QUEST = "+ New",
    BTN_IMPORT_CODE = "Import",
    BTN_ACTIVATE = "Set Active",
    BTN_DEACTIVATE = "Untrack",
    BTN_TEST_QUEST = "Test Quest",
    BTN_STOP_TEST = "Stop Testing",
    BTN_SHOW_ON_MAP = "Show on Map",
    BTN_EDIT = "Edit",
    BTN_RESET = "Reset",
    BTN_SHARE = "Share Code",
    BTN_COMPLETION_CODE = "Delivery Code",
    BTN_VALIDATE_DELIVERY = "Validate Delivery",
    BTN_DELETE = "Delete",
    BTN_SAVE = "Create Quest",
    BTN_CLEAR_TARGETS = "Clear Targets",
    BTN_CANCEL = "Cancel",
    BTN_CONFIRM_IMPORT = "Import Quest",
    BTN_RADIUS_SMALL = "Small",
    BTN_RADIUS_MEDIUM = "Medium",
    BTN_RADIUS_LARGE = "Large",

    -- Detail View
    STATUS_ACTIVE = "Status: |c33FF33Active (Tracked)|r",
    STATUS_AVAILABLE = "Status: |cE8D5A0Available|r",
    STATUS_COMPLETED = "Status: |c00CCFFCompleted|r",
    LABEL_LOCATION = "Location: %s",
    LABEL_UNKNOWN_LOCATION = "Unknown Location",
    LABEL_DESCRIPTION_HEADER = "BACKGROUND & DESCRIPTION",
    LABEL_NO_DESCRIPTION = "No additional description provided.",
    LABEL_OBJECTIVE_HEADER = "TASKS",
    OBJECTIVE_KILL_FORMAT = "• Eliminate %s: %d / %d",
    OBJECTIVE_COMPLETED_SUFFIX = " |c33FF33(Completed)|r",
    LABEL_CODE_BOX_HEADER = "CODE (Generate above or paste here to validate):",
    LABEL_SHARE_CODE_HEADER = "SHARE CODE (Press Ctrl+C to copy):",
    LABEL_VALIDATE_BOX_HEADER = "VALIDATE DELIVERY (Paste RPQC1 code below):",
    LABEL_COMPLETION_CODE_HEADER = "DELIVERY CODE (Press Ctrl+C to copy):",

    -- Editor View (Create / Edit)
    EDITOR_CREATE_TITLE = "CREATE NEW CUSTOM QUEST",
    EDITOR_EDIT_TITLE = "EDIT CUSTOM QUEST",
    LABEL_INPUT_TITLE = "Quest Title:",
    DEFAULT_QUEST_TITLE = "Custom Quest #%d",
    LABEL_INPUT_DESCRIPTION = "Description / Story:",
    LABEL_INPUT_COMPLETION_MSG = "Completion Message (Optional):",
    LABEL_TARGET_SECTION = "Target (NPC) & Search Area:",
    TARGET_CAPTURED_FORMAT = "Target: |c33FF33%s|r (%s)",
    TARGET_NOT_CAPTURED = "|cFFAA33Aim at a living NPC and press the Capture keybind.|r",
    LABEL_AREA_SIZE = "Map Search Area Size:",

    -- Import View
    IMPORT_VIEW_TITLE = "IMPORT QUEST BY CODE",
    IMPORT_INSTRUCTIONS = "Paste the quest code (RPQ1:...) shared by another player below:",

    -- Validate Delivery (Inline)
    VALIDATE_RESULT_SUCCESS = "|c33FF33Valid delivery!|r Quest completed successfully by |cE8D5A0%s|r.",
    VALIDATE_ERR_EMPTY = "|cFFAA33Paste a delivery code (RPQC1:...) into the text box first.|r",
    VALIDATE_ERR_NOT_COMPLETION_CODE = "|cFF4444That is a quest share code (RPQ1), not a delivery code (RPQC1).|r",
    VALIDATE_ERR_WRONG_QUEST = "|cFF4444This delivery code belongs to a different quest.|r",
    VALIDATE_ERR_NOT_COMPLETED = "|cFF4444The code does not indicate that the quest was completed.|r",
    VALIDATE_ERR_INVALID_CODE = "|cFF4444Invalid or corrupted delivery code.|r",

    -- Alerts & Announcements
    ALERT_NO_RETICLE_TARGET = "RPQuest: No target under reticle.",
    ALERT_INVALID_TARGET_PLAYER = "RPQuest: Players cannot be selected as NPC quest targets.",
    ALERT_INVALID_TARGET_DEAD = "RPQuest: Target is already dead.",
    ALERT_INVALID_TARGET_FRIENDLY = "RPQuest: Target cannot be eliminated.",
    ALERT_TARGET_CAPTURED = "RPQuest: Target captured -> %s (%s)",
    ALERT_QUEST_SAVED = "RPQuest: Quest saved -> %s",
    ALERT_QUEST_DELETED = "RPQuest: Quest deleted.",
    ALERT_QUEST_RESET = "RPQuest: Quest progress reset.",
    ALERT_QUEST_IMPORTED = "RPQuest: Quest imported -> %s",
    ALERT_SHARE_READY = "RPQuest: Code selected! Press Ctrl+C to copy.",
    ALERT_COMPLETION_CODE_READY = "RPQuest: Delivery code ready! Press Ctrl+C to copy.",
    ERR_MISSING_TARGET = "Capture an NPC target with the reticle keybind before creating the quest.",
    ERR_INVALID_CODE = "Invalid or corrupted RPQuest code.",
    ERR_CANNOT_EDIT_RECEIVED = "Received quests cannot be edited.",
    CSA_QUEST_PROGRESS = "%s: %d / %d",
    CSA_QUEST_COMPLETED = "Quest Completed: %s",

    -- Map
    MAP_TOOLTIP_HEADER = "RPQuest: %s",
    MAP_TOOLTIP_OBJECTIVE = "Search Area: Eliminate %s (%d/%d)",
}

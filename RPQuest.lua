-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.name = (Addon.Constants and Addon.Constants.METADATA and Addon.Constants.METADATA.NAME) or "RPQuest"

-- Inicializar las cadenas de Keybindings en el momento de carga para que Bindings.xml las resuelva
if Addon.Locale then
    Addon.Locale:Initialize()
end

function Addon:Initialize()
    if Addon.Locale then
        Addon.Locale:Initialize()
    end

    local defaults = (Addon.QuestRepository and Addon.QuestRepository:GetDefaults()) or {}
    local svName = (Addon.Constants and Addon.Constants.SAVED_VARS and Addon.Constants.SAVED_VARS.NAME) or "RPQuest_SavedVariables"
    local svVersion = (Addon.Constants and Addon.Constants.SAVED_VARS and Addon.Constants.SAVED_VARS.VERSION) or 1

    local savedVars
    if ZO_SavedVars and ZO_SavedVars.NewCharacterIdSettings then
        savedVars = ZO_SavedVars:NewCharacterIdSettings(svName, svVersion, nil, defaults)
    else
        _G[svName] = _G[svName] or defaults
        savedVars = _G[svName]
    end
    self.savedVars = savedVars

    if Addon.QuestRepository then
        Addon.QuestRepository:Initialize(savedVars)
    end

    if Addon.CombatTracker then
        Addon.CombatTracker:Initialize()
    end

    if Addon.WorldMapArea then
        Addon.WorldMapArea:Initialize()
    end

    if Addon.HudTracker then
        Addon.HudTracker:Initialize()
    end

    if Addon.JournalTab then
        Addon.JournalTab:Initialize()
    end

    if SLASH_COMMANDS then
        SLASH_COMMANDS["/rpquest"] = function(args)
            self:HandleSlashCommand(args)
        end
    end
end

function Addon:OnCaptureTargetKeybind()
    if Addon.TargetCapture then
        return Addon.TargetCapture:CaptureFromReticle()
    end
    return nil
end

function Addon:OnToggleJournalKeybind()
    if Addon.JournalTab then
        Addon.JournalTab:ToggleTab()
    end
end

function Addon:HandleSlashCommand(args)
    local cmd = (type(args) == "string" and args:gsub("^%s+", ""):gsub("%s+$", ""):lower()) or ""
    if cmd == "capture" or cmd == "target" then
        self:OnCaptureTargetKeybind()
    elseif cmd == "map" then
        if Addon.WorldMapArea then
            Addon.WorldMapArea:ShowQuestOnMap()
        end
    else
        self:OnToggleJournalKeybind()
    end
end

local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= Addon.name then
        return
    end
    if EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForEvent(Addon.name, EVENT_ADD_ON_LOADED)
    end
    Addon:Initialize()
end

if EVENT_MANAGER and EVENT_ADD_ON_LOADED then
    EVENT_MANAGER:RegisterForEvent(Addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
end

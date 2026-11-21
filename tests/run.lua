-- ============================================================================
-- RPQuest Unit Test Runner (tests/run.lua)
-- Concise output (<50 lines on success), zero table dumps on failure.
-- ============================================================================

dofile("tests/mocks/eso_ui_mock.lua")

-- Extend EsoUI mock with APIs required by RPQuest
local mockState = {
    language = "es",
    mapId = 32,
    zoneId = 381,
    mapName = "Auridon",
    playerX = 0.4200,
    playerY = 0.6100,
    worldX = 10000,
    worldY = 500,
    worldZ = 20000,
    reticleExists = true,
    reticleName = "Capitán Pirata^m",
    reticleIsPlayer = false,
    reticleIsDead = false,
    reticleAttackable = true,
    reticleReaction = 2,
    alerts = {},
    csaMessages = {},
    chatMessages = {},
    soundsPlayed = {},
    isGrouped = false,
}

_G.RPQuestTestState = mockState

UNIT_REACTION_HOSTILE = 1
UNIT_REACTION_NEUTRAL = 2
UNIT_REACTION_FRIENDLY = 3
UNIT_REACTION_NPC_ALLY = 4
UNIT_REACTION_PLAYER_ALLY = 5

COMBAT_UNIT_TYPE_NONE = 0
COMBAT_UNIT_TYPE_PLAYER = 1
COMBAT_UNIT_TYPE_PLAYER_PET = 2
COMBAT_UNIT_TYPE_GROUP = 3
COMBAT_UNIT_TYPE_OTHER = 4
COMBAT_UNIT_TYPE_PLAYER_COMPANION = 5
ACTION_RESULT_DIED = 2260
ACTION_RESULT_DIED_XP = 2262
REGISTER_FILTER_COMBAT_RESULT = 2
REGISTER_FILTER_IS_ERROR = 5
EVENT_COMBAT_EVENT = 131103
EVENT_ZONE_CHANGED = 131072
EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED = 131200
EVENT_JUSTICE_INFAMY_UPDATED = 131201
EVENT_JUSTICE_PICKPOCKET_FAILED = 131202
EVENT_MAIL_OPEN_MAILBOX = 131300
EVENT_MAIL_CLOSE_MAILBOX = 131301
EVENT_MAIL_SEND_SUCCESS = 131302
EVENT_MAIL_SEND_FAILED = 131303
EVENT_MAIL_INBOX_UPDATE = 131304
EVENT_MAIL_READABLE = 131305
EVENT_MAIL_REMOVED = 131306
EVENT_CHATTER_BEGIN = 131400
EVENT_GROUP_UPDATE = 131500
MODIFY_TEXT_TYPE_UPPERCASE = 1
SI_NOTIFYTEXT_QUEST_ACCEPT = SI_NOTIFYTEXT_QUEST_ACCEPT or "Quest Accepted: <<1>>"
UI_ALERT_CATEGORY_ALERT = 0
UI_ALERT_CATEGORY_ERROR = 1
CSA_CATEGORY_LARGE_TEXT = 1
CSA_CATEGORY_SMALL_TEXT = 2
CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED = 9
CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_COMPLETED = 10
CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_CONDITION_COMPLETED = 11
MAPTYPE_WORLD = 1
MAPTYPE_COSMIC = 2
MAPTYPE_ZONE = 3
SET_MAP_RESULT_MAP_CHANGED = 1
SET_MAP_RESULT_CURRENT_MAP_UNCHANGED = 2
SET_MAP_RESULT_FAILED = 0
MENU_CATEGORY_MAP = 4
MOUSE_BUTTON_INDEX_LEFT = 1
MOUSE_BUTTON_INDEX_RIGHT = 2
TEXT_ALIGN_RIGHT = 2

ZO_PostHook = function(tbl, fnName, hookFn)
    local orig = tbl[fnName]
    tbl[fnName] = function(...)
        if orig then orig(...) end
        hookFn(...)
    end
end

SOUNDS.QUEST_ACCEPTED = "Quest_Accept"
SOUNDS.QUEST_COMPLETED = "Quest_Complete"
SOUNDS.QUEST_OBJECTIVE_INCREMENT = "Quest_ObjectivesIncrement"
SOUNDS.QUEST_OBJECTIVE_COMPLETE = "Quest_ObjectivesComplete"
SOUNDS.NOTE_TAKEN = "Note_Taken"
SOUNDS.GENERAL_ALERT_ERROR = "General_Alert_Error"
SOUNDS.DEFAULT_CLICK = "Default_Click"
SOUNDS.EDIT_CLICK = "Edit_Click"
ESO_Dialogs = ESO_Dialogs or {}
ZO_Dialogs_ShowDialog = ZO_Dialogs_ShowDialog or function() end
KEYBIND_STRIP = KEYBIND_STRIP or {
    UpdateKeybindButtonGroup = function() end,
    AddKeybindButtonGroup = function() end,
    RemoveKeybindButtonGroup = function() end,
}
ApplyTemplateToControl = ApplyTemplateToControl or function() end
ZO_QuestJournal = ZO_QuestJournal or CreateControl("ZO_QuestJournal", GuiRoot, CT_TOPLEVELCONTROL)

GetCVar = function(name)
    if name == "language.2" or name == "Language.2" then
        return mockState.language
    end
    return ""
end

ZO_CreateStringId = function(id, val)
    _G[id] = val
end

GetString = function(id)
    if type(id) == "string" then
        return _G[id] or id
    end
    return tostring(id)
end

zo_strformat = function(fmt, ...)
    local arg1 = select(1, ...)
    if fmt == "<<C:1>>" and type(arg1) == "string" then
        return arg1
    end
    return tostring(arg1 or fmt)
end

zo_callLater = function()
end

ZO_Alert = function(cat, sound, text)
    table.insert(mockState.alerts, { category = cat, sound = sound, text = text })
end

PlaySound = function(soundId)
    table.insert(mockState.soundsPlayed, soundId)
end

DoesUnitExist = function(tag)
    if tag == "reticleover" then return mockState.reticleExists end
    return true
end

GetUnitName = function(tag)
    if tag == "reticleover" then return mockState.reticleName end
    return "Jugador"
end

IsUnitPlayer = function(tag)
    if tag == "reticleover" then return mockState.reticleIsPlayer end
    return false
end

IsUnitDead = function(tag)
    if tag == "reticleover" then return mockState.reticleIsDead end
    return false
end

IsUnitAttackable = function(tag)
    if tag == "reticleover" then return mockState.reticleAttackable end
    return true
end

GetUnitReaction = function(tag)
    if tag == "reticleover" then return mockState.reticleReaction end
    return UNIT_REACTION_HOSTILE
end

IsUnitGrouped = function(unitTag)
    return mockState.isGrouped == true
end

HUD_SCENE = ZO_Scene:New("hud", SCENE_MANAGER)
SCENE_MANAGER:AddScene(HUD_SCENE)
HUD_UI_SCENE = ZO_Scene:New("hudui", SCENE_MANAGER)
SCENE_MANAGER:AddScene(HUD_UI_SCENE)

SetMapToPlayerLocation = function()
    return SET_MAP_RESULT_CURRENT_MAP_UNCHANGED
end

DoesCurrentMapMatchMapForPlayerLocation = function()
    return true
end

SetMapToMapId = function(mapId)
    mockState.mapId = mapId
    return SET_MAP_RESULT_MAP_CHANGED
end

WORLD_MAP_MANAGER = WORLD_MAP_MANAGER or {
    SetMapById = function(self, mapId)
        SetMapToMapId(mapId)
    end,
}

ZO_MapPin = ZO_MapPin or { ASSISTED_PIN_TYPES = {} }
ZO_WorldMapPins_Manager = ZO_WorldMapPins_Manager or {
    IsCurrentMapGlobal = function() return false end,
}
CALLBACK_MANAGER = CALLBACK_MANAGER or {
    RegisterCallback = function() end,
    FireCallbacks = function() end,
}
IsInGamepadPreferredMode = IsInGamepadPreferredMode or function() return false end
EVENT_MANAGER.AddFilterForEvent = EVENT_MANAGER.AddFilterForEvent or function() end
MAIN_MENU_KEYBOARD.ShowCategory = MAIN_MENU_KEYBOARD.ShowCategory or function(self, category)
    if category == MENU_CATEGORY_MAP then
        SCENE_MANAGER:Show("worldMap")
    end
end
INTERFACE_COLOR_TYPE_GENERAL = INTERFACE_COLOR_TYPE_GENERAL or 1
INTERFACE_GENERAL_COLOR_DISABLED = INTERFACE_GENERAL_COLOR_DISABLED or 1
GetInterfaceColor = GetInterfaceColor or function() return 0.5, 0.5, 0.5, 1 end

GetCurrentMapId = function()
    return mockState.mapId
end

GetCurrentMapZoneIndex = function()
    return 1
end

GetZoneId = function(zoneIndex)
    return mockState.zoneId
end

GetUnitZoneIndex = function(unitTag)
    return 1
end

GetMapName = function()
    return mockState.mapName
end

GetMapPlayerPosition = function(unitTag)
    return mockState.playerX, mockState.playerY, 0, true, false
end

GetUnitWorldPosition = function(unitTag)
    return mockState.zoneId, mockState.worldX, mockState.worldY, mockState.worldZ
end

CHAT_SYSTEM = {
    AddMessage = function(self, msg)
        table.insert(mockState.chatMessages, msg)
    end,
}

if EVENT_MANAGER then
    EVENT_MANAGER._updates = EVENT_MANAGER._updates or {}
    EVENT_MANAGER.RegisterForUpdate = EVENT_MANAGER.RegisterForUpdate or function(self, name, intervalMs, callback)
        self._updates[name] = { intervalMs = intervalMs, callback = callback }
    end
    EVENT_MANAGER.UnregisterForUpdate = EVENT_MANAGER.UnregisterForUpdate or function(self, name)
        self._updates[name] = nil
    end
end

GetMapType = function()
    return mockState.mapType or MAPTYPE_ZONE
end

local mockPinManager = {
    _customPins = {},
    _createdPins = {},
    _nextPinId = 500,
    AddCustomPin = function(self, pinTypeString, layoutCallback, resizeCallback, pinLayoutData, pinTooltipCreator)
        self._nextPinId = self._nextPinId + 1
        _G[pinTypeString] = self._nextPinId
        self._customPins[self._nextPinId] = {
            pinTypeString = pinTypeString,
            layoutCallback = layoutCallback,
            resizeCallback = resizeCallback,
            pinLayoutData = pinLayoutData,
            pinTooltipCreator = pinTooltipCreator,
            enabled = false,
        }
    end,
    SetCustomPinEnabled = function(self, pinTypeId, enabled)
        if self._customPins[pinTypeId] then
            self._customPins[pinTypeId].enabled = enabled
        end
    end,
    RefreshCustomPins = function(self, optionalPinType)
        self._createdPins = {}
        for id, data in pairs(self._customPins) do
            if (optionalPinType == nil or optionalPinType == id) and data.enabled and data.layoutCallback then
                data.layoutCallback(self)
            end
        end
    end,
    CreatePin = function(self, pinTypeId, pinTag, xLoc, yLoc, radius)
        local p = {
            pinTypeId = pinTypeId,
            pinTag = pinTag,
            x = xLoc,
            y = yLoc,
            radius = radius,
        }
        table.insert(self._createdPins, p)
        return p
    end,
}

ZO_WorldMap_GetPinManager = function()
    return mockPinManager
end

ZO_WorldMap_PanToNormalizedPosition = function(x, y)
    mockState.lastPannedX = x
    mockState.lastPannedY = y
end

CENTER_SCREEN_ANNOUNCE = {
    CreateMessageParams = function(self, category, sound)
        local p = { category = category, sound = sound }
        function p:SetText(mainText, subText)
            self.mainText = mainText
            self.subText = subText
        end
        function p:SetCSAType(csaType)
            self.csaType = csaType
        end
        return p
    end,
    AddMessageWithParams = function(self, params)
        table.insert(mockState.csaMessages, params)
    end,
}

WINDOW_MANAGER = WINDOW_MANAGER or {
    CreateControl = function(self, name, parent, controlType)
        local c = CreateControl(name, parent, controlType)
        function c:TakeFocus() self._focused = true end
        function c:LoseFocus() self._focused = false end
        function c:SelectAll() self._selectedAll = true end
        function c:SetHorizontalAlignment() end
        function c:SetNormalFontColor() end
        function c:SetMouseOverFontColor() end
        function c:SetCenterColor() end
        function c:SetEdgeColor() end
        function c:SetEditEnabled() end
        function c:SetMaxInputChars() end
        function c:SetMultiLine() end
        function c:SetNewLineEnabled() end
        return c
    end,
    CreateTopLevelWindow = function(self, name)
        return CreateControl(name, GuiRoot, CT_TOPLEVELCONTROL)
    end,
}

QUEST_JOURNAL_KEYBOARD = {
    initializedTabs = true,
    mode = 1,
    SetMode = function(self, m) self.mode = m end,
    OnShowing = function(self) end,
    tabs = {
        _addedTabs = {},
        _selectedFragment = nil,
        Add = function(self, name, fragments, tabData)
            self._addedTabs[name] = { fragments = fragments, tabData = tabData }
        end,
        SelectFragment = function(self, name)
            self._selectedFragment = name
            local entry = self._addedTabs[name]
            if entry and entry.fragments then
                for _, f in ipairs(entry.fragments) do
                    if f.Show then f:Show() end
                end
            end
        end,
        UpdateButtons = function(self) end,
    },
}

-- Load core, gameplay, UI and entrypoint modules under test
dofile("src/Constants.lua")
dofile("lang/en.lua")
dofile("lang/es.lua")
dofile("src/Locale.lua")
dofile("src/ShareCodec.lua")
dofile("src/QuestRepository.lua")
dofile("src/Announcements.lua")
dofile("src/TargetCapture.lua")
dofile("src/CombatTracker.lua")
dofile("src/DiscoveryTracker.lua")
dofile("src/DialogueInjector.lua")
dofile("src/WorldMapArea.lua")
dofile("src/MailTransport.lua")
dofile("src/JournalTab.lua")
dofile("RPQuest.lua")

local passed = 0
local failed = 0
local failures = {}

local function AssertEqual(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s | expected: %s, got: %s", msg or "AssertEqual failed", tostring(expected), tostring(actual)), 2)
    end
end

local function AssertTrue(cond, msg)
    if not cond then
        error(msg or "AssertTrue failed", 2)
    end
end

local function RunTest(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        table.insert(failures, string.format("FAIL [%s]: %s", name, tostring(err)))
    end
end

-- ============================================================================
-- 1. Tests de Localización (lang/en.lua, lang/es.lua, src/Locale.lua)
-- ============================================================================
RunTest("Locale automatic detection and Spanish strings", function()
    mockState.language = "es"
    RPQuest.Locale:Initialize()
    AssertEqual(RPQuest.Locale:GetLanguage(), "es", "Language should be es")
    AssertEqual(RPQuest.Locale:Get("BTN_NEW_QUEST"), "+ Nueva", "Spanish button label")
    AssertEqual(RPQuest.Locale:Get("OBJECTIVE_KILL_FORMAT", "Bandido", 1, 3), "• Eliminar a Bandido: 1 / 3", "Formatted Spanish objective")
end)

RunTest("Locale switch to English and fallback on unsupported language", function()
    mockState.language = "fr"
    RPQuest.Locale:Initialize()
    AssertEqual(RPQuest.Locale:GetLanguage(), "en", "Unsupported language falls back to en")
    AssertEqual(RPQuest.Locale:Get("BTN_NEW_QUEST"), "+ New", "English button label")
end)

-- ============================================================================
-- 2. Tests de ShareCodec (src/ShareCodec.lua)
-- ============================================================================
RunTest("ShareCodec roundtrip preserves UTF-8, pipes, newlines and coordinates", function()
    local original = {
        title = "Caza en Auridon: El Traidor | Parte 1",
        description = "Busca al capitán cerca del muelle.\nNo tengas piedad con él.",
        targets = {
            { name = "Capitán Pirata", currentCount = 0, requiredCount = 3 },
            { name = "Contramaestre", currentCount = 0, requiredCount = 1 },
        },
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.4215,
        targetY = 0.6180,
        areaCenterX = 0.4510,
        areaCenterY = 0.5920,
        areaRadius = 0.0750,
    }

    local code, err = RPQuest.ShareCodec:EncodeQuest(original)
    AssertTrue(code ~= nil, "Code should be generated without error: " .. tostring(err))
    AssertTrue(string.sub(code, 1, 5) == "RPQ3:", "Code must start with RPQ3:")

    local decoded, decErr = RPQuest.ShareCodec:DecodeQuest(code)
    AssertTrue(decoded ~= nil, "Decode should succeed: " .. tostring(decErr))
    AssertEqual(decoded.title, original.title, "Title matches")
    AssertEqual(decoded.description, original.description, "Description with newline matches")
    AssertEqual(#decoded.targets, 2, "Decoded targets count matches")
    AssertEqual(decoded.targets[1].name, "Capitán Pirata", "Target 1 name matches")
    AssertEqual(decoded.targets[1].requiredCount, 3, "Target 1 required count matches")
    AssertEqual(decoded.targets[2].name, "Contramaestre", "Target 2 name matches")
    AssertEqual(decoded.mapId, 32, "MapId matches")
    AssertEqual(decoded.zoneId, 381, "ZoneId matches")
    AssertEqual(decoded.mapName, "Auridon", "MapName matches")
    AssertTrue(math.abs(decoded.areaCenterX - original.areaCenterX) < 0.001, "AreaCenterX matches")
    AssertTrue(math.abs(decoded.areaCenterY - original.areaCenterY) < 0.001, "AreaCenterY matches")
    AssertTrue(math.abs(decoded.areaRadius - original.areaRadius) < 0.001, "AreaRadius matches")
end)

RunTest("ShareCodec rejects tampered or malformed codes", function()
    local validQuest = {
        title = "Test",
        description = "Desc",
        targets = {
            { name = "Goblin", currentCount = 0, requiredCount = 1 },
        },
        mapId = 10,
        zoneId = 20,
        mapName = "Glenumbra",
        targetX = 0.5,
        targetY = 0.5,
        areaCenterX = 0.52,
        areaCenterY = 0.48,
        areaRadius = 0.075,
    }
    local code = RPQuest.ShareCodec:EncodeQuest(validQuest)
    local tampered = code:gsub("^RPQ3:[0-9A-F][0-9A-F][0-9A-F][0-9A-F]:", "RPQ3:0000:")
    local res, tamperErr = RPQuest.ShareCodec:DecodeQuest(tampered)
    AssertEqual(res, nil, "Tampered checksum must fail")
    AssertEqual(tamperErr, "ERR_IMPORT_TRUNCATED_OR_CORRUPT", "Tampered checksum returns specific error key")

    local malformed, malformedErr = RPQuest.ShareCodec:DecodeQuest("INVALID_STRING")
    AssertEqual(malformed, nil, "Malformed string must fail")
    AssertEqual(malformedErr, "ERR_IMPORT_INVALID_FORMAT", "Malformed string returns format error key")

    local emptyRes, emptyErr = RPQuest.ShareCodec:DecodeQuest("   ")
    AssertEqual(emptyRes, nil, "Empty string must fail")
    AssertEqual(emptyErr, "ERR_IMPORT_EMPTY", "Empty string returns empty error key")

    local futureCode = code:gsub("^RPQ3:", "RPQ9:")
    local futureRes, futureErr = RPQuest.ShareCodec:DecodeQuest(futureCode)
    AssertEqual(futureRes, nil, "Unknown version prefix must fail")
    AssertEqual(futureErr, "ERR_IMPORT_UNSUPPORTED_VERSION", "Unknown version prefix returns version error key")

    validQuest.completed = true
    local compCode = RPQuest.ShareCodec:EncodeCompletion(validQuest, "Tester", 12345)
    AssertTrue(compCode ~= nil, "Completion code should be generated")
    local compRes, compErr = RPQuest.ShareCodec:DecodeQuest(compCode)
    AssertEqual(compRes, nil, "Completion code in quest importer must fail")
    AssertEqual(compErr, "ERR_IMPORT_NOT_QUEST_CODE", "Completion code returns not-quest-code error key")

    local importedBad, importedErr = RPQuest.QuestRepository:ImportQuestFromCode(futureCode)
    AssertEqual(importedBad, nil, "ImportQuestFromCode must fail on incompatible version")
    AssertEqual(importedErr, RPQuest.Locale:Get("ERR_IMPORT_UNSUPPORTED_VERSION"), "ImportQuestFromCode returns localized specific error")
end)

RunTest("ShareCodec rejects quests created in another client language", function()
    local prevLang = mockState.language
    mockState.language = "en"
    RPQuest.Locale:Initialize("en")
    RPQuest.QuestRepository:Initialize({})

    local enQuest = {
        title = "Wool Hunt",
        description = "Hunt sheep",
        targets = {
            { name = "Sheep", currentCount = 0, requiredCount = 1 },
        },
        mapId = 1,
        zoneId = 2,
        mapName = "Glenumbra",
        targetX = 0.5,
        targetY = 0.5,
        areaCenterX = 0.52,
        areaCenterY = 0.48,
        areaRadius = 0.075,
    }
    local enCode = RPQuest.ShareCodec:EncodeQuest(enQuest)
    AssertTrue(enCode ~= nil, "EncodeQuest must succeed in EN")

    -- Switch client to Spanish
    mockState.language = "es"
    RPQuest.Locale:Initialize("es")

    local decoded, errKey = RPQuest.ShareCodec:DecodeQuest(enCode)
    AssertEqual(decoded, nil, "DecodeQuest must reject quest from another language")
    AssertEqual(errKey, "ERR_IMPORT_LANGUAGE_MISMATCH", "DecodeQuest returns ERR_IMPORT_LANGUAGE_MISMATCH")

    local imported, importErr = RPQuest.QuestRepository:ImportQuestFromCode(enCode)
    AssertEqual(imported, nil, "ImportQuestFromCode must reject quest from another language")
    AssertEqual(importErr, "Misión inválida: creada en otro idioma.", "ImportQuestFromCode returns localized Spanish mismatch error")

    -- Same language (ES -> ES) must succeed
    local esCode = RPQuest.ShareCodec:EncodeQuest(enQuest)
    local decodedEs, errEs = RPQuest.ShareCodec:DecodeQuest(esCode)
    AssertTrue(decodedEs ~= nil, "DecodeQuest must accept quest in same language")
    AssertEqual(errEs, nil, "No error when language matches")
    AssertEqual(decodedEs.language, "es", "Decoded quest preserves source language")

    -- Restore
    mockState.language = prevLang
    RPQuest.Locale:Initialize(prevLang)
end)

-- ============================================================================
-- 3. Tests de QuestRepository (src/QuestRepository.lua)
-- ============================================================================
RunTest("QuestRepository offset calculation keeps target inside circle but off-center", function()
    RPQuest.QuestRepository:Initialize({})
    local tx, ty = 0.50, 0.50
    local radius = 0.08
    for i = 0, 10 do
        local cx, cy = RPQuest.QuestRepository:ComputeOffsetCenter(tx, ty, radius, i / 10, 0.5)
        local dx = tx - cx
        local dy = ty - cy
        local dist = math.sqrt((dx * dx) + (dy * dy))
        AssertTrue(dist > 0.005, "Center must not be identical to target exact point")
        AssertTrue(dist < radius, "Target must strictly lie inside the search circle radius")
    end
end)

RunTest("QuestRepository full lifecycle: Draft, Save, Edit, Kill Progress, Complete, Reset, Export/Import, Delete", function()
    mockState.language = "es"
    RPQuest.Locale:Initialize("es")
    RPQuest.QuestRepository:Initialize({})

    -- 1. Capturar objetivo en borrador (2 veces para inferir requiredCount = 2)
    RPQuest.QuestRepository:SetDraftCapturedTarget({
        targetName = "Nigromante Oscuro^m",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.40,
        targetY = 0.60,
    })
    RPQuest.QuestRepository:SetDraftCapturedTarget({
        targetName = "Nigromante Oscuro^m",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.40,
        targetY = 0.60,
    })

    -- 2. Guardar misión con 2 bajas requeridas inferidas
    local quest, err = RPQuest.QuestRepository:SaveDraft("Purga en el Bosque", "Elimina a los nigromantes.", 0.075)
    AssertTrue(quest ~= nil, "Quest should be created: " .. tostring(err))
    AssertEqual(quest.role, RPQuest.Constants.QUEST_ROLE.PREPARED, "Newly created quest has role=prepared")
    AssertEqual(quest.targets[1].name, "Nigromante Oscuro", "Gender suffix stripped")
    AssertEqual(quest.targets[1].requiredCount, 2, "Required count is 2")
    AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Newly created prepared quest does not auto-activate")
    RPQuest.QuestRepository:SetActiveQuest(quest.id)
    AssertEqual(RPQuest.QuestRepository:GetActiveQuest().id, quest.id, "Prepared quest can be activated manually for local testing")

    -- 3. Editar la misión
    RPQuest.QuestRepository:LoadQuestIntoDraft(quest.id)
    local updated = RPQuest.QuestRepository:SaveDraft("Purga Real en el Bosque", "Nueva descripción", 0.075)
    AssertEqual(updated.title, "Purga Real en el Bosque", "Quest title updated in place")
    AssertEqual(#RPQuest.QuestRepository:GetAllQuests(), 1, "Still 1 quest after edit")

    -- 4. Progreso de bajas en mapa incorrecto (debe ignorarse)
    local recWrongMap = RPQuest.QuestRepository:RecordTargetEliminated("Nigromante Oscuro", {
        mapId = 999,
        zoneId = 999,
        x = 0.40,
        y = 0.60,
    })
    AssertEqual(recWrongMap, false, "Kill in wrong map/zone must not count")

    -- 5. Primera baja válida (1/2)
    local rec1, _, comp1 = RPQuest.QuestRepository:RecordTargetEliminated("Nigromante Oscuro^m", {
        mapId = 32,
        zoneId = 381,
        x = 0.40,
        y = 0.60,
    })
    AssertTrue(rec1, "First valid kill recorded")
    AssertEqual(comp1, false, "Not completed at 1/2")
    AssertEqual(quest.targets[1].currentCount, 1, "Current count is 1")

    -- 6. Segunda baja válida (2/2 -> Completada)
    local rec2, _, comp2 = RPQuest.QuestRepository:RecordTargetEliminated("Nigromante Oscuro", {
        mapId = 32,
        zoneId = 381,
        x = 0.40,
        y = 0.60,
    })
    AssertTrue(rec2, "Second valid kill recorded")
    AssertTrue(comp2, "Completed at 2/2")
    AssertTrue(quest.completed, "Quest marked completed")
    AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Active quest cleared upon completion")
    AssertEqual(#RPQuest.QuestRepository:GetCompletedQuests(), 1, "1 quest in completed list")

    -- 7. Exportar e Importar misión por código
    local shareCode = RPQuest.QuestRepository:ExportQuestToCode(quest.id)
    AssertTrue(shareCode ~= nil, "Share code exported")
    local imported, impErr = RPQuest.QuestRepository:ImportQuestFromCode(shareCode)
    AssertTrue(imported ~= nil, "Imported quest created: " .. tostring(impErr))
    AssertEqual(imported.title, "Purga Real en el Bosque", "Imported title matches")
    AssertEqual(imported.completed, false, "Imported quest starts uncompleted")
    AssertEqual(imported.targets[1].currentCount, 0, "Imported quest starts at 0 kills")
    AssertEqual(RPQuest.QuestRepository:GetActiveQuest().id, imported.id, "Imported quest becomes active")

    -- 8. Reiniciar misión completada
    RPQuest.QuestRepository:ResetQuest(quest.id)
    AssertEqual(quest.completed, false, "Reset quest is uncompleted")
    AssertEqual(quest.targets[1].currentCount, 0, "Reset quest count is 0")

    -- 9. Eliminar misiones
    AssertTrue(RPQuest.QuestRepository:DeleteQuest(imported.id), "Delete imported quest")
    AssertTrue(RPQuest.QuestRepository:DeleteQuest(quest.id), "Delete original quest")
    AssertEqual(#RPQuest.QuestRepository:GetAllQuests(), 0, "All quests deleted")
end)

-- ============================================================================
-- 4. Tests de TargetCapture, CombatTracker, Announcements y WorldMapArea
-- ============================================================================
RunTest("TargetCapture validates reticle unit and captures map coordinates into draft", function()
    mockState.language = "es"
    RPQuest.Locale:Initialize("es")
    RPQuest.QuestRepository:Initialize({})

    -- Sin objetivo bajo retícula
    mockState.reticleExists = false
    local d1, _ = RPQuest.TargetCapture:CaptureFromReticle()
    AssertEqual(d1, nil, "Must reject empty reticle")

    -- Objetivo es otro jugador
    mockState.reticleExists = true
    mockState.reticleIsPlayer = true
    local d2, _ = RPQuest.TargetCapture:CaptureFromReticle()
    AssertEqual(d2, nil, "Must reject player unit")

    -- Objetivo ya muerto
    mockState.reticleIsPlayer = false
    mockState.reticleIsDead = true
    local d3, _ = RPQuest.TargetCapture:CaptureFromReticle()
    AssertEqual(d3, nil, "Must reject dead unit")

    -- Objetivo NPC válido
    mockState.reticleIsDead = false
    mockState.reticleName = "Jefe Bandido^m"
    mockState.mapId = 45
    mockState.zoneId = 104
    mockState.mapName = "Deshaan"
    mockState.playerX = 0.3300
    mockState.playerY = 0.7700

    local draft = RPQuest.TargetCapture:CaptureFromReticle()
    AssertTrue(draft ~= nil, "Valid NPC must be captured into draft")
    AssertEqual(draft.targets[1].name, "Jefe Bandido", "Captured target name normalized")
    AssertEqual(draft.mapId, 45, "Captured mapId matches")
    AssertEqual(draft.mapName, "Deshaan", "Captured mapName matches")
    AssertEqual(draft.targetX, 0.3300, "Captured targetX matches")
    AssertEqual(draft.targetY, 0.7700, "Captured targetY matches")
    AssertTrue(draft.areaCenterX ~= nil and draft.areaCenterY ~= nil, "Offset area center generated")
end)

RunTest("CombatTracker + WorldMapArea integration: area pin shown when active, hidden when completed", function()
    mockState.language = "es"
    RPQuest.Locale:Initialize("es")
    RPQuest.QuestRepository:Initialize({})
    RPQuest.CombatTracker:Initialize()
    RPQuest.WorldMapArea:Initialize()
    mockState.csaMessages = {}

    mockState.reticleExists = true
    mockState.reticleIsPlayer = false
    mockState.reticleIsDead = false
    mockState.reticleName = "Cultista de Gusano"
    mockState.mapId = 45
    mockState.zoneId = 104
    mockState.mapName = "Deshaan"
    mockState.playerX = 0.50
    mockState.playerY = 0.50

    RPQuest.TargetCapture:CaptureFromReticle()
    RPQuest.TargetCapture:CaptureFromReticle()
    local q = RPQuest.QuestRepository:SaveDraft("Amenaza del Culto", "Elimina a 2 cultistas.", 0.08)
    AssertTrue(q ~= nil, "Quest created")
    RPQuest.QuestRepository:SetActiveQuest(q.id)

    -- Verificar que una muerte de otro NPC no consulte el mapa innecesariamente
    local mapCalls = 0
    local origSetMap = SetMapToPlayerLocation
    SetMapToPlayerLocation = function()
        mapCalls = mapCalls + 1
        return origSetMap()
    end
    EVENT_MANAGER:FireEvent(
        EVENT_COMBAT_EVENT,
        ACTION_RESULT_DIED, false, "Ataque", 0, 0,
        "Jugador", 1, "Araña del Bosque", 2,
        500, 0, 0, false, 1, 2, 100
    )
    AssertEqual(mapCalls, 0, "Unrelated NPC death must not invoke SetMapToPlayerLocation")
    SetMapToPlayerLocation = origSetMap

    -- En el mismo mapa (mapId 45) debe dibujarse 1 pin de área grande
    RPQuest.WorldMapArea:RefreshPins()
    AssertEqual(#mockPinManager._createdPins, 1, "Search area pin must be rendered on quest mapId")
    AssertEqual(mockPinManager._createdPins[1].radius, 0.08, "Pin uses quest area radius")

    -- En otro mapa (mapId 99) no debe dibujarse ningún pin
    mockState.mapId = 99
    RPQuest.WorldMapArea:RefreshPins()
    AssertEqual(#mockPinManager._createdPins, 0, "No pin rendered on unrelated mapId")

    -- Volver al mapa 45 y disparar EVENT_COMBAT_EVENT (1ra muerte)
    mockState.mapId = 45
    EVENT_MANAGER:FireEvent(
        EVENT_COMBAT_EVENT,
        ACTION_RESULT_DIED, false, "Ataque", 0, 0,
        "Jugador", COMBAT_UNIT_TYPE_PLAYER, "Cultista de Gusano^m", COMBAT_UNIT_TYPE_OTHER,
        1500, 0, 0, false, 1, 2001, 100
    )
    AssertEqual(q.targets[1].currentCount, 1, "Kill count incremented to 1")
    AssertEqual(q.completed, false, "Not yet completed")
    AssertEqual(#mockState.csaMessages, 1, "1 CSA progress message emitted")

    -- Mismo targetUnitId con ACTION_RESULT_DIED_XP no debe duplicar
    EVENT_MANAGER:FireEvent(
        EVENT_COMBAT_EVENT,
        ACTION_RESULT_DIED_XP, false, "Ataque", 0, 0,
        "Jugador", COMBAT_UNIT_TYPE_PLAYER, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
        1500, 0, 0, false, 1, 2001, 100
    )
    AssertEqual(q.targets[1].currentCount, 1, "Duplicate death event for same targetUnitId is ignored")

    -- Muerte causada por otro jugador ajeno (sin grupo) no cuenta
    mockState.isGrouped = false
    EVENT_MANAGER:FireEvent(
        EVENT_COMBAT_EVENT,
        ACTION_RESULT_DIED, false, "Ataque", 0, 0,
        "Desconocido", COMBAT_UNIT_TYPE_OTHER, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
        1500, 0, 0, false, 99, 2002, 100
    )
    AssertEqual(q.targets[1].currentCount, 1, "Unrelated player kill does not count")

    -- Muerte de miembro de grupo cuando NO se está en grupo no cuenta
    EVENT_MANAGER:FireEvent(
        EVENT_COMBAT_EVENT,
        ACTION_RESULT_DIED, false, "Ataque", 0, 0,
        "Compañero", COMBAT_UNIT_TYPE_GROUP, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
        1500, 0, 0, false, 98, 2003, 100
    )
    AssertEqual(q.targets[1].currentCount, 1, "Group unit kill ignored when solo")

    -- En grupo, muerte de miembro del grupo sigue siendo ignorada (flujo 1-a-1)
    mockState.isGrouped = true
    EVENT_MANAGER:FireEvent(
        EVENT_COMBAT_EVENT,
        ACTION_RESULT_DIED_XP, false, "Ataque", 0, 0,
        "Compañero", COMBAT_UNIT_TYPE_GROUP, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
        1500, 0, 0, false, 98, 2004, 100
    )
    mockState.isGrouped = false
    AssertEqual(q.targets[1].currentCount, 1, "Group unit kill ignored even when grouped")

    -- Muerte del jugador completa la misión
    EVENT_MANAGER:FireEvent(
        EVENT_COMBAT_EVENT,
        ACTION_RESULT_DIED_XP, false, "Ataque", 0, 0,
        "Jugador", COMBAT_UNIT_TYPE_PLAYER, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
        1500, 0, 0, false, 1, 2005, 100
    )
    AssertTrue(q.completed, "Quest completed on second kill")
    AssertEqual(#mockState.csaMessages, 2, "CSA completion message emitted")
    AssertEqual(mockState.csaMessages[2].sound, SOUNDS.QUEST_COMPLETED, "Played QUEST_COMPLETED sound")
    AssertEqual(#mockPinManager._createdPins, 0, "Search area pin automatically removed when quest completes")
end)

-- ============================================================================
-- 5. Tests de JournalTab y Ciclo de Vida EVENT_ADD_ON_LOADED
-- ============================================================================
RunTest("RPQuest Initialize via EVENT_ADD_ON_LOADED sets up Character SavedVars and JournalTab", function()
    mockState.language = "es"
    EVENT_MANAGER:FireEvent(EVENT_ADD_ON_LOADED, "RPQuest")

    AssertTrue(RPQuest.savedVars ~= nil, "Character SavedVars initialized")
    AssertTrue(RPQuest.JournalTab.isInitialized, "JournalTab initialized")
    AssertTrue(RPQuest.JournalTab.isTabAdded, "Custom Quests tab registered in QUEST_JOURNAL_KEYBOARD.tabs")

    -- Crear una misión desde la UI del Editor en la pestaña del Diario
    RPQuest.JournalTab:OpenTab()
    RPQuest.JournalTab:OpenCreateEditor()
    AssertEqual(RPQuest.JournalTab.editorPane:IsHidden(), false, "Editor pane is visible")

    mockState.reticleExists = true
    mockState.reticleIsPlayer = false
    mockState.reticleIsDead = false
    mockState.reticleName = "Señor Vampiro"
    mockState.mapId = 60
    mockState.zoneId = 200
    mockState.mapName = "Rivenspire"
    mockState.playerX = 0.25
    mockState.playerY = 0.75

    RPQuest:OnCaptureTargetKeybind()
    RPQuest.JournalTab.titleEdit:SetText("Cacería Nocturna")
    RPQuest.JournalTab.descEdit:SetText("Derrota al vampiro en las ruinas.")
    AssertEqual(RPQuest.JournalTab.countEdit, nil, "Manual countEdit must not exist in JournalTab")
    AssertEqual(RPQuest.JournalTab.btnSaveEditor:GetText(), "Crear Misión", "Spanish button label is Crear Misión")
    RPQuest.JournalTab.titleEdit:FireHandler("OnMouseDown")
    AssertTrue(RPQuest.JournalTab.titleEdit._focused, "Clicking titleEdit focuses it for keyboard input")
    RPQuest.JournalTab.descEdit:FireHandler("OnMouseDown")
    AssertTrue(RPQuest.JournalTab.descEdit._focused, "Clicking descEdit focuses it for keyboard input")
    RPQuest.JournalTab:OnSaveDraftClicked()

    local savedList = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.PREPARED)
    AssertEqual(#savedList, 1, "Prepared quest saved from JournalTab")
    local preparedQuest = savedList[1]
    AssertEqual(preparedQuest.title, "Cacería Nocturna", "Saved title matches")
    AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Prepared quest is not auto-activated on save")

    -- Probar la misión manualmente desde En Preparación
    RPQuest.JournalTab:OnToggleActiveClicked()
    local active = RPQuest.QuestRepository:GetActiveQuest()
    AssertTrue(active ~= nil and active.id == preparedQuest.id, "Prepared quest activated for local testing via JournalTab")

    -- Código para compartir siempre visible en shareEdit al seleccionar/crear la misión
    local generatedCode = RPQuest.JournalTab.shareEdit:GetText()
    AssertTrue(string.sub(generatedCode, 1, 5) == "RPQ3:", "Share edit box auto-populated with RPQ3 code")
    AssertEqual(RPQuest.JournalTab.btnShare, nil, "Share button removed in favor of always-visible share box")
    RPQuest.JournalTab.shareEdit._selectedAll = false
    RPQuest.JournalTab.shareEdit:FireHandler("OnFocusGained")
    AssertTrue(RPQuest.JournalTab.shareEdit._selectedAll, "Share edit box selects all text when focused")

    -- Probar vista Importar en JournalTab
    mockState.csaMessages = {}
    RPQuest.JournalTab:OpenImportView()
    AssertEqual(RPQuest.JournalTab.importPane:IsHidden(), false, "Import pane is visible")
    RPQuest.JournalTab.importCodeEdit:SetText(generatedCode)
    RPQuest.JournalTab:OnConfirmImportClicked()
    AssertEqual(#RPQuest.QuestRepository:GetAllQuests(), 2, "Second quest imported via UI")
    AssertEqual(#mockState.csaMessages, 1, "Importing quest emits one CENTER_SCREEN_ANNOUNCE banner")
    AssertEqual(mockState.csaMessages[1].category, CSA_CATEGORY_LARGE_TEXT, "Quest accepted CSA uses large text category")
    AssertEqual(mockState.csaMessages[1].sound, SOUNDS.QUEST_ACCEPTED, "Quest accepted CSA plays SOUNDS.QUEST_ACCEPTED")
    AssertEqual(mockState.csaMessages[1].csaType, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED, "Quest accepted CSA uses CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED")

    -- Verificar que salir de Edit mode seleccionando otra misión limpia editingQuestId
    RPQuest.JournalTab:OpenEditEditor(active.id)
    AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, active.id, "Draft has editingQuestId while in Edit mode")
    RPQuest.JournalTab:SelectQuest(active.id)
    AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, nil, "Selecting a quest in list clears orphaned editingQuestId")
end)

RunTest("Reticle inference: repeated same NPC (Imp x3) and multiple named NPCs + Create Quest button", function()
    mockState.language = "en"
    RPQuest.Locale:Initialize("en")
    AssertEqual(RPQuest.Locale:Get("BTN_SAVE"), "Create Quest", "English create button label is Create Quest")

    RPQuest.QuestRepository:Initialize({})
    mockState.reticleExists = true
    mockState.reticleIsPlayer = false
    mockState.reticleIsDead = false
    mockState.mapId = 32
    mockState.zoneId = 381
    mockState.mapName = "Auridon"
    mockState.playerX = 0.50
    mockState.playerY = 0.50

    -- Caso A: Apuntar a un Imp 3 veces -> objetivo inferido: Imp x3
    mockState.reticleName = "Imp"
    RPQuest.TargetCapture:CaptureFromReticle()
    RPQuest.TargetCapture:CaptureFromReticle()
    local draftImp = RPQuest.TargetCapture:CaptureFromReticle()
    AssertEqual(#draftImp.targets, 1, "Same NPC merges into 1 target entry")
    AssertEqual(draftImp.targets[1].requiredCount, 3, "Imp captured 3 times requires 3 kills")
    AssertEqual(RPQuest.QuestRepository:FormatTargetsSummary(draftImp.targets), "Imp x3", "Formatted summary is Imp x3")

    local impQuest = RPQuest.QuestRepository:SaveDraft("Imp Hunt", "Clear the imps.")
    AssertEqual(impQuest.targets[1].requiredCount, 3, "Saved quest inferred requiredCount = 3 from reticle")

    -- Caso B: Apuntar a dos NPCs con nombre distinto -> ambos son objetivos exclusivos
    mockState.reticleName = "Lord Vane"
    RPQuest.TargetCapture:CaptureFromReticle()
    mockState.reticleName = "Lady Vane"
    local draftDuo = RPQuest.TargetCapture:CaptureFromReticle()
    AssertEqual(#draftDuo.targets, 2, "Two distinct named NPCs create 2 target entries")
    AssertEqual(RPQuest.QuestRepository:FormatTargetsSummary(draftDuo.targets), "Lord Vane, Lady Vane", "Summary lists both named NPCs")

    local duoQuest = RPQuest.QuestRepository:SaveDraft("Twin Assassination", "Eliminate both targets.")
    AssertEqual(#duoQuest.targets, 2, "Saved quest has 2 distinct targets")
    RPQuest.QuestRepository:SetActiveQuest(duoQuest.id)

    -- Matar a Lord Vane 2 veces no debe completar a Lady Vane
    local r1, _, c1 = RPQuest.QuestRepository:RecordTargetEliminated("Lord Vane", { mapId = 32, zoneId = 381, x = 0.50, y = 0.50 })
    AssertTrue(r1 and not c1, "Killing Lord Vane advances progress but does not complete quest")
    local rDup = RPQuest.QuestRepository:RecordTargetEliminated("Lord Vane", { mapId = 32, zoneId = 381, x = 0.50, y = 0.50 })
    AssertEqual(rDup, false, "Killing already completed named target again is ignored")

    -- Matar a Lady Vane completa la misión
    local r2, _, c2 = RPQuest.QuestRepository:RecordTargetEliminated("Lady Vane", { mapId = 32, zoneId = 381, x = 0.50, y = 0.50 })
    AssertTrue(r2 and c2, "Killing second named target completes the quest")

    -- Exportar e importar misión multi-objetivo conserva todos los objetivos
    local code = RPQuest.QuestRepository:ExportQuestToCode(duoQuest.id)
    local imported = RPQuest.QuestRepository:ImportQuestFromCode(code)
    AssertEqual(#imported.targets, 2, "Imported multi-target quest preserves both targets")
    AssertEqual(imported.targets[1].name, "Lord Vane", "First imported target matches")
    AssertEqual(imported.targets[2].name, "Lady Vane", "Second imported target matches")

    -- Caso C: Capturar objetivos en mapas distintos reinicia la lista al nuevo mapa
    RPQuest.QuestRepository:ResetDraft()
    mockState.mapId = 32
    mockState.playerX = 0.20
    mockState.playerY = 0.20
    mockState.reticleName = "Guardia de Auridon"
    RPQuest.TargetCapture:CaptureFromReticle()

    mockState.mapId = 45
    mockState.playerX = 0.80
    mockState.playerY = 0.80
    mockState.reticleName = "Guardia de Deshaan"
    local draftMapSwitch = RPQuest.TargetCapture:CaptureFromReticle()
    AssertEqual(#draftMapSwitch.targets, 1, "Capturing target in a new map resets targets from previous map")
    AssertEqual(draftMapSwitch.targets[1].name, "Guardia de Deshaan", "Only the new map target remains")
    AssertEqual(draftMapSwitch.targetX, 0.80, "Centroid X is strictly from the new map")
    AssertEqual(draftMapSwitch.targetY, 0.80, "Centroid Y is strictly from the new map")

    -- Caso D: ClearDraftTargets limpia también metadatos del mapa
    RPQuest.QuestRepository:ClearDraftTargets()
    AssertEqual(draftMapSwitch.mapId, 0, "ClearDraftTargets resets mapId to 0")
    AssertEqual(draftMapSwitch.zoneId, 0, "ClearDraftTargets resets zoneId to 0")
    AssertEqual(draftMapSwitch.mapName, "", "ClearDraftTargets resets mapName to empty")
end)

RunTest("Bugfixes: DeleteQuest resets dangling draft and JournalTab scrolls >14 rows", function()
    RPQuest.QuestRepository:Initialize({})
    RPQuest.JournalTab:Initialize()

    -- 1. DeleteQuest limpia editingQuestId si esa misión estaba en edición
    mockState.reticleExists = true
    mockState.reticleName = "Bandido"
    RPQuest.TargetCapture:CaptureFromReticle()
    local q1 = RPQuest.QuestRepository:SaveDraft("Misión Uno", "Desc", 0.05)
    RPQuest.JournalTab:OpenEditEditor(q1.id)
    AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, q1.id, "Draft editing q1")
    RPQuest.QuestRepository:DeleteQuest(q1.id)
    AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, nil, "DeleteQuest clears dangling editingQuestId")

    -- 2. JournalTab pagina/desplaza más allá de 14 filas
    for i = 1, 16 do
        RPQuest.TargetCapture:CaptureFromReticle()
        RPQuest.QuestRepository:SaveDraft("Quest #" .. tostring(i), "", 0.05)
    end
    RPQuest.JournalTab:Refresh()
    AssertEqual(RPQuest.JournalTab.btnListNext:IsHidden(), false, "Scroll Next button shown when > 14 rows")
    AssertEqual(RPQuest.JournalTab.listOffset, 0, "Initial listOffset is 0")
    RPQuest.JournalTab:ScrollQuestList(2)
    AssertEqual(RPQuest.JournalTab.listOffset, 2, "ScrollQuestList advances offset")
    AssertEqual(RPQuest.JournalTab.rowBindings[1].questId, 3, "First visible row reflects scrolled offset")
end)

RunTest("12. Higiene UI: anclaje dinámico de botones, título único tras borrado y ciclo _dirty", function()
    RPQuest.QuestRepository:Initialize({})
    RPQuest.JournalTab:Initialize()
    mockState.reticleExists = true
    mockState.reticleName = "Bandido"

    -- 1. Título por defecto usa nextId y no colisiona tras borrar
    RPQuest.TargetCapture:CaptureFromReticle()
    local qa = RPQuest.QuestRepository:SaveDraft("", "", 0.05)
    RPQuest.TargetCapture:CaptureFromReticle()
    local qb = RPQuest.QuestRepository:SaveDraft("", "", 0.05)
    RPQuest.QuestRepository:DeleteQuest(qa.id)
    RPQuest.TargetCapture:CaptureFromReticle()
    local qc = RPQuest.QuestRepository:SaveDraft("", "", 0.05)
    AssertTrue(qb.title ~= qc.title, "Default title uses nextId and does not collide after deletion")

    -- 2. Separador de código, cuadro de compartir y cuadro de validación visibles en detalle de misión
    RPQuest.JournalTab:SelectQuest(qc.id)
    AssertEqual(RPQuest.JournalTab.codeDivider:IsHidden(), false, "codeDivider visible when quest selected")
    AssertEqual(RPQuest.JournalTab.shareBg:IsHidden(), false, "shareBg always visible in code section when quest selected")
    AssertEqual(RPQuest.JournalTab.validateBg:IsHidden(), false, "validateBg visible for prepared quest")
    AssertEqual(RPQuest.JournalTab.shareHeader._anchors[1].relTo, RPQuest.JournalTab.codeDivider, "shareHeader anchored below codeDivider")

    -- 3. _dirty se marca cuando panel está oculto y se limpia al abrir
    RPQuest.JournalTab.panel:SetHidden(true)
    RPQuest.QuestRepository:SetActiveQuest(qb.id)
    AssertEqual(RPQuest.JournalTab._dirty, true, "_dirty set while panel is hidden")
    RPQuest.JournalTab:OpenTab()
    AssertEqual(RPQuest.JournalTab._dirty, false, "_dirty cleared after OpenTab")
end)

RunTest("13. Separación de roles: En Preparación vs Para Jugar, prueba local y bloqueo de edición en recibidas", function()
    mockState.language = "es"
    RPQuest.Locale:Initialize("es")

    -- 1. Migración de misiones legacy sin campo role -> received
    RPQuest.QuestRepository:Initialize({
        nextId = 2,
        quests = {
            { id = 1, title = "Legacy", description = "", targets = { { name = "Imp", currentCount = 0, requiredCount = 1 } }, completed = false },
        },
    })
    local legacy = RPQuest.QuestRepository:GetQuestById(1)
    AssertEqual(legacy.role, RPQuest.Constants.QUEST_ROLE.RECEIVED, "Legacy quest without role migrates to received")

    RPQuest.JournalTab:Initialize()
    RPQuest.JournalTab.collapsedSections = { missions = false, completed = true, preparing = true }
    RPQuest.JournalTab:Refresh()
    -- Sin misiones en preparación, la sección PREPARANDO no aparece en el árbol
    local hasPreparingHeader = false
    for _, b in pairs(RPQuest.JournalTab.rowBindings) do
        if b.isHeader and b.sectionKey == "preparing" then
            hasPreparingHeader = true
        end
    end
    AssertEqual(hasPreparingHeader, false, "PREPARANDO section is hidden when empty")
    AssertEqual(RPQuest.JournalTab.collapsedSections.missions, false, "MISIONES section starts expanded")
    AssertEqual(RPQuest.JournalTab.collapsedSections.completed, true, "COMPLETADAS section starts collapsed")
    AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, true, "PREPARANDO section starts collapsed")

    mockState.reticleExists = true
    mockState.reticleName = "Cultista"
    mockState.mapId = 32
    mockState.zoneId = 381
    mockState.mapName = "Auridon"
    mockState.playerX = 0.5
    mockState.playerY = 0.5

    -- 2. Crear misión nueva -> role=prepared, no se auto-activa, expande PREPARANDO
    RPQuest.TargetCapture:CaptureFromReticle()
    local prep = RPQuest.QuestRepository:SaveDraft("Misión GM", "Para probar y enviar", 0.05)
    AssertEqual(prep.role, RPQuest.Constants.QUEST_ROLE.PREPARED, "Created quest is prepared")
    AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Created quest does not auto-activate")
    AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, false, "JournalTab expands PREPARANDO on create")
    AssertEqual(RPQuest.JournalTab.btnEdit:IsHidden(), false, "Edit button visible for prepared quest")
    AssertEqual(RPQuest.JournalTab.btnActivate:GetText(), "Probar", "Activate button says Probar for prepared quest")

    -- 2b. Sección con item seleccionado no se colapsa; sin item seleccionado/activo sí colapsa y expande
    RPQuest.JournalTab:ToggleSection("preparing")
    AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, false, "Section with selected quest stays expanded")
    RPQuest.JournalTab:SelectQuest(nil)
    RPQuest.JournalTab:ToggleSection("preparing")
    AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, true, "ToggleSection collapses preparing when no item is selected/active")
    local prepRowVisible = false
    for _, b in pairs(RPQuest.JournalTab.rowBindings) do
        if b.questId == prep.id then prepRowVisible = true end
    end
    AssertEqual(prepRowVisible, false, "Collapsed section hides its quest rows")
    RPQuest.JournalTab:ToggleSection("preparing")
    AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, false, "ToggleSection expands preparing again")
    RPQuest.JournalTab:SelectQuest(prep.id)

    -- 2c. Mostrar en mapa una misión en preparación (aunque no esté activa)
    RPQuest.WorldMapArea:Initialize()
    RPQuest.WorldMapArea:ShowQuestOnMap(prep)
    local pins = ZO_WorldMap_GetPinManager()._createdPins
    AssertEqual(#pins, 1, "ShowQuestOnMap renders area pin for prepared quest even when inactive")
    AssertEqual(pins[1].pinTag, prep.id, "Rendered preview pin belongs to prepared quest")
    AssertEqual(pins[1].radius, 0.05, "Rendered preview pin uses prepared quest radius")

    -- 3. Probar localmente y luego detener prueba
    RPQuest.JournalTab:OnToggleActiveClicked()
    AssertEqual(RPQuest.QuestRepository:GetActiveQuest().id, prep.id, "Prepared quest activated for local testing")
    AssertEqual(RPQuest.JournalTab.btnActivate:GetText(), "Dejar de probar", "Activate button says Dejar de probar while testing")

    -- 4. Compartir e importar -> misión recibida en MISIONES sin botón Editar
    local code = RPQuest.QuestRepository:ExportQuestToCode(prep.id)
    local imported = RPQuest.QuestRepository:ImportQuestFromCode(code)
    AssertEqual(imported.role, RPQuest.Constants.QUEST_ROLE.RECEIVED, "Imported quest has role=received")
    AssertEqual(RPQuest.JournalTab.collapsedSections.missions, false, "JournalTab expands MISIONES on import")
    AssertEqual(RPQuest.JournalTab.btnEdit:IsHidden(), true, "Edit button hidden for received quest")
    AssertEqual(RPQuest.JournalTab.btnReset:IsHidden(), true, "Reset button hidden for received quest")
    AssertEqual(RPQuest.JournalTab.btnActivate:GetText(), "Desactivar", "Imported quest is active so button says Desactivar")

    local deniedDraft, deniedErr = RPQuest.QuestRepository:LoadQuestIntoDraft(imported.id)
    AssertEqual(deniedDraft, nil, "LoadQuestIntoDraft rejects received quest")
    AssertTrue(type(deniedErr) == "string" and deniedErr ~= "", "Rejection returns localized error message")
end)

RunTest("14. Mensaje de finalizacion editable y refresco de pin al editar radio y abrir mapa", function()
    RPQuest.QuestRepository:Initialize({})
    RPQuest.JournalTab:Initialize()
    RPQuest.WorldMapArea:Initialize()

    mockState.reticleExists = true
    mockState.reticleName = "Oveja"
    mockState.mapId = 45
    mockState.zoneId = 104
    mockState.mapName = "Deshaan"
    mockState.playerX = 0.50
    mockState.playerY = 0.50

    -- 1. Crear misión con mensaje de finalización personalizado desde JournalTab
    RPQuest.JournalTab:OpenCreateEditor()
    RPQuest.TargetCapture:CaptureFromReticle()
    RPQuest.JournalTab.titleEdit:SetText("Gran Cacería")
    RPQuest.JournalTab.descEdit:SetText("Caza en el valle.")
    RPQuest.JournalTab.completionEdit:SetText("¡Has limpiado el valle!")
    RPQuest.JournalTab:OnSaveDraftClicked()

    local q = RPQuest.QuestRepository:GetAllQuests()[1]
    AssertEqual(q.completionMessage, "¡Has limpiado el valle!", "completionMessage saved from JournalTab")

    -- 2. ShareCodec preserva completionMessage
    local code = RPQuest.QuestRepository:ExportQuestToCode(q.id)
    local decoded = RPQuest.ShareCodec:DecodeQuest(code)
    AssertEqual(decoded.completionMessage, "¡Has limpiado el valle!", "ShareCodec preserves completionMessage")

    -- 3. AnnounceQuestCompleted usa completionMessage en lugar de un único objetivo
    local capturedSubText = nil
    local origCSA = CENTER_SCREEN_ANNOUNCE
    CENTER_SCREEN_ANNOUNCE = {
        CreateMessageParams = function()
            return {
                SetText = function(_, _, sub) capturedSubText = sub end,
                SetCSAType = function() end,
            }
        end,
        AddMessageWithParams = function() end,
    }
    RPQuest.Announcements:AnnounceQuestCompleted(q)
    AssertEqual(capturedSubText, "¡Has limpiado el valle!", "AnnounceQuestCompleted uses custom completionMessage")

    -- Sin mensaje personalizado -> subText es nil (no muestra un único objetivo parcial)
    RPQuest.Announcements:AnnounceQuestCompleted({ title = "Sin Msg", completionMessage = "", targets = { { name = "Tirusa", currentCount = 1, requiredCount = 1 } } })
    AssertEqual(capturedSubText, nil, "AnnounceQuestCompleted omits subText when completionMessage is empty")
    CENTER_SCREEN_ANNOUNCE = origCSA

    -- 4. Editar radio de área, desactivar/reactivar y mostrar escena del mapa refresca el pin con el nuevo radio
    RPQuest.JournalTab:OpenEditEditor(q.id)
    RPQuest.QuestRepository:UpdateDraftFields({ areaRadius = RPQuest.Constants.AREA_RADIUS.LARGE })
    RPQuest.JournalTab:OnSaveDraftClicked()
    RPQuest.QuestRepository:SetActiveQuest(q.id)

    -- Simular apertura del mapa mundial via WORLD_MAP_SCENE
    SCENE_MANAGER:Show("worldMap")
    AssertEqual(#mockPinManager._createdPins, 1, "WorldMapArea pin rendered after edit + reactivate + map open")
    AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.LARGE, "WorldMapArea pin uses updated LARGE radius")
end)

RunTest("15. Codigo de entrega RPQC1 y validacion por el Master", function()
    RPQuest.QuestRepository:Initialize({})
    RPQuest.JournalTab:Initialize()
    mockState.reticleExists = true
    mockState.reticleName = "Capitán Pirata^m"
    mockState.reticleIsPlayer = false
    mockState.reticleIsDead = false
    mockState.reticleAttackable = true
    mockState.mapId = 32
    mockState.zoneId = 381
    mockState.mapName = "Auridon"
    mockState.playerX = 0.42
    mockState.playerY = 0.61

    -- Master crea una misión en preparación
    RPQuest.TargetCapture:CaptureFromReticle()
    RPQuest.QuestRepository:UpdateDraftFields({
        title = "Cacería del Capitán",
        description = "Elimina al capitán pirata.",
    })
    local masterQuest = RPQuest.QuestRepository:SaveDraft()
    AssertTrue(masterQuest ~= nil, "Master quest saved")

    -- No se puede generar código de entrega si no está completada
    local noCode = RPQuest.QuestRepository:ExportCompletionCode(masterQuest.id)
    AssertEqual(noCode, nil, "Cannot export completion code for incomplete quest")

    -- Master exporta RPQ1 y otro jugador la importa y completa
    local shareCode = RPQuest.QuestRepository:ExportQuestToCode(masterQuest.id)
    local playerQuest = RPQuest.QuestRepository:ImportQuestFromCode(shareCode)
    AssertTrue(playerQuest ~= nil, "Player imported quest")

    RPQuest.QuestRepository:SetActiveQuest(playerQuest.id)
    RPQuest.QuestRepository:RecordTargetEliminated("Capitán Pirata", {
        mapId = 32,
        zoneId = 381,
        x = 0.42,
        y = 0.61,
    })
    local updatedPlayerQuest = RPQuest.QuestRepository:GetQuestById(playerQuest.id)
    AssertTrue(updatedPlayerQuest.completed, "Player quest completed")

    -- Jugador genera código de entrega RPQC1
    local completionCode = RPQuest.QuestRepository:ExportCompletionCode(playerQuest.id)
    AssertTrue(type(completionCode) == "string" and completionCode:match("^RPQC1:") ~= nil, "Completion code has RPQC1 prefix")

    -- Master valida el código contra su misión en preparación
    local ok, result = RPQuest.QuestRepository:ValidateCompletionCode(masterQuest.id, completionCode)
    AssertTrue(ok, "Completion code validates against master prepared quest")
    AssertEqual(result.characterName, "Jugador", "Completion code preserves characterName")

    -- Rechaza un código RPQ1 como si fuera entrega
    local okQuestCode, errQuestCode = RPQuest.QuestRepository:ValidateCompletionCode(masterQuest.id, shareCode)
    AssertEqual(okQuestCode, false, "RPQ1 code rejected in delivery validator")
    AssertEqual(errQuestCode, "VALIDATE_ERR_NOT_COMPLETION_CODE", "Specific error returned for RPQ1 code")

    -- Rechaza un código corrupto
    local okBad, errBad = RPQuest.QuestRepository:ValidateCompletionCode(masterQuest.id, completionCode .. "X")
    AssertEqual(okBad, false, "Corrupted RPQC1 code rejected")
    AssertEqual(errBad, "VALIDATE_ERR_INVALID_CODE", "Specific error returned for corrupted code")

    -- Rechaza un código de otra misión distinta
    RPQuest.TargetCapture:CaptureFromReticle()
    RPQuest.QuestRepository:UpdateDraftFields({ title = "Otra Misión Distinta" })
    local otherMasterQuest = RPQuest.QuestRepository:SaveDraft()
    local okWrong, errWrong = RPQuest.QuestRepository:ValidateCompletionCode(otherMasterQuest.id, completionCode)
    AssertEqual(okWrong, false, "RPQC1 from another quest rejected")
    AssertEqual(errWrong, "VALIDATE_ERR_WRONG_QUEST", "Specific error returned for wrong quest")

    -- Flujo UI en JournalTab: delivery code se genera automáticamente al completarse la misión
    RPQuest.JournalTab:SelectQuest(playerQuest.id)
    AssertEqual(RPQuest.JournalTab.btnCompletionCode, nil, "On-demand completion code button removed")
    AssertEqual(RPQuest.JournalTab.btnActivate:IsHidden(), true, "Set Active button hidden for completed player quest")
    AssertEqual(RPQuest.JournalTab.deliveryBg:IsHidden(), false, "Delivery code box visible for completed received quest")
    AssertEqual(RPQuest.JournalTab.validateBg:IsHidden(), true, "Validate box hidden for received quest")
    local initialShareText = RPQuest.JournalTab.shareEdit:GetText()
    AssertTrue(string.sub(initialShareText, 1, 5) == "RPQ3:", "shareEdit populated with RPQ3 code for received quest")
    AssertEqual(RPQuest.JournalTab.deliveryEdit:GetText(), completionCode, "JournalTab auto-populates RPQC1 code into deliveryEdit")
    AssertEqual(RPQuest.JournalTab.shareEdit:GetText(), initialShareText, "shareEdit is not overwritten by delivery code")

    -- Keybind X Abandon presente en keybindStripDescriptor
    AssertTrue(RPQuest.JournalTab.abandonQuestDescriptor ~= nil, "Abandon quest keybind descriptor exists")
    AssertEqual(RPQuest.JournalTab.abandonQuestDescriptor.keybind, "UI_SHORTCUT_NEGATIVE", "Abandon uses UI_SHORTCUT_NEGATIVE")

    -- Sección con misión seleccionada/activa no puede colapsarse (comportamiento vanilla)
    RPQuest.JournalTab.collapsedSections.completed = false
    RPQuest.JournalTab:ToggleSection("completed")
    AssertEqual(RPQuest.JournalTab.collapsedSections.completed, false, "Section with selected quest cannot be collapsed")

    -- Los textbox de código generado son readonly (revierten ediciones del usuario)
    RPQuest.JournalTab.shareEdit:SetText("MODIFIED")
    if RPQuest.JournalTab.shareEdit._handlers and RPQuest.JournalTab.shareEdit._handlers.OnTextChanged then
        RPQuest.JournalTab.shareEdit._handlers.OnTextChanged(RPQuest.JournalTab.shareEdit)
    end
    AssertEqual(RPQuest.JournalTab.shareEdit:GetText(), initialShareText, "shareEdit reverts manual edits (readonly)")

    RPQuest.JournalTab.deliveryEdit:SetText("MODIFIED")
    if RPQuest.JournalTab.deliveryEdit._handlers and RPQuest.JournalTab.deliveryEdit._handlers.OnTextChanged then
        RPQuest.JournalTab.deliveryEdit._handlers.OnTextChanged(RPQuest.JournalTab.deliveryEdit)
    end
    AssertEqual(RPQuest.JournalTab.deliveryEdit:GetText(), completionCode, "deliveryEdit reverts manual edits (readonly)")

    -- Alerta amigable al generar código de entrega (no clave cruda)
    local readyAlert = RPQuest.Locale:Get("ALERT_COMPLETION_CODE_READY")
    AssertTrue(readyAlert ~= "ALERT_COMPLETION_CODE_READY", "ALERT_COMPLETION_CODE_READY is localized")

    RPQuest.JournalTab:SelectQuest(masterQuest.id)
    AssertEqual(RPQuest.JournalTab.btnValidateDelivery:IsHidden(), false, "Validate delivery button visible for prepared quest")
    AssertEqual(RPQuest.JournalTab.validateBg:IsHidden(), false, "Validate box visible for prepared quest")
    AssertEqual(RPQuest.JournalTab.deliveryBg:IsHidden(), true, "Delivery code box hidden for prepared quest")
    AssertEqual(RPQuest.JournalTab.deliveryEdit:GetText(), "", "deliveryEdit cleared when switching quest")
    AssertTrue(string.sub(RPQuest.JournalTab.shareEdit:GetText(), 1, 5) == "RPQ3:", "shareEdit auto-populated with RPQ3 code for prepared quest")
    AssertEqual(RPQuest.JournalTab.validateEdit:GetText(), "", "validateEdit cleared when switching quest")
    RPQuest.JournalTab:OnValidateDeliveryClicked()
    local emptyMsg = RPQuest.JournalTab.validateResultLabel:GetText()
    AssertEqual(emptyMsg, RPQuest.Locale:Get("VALIDATE_ERR_EMPTY"), "Validate UI prompts when validate box is empty (ignores shareEdit)")
    RPQuest.JournalTab.validateEdit:SetText(completionCode)
    RPQuest.JournalTab:OnValidateDeliveryClicked()
    local msg = RPQuest.JournalTab.validateResultLabel:GetText()
    AssertTrue(msg:find("Jugador", 1, true) ~= nil, "Validate UI shows character name on success")
    AssertTrue(string.sub(RPQuest.JournalTab.shareEdit:GetText(), 1, 5) == "RPQ3:", "shareEdit still preserves RPQ3 code after validation")
end)

RunTest("16. Marca del mapa visible en preparacion y actualizada al instante al editar tamano", function()
    RPQuest.QuestRepository:Initialize({})
    RPQuest.JournalTab:Initialize()
    RPQuest.WorldMapArea:Initialize()

    local mockPinManager = ZO_WorldMap_GetPinManager()
    mockPinManager._createdPins = {}

    mockState.reticleExists = true
    mockState.reticleName = "Nigromante"
    mockState.reticleIsPlayer = false
    mockState.reticleIsDead = false
    mockState.reticleAttackable = true
    mockState.mapId = 45
    mockState.zoneId = 104
    mockState.mapName = "Deshaan"
    mockState.playerX = 0.50
    mockState.playerY = 0.50

    -- 1. En creación (sin guardar), capturar objetivo muestra el pin en el mapa y habilita Ver en Mapa en el editor
    RPQuest.JournalTab:OpenCreateEditor()
    AssertEqual(RPQuest.JournalTab.btnShowMapEditor:IsHidden(), true, "ShowMapEditor hidden before target capture")
    RPQuest.TargetCapture:CaptureFromReticle()
    AssertEqual(RPQuest.JournalTab.btnShowMapEditor:IsHidden(), false, "ShowMapEditor visible after target capture")
    AssertEqual(#mockPinManager._createdPins, 1, "Map pin rendered immediately during draft preparation")
    AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.MEDIUM, "Draft pin starts with MEDIUM radius")

    -- 2. Cambiar radio en el editor antes de guardar actualiza el pin al instante
    RPQuest.JournalTab.btnRadiusLarge:FireHandler("OnClicked")
    AssertEqual(#mockPinManager._createdPins, 1, "Map pin refreshed on radius change")
    AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.LARGE, "Draft pin immediately reflects LARGE radius")

    -- Guardar la misión preparada
    RPQuest.JournalTab.titleEdit:SetText("Ritual en Deshaan")
    RPQuest.JournalTab:OnSaveDraftClicked()
    local q = RPQuest.QuestRepository:GetAllQuests()[1]
    AssertEqual(q.areaRadius, RPQuest.Constants.AREA_RADIUS.LARGE, "Saved quest keeps LARGE radius")

    -- 3. Abrir Editar y cambiar radio a SMALL refleja el nuevo tamaño en el mapa al instante (sin guardar todavía)
    RPQuest.JournalTab:OpenEditEditor(q.id)
    RPQuest.JournalTab.btnRadiusSmall:FireHandler("OnClicked")
    AssertEqual(#mockPinManager._createdPins, 1, "Map pin refreshed when editing quest radius")
    AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.SMALL, "Edited draft pin immediately reflects SMALL radius")

    -- 4. Pulsar Ver en Mapa desde el editor abre el mapa mostrando el pin editado
    RPQuest.JournalTab.btnShowMapEditor:FireHandler("OnClicked")
    AssertEqual(#mockPinManager._createdPins, 1, "ShowQuestOnMap from editor renders pin")
    AssertEqual(mockPinManager._createdPins[1].radius, RPQuest.Constants.AREA_RADIUS.SMALL, "ShowQuestOnMap from editor uses current edited SMALL radius")
end)

RunTest("17. ShowQuestOnMap cambia de zona con WORLD_MAP_MANAGER y abrir con M muestra pin activo", function()
    local sv = {}
    RPQuest.QuestRepository:Initialize(sv)
    RPQuest.WorldMapArea:Initialize()

    local mockPinManager = ZO_WorldMap_GetPinManager()
    mockPinManager._createdPins = {}

    -- Crear misión en Stonefalls (mapId = 27) y activarla
    mockState.reticleExists = true
    mockState.reticleName = "Cultista"
    mockState.reticleIsPlayer = false
    mockState.reticleIsDead = false
    mockState.reticleAttackable = true
    mockState.mapId = 27
    mockState.zoneId = 41
    mockState.mapName = "Stonefalls"
    mockState.playerX = 0.62
    mockState.playerY = 0.38

    RPQuest.TargetCapture:CaptureFromReticle()
    local stonefallsQuest = RPQuest.QuestRepository:SaveDraft("Misión en Stonefalls", "Desc", RPQuest.Constants.AREA_RADIUS.MEDIUM)
    RPQuest.QuestRepository:SetActiveQuest(stonefallsQuest.id)

    -- Jugador viaja a Deshaan (mapId = 45) y el mapa está cerrado
    SCENE_MANAGER:Hide("worldMap")
    mockState.mapId = 45
    mockState.zoneId = 104
    mockState.mapName = "Deshaan"
    mockPinManager._createdPins = {}
    mockState.lastPannedX = nil
    mockState.lastPannedY = nil

    local callOrder = {}
    local origSceneShow = SCENE_MANAGER.Show
    SCENE_MANAGER.Show = function(self, sceneName)
        table.insert(callOrder, "ShowScene:" .. tostring(sceneName))
        return origSceneShow(self, sceneName)
    end

    local origWorldMapManager = WORLD_MAP_MANAGER
    local setMapByIdCalledWith = nil
    WORLD_MAP_MANAGER = {
        SetMapById = function(self, mapId)
            table.insert(callOrder, "SetMapById")
            setMapByIdCalledWith = mapId
            SetMapToMapId(mapId)
        end,
    }

    -- 1. Show on Map desde Deshaan debe cambiar el mapa a Stonefalls ANTES de abrir la escena
    local shown = RPQuest.WorldMapArea:ShowQuestOnMap(stonefallsQuest)
    AssertEqual(shown, true, "ShowQuestOnMap returns true")
    AssertEqual(setMapByIdCalledWith, 27, "WORLD_MAP_MANAGER:SetMapById called with Stonefalls mapId")
    AssertEqual(callOrder[1], "SetMapById", "SetMapById called before opening world map")
    AssertEqual(callOrder[2], "ShowScene:worldMap", "World map opened after SetMapById")
    AssertEqual(mockState.mapId, 27, "Current mapId switched to Stonefalls")
    AssertEqual(#mockPinManager._createdPins, 1, "Stonefalls quest pin rendered when viewing from Deshaan")
    AssertEqual(mockState.lastPannedX, stonefallsQuest.areaCenterX, "Map panned to quest areaCenterX")
    AssertEqual(mockState.lastPannedY, stonefallsQuest.areaCenterY, "Map panned to quest areaCenterY")

    -- Restaurar mocks globales
    SCENE_MANAGER.Show = origSceneShow
    WORLD_MAP_MANAGER = origWorldMapManager

    -- 2. Cerrar el mapa y abrirlo por fuera con M en Stonefalls debe mostrar la marca activa
    SCENE_MANAGER:Hide("worldMap")
    mockPinManager._createdPins = {}
    mockState.mapId = 27
    SCENE_MANAGER:Show("worldMap")
    RPQuest.WorldMapArea:RefreshPins()
    AssertEqual(#mockPinManager._createdPins, 1, "Opening map with M renders active quest pin")
end)

RunTest("18. Issue 47: Deep optimization, overflow caps, deferred map pins and O(1) caches", function()
    RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
    RPQuest.JournalTab:Initialize()
    RPQuest.CombatTracker:Initialize()
    RPQuest.WorldMapArea:Initialize()

    local mockPinManager = ZO_WorldMap_GetPinManager()
    local refreshCalls = 0
    local origRefreshCustomPins = mockPinManager.RefreshCustomPins
    mockPinManager.RefreshCustomPins = function(self, ...)
        refreshCalls = refreshCalls + 1
        return origRefreshCustomPins(self, ...)
    end

    -- 1. RequestRefreshPins debe diferirse cuando el mapa está cerrado
    SCENE_MANAGER:Hide("worldMap")
    refreshCalls = 0
    RPQuest.WorldMapArea:RequestRefreshPins()
    AssertEqual(refreshCalls, 0, "RequestRefreshPins defers when world map is hidden")
    AssertEqual(RPQuest.WorldMapArea._pinsDirty, true, "Deferred refresh marks _pinsDirty")
    mockPinManager.RefreshCustomPins = origRefreshCustomPins

    -- 2. TargetCapture no debe llamar SetMapToPlayerLocation si DoesCurrentMapMatchMapForPlayerLocation() == true
    local setMapCalls = 0
    local origSetMap = SetMapToPlayerLocation
    local origDoesMatch = DoesCurrentMapMatchMapForPlayerLocation
    SetMapToPlayerLocation = function() setMapCalls = setMapCalls + 1; return SET_MAP_RESULT_CURRENT_MAP_UNCHANGED end
    DoesCurrentMapMatchMapForPlayerLocation = function() return true end
    RPQuest.TargetCapture:GetPlayerMapContext(false)
    AssertEqual(setMapCalls, 0, "Skips SetMapToPlayerLocation when map already matches player location")
    SetMapToPlayerLocation = origSetMap
    DoesCurrentMapMatchMapForPlayerLocation = origDoesMatch

    -- 3. UI vertical overflow cap (>4 objetivos) y códigos largos (>1024 chars)
    for i = 1, 10 do
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Objetivo Largo Numero " .. i .. " de Prueba",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
    end
    local longDesc = string.rep("Descripcion extensa para probar limites de Base64Url. ", 8)
    local q = RPQuest.QuestRepository:SaveDraft("Mision Extensa", longDesc, nil, "Completada con exito!")
    AssertTrue(q ~= nil, "Saved quest with 10 targets")

    local code = RPQuest.QuestRepository:ExportQuestToCode(q.id)
    AssertTrue(type(code) == "string" and #code > 100 and code:sub(1, 5) == "RPQ3:", "Exported RPQ3 code generated cleanly")

    -- Verificar que maxChars >= 4096 en importCodeEdit y shareEdit
    RPQuest.JournalTab:SelectQuest(q.id)
    local _, objHeight = RPQuest.JournalTab.detailObjText:GetDimensions()
    AssertTrue(objHeight <= 96, "detailObjText height capped at <= 96px to prevent vertical overflow")
    AssertEqual(RPQuest.JournalTab.shareEdit:GetText(), code, "Long share code is not truncated in shareEdit")

    -- Verificar invalidación de caché de ExportQuestToCode al editar
    RPQuest.QuestRepository:LoadQuestIntoDraft(q.id)
    local updated = RPQuest.QuestRepository:SaveDraft("Mision Extensa Editada", longDesc, nil, "Nuevo mensaje")
    local updatedCode = RPQuest.QuestRepository:ExportQuestToCode(updated.id)
    AssertTrue(updatedCode ~= code, "Share code cache invalidated on quest update")

    -- 4. Ring buffer O(1) en CombatTracker:MarkUnitKilled (>32 unidades)
    for u = 1, 40 do
        RPQuest.CombatTracker:MarkUnitKilled(u)
    end
    AssertEqual(RPQuest.CombatTracker._recentKilledSet[1], nil, "Oldest unit evicted from 32-slot ring buffer")
    AssertEqual(RPQuest.CombatTracker._recentKilledSet[40], true, "Newest unit retained in ring buffer")
end)

RunTest("Undetected (stealth) quest option, Justice events, area check, and completion code", function()
    RPQuest.QuestRepository:ResetDraft()
    mockState.mapId = 32
    mockState.zoneId = 381
    mockState.mapName = "Auridon"
    mockState.playerX = 0.42
    mockState.playerY = 0.61

    -- 1. Toggle in editor + SaveDraft
    RPQuest.QuestRepository:SetDraftCapturedTarget({
        targetName = "Guardia de Sombra",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.42,
        targetY = 0.61,
    })
    RPQuest.QuestRepository:UpdateDraftFields({ requireUndetected = true })
    RPQuest.JournalTab:RefreshEditorPane()
    AssertTrue(RPQuest.JournalTab.btnRequireUndetected:GetText():find("%[X%]") ~= nil, "Editor toggle shows [X] when requireUndetected is true")

    local prepared = RPQuest.QuestRepository:SaveDraft("Contrato de Sigilo", "Sin testigos.", nil, "Trabajo limpio.")
    AssertTrue(prepared ~= nil, "Saved stealth quest")
    AssertEqual(prepared.requireUndetected, true, "Prepared quest has requireUndetected = true")
    AssertEqual(prepared.wasDetected, false, "Prepared quest starts with wasDetected = false")

    -- 2. ShareCodec preserves requireUndetected
    local shareCode = RPQuest.QuestRepository:ExportQuestToCode(prepared.id)
    local imported = RPQuest.QuestRepository:ImportQuestFromCode(shareCode)
    AssertTrue(imported ~= nil, "Imported stealth quest")
    AssertEqual(imported.requireUndetected, true, "Imported quest preserves requireUndetected = true")
    AssertEqual(imported.wasDetected, false, "Imported quest starts with wasDetected = false")
    AssertEqual(RPQuest.CombatTracker._isJusticeRegistered, true, "Justice events registered for active undetected quest")

    -- 3. Justice events outside quest area do NOT trigger detection
    mockState.mapId = 999
    mockState.zoneId = 999
    RPQuest.CombatTracker:OnJusticeBountyUpdated(EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, 0, 150, false)
    AssertEqual(imported.wasDetected, false, "Bounty outside quest area does not mark detected")

    -- 4. Initialization / non-increasing bounty inside area do NOT trigger detection
    mockState.mapId = 32
    mockState.zoneId = 381
    mockState.playerX = imported.areaCenterX
    mockState.playerY = imported.areaCenterY
    RPQuest.CombatTracker:OnJusticeBountyUpdated(EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, 0, 150, true)
    AssertEqual(imported.wasDetected, false, "isInitialize bounty event does not mark detected")
    RPQuest.CombatTracker:OnJusticeInfamyUpdated(EVENT_JUSTICE_INFAMY_UPDATED, 100, 100, 1, 1)
    AssertEqual(imported.wasDetected, false, "Non-increasing infamy does not mark detected")

    -- 5. Justice bounty increase inside quest area marks wasDetected = true without blocking quest
    mockState.alerts = {}
    RPQuest.CombatTracker:OnJusticeBountyUpdated(EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, 0, 200, false)
    AssertEqual(imported.wasDetected, true, "Bounty increase inside quest area marks wasDetected = true")
    AssertEqual(imported.completed, false, "Detection does not fail or complete the quest")
    AssertEqual(#mockState.alerts, 1, "Player receives informative alert on detection")
    AssertEqual(RPQuest.CombatTracker._isJusticeRegistered, false, "Justice events unregistered once detected")

    -- 6. Quest can still be completed and completion code includes wasDetected = true
    local recorded, _, justCompleted = RPQuest.QuestRepository:RecordTargetEliminated("Guardia de Sombra", {
        mapId = 32,
        zoneId = 381,
        x = imported.areaCenterX,
        y = imported.areaCenterY,
    })
    AssertEqual(recorded, true, "Target elimination still succeeds after detection")
    AssertEqual(justCompleted, true, "Quest still completes normally after detection")

    local compCodeDetected = RPQuest.QuestRepository:ExportCompletionCode(imported.id)
    local okDet, decodedDet = RPQuest.QuestRepository:ValidateCompletionCode(prepared.id, compCodeDetected)
    AssertEqual(okDet, true, "Completion code with detection is still valid")
    AssertEqual(decodedDet.wasDetected, true, "Completion code records wasDetected = true")

    -- 7. ResetQuest clears wasDetected and completing cleanly records wasDetected = false
    RPQuest.QuestRepository:ResetQuest(imported.id)
    AssertEqual(imported.wasDetected, false, "ResetQuest clears wasDetected")
    AssertEqual(RPQuest.CombatTracker._isJusticeRegistered, true, "Justice events re-registered after ResetQuest")

    RPQuest.QuestRepository:RecordTargetEliminated("Guardia de Sombra", {
        mapId = 32,
        zoneId = 381,
        x = imported.areaCenterX,
        y = imported.areaCenterY,
    })
    local compCodeClean = RPQuest.QuestRepository:ExportCompletionCode(imported.id)
    local okClean, decodedClean = RPQuest.QuestRepository:ValidateCompletionCode(prepared.id, compCodeClean)
    AssertEqual(okClean, true, "Completion code without detection is valid")
    AssertEqual(decodedClean.wasDetected, false, "Completion code records wasDetected = false")

    -- 8. Pickpocket failed & Infamy increase also trigger detection
    RPQuest.QuestRepository:ResetQuest(imported.id)
    RPQuest.CombatTracker:OnJusticePickpocketFailed(EVENT_JUSTICE_PICKPOCKET_FAILED)
    AssertEqual(imported.wasDetected, true, "Pickpocket failed inside quest area marks wasDetected = true")

    RPQuest.QuestRepository:ResetQuest(imported.id)
    RPQuest.CombatTracker:OnJusticeInfamyUpdated(EVENT_JUSTICE_INFAMY_UPDATED, 0, 50, 0, 1)
    AssertEqual(imported.wasDetected, true, "Infamy increase inside quest area marks wasDetected = true")
end)

RunTest("Hidden discovery points: capture, ShareCodec, proximity trigger, no map pins, mixed quest", function()
    RPQuest.QuestRepository:ResetDraft()
    RPQuest.QuestRepository:SetActiveQuest(nil)
    RPQuest.DiscoveryTracker:UpdatePollingState()
    mockState.zoneId = 381
    mockState.mapId = 32
    mockState.worldX = 10000
    mockState.worldY = 500
    mockState.worldZ = 20000

    -- 1. Capture 2 discovery points in-situ without combat targets
    local draft1, cnt1 = RPQuest.TargetCapture:CaptureDiscoveryPoint("Notas un olor particular que viene del norte", 1000)
    AssertTrue(draft1 ~= nil, "First discovery point captured")
    AssertEqual(cnt1, 1, "Draft has 1 discovery point")

    mockState.worldX = 15000
    mockState.worldZ = 25000
    local draft2, cnt2 = RPQuest.TargetCapture:CaptureDiscoveryPoint("Escuchas un ruido de ovejas que viene del noreste", 1500)
    AssertTrue(draft2 ~= nil, "Second discovery point captured")
    AssertEqual(cnt2, 2, "Draft has 2 discovery points")

    -- 1b. Edit and remove individual discovery points in draft
    local editedPt = RPQuest.QuestRepository:UpdateDraftDiscoveryPoint(1, {
        message = "Notas un olor particular que viene del norte",
        radius = 800,
    })
    AssertTrue(editedPt ~= nil, "Discovery point #1 updated in draft")
    AssertEqual(draft2.discoveries[1].radius, 800, "Discovery point #1 radius updated")
    RPQuest.TargetCapture:CaptureDiscoveryPoint("Punto temporal", 800)
    AssertEqual(#draft2.discoveries, 3, "Temporary discovery point #3 added")
    RPQuest.QuestRepository:RemoveDraftDiscoveryPoint(3)
    AssertEqual(#draft2.discoveries, 2, "Temporary discovery point #3 removed individually")
    RPQuest.QuestRepository:UpdateDraftDiscoveryPoint(1, { radius = 1000 })

    -- 2. Save discovery-only quest (0 combat targets)
    local saved = RPQuest.QuestRepository:SaveDraft("Rastreo en Auridon", "Sigue las pistas")
    AssertTrue(saved ~= nil, "Discovery-only quest saved successfully")
    AssertEqual(#saved.targets, 0, "Discovery-only quest has 0 combat targets")
    AssertEqual(#saved.discoveries, 2, "Discovery-only quest has 2 discovery points")
    AssertEqual(RPQuest.DiscoveryTracker._isPolling, false, "Polling inactive when prepared quest is not active")

    -- 3. ShareCodec roundtrip preserves discoveries and resets discovered=false
    local code = RPQuest.QuestRepository:ExportQuestToCode(saved.id)
    AssertTrue(type(code) == "string" and code:sub(1, 5) == "RPQ3:", "ShareCodec encodes discovery-only quest")

    local imported = RPQuest.QuestRepository:ImportQuestFromCode(code)
    AssertTrue(imported ~= nil, "ShareCodec decodes and imports discovery-only quest")
    AssertEqual(#imported.discoveries, 2, "Imported quest preserves 2 discovery points")
    AssertEqual(imported.discoveries[1].message, "Notas un olor particular que viene del norte", "Discovery #1 message preserved")
    AssertEqual(imported.discoveries[2].radius, 1500, "Discovery #2 radius preserved")
    AssertEqual(imported.discoveries[1].discovered, false, "Imported discovery #1 starts undiscovered")

    -- 4. No map pins are rendered for discovery-only quests
    RPQuest.WorldMapArea:RefreshPins()
    AssertEqual(#mockPinManager._createdPins, 0, "No map pins created for hidden discovery points")

    -- 5. Polling activates when imported quest is active
    AssertEqual(RPQuest.DiscoveryTracker._isPolling, true, "Polling active when active quest has pending discoveries")

    -- 6. Wrong zone or outside radius does NOT trigger
    local triggeredWrongZone = RPQuest.DiscoveryTracker:EvaluatePlayerPosition(999, 10000, 500, 20000)
    AssertEqual(triggeredWrongZone, false, "Wrong zoneId does not trigger discovery")

    local triggeredFar = RPQuest.DiscoveryTracker:EvaluatePlayerPosition(381, 12000, 500, 20000)
    AssertEqual(triggeredFar, false, "Outside radius (2000 > 1000) does not trigger discovery")

    -- 7. Entering radius of point #1 triggers it once (CSA + Chat)
    mockState.csaMessages = {}
    mockState.chatMessages = {}
    local triggered1 = RPQuest.DiscoveryTracker:EvaluatePlayerPosition(381, 10500, 500, 20500)
    AssertEqual(triggered1, true, "Inside radius triggers discovery #1")
    AssertEqual(imported.discoveries[1].discovered, true, "Discovery #1 marked discovered = true")
    AssertEqual(imported.completed, false, "Quest not completed until discovery #2 is also found")
    AssertEqual(#mockState.csaMessages, 1, "CSA shown for discovery #1")
    AssertEqual(#mockState.chatMessages, 1, "Chat message shown for discovery #1")

    -- Re-evaluating at same position does NOT re-trigger
    local triggeredRepeat = RPQuest.DiscoveryTracker:EvaluatePlayerPosition(381, 10500, 500, 20500)
    AssertEqual(triggeredRepeat, false, "Already discovered point does not re-trigger")
    AssertEqual(#mockState.csaMessages, 1, "No duplicate CSA on repeat tick")

    -- 8. Entering radius of point #2 completes the quest and stops polling
    local triggered2 = RPQuest.DiscoveryTracker:EvaluatePlayerPosition(381, 15000, 500, 25000)
    AssertEqual(triggered2, true, "Inside radius triggers discovery #2")
    AssertEqual(imported.completed, true, "Quest completed after all discoveries found")
    AssertEqual(RPQuest.DiscoveryTracker._isPolling, false, "Polling stops automatically once quest is completed")

    -- 9. ResetQuest resets discoveries and re-enables polling
    RPQuest.QuestRepository:ResetQuest(imported.id)
    AssertEqual(imported.discoveries[1].discovered, false, "ResetQuest resets discovery #1")
    AssertEqual(imported.discoveries[2].discovered, false, "ResetQuest resets discovery #2")
    AssertEqual(RPQuest.DiscoveryTracker._isPolling, true, "Polling re-enabled after ResetQuest")

    -- 10. Mixed quest (combat target + discovery point) requires BOTH
    RPQuest.QuestRepository:ResetDraft()
    mockState.reticleExists = true
    mockState.reticleName = "Bandido"
    mockState.worldX = 20000
    mockState.worldZ = 30000
    RPQuest.TargetCapture:CaptureFromReticle()
    RPQuest.TargetCapture:CaptureDiscoveryPoint("Encuentras el campamento oculto", 1200)
    local mixedPrepared = RPQuest.QuestRepository:SaveDraft("Misión Mixta", "Investiga y elimina")
    local mixedCode = RPQuest.QuestRepository:ExportQuestToCode(mixedPrepared.id)
    local mixed = RPQuest.QuestRepository:ImportQuestFromCode(mixedCode)
    AssertTrue(mixed ~= nil, "Mixed quest imported")

    local killOk, _, killCompleted = RPQuest.QuestRepository:RecordTargetEliminated("Bandido", {
        mapId = 32,
        zoneId = 381,
        x = mixed.areaCenterX,
        y = mixed.areaCenterY,
    })
    AssertEqual(killOk, true, "Mixed quest target eliminated")
    AssertEqual(killCompleted, false, "Mixed quest not completed until discovery point is also reached")

    local discOk = RPQuest.DiscoveryTracker:EvaluatePlayerPosition(381, 20000, 500, 30000)
    AssertEqual(discOk, true, "Mixed quest discovery triggered")
    AssertEqual(mixed.completed, true, "Mixed quest completed once both target and discovery are done")
end)

RunTest("NPC Dialogues, Clue, HideMapArea, RPQ2 & RPQ1 compat, and DialogueInjector hook", function()
    RPQuest.QuestRepository:ResetDraft()
    RPQuest.QuestRepository:SetActiveQuest(nil)

    -- 1. Session capture via EVENT_CHATTER_BEGIN (OnChatterBegin)
    local currentInteractName = "Mercader Sospechoso^m"
    _G.GetUnitName = function(unitTag)
        if unitTag == "interact" then return currentInteractName end
        return "Jugador"
    end
    mockState.worldX = 12000
    mockState.worldZ = 22000
    mockState.zoneId = 381

    RPQuest.DialogueInjector:OnChatterBegin()
    local lastNpc = RPQuest.QuestRepository:GetLastInteractedNpc()
    AssertTrue(lastNpc ~= nil, "Last interacted NPC captured")
    AssertEqual(lastNpc.name, "Mercader Sospechoso", "NPC name normalized without gender suffix")
    AssertEqual(lastNpc.zoneId, 381, "NPC zoneId captured")

    -- 2. Draft dialogue management (0..3 max, duplicate prevention)
    RPQuest.QuestRepository:ResetDraft()
    RPQuest.QuestRepository:UpdateDraftFields({
        clue = "el sello roto",
        hideMapArea = true,
    })
    local ok1, idx1 = RPQuest.QuestRepository:AddDraftDialogueFromLastNpc("Vi a un encapuchado huir hacia los muelles.")
    AssertTrue(ok1 ~= nil and idx1 == 1, "Dialogue #1 added from last NPC")

    local dupOk, dupErr = RPQuest.QuestRepository:AddDraftDialogueFromLastNpc("Repetido")
    AssertEqual(dupOk, nil, "Duplicate NPC rejected")
    AssertTrue(type(dupErr) == "string" and dupErr ~= "", "Duplicate NPC returns error message")

    currentInteractName = "Guardia del Puerto^f"
    RPQuest.DialogueInjector:OnChatterBegin()
    RPQuest.QuestRepository:AddDraftDialogueFromLastNpc("Nadie entra sin pase; revisa el almacén sur.")

    currentInteractName = "Tabernero^m"
    RPQuest.DialogueInjector:OnChatterBegin()
    RPQuest.QuestRepository:AddDraftDialogueFromLastNpc("Dejó una nota bajo la mesa 4~5; busca allí.")

    currentInteractName = "Cuarto NPC"
    RPQuest.DialogueInjector:OnChatterBegin()
    local limitOk, limitErr = RPQuest.QuestRepository:AddDraftDialogueFromLastNpc("Excede")
    AssertEqual(limitOk, nil, "4th NPC dialogue rejected (max 3)")
    AssertTrue(type(limitErr) == "string" and limitErr ~= "", "Limit error returned")

    -- Capture target and save quest
    mockState.reticleExists = true
    mockState.reticleName = "Contrabandista"
    RPQuest.TargetCapture:CaptureFromReticle()
    local saved = RPQuest.QuestRepository:SaveDraft("El Sello Roto", "Investiga en el puerto.")
    AssertTrue(saved ~= nil, "Quest with dialogues and hideMapArea saved")
    AssertEqual(saved.clue, "el sello roto", "Clue persisted on quest")
    AssertEqual(saved.hideMapArea, true, "hideMapArea persisted on quest")
    AssertEqual(#saved.dialogues, 3, "3 dialogues persisted on quest")

    -- 3. WorldMapArea respects hideMapArea
    RPQuest.QuestRepository:SetActiveQuest(saved.id)
    mockPinManager._createdPins = {}
    RPQuest.WorldMapArea:RefreshPins()
    AssertEqual(#mockPinManager._createdPins, 0, "WorldMapArea does not render pin when hideMapArea is true")

    -- 4. ShareCodec RPQ2 roundtrip
    local code = RPQuest.QuestRepository:ExportQuestToCode(saved.id)
    AssertTrue(type(code) == "string" and code:sub(1, 5) == "RPQ3:", "Exported code uses RPQ3 prefix")

    local imported = RPQuest.QuestRepository:ImportQuestFromCode(code)
    AssertTrue(imported ~= nil, "RPQ2 quest imported successfully")
    AssertEqual(imported.clue, "el sello roto", "Imported clue preserved")
    AssertEqual(imported.hideMapArea, true, "Imported hideMapArea preserved")
    AssertEqual(#imported.dialogues, 3, "Imported 3 dialogues preserved")
    AssertEqual(imported.dialogues[3].response, "Dejó una nota bajo la mesa 4~5; busca allí.", "Special chars in dialogue response preserved")

    -- Imported quest with hideMapArea also hides pin
    mockPinManager._createdPins = {}
    RPQuest.WorldMapArea:RefreshPins()
    AssertEqual(#mockPinManager._createdPins, 0, "Imported quest with hideMapArea=true renders 0 map pins")

    -- 5. DialogueInjector hook on ZO_Interaction
    local bodyTextValue = "Saludos, viajero."
    local populatedOptions = {}
    local finalizedCount = nil
    local selectChatterCalled = false
    _G.SelectChatterOption = function() selectChatterCalled = true end
    _G.CHATTER_TALK_CHOICE = 1
    _G.CHATTER_GOODBYE = 2
    _G.MAX_CHATTER_OPTIONS = 10

    local mockBodyLabel = { SetText = function(_, txt) bodyTextValue = txt end }
    local mockControl = { GetNamedChild = function(_, name) if name == "TargetAreaBodyText" then return mockBodyLabel end end }

    local MockInteraction = { optionControls = {} }
    function MockInteraction:PopulateChatterOption(controlID, optionIndex, optionText, optionType, optionalArg, isImportant, chosenBefore)
        local ctrl = { chosenBefore = chosenBefore, SetColor = function(c, r, g, b, a) c._color = { r, g, b, a } end }
        self.optionControls[controlID] = ctrl
        table.insert(populatedOptions, {
            controlID = controlID,
            optionIndex = optionIndex,
            optionText = optionText,
            optionType = optionType,
            chosenBefore = chosenBefore,
        })
    end
    function MockInteraction:FinalizeChatterOptions(optionCount)
        finalizedCount = optionCount
    end
    function MockInteraction:PopulateChatterOptions(optionCount)
        for i = 1, optionCount do
            self:PopulateChatterOption(i, i, "Nativa " .. i, CHATTER_TALK_CHOICE)
        end
        local nextId = optionCount + 1
        self:PopulateChatterOption(nextId, function() end, "Adiós", CHATTER_GOODBYE)
        self:FinalizeChatterOptions(nextId)
        return nextId, {}
    end
    MockInteraction.control = mockControl
    _G.ZO_Interaction = MockInteraction
    RPQuest.DialogueInjector:InstallHooks()

    -- Matching NPC: injects RPQuest option before CHATTER_GOODBYE
    currentInteractName = "Tabernero^m"
    mockState.zoneId = 381
    populatedOptions = {}
    local finalCount = MockInteraction:PopulateChatterOptions(1)
    AssertEqual(finalCount, 3, "Injected 1 option before CHATTER_GOODBYE (total 3)")
    AssertEqual(finalizedCount, 3, "FinalizeChatterOptions received updated count 3")
    AssertEqual(populatedOptions[2].optionText, "el sello roto", "Injected option text uses exact player dialogue text")
    AssertEqual(type(populatedOptions[2].optionIndex), "function", "Injected optionIndex is a Lua callback function")
    AssertEqual(populatedOptions[3].optionType, CHATTER_GOODBYE, "CHATTER_GOODBYE remains last option")

    -- Clicking injected option updates NPC body text without calling SelectChatterOption and grays out option
    AssertEqual(populatedOptions[2].chosenBefore, false, "Option starts unseen (chosenBefore=false)")
    populatedOptions[2].optionIndex()
    AssertEqual(bodyTextValue, "Dejó una nota bajo la mesa 4~5; busca allí.", "NPC response shown in TargetAreaBodyText")
    AssertEqual(selectChatterCalled, false, "SelectChatterOption is never called for RPQuest dialogue")
    AssertEqual(MockInteraction.optionControls[2].chosenBefore, true, "Clicked option marked chosenBefore=true")
    AssertTrue(MockInteraction.optionControls[2]._color ~= nil, "Clicked option color updated to disabled/seen gray")

    -- Re-opening dialogue with same NPC keeps chosenBefore=true
    populatedOptions = {}
    MockInteraction:PopulateChatterOptions(1)
    AssertEqual(populatedOptions[2].chosenBefore, true, "Re-opened dialogue preserves chosenBefore=true")

    -- Non-matching NPC: native options untouched
    currentInteractName = "Mendigo Aleatorio"
    populatedOptions = {}
    local untouchedCount = MockInteraction:PopulateChatterOptions(1)
    AssertEqual(untouchedCount, 2, "Non-matching NPC has untouched option count")
    AssertEqual(populatedOptions[2].optionType, CHATTER_GOODBYE, "Non-matching NPC keeps native CHATTER_GOODBYE at 2")

    -- MAX_CHATTER_OPTIONS cap respected
    currentInteractName = "Tabernero^m"
    populatedOptions = {}
    local cappedCount = MockInteraction:PopulateChatterOptions(9)
    AssertEqual(cappedCount, 10, "At MAX_CHATTER_OPTIONS=10 (9 native + goodbye), does not overflow")
    AssertEqual(populatedOptions[10].optionType, CHATTER_GOODBYE, "CHATTER_GOODBYE preserved at cap")

    -- 6. Backward compatibility with RPQ1 codes
    local rpq1Code = code:gsub("^RPQ2:", "RPQ1:")
    -- Recompute checksum? No, RPQ1 had 14 fields; let's test DecodeCompletion rejecting RPQ1 as not-completion-code
    local okComp, errComp = RPQuest.ShareCodec:DecodeCompletion(rpq1Code)
    AssertEqual(okComp, nil, "DecodeCompletion rejects RPQ1 code")
    AssertEqual(errComp, "VALIDATE_ERR_NOT_COMPLETION_CODE", "RPQ1 rejected with VALIDATE_ERR_NOT_COMPLETION_CODE")
end)

RunTest("Editor Accordion Sections: default state, toggle layout, and auto-expand on edit", function()
    RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
    RPQuest.JournalTab:Initialize()
    RPQuest.JournalTab:OpenTab()
    RPQuest.JournalTab:OpenCreateEditor()

    local sections = RPQuest.JournalTab.editorSectionsByKey
    AssertTrue(sections ~= nil, "editorSectionsByKey initialized")
    AssertEqual(sections.target.body:IsHidden(), true, "Target section starts collapsed")
    AssertEqual(sections.discovery.body:IsHidden(), true, "Discovery section starts collapsed")
    AssertEqual(sections.dialogue.body:IsHidden(), true, "Dialogue section starts collapsed")
    AssertEqual(sections.options.body:IsHidden(), true, "Options section starts collapsed")

    local yCollapsed = sections.dialogue.divider._anchors[1].y
    RPQuest.JournalTab:ToggleEditorSection("discovery")
    AssertEqual(sections.discovery.body:IsHidden(), false, "Discovery section expands on toggle")
    local yExpanded = sections.dialogue.divider._anchors[1].y
    AssertTrue(yExpanded > yCollapsed, "Subsequent section Y offset increases when discovery accordion expands")

    RPQuest.JournalTab:ToggleEditorSection("discovery")
    AssertEqual(sections.discovery.body:IsHidden(), true, "Discovery section collapses on second toggle")

    -- Save a quest with options configured and verify OpenEditEditor keeps all accordions collapsed by default
    RPQuest.QuestRepository:SetDraftCapturedTarget({
        targetName = "Bandido",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.50,
        targetY = 0.50,
    })
    RPQuest.QuestRepository:UpdateDraftFields({ requireUndetected = true })
    local q = RPQuest.QuestRepository:SaveDraft("Misión Acordeón", "Prueba.", nil, "Listo.")
    AssertTrue(q ~= nil, "Quest saved for edit accordion test")

    RPQuest.JournalTab:OpenEditEditor(q.id)
    AssertEqual(sections.target.body:IsHidden(), true, "Target section starts collapsed on edit")
    AssertEqual(sections.options.body:IsHidden(), true, "Options section starts collapsed on edit")
    AssertEqual(sections.discovery.body:IsHidden(), true, "Discovery section starts collapsed on edit")
end)

RunTest("Optimizations: completion code cache, discovery-only FindPendingTarget, ShareCodec escape, keybind string", function()
    RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())

    -- 1. Keybind string for discovery capture is registered
    RPQuest.Locale._stringsRegistered = false
    RPQuest.Locale:Initialize("en")
    AssertTrue(_G["SI_BINDING_NAME_RPQUEST_CAPTURE_DISCOVERY"] ~= nil, "SI_BINDING_NAME_RPQUEST_CAPTURE_DISCOVERY is registered")

    -- 2. ShareCodec escaping roundtrip with special delimiters
    local specialQuest = {
        title = "100% Test | ; ~",
        description = "Line 1\nLine 2 %7C ~ ;",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.5,
        targetY = 0.5,
        areaCenterX = 0.5,
        areaCenterY = 0.5,
        areaRadius = 0.075,
        targets = { { name = "Bandit | Boss", requiredCount = 2 } },
    }
    local encoded = RPQuest.ShareCodec:EncodeQuest(specialQuest)
    local decoded = RPQuest.ShareCodec:DecodeQuest(encoded)
    AssertTrue(decoded ~= nil, "Special characters quest decoded")
    AssertEqual(decoded.title, specialQuest.title, "Special delimiter characters preserved in title")
    AssertEqual(decoded.description, specialQuest.description, "Newline and percent sequences preserved in description")
    AssertEqual(decoded.targets[1].name, "Bandit | Boss", "Pipe preserved in target name")

    -- 3. Discovery-only active quest skips target normalization in FindPendingTarget
    RPQuest.QuestRepository:ResetDraft()
    RPQuest.QuestRepository:AddDraftDiscoveryPoint({
        zoneId = 381,
        worldX = 1000,
        worldY = 0,
        worldZ = 2000,
        radius = 1000,
        message = "Clue",
    })
    local discQuest = RPQuest.QuestRepository:SaveDraft("Discovery Only", "Desc")
    RPQuest.QuestRepository:SetActiveQuest(discQuest.id)
    local matchedQ, matchedT = RPQuest.QuestRepository:FindPendingTarget("Random Mob")
    AssertEqual(matchedQ, nil, "FindPendingTarget returns nil for discovery-only quest")
    AssertEqual(matchedT, nil, "FindPendingTarget returns nil target for discovery-only quest")

    -- 4. ExportCompletionCode caches result and invalidates on ResetQuest
    RPQuest.QuestRepository:ResetDraft()
    RPQuest.QuestRepository:SetDraftCapturedTarget({
        targetName = "Bandido",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.50,
        targetY = 0.50,
    })
    local q = RPQuest.QuestRepository:SaveDraft("Cache Test", "Desc")
    local code = RPQuest.QuestRepository:ExportQuestToCode(q.id)
    local imp = RPQuest.QuestRepository:ImportQuestFromCode(code)
    RPQuest.QuestRepository:RecordTargetEliminated("Bandido", { mapId = 32, zoneId = 381, x = imp.areaCenterX, y = imp.areaCenterY })
    AssertEqual(imp.completed, true, "Imported quest completed")
    local c1 = RPQuest.QuestRepository:ExportCompletionCode(imp.id)
    local c2 = RPQuest.QuestRepository:ExportCompletionCode(imp.id)
    AssertTrue(c1 ~= nil and c1 == c2, "ExportCompletionCode returns cached code")
    RPQuest.QuestRepository:ResetQuest(imp.id)
    local cAfterReset, errAfterReset = RPQuest.QuestRepository:ExportCompletionCode(imp.id)
    AssertEqual(cAfterReset, nil, "ExportCompletionCode cache invalidated on ResetQuest")
    AssertEqual(errAfterReset, "Quest is not completed", "ResetQuest marks quest incomplete")
end)

RunTest("Target location conditions and custom messages (Issue #99)", function()
    local sv = RPQuest.QuestRepository:GetDefaults()
    RPQuest.QuestRepository:Initialize(sv)
    RPQuest.CombatTracker:Initialize()

    -- Helper to spy on Announcements
    local customMsgCalls = {}
    local failedCalls = {}
    local origCustom = RPQuest.Announcements.AnnounceTargetCustomMessage
    local origFailed = RPQuest.Announcements.AnnounceQuestFailed
    RPQuest.Announcements.AnnounceTargetCustomMessage = function(self, quest, target)
        table.insert(customMsgCalls, target.customMessage)
        origCustom(self, quest, target)
    end
    RPQuest.Announcements.AnnounceQuestFailed = function(self, quest, target)
        table.insert(failedCalls, quest.id)
        origFailed(self, quest, target)
    end

    local origGetMapId = _G.GetCurrentMapId
    local origGetMapPos = _G.GetMapPlayerPosition
    local origGetWorldPos = _G.GetUnitWorldPosition
    _G.GetCurrentMapId = function() return 32 end
    _G.GetMapPlayerPosition = function() return 0.5, 0.5 end

    -- Case 1 & 2: Required location
    RPQuest.QuestRepository:ResetDraft()
    RPQuest.QuestRepository:SetDraftCapturedTarget({
        targetName = "Guard",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.5,
        targetY = 0.5,
    })
    RPQuest.QuestRepository:CaptureDraftTargetLocation(1, 381, 10000, 20000, 1000)
    RPQuest.QuestRepository:UpdateDraftTarget(1, {
        locationRequired = true,
        customMessage = "Silent takedown in the alley.",
    })
    local qReq = RPQuest.QuestRepository:SaveDraft("Required Loc Quest", "Desc")
    RPQuest.QuestRepository:SetActiveQuest(qReq.id)

    -- Kill outside required location -> fails quest, kill does NOT count
    _G.GetUnitWorldPosition = function() return 381, 50000, 0, 50000 end
    RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Guard", 0, 1, 0, 0, false, 1, 901, 0)
    AssertEqual(qReq.failed, true, "Quest fails when required location target is killed outside radius")
    AssertEqual(qReq.targets[1].currentCount, 0, "Kill outside required location does not count")
    AssertEqual(#failedCalls, 1, "AnnounceQuestFailed called once")
    AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Failed quest is deactivated")

    -- Reset quest and kill inside required location -> counts kill + shows customMessage
    RPQuest.QuestRepository:ResetQuest(qReq.id)
    AssertEqual(qReq.failed, false, "ResetQuest clears failed flag")
    _G.GetUnitWorldPosition = function() return 381, 10200, 0, 20200 end
    RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Guard", 0, 1, 0, 0, false, 1, 902, 0)
    AssertEqual(qReq.targets[1].currentCount, 1, "Kill inside required location counts")
    AssertEqual(qReq.completed, true, "Quest completes on kill inside required location")
    AssertEqual(#customMsgCalls, 1, "Custom message shown inside required location")
    AssertEqual(customMsgCalls[1], "Silent takedown in the alley.", "Exact custom message emitted")

    -- Case 3: Optional location + defined point
    RPQuest.QuestRepository:ResetDraft()
    RPQuest.QuestRepository:SetDraftCapturedTarget({
        targetName = "Scout",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.5,
        targetY = 0.5,
    })
    RPQuest.QuestRepository:CaptureDraftTargetLocation(1, 381, 10000, 20000, 1000)
    RPQuest.QuestRepository:UpdateDraftTarget(1, {
        locationRequired = false,
        customMessage = "Scout ambushed at the bridge!",
    })
    RPQuest.QuestRepository:GetDraft().targets[1].requiredCount = 2
    local qOpt = RPQuest.QuestRepository:SaveDraft("Optional Loc Quest", "Desc")
    RPQuest.QuestRepository:SetActiveQuest(qOpt.id)

    -- Kill outside defined point -> counts kill, does NOT show customMessage, does NOT fail
    _G.GetUnitWorldPosition = function() return 381, 50000, 0, 50000 end
    RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Scout", 0, 1, 0, 0, false, 1, 903, 0)
    AssertEqual(qOpt.failed, false, "Optional location does not fail quest outside radius")
    AssertEqual(qOpt.targets[1].currentCount, 1, "Kill outside optional location still counts")
    AssertEqual(#customMsgCalls, 1, "Custom message NOT shown outside optional location")

    -- Kill inside defined point -> counts kill + shows customMessage
    _G.GetUnitWorldPosition = function() return 381, 10100, 0, 20100 end
    RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Scout", 0, 1, 0, 0, false, 1, 904, 0)
    AssertEqual(qOpt.targets[1].currentCount, 2, "Second kill inside optional location counts")
    AssertEqual(#customMsgCalls, 2, "Custom message shown inside optional location")

    -- Case 4: Optional location + NO defined point
    RPQuest.QuestRepository:ResetDraft()
    RPQuest.QuestRepository:SetDraftCapturedTarget({
        targetName = "Bandit",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.5,
        targetY = 0.5,
    })
    RPQuest.QuestRepository:UpdateDraftTarget(1, {
        locationRequired = false,
        customMessage = "Bandit eliminated anywhere.",
    })
    local qNoLoc = RPQuest.QuestRepository:SaveDraft("No Loc Custom Msg", "Desc")
    RPQuest.QuestRepository:SetActiveQuest(qNoLoc.id)
    RPQuest.CombatTracker:OnCombatEvent(0, ACTION_RESULT_DIED, false, "", 0, 0, "Player", COMBAT_UNIT_TYPE_PLAYER, "Bandit", 0, 1, 0, 0, false, 1, 905, 0)
    AssertEqual(qNoLoc.targets[1].currentCount, 1, "Target without location counts anywhere")
    AssertEqual(#customMsgCalls, 3, "Custom message shown anywhere when no location defined")

    -- ShareCodec roundtrip for target conditions & custom message
    local exported = RPQuest.QuestRepository:ExportQuestToCode(qReq.id)
    local decoded = RPQuest.ShareCodec:DecodeQuest(exported)
    AssertTrue(decoded ~= nil and decoded.targets ~= nil and #decoded.targets == 1, "Encoded quest with target condition decoded")
    AssertEqual(decoded.targets[1].zoneId, 381, "Target zoneId preserved in ShareCodec")
    AssertEqual(decoded.targets[1].worldX, 10000, "Target worldX preserved in ShareCodec")
    AssertEqual(decoded.targets[1].worldZ, 20000, "Target worldZ preserved in ShareCodec")
    AssertEqual(decoded.targets[1].radius, 1000, "Target radius preserved in ShareCodec")
    AssertEqual(decoded.targets[1].locationRequired, true, "Target locationRequired preserved in ShareCodec")
    AssertEqual(decoded.targets[1].customMessage, "Silent takedown in the alley.", "Target customMessage preserved in ShareCodec")

    RPQuest.Announcements.AnnounceTargetCustomMessage = origCustom
    RPQuest.Announcements.AnnounceQuestFailed = origFailed
    _G.GetCurrentMapId = origGetMapId
    _G.GetMapPlayerPosition = origGetMapPos
    _G.GetUnitWorldPosition = origGetWorldPos
end)

RunTest("RPQ3 compact codec: compression ratio, negative varints, Discord safety, corrupt inputs (Issue #100)", function()
    local complexQuest = {
        title = "La Conspiración de Auridon — Año Nuevo (Ñoño)",
        description = "Investiga las ruinas antiguas al norte de Vulkhel Guard. "
            .. "Los agentes del Veiled Heritance han estado reuniendo suministros y "
            .. "enviando mensajeros secretos entre los campamentos de la costa. "
            .. "Elimina a los exploradores en el puente y recoge las pistas ocultas.",
        clue = "Busca el sello roto junto al muelle de los contrabandistas.",
        completionMessage = "¡Misión completada! Regresa con el capitán para recibir tu recompensa.",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.432149,
        targetY = 0.678951,
        areaCenterX = 0.451249,
        areaCenterY = 0.654351,
        areaRadius = 0.075,
        hideMapArea = true,
        requireUndetected = true,
        targets = {
            {
                name = "Explorador del Velo",
                requiredCount = 3,
                zoneId = 381,
                worldX = -123456,
                worldZ = -78901,
                radius = 1500,
                locationRequired = true,
                customMessage = "Has interceptado al explorador en el puente secreto.",
            },
            {
                name = "Capitán Contrabandista",
                requiredCount = 1,
                locationRequired = false,
                customMessage = "El capitán cae tras una breve escaramuza.",
            },
        },
        discoveries = {
            {
                zoneId = 381,
                worldX = -45000,
                worldY = 1200,
                worldZ = 98765,
                mapId = 32,
                x = 0.4123,
                y = 0.6123,
                radius = 1500,
                message = "Notas huellas recientes que conducen hacia la cueva oculta.",
            },
            {
                zoneId = 381,
                worldX = -46000,
                worldY = 1250,
                worldZ = 99500,
                mapId = 32,
                x = 0.4223,
                y = 0.6223,
                radius = 800,
                message = "Encuentras una carta cifrada con el emblema del Velo.",
            },
        },
        dialogues = {
            { npcName = "Tabernero Orin", zoneId = 381, response = "Los contrabandistas suelen reunirse al anochecer cerca del muelle." },
            { npcName = "Guardia Elara", zoneId = 381, response = "Ten cuidado, los exploradores vigilan el puente norte." },
        },
    }

    local rpq3 = RPQuest.ShareCodec:EncodeQuest(complexQuest)
    AssertTrue(type(rpq3) == "string" and rpq3:sub(1, 5) == "RPQ3:", "EncodeQuest emits RPQ3 prefix")

    -- Verify Discord-safe Base85 payload (no *, _, ~, `, |, >, <, \, :, or whitespace)
    local payload = rpq3:match("^RPQ3:[0-9A-F][0-9A-F][0-9A-F][0-9A-F]:(.+)$")
    AssertTrue(payload ~= nil and #payload > 0, "RPQ3 envelope matches RPQ3:<CRC16>:<PAYLOAD>")
    AssertEqual(payload:find("[*_~`|>\\:<%s]"), nil, "RPQ3 Base85 payload contains no Discord-unsafe or delimiter chars")

    -- Verify >= 45% length reduction vs RPQ2 on a medium/large quest
    local repeatedQuest = {
        title = "Patrulla del Velo en Auridon",
        description = string.rep("Los exploradores del Velo vigilan los caminos del norte de Auridon. ", 6),
        clue = "Busca los campamentos del Velo en la costa norte.",
        completionMessage = "Los campamentos del Velo han sido despejados.",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.5,
        targetY = 0.5,
        areaCenterX = 0.52,
        areaCenterY = 0.48,
        areaRadius = 0.075,
        targets = {
            { name = "Explorador del Velo", requiredCount = 3, zoneId = 381, worldX = 10000, worldZ = 20000, radius = 1500, locationRequired = true, customMessage = "Explorador del Velo eliminado en el campamento." },
            { name = "Guardia del Velo", requiredCount = 2, zoneId = 381, worldX = 10500, worldZ = 20500, radius = 1500, locationRequired = false, customMessage = "Guardia del Velo eliminado en el campamento." },
            { name = "Capitán del Velo", requiredCount = 1, zoneId = 381, worldX = 11000, worldZ = 21000, radius = 1500, locationRequired = true, customMessage = "Capitán del Velo eliminado en el campamento." },
        },
        discoveries = {
            { zoneId = 381, worldX = 10000, worldY = 100, worldZ = 20000, mapId = 32, x = 0.5, y = 0.5, radius = 1500, message = "Campamento norte descubierto." },
            { zoneId = 381, worldX = 11000, worldY = 100, worldZ = 21000, mapId = 32, x = 0.55, y = 0.55, radius = 1500, message = "Campamento sur descubierto." },
        },
    }
    local rpq3Rep = RPQuest.ShareCodec:EncodeQuest(repeatedQuest)
    -- Compute exact RPQ2 length for repeatedQuest (18-field pipe string * 4/3 Base64Url)
    local rpq2RawLen = #repeatedQuest.title + #repeatedQuest.description + #repeatedQuest.clue + #repeatedQuest.completionMessage
        + #repeatedQuest.mapName + 5 * 6 + 17 + 3 * 70 + 2 * 75
    local rpq2Len = 10 + math.ceil(rpq2RawLen * 4 / 3)
    local reduction = 1 - (#rpq3Rep / rpq2Len)
    AssertTrue(reduction >= 0.45, string.format("RPQ3 achieves >= 45%% reduction vs RPQ2 (actual: %.1f%%, len=%d vs rpq2=%d)", reduction * 100, #rpq3Rep, rpq2Len))

    -- Verify exact round-trip (coords <= 0.0001)
    local decoded, decErr = RPQuest.ShareCodec:DecodeQuest(rpq3)
    AssertTrue(decoded ~= nil, "RPQ3 decodes cleanly: " .. tostring(decErr))
    AssertEqual(decoded.title, complexQuest.title, "UTF-8 title preserved")
    AssertEqual(decoded.description, complexQuest.description, "UTF-8 description preserved")
    AssertEqual(decoded.clue, complexQuest.clue, "Clue preserved")
    AssertEqual(decoded.completionMessage, complexQuest.completionMessage, "Completion message preserved")
    AssertTrue(math.abs(decoded.targetX - complexQuest.targetX) <= 0.0001, "targetX uint16 precision <= 0.0001")
    AssertTrue(math.abs(decoded.targetY - complexQuest.targetY) <= 0.0001, "targetY uint16 precision <= 0.0001")
    AssertTrue(math.abs(decoded.areaCenterX - complexQuest.areaCenterX) <= 0.0001, "areaCenterX uint16 precision <= 0.0001")
    AssertTrue(math.abs(decoded.areaCenterY - complexQuest.areaCenterY) <= 0.0001, "areaCenterY uint16 precision <= 0.0001")
    AssertTrue(math.abs(decoded.areaRadius - complexQuest.areaRadius) <= 0.0001, "areaRadius uint16 precision <= 0.0001")
    AssertEqual(decoded.hideMapArea, true, "hideMapArea preserved")
    AssertEqual(decoded.requireUndetected, true, "requireUndetected preserved")
    AssertEqual(#decoded.targets, 2, "2 targets preserved")
    AssertEqual(decoded.targets[1].worldX, -123456, "Negative worldX preserved via ZigZag varint")
    AssertEqual(decoded.targets[1].worldZ, -78901, "Negative worldZ preserved via ZigZag varint")
    AssertEqual(decoded.targets[1].locationRequired, true, "Target locationRequired preserved")
    AssertEqual(decoded.targets[1].customMessage, complexQuest.targets[1].customMessage, "Target customMessage preserved")
    AssertEqual(decoded.targets[2].worldX, nil, "Target without location has nil worldX")
    AssertEqual(#decoded.discoveries, 2, "2 discoveries preserved")
    AssertEqual(decoded.discoveries[1].worldX, -45000, "Discovery negative worldX preserved")
    AssertEqual(#decoded.dialogues, 2, "2 dialogues preserved")

    -- Truncated/corrupted RPQ3 rejection
    local trunc = rpq3:sub(1, #rpq3 - 5)
    local tRes, tErr = RPQuest.ShareCodec:DecodeQuest(trunc)
    AssertEqual(tRes, nil, "Truncated RPQ3 rejected")
    AssertEqual(tErr, "ERR_IMPORT_TRUNCATED_OR_CORRUPT", "Truncated RPQ3 returns corrupt error")

    local badChar = "RPQ3:0000:INVALID*CHAR"
    local bRes, bErr = RPQuest.ShareCodec:DecodeQuest(badChar)
    AssertEqual(bRes, nil, "Invalid Base85 char rejected")
    AssertEqual(bErr, "ERR_IMPORT_TRUNCATED_OR_CORRUPT", "Invalid Base85 char returns corrupt error")

    -- ComputeQuestSignature remains deterministic across RPQ3
    local sig1 = RPQuest.ShareCodec:ComputeQuestSignature(complexQuest)
    local sig2 = RPQuest.ShareCodec:ComputeQuestSignature(decoded)
    AssertTrue(sig1 ~= nil and #sig1 == 8, "ComputeQuestSignature returns 8-char hex")
    AssertEqual(sig1, sig2, "ComputeQuestSignature matches between original and RPQ3-decoded quest")
    decoded.completed = true
    local compCode = RPQuest.ShareCodec:EncodeCompletion(decoded, "Player", 1000)
    AssertTrue(compCode ~= nil and compCode:sub(1, 6) == "RPQC1:", "RPQC1 completion code works for RPQ3-decoded quest")
    local okVal, valRes = RPQuest.ShareCodec:ValidateCompletionForQuest(complexQuest, compCode)
    AssertEqual(okVal, true, "Original quest validates RPQC1 from RPQ3-decoded quest: " .. tostring(valRes))
end)

RunTest("MailTransport: sequential send queue, body limit, inbox parsing, Accept/Reject and autoDeleteMail (Issue #101)", function()
    local sv = RPQuest.QuestRepository:GetDefaults()
    RPQuest.QuestRepository:Initialize(sv)
    RPQuest.MailTransport:Initialize()

    -- Mock ESO Mail API
    local sentMails = {}
    local deletedMails = {}
    local openCalls = 0
    local closeCalls = 0
    local nativeMailOpen = false

    local origSendMail = _G.SendMail
    local origReqOpen = _G.RequestOpenMailbox
    local origClose = _G.CloseMailbox
    local origGetNext = _G.GetNextMailId
    local origGetInfo = _G.GetMailItemInfo
    local origReqRead = _G.RequestReadMail
    local origReadMail = _G.ReadMail
    local origDeleteMail = _G.DeleteMail
    local origMaxBody = _G.MAIL_MAX_BODY_CHARACTERS
    local origScene = _G.SCENE_MANAGER

    _G.MAIL_MAX_BODY_CHARACTERS = 700
    _G.SendMail = function(to, subject, body)
        table.insert(sentMails, { to = to, subject = subject, body = body })
    end
    _G.RequestOpenMailbox = function() openCalls = openCalls + 1 end
    _G.CloseMailbox = function() closeCalls = closeCalls + 1 end
    _G.DeleteMail = function(mailId) table.insert(deletedMails, mailId) end
    _G.SCENE_MANAGER = {
        IsShowing = function(_, name)
            return nativeMailOpen and (name == "mailInbox" or name == "mailSend")
        end,
    }

    -- Create a prepared quest
    RPQuest.QuestRepository:ResetDraft()
    RPQuest.QuestRepository:SetDraftCapturedTarget({
        targetName = "Guardia",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.5,
        targetY = 0.5,
    })
    local q = RPQuest.QuestRepository:SaveDraft("Misión por Correo", "Descripción corta")

    -- 1. Reject > 1 recipient (1-to-1 model)
    local okMany, errMany = RPQuest.MailTransport:SendQuestToRecipients(q, "@A, @B", "Hola")
    AssertEqual(okMany, false, "Rejects more than 1 recipient")
    AssertEqual(errMany, "ERR_MAIL_TOO_MANY_RECIPIENTS", "Returns too many recipients error")

    -- 2. Reject body exceeding max multi-part limit (MAX_MAIL_PARTS * chunkSize)
    local hugeMsg = string.rep("A", 4200)
    local okLong, errLong = RPQuest.MailTransport:SendQuestToRecipients(q, "@PlayerOne", hugeMsg)
    AssertEqual(okLong, false, "Rejects mail exceeding multi-part mail limit")
    AssertEqual(errLong, "ERR_MAIL_BODY_TOO_LONG", "Returns body too long error")

    -- 3. Single recipient send (waits for EVENT_MAIL_OPEN_MAILBOX, normalizes @ prefix, deduplicates)
    local okSend, errSend = RPQuest.MailTransport:SendQuestToRecipients(q, "One, @one", "Mensaje de rol.")
    AssertEqual(okSend, true, "Single recipient mail send started: " .. tostring(errSend))
    AssertEqual(openCalls, 1, "RequestOpenMailbox called when native UI closed")
    AssertEqual(#sentMails, 0, "SendMail deferred until EVENT_MAIL_OPEN_MAILBOX fires")
    AssertEqual(closeCalls, 0, "CloseMailbox not called while waiting for mailbox open")

    RPQuest.MailTransport:OnMailboxOpened()
    AssertEqual(#sentMails, 1, "Mail dispatched after EVENT_MAIL_OPEN_MAILBOX")
    AssertEqual(sentMails[1].to, "@One", "Recipient normalized with @ prefix")
    AssertEqual(sentMails[1].subject, "[RPQuest] Misión por Correo", "Subject uses [RPQuest] prefix")

    RPQuest.MailTransport:OnMailSendSuccess("@One")
    AssertEqual(closeCalls, 1, "CloseMailbox called after queue finishes when native UI is closed")

    -- 3b. Unexpected mailbox close mid-send aborts cleanly without hanging
    local lastComplete = nil
    RPQuest.MailTransport:RegisterListener(function(evType, payload)
        if evType == "MAIL_SEND_COMPLETE" then
            lastComplete = payload
        end
    end)
    local okAbort = RPQuest.MailTransport:SendQuestToRecipients(q, "@One", "Hola")
    AssertEqual(okAbort, true, "Second send batch started")
    RPQuest.MailTransport:OnMailboxClosed()
    AssertEqual(RPQuest.MailTransport._isSending, false, "Sending flag cleared on unexpected mailbox close")
    AssertTrue(lastComplete ~= nil and lastComplete.failed == 1 and lastComplete.sent == 0, "MAIL_SEND_COMPLETE reports remaining mail as failed")

    -- 4. Native mailbox open coordination: do not close if native UI is showing
    nativeMailOpen = true
    openCalls = 0
    closeCalls = 0
    local okNative = RPQuest.MailTransport:SendQuestToRecipients(q, "@Four", "")
    AssertEqual(okNative, true, "Send succeeds when native mailbox already open")
    AssertEqual(openCalls, 0, "RequestOpenMailbox skipped when native UI open")
    RPQuest.MailTransport:OnMailSendSuccess("@Four")
    AssertEqual(closeCalls, 0, "CloseMailbox NOT called when native mailbox UI is open")

    -- 5. Inbox scanning & async EVENT_MAIL_READABLE parsing + Accept/Reject + autoDeleteMail
    local rpq3Code = RPQuest.QuestRepository:ExportQuestToCode(q.id)
    local mockInbox = {
        [101] = { sender = "@QuestMaster", char = "Master", subject = "[RPQuest] Misión por Correo", body = "Te encomiendo esta tarea.\n\n" .. rpq3Code },
        [102] = { sender = "@Other", char = "Other", subject = "Normal Mail", body = "Nothing here" },
        [103] = { sender = "@RejectMe", char = "Reject", subject = "[RPQuest] Otra", body = rpq3Code },
    }
    _G.GetNextMailId = function(lastId)
        if lastId == nil then return 101 end
        if lastId == 101 then return 102 end
        if lastId == 102 then return 103 end
        return nil
    end
    _G.GetMailItemInfo = function(id)
        local m = mockInbox[id]
        if not m then return nil end
        return m.sender, m.char, m.subject, "", true, false, false, false, 0, 0, 0, 30, 10, 0
    end
    _G.ReadMail = function(id)
        if id == 103 then return "" end -- simulate async load for 103
        return mockInbox[id] and mockInbox[id].body or ""
    end
    _G.RequestReadMail = function(id)
        -- simulate EVENT_MAIL_READABLE later
    end

    RPQuest.MailTransport:ScanInbox(false)
    AssertEqual(RPQuest.MailTransport:GetReceivedMailCount(), 0, "101 auto-ingested from inbox, 102 ignored")
    local receivedQuests = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
    AssertEqual(#receivedQuests, 1, "101 auto-ingested as OFFERED quest")
    AssertEqual(RPQuest.QuestRepository:IsOfferedQuest(receivedQuests[1]), true, "Ingested quest has OFFERED status")
    AssertEqual(receivedQuests[1].senderDisplayName, "@QuestMaster", "Sender displayName preserved")
    AssertEqual(#deletedMails, 1, "DeleteMail called on auto-ingest when autoDeleteMail is true")
    AssertEqual(deletedMails[1], 101, "Deleted mail 101")

    -- Simulate async readable for 103 with autoDeleteMail = false
    RPQuest.QuestRepository:SetSetting("autoDeleteMail", false)
    _G.ReadMail = function(id) return mockInbox[id] and mockInbox[id].body or "" end
    RPQuest.MailTransport:OnMailReadable(103)
    receivedQuests = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
    AssertEqual(#receivedQuests, 2, "103 auto-ingested via OnMailReadable")
    AssertEqual(#deletedMails, 1, "DeleteMail NOT called when autoDeleteMail is false")

    -- Re-scan does not duplicate 103
    RPQuest.MailTransport:ScanInbox(false)
    AssertEqual(#RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED), 2, "No duplicate on re-scan")

    -- Accept 101 and Reject 103
    local accOk = RPQuest.QuestRepository:AcceptOfferedQuest(receivedQuests[1].id)
    AssertEqual(accOk, true, "AcceptOfferedQuest succeeds")
    AssertEqual(RPQuest.QuestRepository:IsOfferedQuest(receivedQuests[1]), false, "Accepted quest is no longer OFFERED")
    local rejOk = RPQuest.QuestRepository:RejectOfferedQuest(receivedQuests[2].id)
    AssertEqual(rejOk, true, "RejectOfferedQuest succeeds")
    AssertEqual(#RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED), 1, "Rejected quest removed from list")

    -- Restore globals
    _G.SendMail = origSendMail
    _G.RequestOpenMailbox = origReqOpen
    _G.CloseMailbox = origClose
    _G.GetNextMailId = origGetNext
    _G.GetMailItemInfo = origGetInfo
    _G.RequestReadMail = origReqRead
    _G.ReadMail = origReadMail
    _G.DeleteMail = origDeleteMail
    _G.MAIL_MAX_BODY_CHARACTERS = origMaxBody
    _G.SCENE_MANAGER = origScene
end)

RunTest("MailTransport completion report (manual/auto) and creator auto-validation (Issue #102)", function()
    local sv = RPQuest.QuestRepository:GetDefaults()
    RPQuest.QuestRepository:Initialize(sv)
    RPQuest.MailTransport:Initialize()

    local sentMails = {}
    local deletedMails = {}
    local origSendMail = _G.SendMail
    local origDeleteMail = _G.DeleteMail
    local origGetNext = _G.GetNextMailId
    local origGetInfo = _G.GetMailItemInfo
    local origReadMail = _G.ReadMail
    local origReqOpen = _G.RequestOpenMailbox
    local origClose = _G.CloseMailbox

    _G.SendMail = function(to, subject, body)
        table.insert(sentMails, { to = to, subject = subject, body = body })
    end
    _G.DeleteMail = function(mailId) table.insert(deletedMails, mailId) end
    _G.RequestOpenMailbox = function() end
    _G.CloseMailbox = function() end

    -- Creator prepares quest
    RPQuest.QuestRepository:ResetDraft()
    RPQuest.QuestRepository:SetDraftCapturedTarget({
        targetName = "Bandido",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.5,
        targetY = 0.5,
    })
    local preparedQuest = RPQuest.QuestRepository:SaveDraft("Entrega por Correo", "Desc")
    local rpq3Code = RPQuest.QuestRepository:ExportQuestToCode(preparedQuest.id)

    -- Player receives quest via mail from @Creator
    _G.GetNextMailId = function(lastId) return (lastId == nil) and 201 or nil end
    _G.GetMailItemInfo = function(id)
        if id == 201 then return "@Creator", "CreatorChar", "[RPQuest] Entrega por Correo", "", true, false, false, false, 0, 0, 0, 30, 5, 0 end
        return nil
    end
    _G.ReadMail = function(id) return (id == 201) and rpq3Code or "" end

    RPQuest.MailTransport:ScanInbox(false)
    local receivedList = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
    local imported = receivedList[1]
    AssertTrue(imported ~= nil, "Quest auto-ingested from mail")
    RPQuest.QuestRepository:AcceptOfferedQuest(imported.id)
    AssertEqual(imported.senderDisplayName, "@Creator", "senderDisplayName persisted on imported quest")

    -- Manual mode (default): completing quest does NOT auto-send, shows manual button
    AssertEqual(RPQuest.QuestRepository:GetSetting("autoSendCompletionMail"), false, "autoSendCompletionMail defaults to false")
    RPQuest.QuestRepository:SetActiveQuest(imported.id)
    RPQuest.QuestRepository:RecordTargetEliminated("Bandido", { mapId = 32, zoneId = 381, x = imported.areaCenterX, y = imported.areaCenterY })
    AssertEqual(imported.completed, true, "Imported quest completed")
    AssertEqual(#sentMails, 0, "Manual mode does NOT auto-send completion mail")

    RPQuest.JournalTab:SelectQuest(imported.id)
    AssertEqual(RPQuest.JournalTab.btnReportCompletionMail:IsHidden(), false, "Manual report button visible in manual mode")

    -- 1-click manual send
    local okManual = RPQuest.MailTransport:SendCompletionReport(imported)
    AssertEqual(okManual, true, "SendCompletionReport succeeds in manual mode")
    RPQuest.MailTransport:OnMailboxOpened()
    AssertEqual(#sentMails, 1, "Completion mail sent to creator")
    AssertEqual(sentMails[1].to, "@Creator", "Sent to @Creator")
    AssertEqual(sentMails[1].subject, "[RPQuest:Done] Entrega por Correo", "Uses [RPQuest:Done] subject")
    local rpqc1Code = sentMails[1].body
    AssertTrue(rpqc1Code:sub(1, 6) == "RPQC1:", "Body contains RPQC1 code")
    RPQuest.MailTransport:OnMailSendSuccess("@Creator")
    AssertEqual(imported.completionReported, true, "completionReported marked true after send success")

    -- Automatic mode: reset quest, enable autoSendCompletionMail, complete again
    RPQuest.QuestRepository:ResetQuest(imported.id)
    RPQuest.QuestRepository:SetSetting("autoSendCompletionMail", true)
    RPQuest.QuestRepository:RecordTargetEliminated("Bandido", { mapId = 32, zoneId = 381, x = imported.areaCenterX, y = imported.areaCenterY })
    RPQuest.MailTransport:OnMailboxOpened()
    AssertEqual(#sentMails, 2, "Automatic mode sends completion mail upon QUEST_COMPLETED")
    RPQuest.JournalTab:SelectQuest(imported.id)
    AssertEqual(RPQuest.JournalTab.btnReportCompletionMail:IsHidden(), true, "Manual report button hidden in automatic mode")
    RPQuest.MailTransport:OnMailSendSuccess("@Creator")

    -- Creator receives [RPQuest:Done] mail and auto-validates RPQC1
    deletedMails = {}
    _G.GetNextMailId = function(lastId) return (lastId == nil) and 301 or nil end
    _G.GetMailItemInfo = function(id)
        if id == 301 then return "@Finisher", "FinisherChar", "[RPQuest:Done] Entrega por Correo", "", true, false, false, false, 0, 0, 0, 30, 2, 0 end
        return nil
    end
    _G.ReadMail = function(id) return (id == 301) and rpqc1Code or "" end

    RPQuest.MailTransport:ScanInbox(false)
    AssertEqual(#(preparedQuest.deliveries or {}), 1, "Creator recorded 1 verified delivery from [RPQuest:Done] mail")
    AssertEqual(preparedQuest.deliveries[1].senderDisplayName, "@Finisher", "Recorded finisher @AccountName")
    AssertEqual(#deletedMails, 1, "Completion mail auto-deleted when autoDeleteMail is true")
    AssertEqual(deletedMails[1], 301, "Deleted completion mail 301")

    _G.SendMail = origSendMail
    _G.DeleteMail = origDeleteMail
    _G.GetNextMailId = origGetNext
    _G.GetMailItemInfo = origGetInfo
    _G.ReadMail = origReadMail
    _G.RequestOpenMailbox = origReqOpen
    _G.CloseMailbox = origClose
end)

RunTest("29. JournalTab:OpenTab defers SelectFragment during async scene transition from another scene", function()
    RPQuest.JournalTab:Initialize()

    local origIsShowing = SCENE_MANAGER.IsShowing
    local origShow = SCENE_MANAGER.Show
    local origSelectFragment = QUEST_JOURNAL_KEYBOARD.tabs.SelectFragment
    local selectCalls = 0

    QUEST_JOURNAL_KEYBOARD.tabs.SelectFragment = function(tabsSelf, name)
        selectCalls = selectCalls + 1
        origSelectFragment(tabsSelf, name)
    end

    -- Simular transición asíncrona (ej. desde Notificaciones o Correo en SCENE_HIDING):
    -- SCENE_MANAGER:Show("questJournal") encola la escena pero IsShowing("questJournal") sigue false hasta SCENE_SHOWING.
    SCENE_MANAGER.IsShowing = function(_, sceneName)
        return false
    end
    SCENE_MANAGER.Show = function(_, sceneName)
        -- No cambia a SCENE_SHOWN de forma síncrona
    end

    RPQuest.JournalTab:OpenTab()
    AssertEqual(selectCalls, 0, "SelectFragment not called synchronously while previous scene is still hiding")
    AssertEqual(QUEST_JOURNAL_KEYBOARD.mode, RPQuest.Constants.UI.TAB_DESCRIPTOR, "QuestJournal mode set before OnShowing")

    -- Cuando la escena previa termina de ocultarse, ESO dispara QUEST_JOURNAL_KEYBOARD:OnShowing()
    QUEST_JOURNAL_KEYBOARD:OnShowing()
    AssertEqual(selectCalls, 1, "SelectFragment called inside OnShowing once questJournal scene starts showing")

    -- Si questJournal ya estaba visible (p. ej. cambiando desde pestaña Quests), sí selecciona síncronamente
    SCENE_MANAGER.IsShowing = function(_, sceneName)
        return sceneName == "questJournal"
    end
    RPQuest.JournalTab:OpenTab()
    AssertEqual(selectCalls, 2, "SelectFragment called synchronously when questJournal is already showing")

    SCENE_MANAGER.IsShowing = origIsShowing
    SCENE_MANAGER.Show = origShow
    QUEST_JOURNAL_KEYBOARD.tabs.SelectFragment = origSelectFragment
end)

RunTest("30. Per-NPC player dialogue option, ShareCodec RPQ3 roundtrip, and JournalTab selected NPC indicator", function()
    RPQuest.JournalTab:Initialize()
    RPQuest.QuestRepository:ResetDraft()

    -- Add 2 NPCs with distinct player dialogue options and responses
    local _, idx1 = RPQuest.QuestRepository:AddDraftDialogue("Farseer Kuamta", 381, "Look near the northern shrine.", "Ask about the shrine")
    local _, idx2 = RPQuest.QuestRepository:AddDraftDialogue("Vasamannu", 381, "He lives to the south, I don't care.", "Daynill? Know him?")
    AssertEqual(idx1, 1, "First NPC added at index 1")
    AssertEqual(idx2, 2, "Second NPC added at index 2")

    -- Capture a target and save quest
    mockState.reticleExists = true
    mockState.reticleName = "Bandit"
    RPQuest.TargetCapture:CaptureFromReticle()
    local saved = RPQuest.QuestRepository:SaveDraft("Per-NPC Clues", "Test distinct options per NPC.")
    AssertTrue(saved ~= nil, "Quest saved with per-NPC clues")
    AssertEqual(saved.dialogues[1].clue, "Ask about the shrine", "NPC 1 clue persisted")
    AssertEqual(saved.dialogues[2].clue, "Daynill? Know him?", "NPC 2 clue persisted")

    -- Active quest dialogue lookup returns each NPC's own clue
    RPQuest.QuestRepository:SetActiveQuest(saved.id)
    local match1 = RPQuest.QuestRepository:FindDialogueForActiveQuest("Farseer Kuamta", 381)
    local match2 = RPQuest.QuestRepository:FindDialogueForActiveQuest("Vasamannu", 381)
    AssertTrue(match1 ~= nil and match1.clue == "Ask about the shrine", "FindDialogueForActiveQuest returns NPC 1's own option")
    AssertTrue(match2 ~= nil and match2.clue == "Daynill? Know him?", "FindDialogueForActiveQuest returns NPC 2's own option")

    -- ShareCodec RPQ3 roundtrip preserves distinct per-NPC clues
    local code = RPQuest.QuestRepository:ExportQuestToCode(saved.id)
    local imported = RPQuest.QuestRepository:ImportQuestFromCode(code)
    AssertTrue(imported ~= nil, "RPQ3 quest with per-NPC clues imported")
    AssertEqual(imported.dialogues[1].clue, "Ask about the shrine", "Imported NPC 1 clue preserved")
    AssertEqual(imported.dialogues[2].clue, "Daynill? Know him?", "Imported NPC 2 clue preserved")

    -- JournalTab editor shows selected NPC name and per-NPC option/response when cycling
    RPQuest.JournalTab:OpenEditEditor(saved.id)
    AssertEqual(RPQuest.JournalTab.selectedDialogueIndex, 1, "Editor selects first NPC on open")
    AssertTrue(RPQuest.JournalTab.lblSelectedNpc:GetText():find("Farseer Kuamta", 1, true) ~= nil, "lblSelectedNpc shows Farseer Kuamta")
    AssertTrue(RPQuest.JournalTab.lblInputClue:GetText():find("Farseer Kuamta", 1, true) ~= nil, "lblInputClue shows Farseer Kuamta")
    AssertTrue(RPQuest.JournalTab.lblDlgResponse:GetText():find("Farseer Kuamta", 1, true) ~= nil, "lblDlgResponse shows Farseer Kuamta")
    AssertEqual(RPQuest.JournalTab.clueEdit:GetText(), "Ask about the shrine", "clueEdit shows NPC 1 option")
    AssertEqual(RPQuest.JournalTab.dlgResponseEdit:GetText(), "Look near the northern shrine.", "dlgResponseEdit shows NPC 1 response")

    -- Cycle to NPC 2
    RPQuest.JournalTab.btnDlgNext:FireHandler("OnClicked")
    AssertEqual(RPQuest.JournalTab.selectedDialogueIndex, 2, "Editor cycles to second NPC")
    AssertTrue(RPQuest.JournalTab.lblSelectedNpc:GetText():find("Vasamannu", 1, true) ~= nil, "lblSelectedNpc updates to Vasamannu")
    AssertTrue(RPQuest.JournalTab.lblInputClue:GetText():find("Vasamannu", 1, true) ~= nil, "lblInputClue updates to Vasamannu")
    AssertTrue(RPQuest.JournalTab.lblDlgResponse:GetText():find("Vasamannu", 1, true) ~= nil, "lblDlgResponse updates to Vasamannu")
    AssertEqual(RPQuest.JournalTab.clueEdit:GetText(), "Daynill? Know him?", "clueEdit updates to NPC 2 option")
    AssertEqual(RPQuest.JournalTab.dlgResponseEdit:GetText(), "He lives to the south, I don't care.", "dlgResponseEdit updates to NPC 2 response")
end)

RunTest("MailTransport: multi-part RPQP chunking, out-of-order reassembly, incomplete state, and batch delete (Issue #113)", function()
    local sv = RPQuest.QuestRepository:GetDefaults()
    RPQuest.QuestRepository:Initialize(sv)
    RPQuest.MailTransport:Initialize()
    RPQuest.QuestRepository:SetSetting("autoDeleteMail", true)

    local sentMails = {}
    local inbox = {}
    local deletedIds = {}

    _G.MAIL_MAX_BODY_CHARACTERS = 700
    _G.RequestOpenMailbox = function() end
    _G.CloseMailbox = function() end
    _G.SendMail = function(to, subject, body)
        table.insert(sentMails, { to = to, subject = subject, body = body })
    end
    _G.GetNextMailId = function(cur)
        local keys = {}
        for k in pairs(inbox) do table.insert(keys, k) end
        table.sort(keys)
        if cur == nil then return keys[1] end
        for i, k in ipairs(keys) do
            if k == cur then return keys[i + 1] end
        end
        return nil
    end
    _G.GetMailItemInfo = function(id)
        local m = inbox[id]
        if not m then return nil end
        return m.sender, m.charName, m.subject, nil, nil, nil, nil, nil, nil, nil, nil, nil, m.secs
    end
    _G.ReadMail = function(id)
        return inbox[id] and inbox[id].body or ""
    end
    _G.DeleteMail = function(id)
        table.insert(deletedIds, id)
        inbox[id] = nil
    end

    -- Build a quest whose RPQ3 code + roleplay message exceeds 700 chars
    RPQuest.QuestRepository:ResetDraft()
    RPQuest.QuestRepository:SetDraftCapturedTarget({
        targetName = "Farseer Kuamta",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.5,
        targetY = 0.5,
    })
    local q = RPQuest.QuestRepository:SaveDraft(
        "House Quest: Multi-Part",
        "Investigate the northern ruins and speak with the informants about the missing relic.",
        nil,
        "You have uncovered the truth behind the House Quest!"
    )
    local roleMsg = string.rep("Greetings agent, this mission requires utmost discretion. ", 18)
    local code = RPQuest.QuestRepository:ExportQuestToCode(q.id)
    local plan = RPQuest.MailTransport:BuildQuestMailPackets(roleMsg, code, q.title)
    AssertTrue(plan.fits, "Multi-part plan fits within MAX_MAIL_PARTS")
    AssertTrue(plan.partCount >= 2, "Splits into >= 2 parts (got " .. tostring(plan.partCount) .. ")")
    for i, pkt in ipairs(plan.packets) do
        AssertTrue(#pkt.body <= 700, "Part " .. i .. " body <= 700 chars (got " .. #pkt.body .. ")")
    end

    -- Send all parts sequentially
    local okSend, errSend = RPQuest.MailTransport:SendQuestToRecipients(q, "@Receiver", roleMsg)
    AssertEqual(okSend, true, "Multi-part send started: " .. tostring(errSend))
    RPQuest.MailTransport:OnMailboxOpened()
    for i = 1, plan.partCount do
        AssertEqual(#sentMails, i, "Dispatched part " .. i)
        RPQuest.MailTransport:OnMailSendSuccess("@Receiver")
    end

    -- Simulate receiving parts out of order (last part first, then remaining)
    RPQuest.MailTransport:Initialize()
    inbox[500 + plan.partCount] = {
        sender = "@Sender",
        charName = "Sender Char",
        subject = sentMails[plan.partCount].subject,
        body = sentMails[plan.partCount].body,
        secs = 5,
    }
    RPQuest.MailTransport:ScanInbox(false)
    local mailsPartial = RPQuest.MailTransport:GetReceivedMails()
    AssertEqual(#mailsPartial, 1, "Shows 1 partial entry in inbox")
    AssertEqual(mailsPartial[1].isIncomplete, true, "Entry marked incomplete while missing parts")
    AssertEqual(mailsPartial[1].partsReceived, 1, "1 part received so far")

    local accFail, accErr = RPQuest.MailTransport:AcceptReceivedMail(mailsPartial[1].mailId)
    AssertEqual(accFail, nil, "Cannot accept incomplete multi-part mail")
    AssertEqual(accErr, "ERR_MAIL_INCOMPLETE", "Returns ERR_MAIL_INCOMPLETE")

    -- Deliver remaining parts
    for i = 1, plan.partCount - 1 do
        inbox[500 + i] = {
            sender = "@Sender",
            charName = "Sender Char",
            subject = sentMails[i].subject,
            body = sentMails[i].body,
            secs = 5 + i,
        }
    end
    RPQuest.MailTransport:ScanInbox(false)
    local receivedMulti = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
    AssertEqual(#receivedMulti, 1, "Multi-part quest auto-ingested once all parts arrive")
    local imported = receivedMulti[1]
    AssertEqual(RPQuest.QuestRepository:IsOfferedQuest(imported), true, "Multi-part quest starts in OFFERED status")
    AssertEqual(imported.title, q.title, "Decoded title matches original")
    AssertEqual(#deletedIds, plan.partCount, "All part mails deleted on auto-ingest")
    AssertEqual(RPQuest.MailTransport:GetReceivedMailCount(), 0, "Inbox empty after auto-ingest")
end)

RunTest("ShareCodec:DecodeQuest surfaces ERR_IMPORT_UNSUPPORTED_VERSION for future RPQ prefixes and JournalTab shows version", function()
    RPQuest.JournalTab:Initialize()
    AssertTrue(RPQuest.JournalTab.versionLabel ~= nil, "JournalTab creates versionLabel")
    AssertEqual(RPQuest.JournalTab.versionLabel:GetText(), "v" .. RPQuest.Constants.METADATA.VERSION, "versionLabel displays addon version")

    local dec1, err1 = RPQuest.ShareCodec:DecodeQuest("RPQ4:1234:abcd")
    AssertEqual(dec1, nil, "RPQ4 standard envelope rejected")
    AssertEqual(err1, "ERR_IMPORT_UNSUPPORTED_VERSION", "RPQ4 returns ERR_IMPORT_UNSUPPORTED_VERSION")

    local dec2, err2 = RPQuest.ShareCodec:DecodeQuest("RPQ99:future_format_payload")
    AssertEqual(dec2, nil, "RPQ99 arbitrary format rejected")
    AssertEqual(err2, "ERR_IMPORT_UNSUPPORTED_VERSION", "RPQ99 returns ERR_IMPORT_UNSUPPORTED_VERSION")

    local imp, impErr = RPQuest.QuestRepository:ImportQuestFromCode("RPQ4:1234:abcd")
    AssertEqual(imp, nil, "ImportQuestFromCode fails for RPQ4")
    AssertEqual(impErr, RPQuest.Locale:Get("ERR_IMPORT_UNSUPPORTED_VERSION"), "ImportQuestFromCode returns localized unsupported version error")
end)

RunTest("MailTransport: surfaces decode errors once per mailId on ScanInbox/OnMailReadable (Issue #125)", function()
    local sv = RPQuest.QuestRepository:GetDefaults()
    RPQuest.QuestRepository:Initialize(sv)
    RPQuest.MailTransport:Initialize()

    local inbox = {
        [901] = { sender = "@Sender", charName = "Sender", subject = "[RPQuest] Corrupt", body = "RPQ3:FFFF:badpayload", secs = 10 },
        [902] = { sender = "@Sender", charName = "Sender", subject = "[RPQuest] Future", body = "RPQ4:1234:futurepayload", secs = 10 },
    }
    _G.GetNextMailId = function(cur)
        if cur == nil then return 901 end
        if cur == 901 then return 902 end
        return nil
    end
    _G.GetMailItemInfo = function(id)
        local m = inbox[id]
        if not m then return nil end
        return m.sender, m.charName, m.subject, nil, false, false, true, false, 0, 0, 0, 0, m.secs
    end
    _G.ReadMail = function(id)
        local m = inbox[id]
        return m and m.body or ""
    end

    local alerts = {}
    local origShowAlert = RPQuest.Announcements.ShowAlert
    RPQuest.Announcements.ShowAlert = function(_, msg, isErr)
        table.insert(alerts, { msg = msg, isErr = isErr })
    end

    local events = {}
    RPQuest.MailTransport:RegisterListener(function(ev, payload)
        if ev == "MAIL_DECODE_ERROR" then
            table.insert(events, payload)
        end
    end)

    RPQuest.MailTransport:ScanInbox(false)
    AssertEqual(#alerts, 2, "2 decode error alerts shown on first ScanInbox")
    AssertEqual(alerts[1].isErr, true, "Corrupt mail alert is error")
    AssertEqual(alerts[1].msg, RPQuest.Locale:Get("ERR_IMPORT_TRUNCATED_OR_CORRUPT"), "Corrupt mail shows ERR_IMPORT_TRUNCATED_OR_CORRUPT")
    AssertEqual(alerts[2].msg, RPQuest.Locale:Get("ERR_IMPORT_UNSUPPORTED_VERSION"), "Future RPQ4 mail shows ERR_IMPORT_UNSUPPORTED_VERSION")
    AssertEqual(#events, 2, "MAIL_DECODE_ERROR emitted for both mails")

    -- Re-scan and OnMailReadable must not duplicate alerts for the same mailIds
    RPQuest.MailTransport:ScanInbox(false)
    RPQuest.MailTransport:OnMailReadable(901)
    AssertEqual(#alerts, 2, "No duplicate alerts on re-scan or OnMailReadable")

    RPQuest.Announcements.ShowAlert = origShowAlert
end)

RunTest("MailTransport: alerts on incoming quest mail without duplicates and supports autoAcceptMail (Issue #124)", function()
    local sv = RPQuest.QuestRepository:GetDefaults()
    RPQuest.QuestRepository:Initialize(sv)
    RPQuest.MailTransport:Initialize()

    AssertEqual(RPQuest.QuestRepository:GetSetting("autoAcceptMail"), false, "autoAcceptMail defaults to false")

    -- Create a valid RPQ3 code
    local code = RPQuest.ShareCodec:EncodeQuest({
        title = "Misión de Correo",
        description = "Prueba de correo.",
        mapId = 1,
        zoneId = 1,
        mapName = "Auridon",
        targets = { { name = "Guardia" } },
    })

    local inbox = {
        [951] = { sender = "@SenderA", charName = "SenderA", subject = "[RPQuest] Misión de Correo", body = code, secs = 5 },
    }
    local deletedIds = {}
    _G.GetNextMailId = function(cur) return (cur == nil and inbox[951]) and 951 or nil end
    _G.GetMailItemInfo = function(id)
        local m = inbox[id]
        if not m then return nil end
        return m.sender, m.charName, m.subject, nil, false, false, true, false, 0, 0, 0, 0, m.secs
    end
    _G.ReadMail = function(id) return inbox[id] and inbox[id].body or "" end
    _G.DeleteMail = function(id)
        table.insert(deletedIds, id)
        inbox[id] = nil
    end

    local alerts = {}
    local origShowAlert = RPQuest.Announcements.ShowAlert
    RPQuest.Announcements.ShowAlert = function(_, msg, isErr)
        table.insert(alerts, { msg = msg, isErr = isErr })
    end

    -- 1. Manual mode (autoAcceptMail = false): auto-ingests as OFFERED
    RPQuest.MailTransport:ScanInbox(false)
    local offeredList = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
    AssertEqual(#offeredList, 1, "Quest auto-ingested as OFFERED in manual mode")
    AssertEqual(RPQuest.QuestRepository:IsOfferedQuest(offeredList[1]), true, "Ingested quest is OFFERED")
    AssertEqual(#alerts, 1, "1 notification alert shown")
    AssertEqual(alerts[1].isErr, false, "Notification alert is not an error")
    AssertEqual(alerts[1].msg, RPQuest.Locale:Get("ALERT_MAIL_QUEST_OFFERED", "Misión de Correo", "@SenderA"), "Notification message matches")

    -- Re-scan does not duplicate quest or alert
    RPQuest.MailTransport:ScanInbox(false)
    AssertEqual(#RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED), 1, "No duplicate OFFERED quest on re-scan")
    AssertEqual(#alerts, 1, "No duplicate notification alert on re-scan")

    -- 2. Auto-accept mode (autoAcceptMail = true)
    RPQuest.QuestRepository:SetSetting("autoAcceptMail", true)
    local qCountBefore = #RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
    inbox[952] = { sender = "@SenderB", charName = "SenderB", subject = "[RPQuest] Misión de Correo", body = code, secs = 2 }
    _G.GetNextMailId = function(cur)
        if cur == nil and inbox[952] then return 952 end
        return nil
    end

    local acceptedCount = 0
    local origAnnounce = RPQuest.Announcements.AnnounceQuestAccepted
    RPQuest.Announcements.AnnounceQuestAccepted = function() acceptedCount = acceptedCount + 1 end

    RPQuest.MailTransport:ScanInbox(false)
    local qCountAfter = #RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
    AssertEqual(qCountAfter, qCountBefore + 1, "Quest auto-imported when autoAcceptMail=true")
    AssertEqual(#deletedIds, 2, "Both ingested and auto-accepted mails deleted when autoDeleteMail=true")
    AssertEqual(deletedIds[2], 952, "Deleted mailId matches auto-accepted mail")
    AssertEqual(acceptedCount, 1, "AnnounceQuestAccepted called on auto-accept")

    RPQuest.Announcements.ShowAlert = origShowAlert
    RPQuest.Announcements.AnnounceQuestAccepted = origAnnounce
end)

RunTest("1-to-1 model: group sharing disabled, group tracking ignored, and DialogueInjector works after mail accept without /reloadui (Issue #142)", function()
    local sv = RPQuest.QuestRepository:GetDefaults()
    RPQuest.QuestRepository:Initialize(sv)
    RPQuest.MailTransport:Initialize()
    RPQuest.JournalTab:Initialize()
    RPQuest.DiscoveryTracker:Initialize()
    RPQuest.CombatTracker:Initialize()
    RPQuest.DialogueInjector:Initialize()

    -- Create quest with targetLocation, discovery point, and NPC dialogue
    local zId = mockState.zoneId
    local code = RPQuest.ShareCodec:EncodeQuest({
        title = "Misión 1-a-1",
        description = "Objetivo individual.",
        mapId = mockState.mapId,
        zoneId = zId,
        mapName = "Auridon",
        targets = {
            { name = "Bandido", requiredCount = 1, worldZoneId = zId, worldX = 5000, worldZ = 5000, radius = 1000, locationRequired = true },
        },
        discoveries = {
            { name = "Ruinas", zoneId = zId, worldX = 20000, worldZ = 20000, radius = 1000 },
        },
        dialogues = {
            { npcName = "Informante", zoneId = zId, clue = "¿Qué sabes del bandido?", response = "Está al sur." },
        },
    })

    -- Verify group sharing APIs/UI are removed
    AssertEqual(RPQuest.JournalTab.shareWithGroupDescriptor, nil, "Group share keybind descriptor removed")
    AssertEqual(RPQuest.MailTransport.ShareQuestWithGroup, nil, "MailTransport:ShareQuestWithGroup removed")
    AssertEqual(RPQuest.MailTransport.GetGroupMemberDisplayNames, nil, "MailTransport:GetGroupMemberDisplayNames removed")

    -- Simulate grouped player receiving and accepting quest via mail without /reloadui
    local isGrouped = true
    _G.IsUnitGrouped = function() return isGrouped end
    _G.GetGroupSize = function() return 2 end
    _G.GetGroupUnitTagByIndex = function(i)
        local tags = { "player", "group1" }
        return tags[i]
    end
    _G.AreUnitsEqual = function(a, b) return a == b end

    -- Group DiscoveryTracker & CombatTracker ignore group1
    local saved = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Creator")
    RPQuest.QuestRepository:SetActiveQuest(saved.id)
    RPQuest.JournalTab:SelectQuest(saved.id)

    _G.GetUnitWorldPosition = function(tag)
        if tag == "player" then return zId, 0, 0, 0 end
        if tag == "group1" then return zId, 20000, 0, 20000 end
        return zId, 0, 0, 0
    end
    RPQuest.DiscoveryTracker:UpdatePollingState()
    RPQuest.DiscoveryTracker:OnUpdateTick()
    AssertEqual(saved.discoveries[1].discovered, false, "Discovery NOT triggered by group1 position")

    _G.GetUnitWorldPosition = function(tag)
        if tag == "player" then return zId, 0, 0, 0 end
        if tag == "group1" then return zId, 5000, 0, 5000 end
        return zId, 0, 0, 0
    end
    _G.GetMapPlayerPosition = function() return 0.5, 0.5 end
    RPQuest.CombatTracker:OnCombatEvent(nil, _G.ACTION_RESULT_DIED, false, "", 0, 0, "Ally1", _G.COMBAT_UNIT_TYPE_GROUP, "Bandido", 0, 0, 0, 0, false, 1, 777, 0)
    AssertEqual(saved.targets[1].currentCount, 0, "Group kill NOT recorded in 1-to-1 mode")

    -- DialogueInjector injects option immediately after mail quest import even while grouped
    local origUnitName = _G.GetUnitName
    _G.GetUnitName = function(tag)
        if tag == "interact" then return "Informante" end
        return origUnitName(tag)
    end
    local injectedOptions = {}
    local fakeInteraction = {
        optionControls = {},
        PopulateChatterOption = function(selfObj, controlID, optionIndex, optionText, optionType)
            table.insert(injectedOptions, { controlID = controlID, text = optionText, optionType = optionType })
        end,
        PopulateChatterOptions = function(selfObj, optionCount)
            selfObj:PopulateChatterOption(1, function() end, "Adiós", _G.CHATTER_GOODBYE)
            selfObj:FinalizeChatterOptions(optionCount)
            return optionCount
        end,
        FinalizeChatterOptions = function(selfObj, optionCount)
            return optionCount
        end,
    }
    _G.ZO_Interaction = fakeInteraction
    RPQuest.DialogueInjector:InstallHooks()
    fakeInteraction:PopulateChatterOptions(0)
    AssertEqual(#injectedOptions, 2, "DialogueInjector injects clue + goodbye immediately without /reloadui")
    AssertEqual(injectedOptions[1].text, "¿Qué sabes del bandido?", "Injected option has expected clue text")
    _G.GetUnitName = origUnitName
end)

RunTest("36. Locale fallback to English for unsupported client languages and direct formatting", function()
    local origLang = mockState.language
    mockState.language = "de"
    RPQuest.Locale.activeLang = nil
    RPQuest.Locale:Initialize()
    AssertEqual(RPQuest.Locale:GetLanguage(), "en", "Unsupported client language 'de' falls back to 'en'")
    AssertEqual(RPQuest.Locale:Get("SECTION_ACTIVE_QUESTS", 3), "QUESTS (3)", "Locale:Get formats placeholders directly")
    mockState.language = origLang
    RPQuest.Locale:Initialize(origLang)
end)

RunTest("37. OFFERED pending quest UI in JournalTab: Accept activates and Reject removes (Issue #143)", function()
    local sv = RPQuest.QuestRepository:GetDefaults()
    RPQuest.QuestRepository:Initialize(sv)
    RPQuest.JournalTab:Initialize()

    local code = RPQuest.ShareCodec:EncodeQuest({
        title = "Contrato Pendiente",
        description = "Acepta o rechaza.",
        mapId = mockState.mapId,
        zoneId = mockState.zoneId,
        mapName = "Auridon",
        targets = { { name = "Lobo", requiredCount = 1 } },
    })

    local offered, _, isDup = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master", {
        status = RPQuest.Constants.QUEST_STATUS.OFFERED,
        sourceMailId = "mail_pending_1",
    })
    AssertTrue(offered ~= nil, "Offered quest imported")
    AssertEqual(isDup, false, "First import is not duplicate")
    AssertEqual(RPQuest.QuestRepository:GetActiveQuest(), nil, "Offered quest is not active yet")
    AssertEqual(RPQuest.QuestRepository:SetActiveQuest(offered.id), false, "Cannot set OFFERED quest active directly")

    -- Duplicate prevention by sourceMailId
    local dupQ, _, isDup2 = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master", {
        status = RPQuest.Constants.QUEST_STATUS.OFFERED,
        sourceMailId = "mail_pending_1",
    })
    AssertEqual(isDup2, true, "Second import with same sourceMailId detected as duplicate")
    AssertEqual(dupQ.id, offered.id, "Returns existing quest on duplicate")

    -- JournalTab shows Accept and Reject buttons for OFFERED quest
    RPQuest.JournalTab:SelectQuest(offered.id)
    RPQuest.JournalTab:Refresh()
    AssertEqual(RPQuest.JournalTab.btnAcceptOffered:IsHidden(), false, "Accept button visible for OFFERED quest")
    AssertEqual(RPQuest.JournalTab.btnRejectOffered:IsHidden(), false, "Reject button visible for OFFERED quest")
    AssertEqual(RPQuest.JournalTab.btnActivate:IsHidden(), true, "Activate button hidden for OFFERED quest")

    -- Accept activates quest
    local accepted = RPQuest.JournalTab:AcceptSelectedOfferedQuest()
    AssertEqual(accepted, true, "AcceptSelectedOfferedQuest succeeds")
    AssertEqual(RPQuest.QuestRepository:GetActiveQuest().id, offered.id, "Quest becomes active after Accept")
    AssertEqual(RPQuest.JournalTab.btnAcceptOffered:IsHidden(), true, "Accept button hidden after Accept")

    -- Reject removes another offered quest
    local offered2 = RPQuest.QuestRepository:ImportQuestFromCode(code, "@Master", {
        status = RPQuest.Constants.QUEST_STATUS.OFFERED,
        sourceMailId = "mail_pending_2",
    })
    RPQuest.JournalTab:SelectQuest(offered2.id)
    local rejected = RPQuest.JournalTab:RejectSelectedOfferedQuest()
    AssertEqual(rejected, true, "RejectSelectedOfferedQuest succeeds")
    AssertEqual(RPQuest.QuestRepository:GetQuestById(offered2.id), nil, "Rejected quest removed from repository")
end)

if failed > 0 then
    for _, f in ipairs(failures) do
        print(f)
    end
    print(string.format("FAILED: %d passed, %d failed", passed, failed))
    os.exit(1)
else
    print(string.format("OK: %d tests passed, 0 failed", passed))
end

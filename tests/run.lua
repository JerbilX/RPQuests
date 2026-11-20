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
UI_ALERT_CATEGORY_ALERT = 0
UI_ALERT_CATEGORY_ERROR = 1
CSA_CATEGORY_LARGE_TEXT = 1
CSA_CATEGORY_SMALL_TEXT = 2
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

SOUNDS.QUEST_COMPLETED = "Quest_Complete"
SOUNDS.QUEST_OBJECTIVE_INCREMENT = "Quest_ObjectivesIncrement"
SOUNDS.QUEST_OBJECTIVE_COMPLETE = "Quest_ObjectivesComplete"
SOUNDS.NOTE_TAKEN = "Note_Taken"
SOUNDS.GENERAL_ALERT_ERROR = "General_Alert_Error"
SOUNDS.DEFAULT_CLICK = "Default_Click"

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

SetMapToMapId = function(mapId)
    mockState.mapId = mapId
    return SET_MAP_RESULT_MAP_CHANGED
end

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
dofile("src/WorldMapArea.lua")
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
    AssertTrue(string.sub(code, 1, 5) == "RPQ1:", "Code must start with RPQ1:")

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
    local tampered = code:gsub("^RPQ1:[0-9A-F][0-9A-F][0-9A-F][0-9A-F]:", "RPQ1:0000:")
    local res, _ = RPQuest.ShareCodec:DecodeQuest(tampered)
    AssertEqual(res, nil, "Tampered checksum must fail")

    local malformed, _ = RPQuest.ShareCodec:DecodeQuest("INVALID_STRING")
    AssertEqual(malformed, nil, "Malformed string must fail")
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

    -- En grupo, muerte de miembro del grupo (distinto targetUnitId) sí cuenta y completa
    mockState.isGrouped = true
    EVENT_MANAGER:FireEvent(
        EVENT_COMBAT_EVENT,
        ACTION_RESULT_DIED_XP, false, "Ataque", 0, 0,
        "Compañero", COMBAT_UNIT_TYPE_GROUP, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
        1500, 0, 0, false, 98, 2004, 100
    )
    mockState.isGrouped = false
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
    AssertTrue(string.sub(generatedCode, 1, 5) == "RPQ1:", "Share edit box auto-populated with RPQ1 code")
    AssertEqual(RPQuest.JournalTab.btnShare, nil, "Share button removed in favor of always-visible share box")
    RPQuest.JournalTab.shareEdit._selectedAll = false
    RPQuest.JournalTab.shareEdit:FireHandler("OnFocusGained")
    AssertTrue(RPQuest.JournalTab.shareEdit._selectedAll, "Share edit box selects all text when focused")

    -- Probar vista Importar en JournalTab
    RPQuest.JournalTab:OpenImportView()
    AssertEqual(RPQuest.JournalTab.importPane:IsHidden(), false, "Import pane is visible")
    RPQuest.JournalTab.importCodeEdit:SetText(generatedCode)
    RPQuest.JournalTab:OnConfirmImportClicked()
    AssertEqual(#RPQuest.QuestRepository:GetAllQuests(), 2, "Second quest imported via UI")

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
    AssertTrue(string.sub(initialShareText, 1, 5) == "RPQ1:", "shareEdit populated with RPQ1 code for received quest")
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
    AssertTrue(string.sub(RPQuest.JournalTab.shareEdit:GetText(), 1, 5) == "RPQ1:", "shareEdit auto-populated with RPQ1 code for prepared quest")
    AssertEqual(RPQuest.JournalTab.validateEdit:GetText(), "", "validateEdit cleared when switching quest")
    RPQuest.JournalTab:OnValidateDeliveryClicked()
    local emptyMsg = RPQuest.JournalTab.validateResultLabel:GetText()
    AssertEqual(emptyMsg, RPQuest.Locale:Get("VALIDATE_ERR_EMPTY"), "Validate UI prompts when validate box is empty (ignores shareEdit)")
    RPQuest.JournalTab.validateEdit:SetText(completionCode)
    RPQuest.JournalTab:OnValidateDeliveryClicked()
    local msg = RPQuest.JournalTab.validateResultLabel:GetText()
    AssertTrue(msg:find("Jugador", 1, true) ~= nil, "Validate UI shows character name on success")
    AssertTrue(string.sub(RPQuest.JournalTab.shareEdit:GetText(), 1, 5) == "RPQ1:", "shareEdit still preserves RPQ1 code after validation")
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
    WORLD_MAP_MANAGER = nil

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
    AssertTrue(type(code) == "string" and #code > 900, "Exported code generated cleanly")

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
    AssertTrue(type(code) == "string" and code:sub(1, 5) == "RPQ1:", "ShareCodec encodes discovery-only quest")

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

if failed > 0 then
    for _, f in ipairs(failures) do
        print(f)
    end
    print(string.format("FAILED: %d passed, %d failed", passed, failed))
    os.exit(1)
else
    print(string.format("OK: %d tests passed, 0 failed", passed))
end

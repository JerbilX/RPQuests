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
    reticleExists = true,
    reticleName = "Capitán Pirata^m",
    reticleIsPlayer = false,
    reticleIsDead = false,
    reticleAttackable = true,
    reticleReaction = 2,
    alerts = {},
    csaMessages = {},
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
        function c:SelectAll() self._selectedAll = true end
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
dofile("src/WorldMapArea.lua")
dofile("src/HudTracker.lua")
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
        targetName = "Capitán Pirata",
        requiredCount = 3,
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
    AssertEqual(decoded.targetName, original.targetName, "Target name matches")
    AssertEqual(decoded.requiredCount, 3, "Required count matches")
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
        targetName = "Goblin",
        requiredCount = 1,
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
    AssertEqual(quest.targetName, "Nigromante Oscuro", "Gender suffix stripped")
    AssertEqual(quest.requiredCount, 2, "Required count is 2")
    AssertEqual(RPQuest.QuestRepository:GetActiveQuest().id, quest.id, "Newly created quest becomes active")

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
    AssertEqual(quest.currentCount, 1, "Current count is 1")

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
    AssertEqual(imported.currentCount, 0, "Imported quest starts at 0 kills")
    AssertEqual(RPQuest.QuestRepository:GetActiveQuest().id, imported.id, "Imported quest becomes active")

    -- 8. Reiniciar misión completada
    RPQuest.QuestRepository:ResetQuest(quest.id)
    AssertEqual(quest.completed, false, "Reset quest is uncompleted")
    AssertEqual(quest.currentCount, 0, "Reset quest count is 0")

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
    AssertEqual(draft.targetName, "Jefe Bandido", "Captured target name normalized")
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
    AssertEqual(q.currentCount, 1, "Kill count incremented to 1")
    AssertEqual(q.completed, false, "Not yet completed")
    AssertEqual(#mockState.csaMessages, 1, "1 CSA progress message emitted")

    -- Mismo targetUnitId con ACTION_RESULT_DIED_XP no debe duplicar
    EVENT_MANAGER:FireEvent(
        EVENT_COMBAT_EVENT,
        ACTION_RESULT_DIED_XP, false, "Ataque", 0, 0,
        "Jugador", COMBAT_UNIT_TYPE_PLAYER, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
        1500, 0, 0, false, 1, 2001, 100
    )
    AssertEqual(q.currentCount, 1, "Duplicate death event for same targetUnitId is ignored")

    -- Muerte causada por otro jugador ajeno (sin grupo) no cuenta
    mockState.isGrouped = false
    EVENT_MANAGER:FireEvent(
        EVENT_COMBAT_EVENT,
        ACTION_RESULT_DIED, false, "Ataque", 0, 0,
        "Desconocido", COMBAT_UNIT_TYPE_OTHER, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
        1500, 0, 0, false, 99, 2002, 100
    )
    AssertEqual(q.currentCount, 1, "Unrelated player kill does not count")

    -- Muerte de miembro de grupo cuando NO se está en grupo no cuenta
    EVENT_MANAGER:FireEvent(
        EVENT_COMBAT_EVENT,
        ACTION_RESULT_DIED, false, "Ataque", 0, 0,
        "Compañero", COMBAT_UNIT_TYPE_GROUP, "Cultista de Gusano", COMBAT_UNIT_TYPE_OTHER,
        1500, 0, 0, false, 98, 2003, 100
    )
    AssertEqual(q.currentCount, 1, "Group unit kill ignored when solo")

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
-- 5. Tests de HudTracker, JournalTab y Ciclo de Vida EVENT_ADD_ON_LOADED
-- ============================================================================
RunTest("RPQuest Initialize via EVENT_ADD_ON_LOADED sets up Character SavedVars, JournalTab and HudTracker", function()
    mockState.language = "es"
    EVENT_MANAGER:FireEvent(EVENT_ADD_ON_LOADED, "RPQuest")

    AssertTrue(RPQuest.savedVars ~= nil, "Character SavedVars initialized")
    AssertTrue(RPQuest.JournalTab.isInitialized, "JournalTab initialized")
    AssertTrue(RPQuest.HudTracker.isInitialized, "HudTracker initialized")
    AssertTrue(RPQuest.JournalTab.isTabAdded, "Custom Quests tab registered in QUEST_JOURNAL_KEYBOARD.tabs")

    -- Sin misión activa, el HUD Tracker está oculto
    SCENE_MANAGER:Show("hud")
    RPQuest.HudTracker:Refresh()
    AssertTrue(RPQuest.HudTracker.panel:IsHidden(), "HudTracker hidden when no active quest")

    -- Crear una misión desde la UI del Editor en la pestaña del Diario
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

    local active = RPQuest.QuestRepository:GetActiveQuest()
    AssertTrue(active ~= nil, "Quest saved and set active from JournalTab")
    AssertEqual(active.title, "Cacería Nocturna", "Saved title matches")

    -- Con misión activa en escena HUD, el HudTracker se muestra con título y objetivo
    SCENE_MANAGER:Show("hud")
    RPQuest.HudTracker:Refresh()
    AssertEqual(RPQuest.HudTracker.panel:IsHidden(), false, "HudTracker shown for active quest")
    AssertEqual(RPQuest.HudTracker.titleLabel:GetText(), "Cacería Nocturna", "HudTracker title updated")

    -- Probar botón Compartir en JournalTab (genera código y lo selecciona en shareEdit)
    RPQuest.JournalTab:OnShareClicked()
    local generatedCode = RPQuest.JournalTab.shareEdit:GetText()
    AssertTrue(string.sub(generatedCode, 1, 5) == "RPQ1:", "Share edit box populated with RPQ1 code")
    AssertTrue(RPQuest.JournalTab.shareEdit._selectedAll, "Share edit box selected all text for Ctrl+C")

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
    AssertEqual(impQuest.requiredCount, 3, "Saved quest inferred requiredCount = 3 from reticle")

    -- Caso B: Apuntar a dos NPCs con nombre distinto -> ambos son objetivos exclusivos
    mockState.reticleName = "Lord Vane"
    RPQuest.TargetCapture:CaptureFromReticle()
    mockState.reticleName = "Lady Vane"
    local draftDuo = RPQuest.TargetCapture:CaptureFromReticle()
    AssertEqual(#draftDuo.targets, 2, "Two distinct named NPCs create 2 target entries")
    AssertEqual(RPQuest.QuestRepository:FormatTargetsSummary(draftDuo.targets), "Lord Vane, Lady Vane", "Summary lists both named NPCs")

    local duoQuest = RPQuest.QuestRepository:SaveDraft("Twin Assassination", "Eliminate both targets.")
    AssertEqual(#duoQuest.targets, 2, "Saved quest has 2 distinct targets")

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

RunTest("Bugfixes: DeleteQuest resets dangling draft, JournalTab scrolls >14 rows, HudTracker obeys scene fragment", function()
    RPQuest.QuestRepository:Initialize({})
    RPQuest.JournalTab:Initialize()
    RPQuest.HudTracker:Initialize()

    -- 1. DeleteQuest limpia editingQuestId si esa misión estaba en edición
    mockState.reticleExists = true
    mockState.reticleName = "Bandido"
    RPQuest.TargetCapture:CaptureFromReticle()
    local q1 = RPQuest.QuestRepository:SaveDraft("Misión Uno", "Desc", 0.05)
    RPQuest.JournalTab:OpenEditEditor(q1.id)
    AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, q1.id, "Draft editing q1")
    RPQuest.QuestRepository:DeleteQuest(q1.id)
    AssertEqual(RPQuest.QuestRepository:GetDraft().editingQuestId, nil, "DeleteQuest clears dangling editingQuestId")

    -- 2. HudTracker controlado por fragment según escena
    RPQuest.TargetCapture:CaptureFromReticle()
    local qHud = RPQuest.QuestRepository:SaveDraft("Misión HUD", "Desc", 0.05)
    SCENE_MANAGER:Show("hud")
    AssertEqual(RPQuest.HudTracker.panel:IsHidden(), false, "HudTracker visible on hud scene with active quest")
    SCENE_MANAGER:Show("questJournal")
    AssertEqual(RPQuest.HudTracker.panel:IsHidden(), true, "HudTracker hidden when non-HUD scene is active")
    SCENE_MANAGER:Show("hud")
    AssertEqual(RPQuest.HudTracker.panel:IsHidden(), false, "HudTracker visible again when returning to hud")
    RPQuest.QuestRepository:DeleteQuest(qHud.id)

    -- 3. JournalTab pagina/desplaza más allá de 14 filas
    for i = 1, 16 do
        RPQuest.TargetCapture:CaptureFromReticle()
        RPQuest.QuestRepository:SaveDraft("Quest #" .. tostring(i), "", 0.05)
    end
    RPQuest.JournalTab:Refresh()
    AssertEqual(RPQuest.JournalTab.btnListNext:IsHidden(), false, "Scroll Next button shown when > 14 rows")
    AssertEqual(RPQuest.JournalTab.listOffset, 0, "Initial listOffset is 0")
    RPQuest.JournalTab:ScrollQuestList(2)
    AssertEqual(RPQuest.JournalTab.listOffset, 2, "ScrollQuestList advances offset")
    AssertEqual(RPQuest.JournalTab.rowBindings[1].questId, 4, "First visible row reflects scrolled offset")
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

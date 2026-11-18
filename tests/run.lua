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
}

_G.RPQuestTestState = mockState

UNIT_REACTION_HOSTILE = 1
UNIT_REACTION_NEUTRAL = 2
UNIT_REACTION_FRIENDLY = 3
UNIT_REACTION_NPC_ALLY = 4
UNIT_REACTION_PLAYER_ALLY = 5

ACTION_RESULT_DIED = 2260
ACTION_RESULT_DIED_XP = 2262
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
    return MAPTYPE_ZONE
end

-- Load core modules under test
dofile("src/Constants.lua")
dofile("lang/en.lua")
dofile("lang/es.lua")
dofile("src/Locale.lua")
dofile("src/ShareCodec.lua")
dofile("src/QuestRepository.lua")

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

    -- 1. Capturar objetivo en borrador
    RPQuest.QuestRepository:SetDraftCapturedTarget({
        targetName = "Nigromante Oscuro^m",
        mapId = 32,
        zoneId = 381,
        mapName = "Auridon",
        targetX = 0.40,
        targetY = 0.60,
    })

    -- 2. Guardar misión con 2 bajas requeridas
    local quest, err = RPQuest.QuestRepository:SaveDraft("Purga en el Bosque", "Elimina a los nigromantes.", 2, 0.075)
    AssertTrue(quest ~= nil, "Quest should be created: " .. tostring(err))
    AssertEqual(quest.targetName, "Nigromante Oscuro", "Gender suffix stripped")
    AssertEqual(quest.requiredCount, 2, "Required count is 2")
    AssertEqual(RPQuest.QuestRepository:GetActiveQuest().id, quest.id, "Newly created quest becomes active")

    -- 3. Editar la misión
    RPQuest.QuestRepository:LoadQuestIntoDraft(quest.id)
    local updated = RPQuest.QuestRepository:SaveDraft("Purga Real en el Bosque", "Nueva descripción", 2, 0.075)
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

if failed > 0 then
    for _, f in ipairs(failures) do
        print(f)
    end
    print(string.format("FAILED: %d passed, %d failed", passed, failed))
    os.exit(1)
else
    print(string.format("OK: %d tests passed, 0 failed", passed))
end

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
MAIL_SEND_RESULT_CANCELED = 1
MAIL_SEND_RESULT_CANT_SEND_TO_SELF = 2
MAIL_SEND_RESULT_MAILBOX_NOT_OPEN = 11
MAIL_SEND_RESULT_RECIPIENT_NOT_FOUND = 15
GetDisplayName = GetDisplayName or function() return mockState.displayName or "@TestPlayer" end
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
MAPTYPE_SUBZONE = 4
ANIMATION_ALPHA = 1
ANIMATION_PLAYBACK_PING_PONG = 2
SET_MAP_RESULT_MAP_CHANGED = 1
SET_MAP_RESULT_CURRENT_MAP_UNCHANGED = 2
SET_MAP_RESULT_FAILED = 0
MENU_CATEGORY_MAP = 4
MOUSE_BUTTON_INDEX_LEFT = 1
MOUSE_BUTTON_INDEX_RIGHT = 2
TEXT_ALIGN_RIGHT = 2

ZO_PreHook = function(tbl, fnName, hookFn)
    local orig = tbl[fnName]
    tbl[fnName] = function(...)
        if hookFn(...) then return end
        if orig then return orig(...) end
    end
end

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

GetTimeStamp = function()
    return os.time()
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
WORLD_MAP_SCENE = ZO_Scene:New("worldMap", SCENE_MANAGER)
SCENE_MANAGER:AddScene(WORLD_MAP_SCENE)

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

ZO_MapPin = ZO_MapPin or {
    ASSISTED_PIN_TYPES = {},
    PulseAnimation = {
        texture = "EsoUI/Art/MapPins/UI-WorldMapPinHighlight.dds",
        duration = 6,
        type = 1,
    },
}
ZO_WorldMapPins_Manager = ZO_WorldMapPins_Manager or {
    IsCurrentMapGlobal = function() return false end,
}
ZO_WorldMap_IsNormalizedPointInsideMapBounds = ZO_WorldMap_IsNormalizedPointInsideMapBounds or function(x, y)
    return type(x) == "number" and type(y) == "number" and x > 0 and x < 1 and y > 0 and y < 1
end
GetNormalizedWorldPosition = GetNormalizedWorldPosition or function(zoneId, worldX, worldY, worldZ)
    if mockState.projectedPositions and mockState.projectedPositions[mockState.mapId] then
        local pos = mockState.projectedPositions[mockState.mapId]
        return pos.x, pos.y
    end
    return nil, nil
end
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
        if optionalPinType == nil then
            self._createdPins = {}
        else
            for i = #self._createdPins, 1, -1 do
                if self._createdPins[i].pinTypeId == optionalPinType then
                    table.remove(self._createdPins, i)
                end
            end
        end
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
            m_PinType = pinTypeId,
            m_PinTag = pinTag,
            x = xLoc,
            y = yLoc,
            radius = radius,
            pingAnimations = {},
            GetPinType = function(pinSelf)
                return pinSelf.m_PinType
            end,
            GetPinTypeAndTag = function(pinSelf)
                return pinSelf.m_PinType, pinSelf.m_PinTag
            end,
            PingMapPin = function(pinSelf, animation)
                table.insert(pinSelf.pingAnimations, animation)
            end,
        }
        if radius and radius > 0 then
            p.pinBlob = {
                alpha = 1,
                SetColor = function(blobSelf, r, g, b, a)
                    blobSelf.color = { r = r, g = g, b = b, a = a }
                end,
                SetAlpha = function(blobSelf, a)
                    blobSelf.alpha = a
                end,
                GetAlpha = function(blobSelf)
                    return blobSelf.alpha
                end,
            }
        end
        table.insert(self._createdPins, p)
        return p
    end,
    GetActiveObjects = function(self)
        return self._createdPins
    end,
    SimulateResize = function(self)
        for _, p in ipairs(self._createdPins) do
            if p.pinBlob and p.pinBlob.SetColor then
                p.pinBlob:SetColor(0.5, 0.8, 1.0, 1.0)
            end
        end
        for _, data in pairs(self._customPins) do
            if data.enabled and data.resizeCallback then
                data.resizeCallback(self, 1000, 1000)
            end
        end
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
    CreateControlFromVirtual = function(self, name, parent, templateName, optionalId)
        return CreateControlFromVirtual(name, parent, templateName, optionalId)
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
dofile("lang/de.lua")
dofile("lang/es.lua")
dofile("lang/fr.lua")
dofile("lang/jp.lua")
dofile("lang/ru.lua")
dofile("lang/zh.lua")
dofile("src/Locale.lua")
dofile("src/BinaryCodec.lua")
dofile("src/ShareCodec.lua")
dofile("src/QuestDraftStore.lua")
dofile("src/QuestMigration.lua")
dofile("src/QuestRepository.lua")
dofile("src/Announcements.lua")
dofile("src/TargetCapture.lua")
dofile("src/CombatTracker.lua")
dofile("src/DiscoveryTracker.lua")
dofile("src/DialogueInjector.lua")
dofile("src/WorldMapArea.lua")
dofile("src/MailInbox.lua")
dofile("src/MailTransport.lua")
dofile("src/JournalWidgets.lua")
dofile("src/JournalDetailPane.lua")
dofile("src/JournalEditorSections.lua")
dofile("src/JournalEditorPane.lua")
dofile("src/JournalMailSendPane.lua")
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
-- Execute Modular Domain Test Suites (tests/suites/*.lua)
-- ============================================================================
local testHarness = {
    RunTest = RunTest,
    AssertEqual = AssertEqual,
    AssertTrue = AssertTrue,
    mockState = mockState,
    mockPinManager = mockPinManager,
}

local suitePaths = {
    "tests/suites/locale.lua",
    "tests/suites/journal_ui.lua",
    "tests/suites/repository.lua",
    "tests/suites/trackers.lua",
    "tests/suites/codec.lua",
    "tests/suites/dialogue.lua",
    "tests/suites/mail_transport.lua",
    "tests/suites/mail_inbox.lua",
    "tests/suites/mail_lifecycle.lua",
}

for _, suitePath in ipairs(suitePaths) do
    local registerSuite = dofile(suitePath)
    registerSuite(testHarness)
end

if failed > 0 then
    for _, f in ipairs(failures) do
        print(f)
    end
    print(string.format("FAILED: %d passed, %d failed", passed, failed))
    os.exit(1)
else
    print(string.format("OK: %d tests passed, 0 failed", passed))
end

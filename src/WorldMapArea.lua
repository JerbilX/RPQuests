-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.WorldMapArea = {}
local WorldMapArea = Addon.WorldMapArea

local PIN_TYPE_STRING = Addon.Constants.UI.PIN_TYPE_STRING
local MAP_LISTENER_NAME = "RPQuest_WorldMapArea"

local function GetWorldMapPinManager()
    local fn = _G["ZO_WorldMap_GetPinManager"]
    if type(fn) == "function" then
        return fn()
    end
    return nil
end

local function PanWorldMapToNormalizedPosition(x, y)
    local fn = _G["ZO_WorldMap_PanToNormalizedPosition"]
    if type(fn) == "function" then
        fn(x, y)
    end
end

function WorldMapArea:Initialize()
    if self.isInitialized then return end

    local pinManager = GetWorldMapPinManager()
    if not pinManager or not pinManager.AddCustomPin then
        return
    end

    local pinLayoutData = {
        level = 115,
        size = 32,
        minAreaSize = 48,
        texture = "",
        showsPinAndArea = false,
    }

    local pinTooltipCreator = {
        creator = function(pin)
            local questId = pin and pin.m_PinTag
            local targetQuest = (questId and Addon.QuestRepository:GetQuestById(questId))
                or Addon.QuestRepository:GetActiveQuest()
            if not targetQuest then return end
            local tooltip = InformationTooltip
            if tooltip and tooltip.AddLine then
                local headerText = Addon.Locale:Get("MAP_TOOLTIP_HEADER", targetQuest.title or "")
                tooltip:AddLine(headerText, "ZoFontWinH4", 0.91, 0.83, 0.63)
                local targets = targetQuest.targets or {}
                for _, t in ipairs(targets) do
                    local objText = Addon.Locale:Get(
                        "MAP_TOOLTIP_OBJECTIVE",
                        t.name or "",
                        t.currentCount or 0,
                        t.requiredCount or 1
                    )
                    tooltip:AddLine(objText, "ZoFontGame", 1, 1, 1)
                end
            end
        end,
        tooltip = 1,
    }

    local layoutCallback = function(pManager)
        self:OnLayoutPins(pManager)
    end

    pinManager:AddCustomPin(PIN_TYPE_STRING, layoutCallback, nil, pinLayoutData, pinTooltipCreator)
    self.pinTypeId = _G[PIN_TYPE_STRING]

    if self.pinTypeId then
        pinManager:SetCustomPinEnabled(self.pinTypeId, true)
        if ZO_MapPin and ZO_MapPin.ASSISTED_PIN_TYPES then
            ZO_MapPin.ASSISTED_PIN_TYPES[self.pinTypeId] = true
        end
    end

    if CALLBACK_MANAGER and CALLBACK_MANAGER.RegisterCallback then
        CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
            self:RefreshPins()
        end)
    end

    if WORLD_MAP_SCENE and WORLD_MAP_SCENE.RegisterCallback then
        WORLD_MAP_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                self:RefreshPins()
            elseif newState == SCENE_HIDDEN then
                self.previewQuestId = nil
            end
        end)
    end

    if EVENT_MANAGER then
        if EVENT_PLAYER_ACTIVATED then
            EVENT_MANAGER:RegisterForEvent(MAP_LISTENER_NAME, EVENT_PLAYER_ACTIVATED, function()
                self:RefreshPins()
            end)
        end
        if EVENT_ZONE_CHANGED then
            EVENT_MANAGER:RegisterForEvent(MAP_LISTENER_NAME .. "_Zone", EVENT_ZONE_CHANGED, function()
                self:RefreshPins()
            end)
        end
    end

    Addon.QuestRepository:RegisterListener(function(eventType)
        if eventType ~= "DRAFT_UPDATED" and eventType ~= "DRAFT_TARGET_CAPTURED" then
            if eventType == "ACTIVE_QUEST_CHANGED" or eventType == "QUEST_DELETED" then
                self.previewQuestId = nil
            end
            self:RefreshPins()
        end
    end)

    self.isInitialized = true
    self:RefreshPins()
end

function WorldMapArea:ShouldRenderOnCurrentMap(quest)
    if not quest or quest.completed then
        return false
    end

    if not quest.mapId or quest.mapId <= 0 then
        return false
    end

    if not quest.areaCenterX or not quest.areaCenterY or not quest.areaRadius or quest.areaRadius <= 0 then
        return false
    end

    if ZO_WorldMapPins_Manager and ZO_WorldMapPins_Manager.IsCurrentMapGlobal and ZO_WorldMapPins_Manager.IsCurrentMapGlobal() then
        return false
    end

    if GetMapType then
        local mapType = GetMapType()
        if (MAPTYPE_WORLD and mapType == MAPTYPE_WORLD) or (MAPTYPE_COSMIC and mapType == MAPTYPE_COSMIC) then
            return false
        end
    end

    local currentMapId = GetCurrentMapId and GetCurrentMapId()
    if not currentMapId or currentMapId ~= quest.mapId then
        return false
    end

    return true
end

function WorldMapArea:OnLayoutPins(pinManager)
    local pManager = pinManager or GetWorldMapPinManager()
    if not pManager or not self.pinTypeId then return end

    local targetQuest = (self.previewQuestId and Addon.QuestRepository:GetQuestById(self.previewQuestId))
        or Addon.QuestRepository:GetActiveQuest()
    if not self:ShouldRenderOnCurrentMap(targetQuest) then
        return
    end

    pManager:CreatePin(
        self.pinTypeId,
        targetQuest.id,
        targetQuest.areaCenterX,
        targetQuest.areaCenterY,
        targetQuest.areaRadius
    )
end

function WorldMapArea:RefreshPins()
    local pinManager = GetWorldMapPinManager()
    if not pinManager or not pinManager.RefreshCustomPins then
        return
    end
    if self.pinTypeId then
        pinManager:RefreshCustomPins(self.pinTypeId)
    else
        pinManager:RefreshCustomPins()
    end
end

function WorldMapArea:ShowQuestOnMap(quest)
    local targetQuest = quest or Addon.QuestRepository:GetActiveQuest()
    if not targetQuest then return false end

    self.previewQuestId = targetQuest.id

    if MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.ShowCategory and MENU_CATEGORY_MAP then
        MAIN_MENU_KEYBOARD:ShowCategory(MENU_CATEGORY_MAP)
    elseif SCENE_MANAGER and SCENE_MANAGER.Show then
        SCENE_MANAGER:Show("worldMap")
    end

    local refreshedByCallback = false
    if SetMapToMapId and targetQuest.mapId and targetQuest.mapId > 0 then
        local res = SetMapToMapId(targetQuest.mapId)
        if res == SET_MAP_RESULT_MAP_CHANGED and CALLBACK_MANAGER and CALLBACK_MANAGER.FireCallbacks then
            CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
            refreshedByCallback = true
        end
    end

    if not refreshedByCallback then
        self:RefreshPins()
    end

    if targetQuest.areaCenterX and targetQuest.areaCenterY then
        PanWorldMapToNormalizedPosition(targetQuest.areaCenterX, targetQuest.areaCenterY)
    end

    return true
end

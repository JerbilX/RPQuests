-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.CombatTracker = {}
local CombatTracker = Addon.CombatTracker

local LISTENER_DIED = "RPQuest_CombatTracker_Died"
local LISTENER_DIED_XP = "RPQuest_CombatTracker_DiedXP"
local MAX_RECENT_KILLED_UNITS = 32

local function IsAllowedKillSource(sourceType)
    if sourceType == COMBAT_UNIT_TYPE_PLAYER
        or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
        or sourceType == COMBAT_UNIT_TYPE_PLAYER_COMPANION then
        return true
    end
    if sourceType == COMBAT_UNIT_TYPE_GROUP then
        return IsUnitGrouped ~= nil and IsUnitGrouped("player")
    end
    return false
end

local function RegisterDeathFilter(listenerName, expectedResult, callback)
    EVENT_MANAGER:UnregisterForEvent(listenerName, EVENT_COMBAT_EVENT)
    if not expectedResult then return end
    EVENT_MANAGER:RegisterForEvent(listenerName, EVENT_COMBAT_EVENT, callback)
    if EVENT_MANAGER.AddFilterForEvent then
        EVENT_MANAGER:AddFilterForEvent(listenerName, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, expectedResult)
        EVENT_MANAGER:AddFilterForEvent(listenerName, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
    end
end

function CombatTracker:UpdateRegistration()
    if not EVENT_MANAGER or not EVENT_COMBAT_EVENT then return end

    local hasActiveQuest = (Addon.QuestRepository:GetActiveQuest() ~= nil)
    if not hasActiveQuest then
        if self._isRegistered then
            EVENT_MANAGER:UnregisterForEvent(LISTENER_DIED, EVENT_COMBAT_EVENT)
            EVENT_MANAGER:UnregisterForEvent(LISTENER_DIED_XP, EVENT_COMBAT_EVENT)
            self._isRegistered = false
        end
        return
    end

    if self._isRegistered then return end

    self._combatHandler = self._combatHandler or function(...)
        self:OnCombatEvent(...)
    end
    RegisterDeathFilter(LISTENER_DIED, ACTION_RESULT_DIED, self._combatHandler)
    RegisterDeathFilter(LISTENER_DIED_XP, ACTION_RESULT_DIED_XP, self._combatHandler)
    self._isRegistered = true
end

function CombatTracker:Initialize()
    if not EVENT_MANAGER or not EVENT_COMBAT_EVENT then return end

    self._isRegistered = false
    self._recentKilledOrder = {}
    self._recentKilledSet = {}
    if not self._repoListenerAdded then
        Addon.QuestRepository:RegisterListener(function(eventType)
            if eventType ~= "DRAFT_UPDATED" and eventType ~= "DRAFT_TARGET_CAPTURED" and eventType ~= "QUEST_PROGRESS" then
                self:UpdateRegistration()
            end
        end)
        self._repoListenerAdded = true
    end

    self:UpdateRegistration()
end

function CombatTracker:MarkUnitKilled(targetUnitId)
    if not targetUnitId or targetUnitId <= 0 then return end
    self._recentKilledOrder = self._recentKilledOrder or {}
    self._recentKilledSet = self._recentKilledSet or {}
    if self._recentKilledSet[targetUnitId] then return end

    table.insert(self._recentKilledOrder, targetUnitId)
    self._recentKilledSet[targetUnitId] = true
    if #self._recentKilledOrder > MAX_RECENT_KILLED_UNITS then
        local oldest = table.remove(self._recentKilledOrder, 1)
        if oldest then
            self._recentKilledSet[oldest] = nil
        end
    end
end

function CombatTracker:OnCombatEvent(eventCode, result, isError, abilityName, abilityGraphic,
                                     abilityActionSlotType, sourceName, sourceType, targetName,
                                     targetType, hitValue, powerType, damageType, log,
                                     sourceUnitId, targetUnitId, abilityId)
    if isError then return end

    local isDeath = (ACTION_RESULT_DIED and result == ACTION_RESULT_DIED)
        or (ACTION_RESULT_DIED_XP and result == ACTION_RESULT_DIED_XP)

    if not isDeath then
        return
    end

    if not IsAllowedKillSource(sourceType) then
        return
    end

    if targetUnitId and targetUnitId > 0 and self._recentKilledSet and self._recentKilledSet[targetUnitId] then
        return
    end

    local activeQuest, matchedTarget = Addon.QuestRepository:FindPendingTarget(targetName)
    if not activeQuest or not matchedTarget then
        return
    end

    local playerContext = Addon.TargetCapture:GetPlayerMapContext()

    local recorded, updatedQuest, justCompleted, finalTarget = Addon.QuestRepository:RecordTargetEliminated(
        targetName, playerContext, activeQuest, matchedTarget
    )
    if not recorded or not updatedQuest then
        return
    end

    self:MarkUnitKilled(targetUnitId)

    if justCompleted then
        Addon.Announcements:AnnounceQuestCompleted(updatedQuest, finalTarget)
    else
        Addon.Announcements:AnnounceQuestProgress(updatedQuest, finalTarget)
    end
end

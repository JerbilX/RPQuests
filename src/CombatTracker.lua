-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.CombatTracker = {}
local CombatTracker = Addon.CombatTracker

local LISTENER_DIED = "RPQuest_CombatTracker_Died"
local LISTENER_DIED_XP = "RPQuest_CombatTracker_DiedXP"

local function RegisterDeathFilter(listenerName, expectedResult, callback)
    EVENT_MANAGER:UnregisterForEvent(listenerName, EVENT_COMBAT_EVENT)
    if not expectedResult then return end
    EVENT_MANAGER:RegisterForEvent(listenerName, EVENT_COMBAT_EVENT, function(eventCode, result, ...)
        if result ~= expectedResult then return end
        callback(eventCode, result, ...)
    end)
    if EVENT_MANAGER.AddFilterForEvent then
        if REGISTER_FILTER_COMBAT_RESULT then
            EVENT_MANAGER:AddFilterForEvent(listenerName, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, expectedResult)
        end
        if REGISTER_FILTER_IS_ERROR then
            EVENT_MANAGER:AddFilterForEvent(listenerName, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
        end
    end
end

function CombatTracker:UpdateRegistration()
    if not EVENT_MANAGER or not EVENT_COMBAT_EVENT then return end

    local hasActiveQuest = (Addon.QuestRepository and Addon.QuestRepository:GetActiveQuest() ~= nil)
    if not hasActiveQuest then
        if self._isRegistered then
            EVENT_MANAGER:UnregisterForEvent(LISTENER_DIED, EVENT_COMBAT_EVENT)
            EVENT_MANAGER:UnregisterForEvent(LISTENER_DIED_XP, EVENT_COMBAT_EVENT)
            self._isRegistered = false
        end
        return
    end

    if self._isRegistered then return end

    local handler = function(...)
        self:OnCombatEvent(...)
    end
    RegisterDeathFilter(LISTENER_DIED, ACTION_RESULT_DIED, handler)
    RegisterDeathFilter(LISTENER_DIED_XP, ACTION_RESULT_DIED_XP, handler)
    self._isRegistered = true
end

function CombatTracker:Initialize()
    if not EVENT_MANAGER or not EVENT_COMBAT_EVENT then return end

    self._isRegistered = false
    if Addon.QuestRepository and not self._repoListenerAdded then
        Addon.QuestRepository:RegisterListener(function()
            self:UpdateRegistration()
        end)
        self._repoListenerAdded = true
    end

    self:UpdateRegistration()
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

    if type(targetName) ~= "string" or targetName == "" then
        return
    end

    local activeQuest = Addon.QuestRepository and Addon.QuestRepository:GetActiveQuest()
    if not activeQuest or activeQuest.completed then
        return
    end

    local playerContext = nil
    if Addon.TargetCapture and Addon.TargetCapture.GetPlayerMapContext then
        playerContext = Addon.TargetCapture:GetPlayerMapContext()
    end

    local recorded, updatedQuest, justCompleted, matchedTarget = Addon.QuestRepository:RecordTargetEliminated(targetName, playerContext)
    if not recorded or not updatedQuest then
        return
    end

    if Addon.Announcements then
        if justCompleted then
            Addon.Announcements:AnnounceQuestCompleted(updatedQuest, matchedTarget)
        else
            Addon.Announcements:AnnounceQuestProgress(updatedQuest, matchedTarget)
        end
    end
end

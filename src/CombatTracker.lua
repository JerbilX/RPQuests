-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.CombatTracker = {}
local CombatTracker = Addon.CombatTracker

local LISTENER_NAME = "RPQuest_CombatTracker"

function CombatTracker:Initialize()
    if not EVENT_MANAGER or not EVENT_COMBAT_EVENT then return end

    EVENT_MANAGER:UnregisterForEvent(LISTENER_NAME, EVENT_COMBAT_EVENT)
    EVENT_MANAGER:RegisterForEvent(LISTENER_NAME, EVENT_COMBAT_EVENT, function(...)
        self:OnCombatEvent(...)
    end)
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

    local recorded, updatedQuest, justCompleted = Addon.QuestRepository:RecordTargetEliminated(targetName, playerContext)
    if not recorded or not updatedQuest then
        return
    end

    if Addon.Announcements then
        if justCompleted then
            Addon.Announcements:AnnounceQuestCompleted(updatedQuest)
        else
            Addon.Announcements:AnnounceQuestProgress(updatedQuest)
        end
    end
end

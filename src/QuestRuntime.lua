-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0014-areas-por-objetivo-mensajes-eliminacion-y-visibilidad-mapa.md
-- Ref: docs/adr/0018-ejes-de-victoria-modo-freeform-y-objetivos-requeridos.md
-- Ref: docs/adr/0019-protocolo-world-profile-rpqw1-y-sincronizacion-correo.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.QuestRuntime = {}
local QuestRuntime = Addon.QuestRuntime

function QuestRuntime:ComputeOffsetCenter(_repo, targetX, targetY, radius, randomAngle01, randomDist01)
    return Addon.WorldMapArea:ComputeOffsetCenter(targetX, targetY, radius, randomAngle01, randomDist01)
end

function QuestRuntime:SetLastInteractedNpc(repo, npcName, zoneId, poiIndex, masterPoiCompleted)
    local cleanName = repo:NormalizeName(npcName)
    if cleanName == "" then
        return nil
    end
    local pIdx = math.floor(tonumber(poiIndex) or 0)
    local pDone = nil
    if pIdx > 0 then
        pDone = (masterPoiCompleted == true)
    end
    repo._lastInteractedNpc = {
        name = cleanName,
        zoneId = math.floor(tonumber(zoneId) or 0),
        poiIndex = (pIdx > 0) and pIdx or nil,
        masterPoiCompleted = pDone,
    }
    repo:NotifyListeners("LAST_NPC_UPDATED", repo._lastInteractedNpc)
    return repo._lastInteractedNpc
end

function QuestRuntime:GetLastInteractedNpc(repo)
    return repo._lastInteractedNpc
end

function QuestRuntime:HasTargetLocation(_repo, target)
    return type(target) == "table" and target.worldX ~= nil and target.worldZ ~= nil
end

function QuestRuntime:HasQuestTargetLocation(repo, quest)
    if type(quest) ~= "table" or type(quest.targets) ~= "table" then
        return false
    end
    for _, target in ipairs(quest.targets) do
        if repo:HasTargetLocation(target) then
            return true
        end
    end
    return false
end

function QuestRuntime:HasQuestSearchAreas(_repo, quest)
    if type(quest) ~= "table" then
        return false
    end
    if type(quest.targets) == "table" then
        for _, target in ipairs(quest.targets) do
            if type(target) == "table" and target.areaCenterX and target.areaCenterY and target.areaRadius and target.areaRadius > 0 then
                return true
            end
        end
    end
    return quest.areaCenterX ~= nil and quest.areaCenterY ~= nil and quest.areaRadius ~= nil and quest.areaRadius > 0
end

function QuestRuntime:HasQuestDiscoveryPoints(_repo, quest)
    return type(quest) == "table" and type(quest.discoveries) == "table" and #quest.discoveries > 0
end

function QuestRuntime:SetQuestMapVisibility(repo, questId, key, enabled)
    if key ~= "showSearchAreas" and key ~= "showLocationAreas" and key ~= "showDiscoveryAreas" then
        return false
    end
    local quest = repo:GetQuestById(questId)
    if not quest then
        return false
    end
    quest[key] = (enabled == true)
    repo:NotifyListeners("QUEST_MAP_VISIBILITY_CHANGED", quest)
    return true
end

function QuestRuntime:IsPlayerInsideTargetLocation(_repo, target, playerZoneId, playerWorldX, playerWorldZ)
    return Addon.WorldMapArea:IsPlayerInsideTargetLocation(target, playerZoneId, playerWorldX, playerWorldZ)
end

function QuestRuntime:IsPlayerInsideQuestArea(_repo, quest, playerMapId, playerZoneId, playerX, playerY)
    return Addon.WorldMapArea:IsPlayerInsideQuestArea(quest, playerMapId, playerZoneId, playerX, playerY)
end

function QuestRuntime:FindPendingTarget(repo, rawTargetName, expectedIsPlayer)
    if type(rawTargetName) ~= "string" or rawTargetName == "" then
        return nil, nil
    end

    local activeQuest = repo:GetActiveQuest()
    if not activeQuest or activeQuest.completed or activeQuest.failed or not activeQuest.targets or #activeQuest.targets == 0 then
        return nil, nil
    end

    local cleanKilled = repo:NormalizeName(rawTargetName):lower()
    if cleanKilled == "" then
        return nil, nil
    end

    local cache = repo._activeTargetCache
    if not cache or cache.questId ~= activeQuest.id then
        local byLowerName = {}
        for _, entry in ipairs(activeQuest.targets or {}) do
            local key = (entry.name or ""):lower()
            if key ~= "" and not byLowerName[key] then
                byLowerName[key] = entry
            end
        end
        cache = {
            questId = activeQuest.id,
            byLowerName = byLowerName,
        }
        repo._activeTargetCache = cache
    end

    local matched = cache.byLowerName[cleanKilled]
    if matched and (matched.currentCount or 0) < (matched.requiredCount or 1) then
        if expectedIsPlayer == nil or (matched.isPlayer == true) == expectedIsPlayer then
            return activeQuest, matched
        end
    end

    return nil, nil
end

local function TrimText(val)
    if type(val) ~= "string" then
        return ""
    end
    return (val:gsub("^%s+", ""):gsub("%s+$", ""))
end

function QuestRuntime:RecordTargetEliminated(repo, rawTargetName, playerContext, preMatchedQuest, preMatchedTarget)
    local activeQuest, matchedTarget = preMatchedQuest, preMatchedTarget
    if not activeQuest or not matchedTarget then
        activeQuest, matchedTarget = repo:FindPendingTarget(rawTargetName)
    end
    if not activeQuest or not matchedTarget then
        return false, nil, false, nil
    end

    local hasTargetLoc = repo:HasTargetLocation(matchedTarget)
    local isLocRequired = hasTargetLoc and (matchedTarget.locationRequired == true)
    local customMsgToShow = nil
    local generalMsg = TrimText(matchedTarget.customMessage)

    if hasTargetLoc then
        local pZone = type(playerContext) == "table" and playerContext.worldZoneId or nil
        local pWX = type(playerContext) == "table" and playerContext.worldX or nil
        local pWZ = type(playerContext) == "table" and playerContext.worldZ or nil
        local inTargetLoc = repo:IsPlayerInsideTargetLocation(matchedTarget, pZone, pWX, pWZ)
        if inTargetLoc then
            local inLocMsg = TrimText(matchedTarget.customMessageInLocation)
            if inLocMsg ~= "" then
                customMsgToShow = inLocMsg
            elseif generalMsg ~= "" then
                customMsgToShow = generalMsg
            end
        else
            if isLocRequired then
                Addon.QuestLifecycle:FinalizeFailedQuest(repo, activeQuest)
                return false, activeQuest, false, matchedTarget, true, (generalMsg ~= "" and generalMsg or nil)
            elseif generalMsg ~= "" then
                customMsgToShow = generalMsg
            end
        end
    elseif generalMsg ~= "" then
        customMsgToShow = generalMsg
    end

    matchedTarget.currentCount = math.min(matchedTarget.requiredCount or 1, (matchedTarget.currentCount or 0) + 1)

    if repo:AreAllObjectivesCompleted(activeQuest) then
        local _, questFailed, failReason = Addon.QuestLifecycle:ResolveQuestCompletion(repo, activeQuest)
        if questFailed then
            return true, activeQuest, false, matchedTarget, true, failReason
        end
        return true, activeQuest, activeQuest.completed, matchedTarget, false, customMsgToShow
    end

    repo:NotifyListeners("QUEST_PROGRESS", activeQuest)
    return true, activeQuest, false, matchedTarget, false, customMsgToShow
end

function QuestRuntime:HasPendingDiscoveries(_repo, quest)
    if not quest or quest.completed or quest.failed or type(quest.discoveries) ~= "table" then
        return false
    end
    for _, d in ipairs(quest.discoveries) do
        if not d.discovered then
            return true
        end
    end
    return false
end

function QuestRuntime:MarkDiscoveryTriggered(repo, questId, discoveryIndex)
    local quest = repo:GetQuestById(questId)
    if not quest or quest.completed or quest.failed or type(quest.discoveries) ~= "table" then
        return false, nil, false, nil, false, nil
    end
    local point = quest.discoveries[discoveryIndex]
    if not point or point.discovered then
        return false, nil, false, nil, false, nil
    end

    point.discovered = true

    if repo:AreAllObjectivesCompleted(quest) then
        local _, questFailed, failReason = Addon.QuestLifecycle:ResolveQuestCompletion(repo, quest, "DISCOVERY_TRIGGERED")
        return true, quest, quest.completed, point, questFailed, failReason
    end

    repo:NotifyListeners("DISCOVERY_TRIGGERED", quest)
    return true, quest, false, point, false, nil
end

-- Ref: docs/adr/0018-ejes-de-victoria-modo-freeform-y-objetivos-requeridos.md
-- Ref: docs/adr/0019-protocolo-world-profile-rpqw1-y-sincronizacion-correo.md
function QuestRuntime:MarkDialogueTriggered(repo, questId, dialogueIndex)
    local quest = repo:GetQuestById(questId)
    if not quest or quest.completed or quest.failed or type(quest.dialogues) ~= "table" then
        return false, nil, false, nil, false, nil
    end
    local dialogue = quest.dialogues[dialogueIndex]
    if not dialogue or dialogue.executed then
        return false, nil, false, nil, false, nil
    end

    dialogue.executed = true

    if repo:AreAllObjectivesCompleted(quest) then
        local _, questFailed, failReason = Addon.QuestLifecycle:ResolveQuestCompletion(repo, quest)
        return true, quest, quest.completed, dialogue, questFailed, failReason
    end

    repo:NotifyListeners("QUEST_PROGRESS", quest)
    return true, quest, false, dialogue, false, nil
end

function QuestRuntime:RecordPlayerDetected(repo, playerContext)
    local activeQuest = repo:GetActiveQuest()
    local modes = Addon.Constants.STEALTH_MODE
    local stealthMode = activeQuest and activeQuest.stealthMode
    if not activeQuest or activeQuest.completed or activeQuest.failed or activeQuest.wasDetected then
        return false, nil, false
    end
    if stealthMode ~= modes.OPTIONAL and stealthMode ~= modes.REQUIRED then
        return false, nil, false
    end

    if type(playerContext) == "table" then
        local inArea = repo:IsPlayerInsideQuestArea(
            activeQuest,
            playerContext.mapId,
            playerContext.zoneId,
            playerContext.x,
            playerContext.y
        )
        if not inArea then
            return false, nil, false
        end
    end

    activeQuest.wasDetected = true
    if stealthMode == modes.REQUIRED then
        Addon.QuestLifecycle:FinalizeFailedQuest(repo, activeQuest)
        return true, activeQuest, true
    end

    repo:NotifyListeners("QUEST_DETECTED", activeQuest)
    return true, activeQuest, false
end

function QuestRuntime:FindDialogueForActiveQuest(repo, rawNpcName, zoneId)
    local activeQuest = repo:GetActiveQuest()
    if not activeQuest or activeQuest.completed or activeQuest.failed then
        return nil
    end

    local questClue = type(activeQuest.clue) == "string" and activeQuest.clue:gsub("^%s+", ""):gsub("%s+$", "") or ""

    local dialogues = activeQuest.dialogues
    if type(dialogues) ~= "table" or #dialogues == 0 then
        return nil
    end

    local cleanNpc = repo:NormalizeName(rawNpcName)
    if cleanNpc == "" then
        return nil
    end

    local lowerNpc = cleanNpc:lower()
    local z = math.floor(tonumber(zoneId) or 0)

    for idx, entry in ipairs(dialogues) do
        if type(entry) == "table" and type(entry.npcName) == "string" and entry.npcName ~= "" then
            local entryName = repo:NormalizeName(entry.npcName):lower()
            local entryZone = math.floor(tonumber(entry.zoneId) or 0)
            if entryName == lowerNpc and (entryZone == 0 or z == 0 or entryZone == z) then
                local entryClue = type(entry.clue) == "string" and entry.clue:gsub("^%s+", ""):gsub("%s+$", "") or ""
                local resolvedClue = (entryClue ~= "" and entryClue) or (entry.clue == nil and questClue) or ""
                if resolvedClue == "" then
                    return nil
                end
                return {
                    questId = activeQuest.id,
                    dialogueIndex = idx,
                    clue = resolvedClue,
                    npcName = entry.npcName,
                    zoneId = entryZone,
                    response = type(entry.response) == "string" and entry.response or "",
                    executed = (entry.executed == true),
                }
            end
        end
    end

    return nil
end

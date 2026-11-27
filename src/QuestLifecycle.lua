-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0015-separacion-ciclo-de-vida-y-estado-de-resolucion.md
-- Ref: docs/adr/0018-ejes-de-victoria-modo-freeform-y-objetivos-requeridos.md
-- Ref: docs/adr/0019-protocolo-world-profile-rpqw1-y-sincronizacion-correo.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.QuestLifecycle = {}
local QuestLifecycle = Addon.QuestLifecycle

local VALID_LIFECYCLE = {
    draft = true,
    sent = true,
    received = true,
}

local VALID_RESOLUTION = {
    accepted = true,
    rejected = true,
    completed = true,
    failed = true,
}

local function AreAllTargetsCompleted(targets)
    if type(targets) ~= "table" or #targets == 0 then
        return false
    end
    for _, t in ipairs(targets) do
        if (t.currentCount or 0) < (t.requiredCount or 1) then
            return false
        end
    end
    return true
end

local function HasOptionalTargets(targets)
    if type(targets) ~= "table" then
        return false
    end
    for _, t in ipairs(targets) do
        if t.optional == true then
            return true
        end
    end
    return false
end

local function AreMandatoryTargetsCompleted(targets)
    if type(targets) ~= "table" then
        return true, false, false
    end
    local hasMandatory = false
    local anyOptionalDone = false
    for _, t in ipairs(targets) do
        local done = (t.currentCount or 0) >= (t.requiredCount or 1)
        if t.optional == true then
            if done then
                anyOptionalDone = true
            end
        else
            hasMandatory = true
            if not done then
                return false, true, anyOptionalDone
            end
        end
    end
    return true, hasMandatory, anyOptionalDone
end

local function AreAllDiscoveriesCompleted(discoveries)
    if type(discoveries) ~= "table" or #discoveries == 0 then
        return false
    end
    for _, d in ipairs(discoveries) do
        if not d.discovered then
            return false
        end
    end
    return true
end

local function AreAllDialoguesExecuted(dialogues)
    if type(dialogues) ~= "table" or #dialogues == 0 then
        return false
    end
    for _, dlg in ipairs(dialogues) do
        if not dlg.executed then
            return false
        end
    end
    return true
end

local function CheckQuestTable(arg)
    return type(arg) == "table" and (
        arg.targets ~= nil
        or arg.discoveries ~= nil
        or arg.dialogues ~= nil
        or arg.id ~= nil
        or arg.title ~= nil
    )
end

-- Ref: docs/adr/0018-ejes-de-victoria-modo-freeform-y-objetivos-requeridos.md
-- Ref: docs/adr/0019-protocolo-world-profile-rpqw1-y-sincronizacion-correo.md
function QuestLifecycle:AreAllObjectivesCompleted(_repo, questOrTargets, discoveriesArg, dialoguesArg)
    local targets, discoveries, dialogues
    if discoveriesArg == nil and dialoguesArg == nil and CheckQuestTable(questOrTargets) then
        targets = questOrTargets.targets
        discoveries = questOrTargets.discoveries
        dialogues = questOrTargets.dialogues
    else
        targets = questOrTargets
        discoveries = discoveriesArg
        dialogues = dialoguesArg
    end

    local hasTargets = type(targets) == "table" and #targets > 0
    local hasDiscoveries = type(discoveries) == "table" and #discoveries > 0
    local hasDialogues = type(dialogues) == "table" and #dialogues > 0

    if not hasTargets and not hasDiscoveries then
        if hasDialogues then
            return AreAllDialoguesExecuted(dialogues)
        end
        return false
    end
    if hasTargets and not AreAllTargetsCompleted(targets) then
        return false
    end
    if hasDiscoveries and not AreAllDiscoveriesCompleted(discoveries) then
        return false
    end
    return true
end

-- Ref: docs/adr/0018-ejes-de-victoria-modo-freeform-y-objetivos-requeridos.md
-- Ref: docs/adr/0019-protocolo-world-profile-rpqw1-y-sincronizacion-correo.md
function QuestLifecycle:CanManuallyCompleteQuest(repo, quest)
    if not quest or quest.completed or quest.failed or repo:IsOfferedQuest(quest) then
        return false
    end
    local hasTargets = type(quest.targets) == "table" and #quest.targets > 0
    local hasDiscoveries = type(quest.discoveries) == "table" and #quest.discoveries > 0
    local hasDialogues = type(quest.dialogues) == "table" and #quest.dialogues > 0
    if not hasTargets and not hasDiscoveries and not hasDialogues then
        return true
    end
    if not HasOptionalTargets(quest.targets) then
        return false
    end
    if repo:AreAllObjectivesCompleted(quest) then
        return false
    end
    local mandatoryDone, hasMandatory, anyOptionalDone = AreMandatoryTargetsCompleted(quest.targets)
    if not mandatoryDone then
        return false
    end
    local allDiscoveriesDone = hasDiscoveries and AreAllDiscoveriesCompleted(quest.discoveries)
    if not hasMandatory and not allDiscoveriesDone and not anyOptionalDone then
        return false
    end
    return true
end

function QuestLifecycle:FinalizeCompletedQuest(repo, quest)
    quest.completed = true
    if repo:GetQuestLifecycle(quest) == Addon.Constants.QUEST_LIFECYCLE.RECEIVED then
        quest.resolution = Addon.Constants.QUEST_RESOLUTION.COMPLETED
    end
    if repo.savedVars.activeQuestId == quest.id then
        repo.savedVars.activeQuestId = nil
    end
    repo:InvalidateActiveTargetCache()
    if Addon.TutorialQuest then
        Addon.TutorialQuest:OnQuestResolved(repo, quest, Addon.Constants.QUEST_RESOLUTION.COMPLETED)
    end
end

function QuestLifecycle:FinalizeFailedQuest(repo, quest)
    quest.failed = true
    if repo:GetQuestLifecycle(quest) == Addon.Constants.QUEST_LIFECYCLE.RECEIVED then
        quest.resolution = Addon.Constants.QUEST_RESOLUTION.FAILED
    end
    if repo.savedVars and repo.savedVars.activeQuestId == quest.id then
        repo.savedVars.activeQuestId = nil
    end
    repo:InvalidateActiveTargetCache()
    repo:NotifyListeners("QUEST_FAILED", quest)
    if Addon.TutorialQuest then
        Addon.TutorialQuest:OnQuestResolved(repo, quest, Addon.Constants.QUEST_RESOLUTION.FAILED)
    end
end

local function FindMissedRequiredObjective(quest)
    if type(quest) ~= "table" then
        return nil, nil
    end
    if type(quest.discoveries) == "table" then
        for _, d in ipairs(quest.discoveries) do
            if type(d) == "table" and d.required == true and not d.discovered then
                return "discovery", Addon.Locale:Get("ALERT_QUEST_FAILED_REQUIRED_DISCOVERY")
            end
        end
    end
    if type(quest.dialogues) == "table" then
        for _, dlg in ipairs(quest.dialogues) do
            if type(dlg) == "table" and dlg.required == true and not dlg.executed then
                local npcLabel = (type(dlg.npcName) == "string" and dlg.npcName ~= "") and dlg.npcName or "NPC"
                return "dialogue", Addon.Locale:Get("ALERT_QUEST_FAILED_REQUIRED_DIALOGUE", npcLabel)
            end
        end
    end
    return nil, nil
end

function QuestLifecycle:ResolveQuestCompletion(repo, quest, preNotifyEvent)
    if preNotifyEvent then
        repo:NotifyListeners(preNotifyEvent, quest)
    end
    local missedKind, failReason = FindMissedRequiredObjective(quest)
    if missedKind then
        self:FinalizeFailedQuest(repo, quest)
        return false, true, failReason
    end
    self:FinalizeCompletedQuest(repo, quest)
    repo:NotifyListeners("QUEST_COMPLETED", quest)
    return true, false, nil
end

function QuestLifecycle:CompleteQuest(repo, questId)
    local quest = repo:GetQuestById(questId)
    if not repo:CanManuallyCompleteQuest(quest) then
        return false, nil, false, nil
    end
    local completedOk, questFailed, failReason = self:ResolveQuestCompletion(repo, quest)
    return completedOk, quest, questFailed, failReason
end

function QuestLifecycle:GetQuestLifecycle(_repo, quest)
    local lifecycles = Addon.Constants.QUEST_LIFECYCLE
    if type(quest) ~= "table" then
        return lifecycles.DRAFT
    end
    if VALID_LIFECYCLE[quest.lifecycle] then
        return quest.lifecycle
    end
    if quest.role == Addon.Constants.QUEST_ROLE.PREPARED then
        local hasSent = (type(quest.sentTo) == "string" and quest.sentTo ~= "")
            or type(quest.lastResult) == "table"
            or (type(quest.deliveries) == "table" and #quest.deliveries > 0)
        return hasSent and lifecycles.SENT or lifecycles.DRAFT
    end
    return lifecycles.RECEIVED
end

function QuestLifecycle:GetQuestResolution(repo, quest)
    if type(quest) ~= "table" then
        return nil, nil
    end
    local lifecycles = Addon.Constants.QUEST_LIFECYCLE
    local lifecycle = repo:GetQuestLifecycle(quest)
    if lifecycle == lifecycles.DRAFT then
        return nil, nil
    elseif lifecycle == lifecycles.SENT then
        local res = VALID_RESOLUTION[quest.resolution] and quest.resolution or nil
        if res ~= nil then
            return res, quest.lastResult
        end
        return nil, { recipient = quest.sentTo, sentAt = quest.sentAt }
    else
        local res = VALID_RESOLUTION[quest.resolution] and quest.resolution or nil
        return res, nil
    end
end

function QuestLifecycle:IsPreparedQuest(repo, quest)
    if type(quest) ~= "table" then
        return false
    end
    local lifecycle = repo:GetQuestLifecycle(quest)
    local lifecycles = Addon.Constants.QUEST_LIFECYCLE
    return lifecycle == lifecycles.DRAFT or lifecycle == lifecycles.SENT or quest.role == Addon.Constants.QUEST_ROLE.PREPARED
end

function QuestLifecycle:IsOfferedQuest(repo, quest)
    if type(quest) ~= "table" then
        return false
    end
    return repo:GetQuestLifecycle(quest) == Addon.Constants.QUEST_LIFECYCLE.RECEIVED
        and repo:GetQuestResolution(quest) == nil
end

function QuestLifecycle:AcceptOfferedQuest(repo, questId)
    local q = repo:GetQuestById(questId)
    if not q or not repo:IsOfferedQuest(q) then
        return false, nil
    end
    q.status = Addon.Constants.QUEST_STATUS.ACTIVE
    q.resolution = Addon.Constants.QUEST_RESOLUTION.ACCEPTED
    repo:SetActiveQuest(q.id)
    repo:NotifyListeners("QUEST_ACCEPTED", q)
    return true, q
end

function QuestLifecycle:RejectOfferedQuest(repo, questId)
    local q = repo:GetQuestById(questId)
    if not q or not repo:IsOfferedQuest(q) then
        return false, nil
    end
    q.resolution = Addon.Constants.QUEST_RESOLUTION.REJECTED
    if Addon.TutorialQuest then
        Addon.TutorialQuest:OnQuestResolved(repo, q, Addon.Constants.QUEST_RESOLUTION.REJECTED)
    end
    repo:DeleteQuest(q.id)
    repo:NotifyListeners("QUEST_REJECTED", q)
    return true, q
end

function QuestLifecycle:GetActiveQuest(repo)
    if not repo.savedVars or not repo.savedVars.activeQuestId then
        return nil
    end
    local q = repo:GetQuestById(repo.savedVars.activeQuestId)
    if q and not q.completed and not q.failed and not repo:IsOfferedQuest(q) then
        return q
    end
    return nil
end

function QuestLifecycle:HasPlayableObjectives(_repo, quest)
    return type(quest) == "table"
end

function QuestLifecycle:HasMissingDiscoveryMessage(_repo, quest)
    if type(quest) ~= "table" or type(quest.discoveries) ~= "table" or #quest.discoveries == 0 then
        return false
    end
    for _, d in ipairs(quest.discoveries) do
        local msg = type(d) == "table" and type(d.message) == "string"
            and d.message:gsub("^%s+", ""):gsub("%s+$", "")
            or ""
        if msg == "" then
            return true
        end
    end
    return false
end

function QuestLifecycle:SetActiveQuest(repo, questId)
    if questId == nil then
        repo.savedVars.activeQuestId = nil
        repo:InvalidateActiveTargetCache()
        repo:NotifyListeners("ACTIVE_QUEST_CHANGED", nil)
        return true
    end

    local q = repo:GetQuestById(questId)
    if not q or q.completed or q.failed or q.needsMigration or repo:IsOfferedQuest(q) then
        return false
    end
    if not repo:HasPlayableObjectives(q) then
        return false, "ERR_MISSING_TARGET"
    end
    if repo:HasMissingDiscoveryMessage(q) then
        return false, "ERR_DISCOVERY_MISSING_MSG"
    end

    repo.savedVars.activeQuestId = q.id
    repo:InvalidateActiveTargetCache()
    repo:NotifyListeners("ACTIVE_QUEST_CHANGED", q)
    return true
end

function QuestLifecycle:ResetQuest(repo, questId, options)
    local q = repo:GetQuestById(questId)
    if not q then return false end

    local shouldActivate = not (type(options) == "table" and options.activate == false)
    if shouldActivate and not repo:HasPlayableObjectives(q) then
        return false, "ERR_MISSING_TARGET"
    end
    if shouldActivate and repo:HasMissingDiscoveryMessage(q) then
        return false, "ERR_DISCOVERY_MISSING_MSG"
    end

    for _, t in ipairs(q.targets or {}) do
        t.currentCount = 0
    end
    for _, d in ipairs(q.discoveries or {}) do
        d.discovered = false
    end
    for _, dlg in ipairs(q.dialogues or {}) do
        dlg.executed = false
    end
    q.completed = false
    q.failed = false
    q.wasDetected = false
    q.completionReported = false
    q.failureReported = false
    if repo:GetQuestLifecycle(q) == Addon.Constants.QUEST_LIFECYCLE.RECEIVED and not repo:IsOfferedQuest(q) then
        q.resolution = Addon.Constants.QUEST_RESOLUTION.ACCEPTED
    end
    if repo._completionCodeCache then
        repo._completionCodeCache[questId] = nil
    end

    local wasActive = (repo.savedVars.activeQuestId == q.id)
    if shouldActivate then
        repo.savedVars.activeQuestId = q.id
    elseif wasActive then
        repo.savedVars.activeQuestId = nil
    end

    repo:InvalidateActiveTargetCache()
    repo:NotifyListeners("QUEST_RESET", q)
    if not shouldActivate and wasActive then
        repo:NotifyListeners("ACTIVE_QUEST_CHANGED", nil)
    end
    return true
end

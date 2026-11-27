-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0013-protocolo-versionado-de-esquema-y-migraciones-de-misiones.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0012-savedvars-account-wide-y-migracion-por-personaje.md
-- Ref: docs/adr/0014-areas-por-objetivo-mensajes-eliminacion-y-visibilidad-mapa.md
-- Ref: docs/adr/0015-separacion-ciclo-de-vida-y-estado-de-resolucion.md
-- Ref: docs/adr/0018-ejes-de-victoria-modo-freeform-y-objetivos-requeridos.md
-- Ref: docs/adr/0019-protocolo-world-profile-rpqw1-y-sincronizacion-correo.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.QuestRepository = {}
local QuestRepository = Addon.QuestRepository

local function BindDelegates(targetModule, methodNames)
    for _, methodName in ipairs(methodNames) do
        QuestRepository[methodName] = function(self, ...)
            return targetModule[methodName](targetModule, self, ...)
        end
    end
end

function QuestRepository:GetDefaults()
    return {
        nextId = 1,
        activeQuestId = nil,
        quests = {},
        ingestedMailIds = {},
        migratedCharacterIds = {},
        worldProfiles = {},
        draft = Addon.QuestDraftStore:CreateDefaultDraft(),
        settings = {
            autoDeleteMail = true,
            autoAcceptMail = false,
            autoOpenJournalOnReceive = true,
            autoSendCompletionMail = true,
            showSearchAreas = false,
            showLocationAreas = false,
            showDiscoveryAreas = false,
        },
        uiState = {
            lastSectionKey = nil,
            lastSelectedQuestId = nil,
        },
        tutorialState = {
            steps = {},
        },
    }
end

function QuestRepository:MigrateCharacterSavedVars(rawRoot, displayName, savedVars, currentCharId)
    return Addon.QuestMigration:MigrateCharacterSavedVars(rawRoot, displayName, savedVars, currentCharId)
end

function QuestRepository:Initialize(savedVars)
    self.savedVars = savedVars or self:GetDefaults()
    self.savedVars.nextId = self.savedVars.nextId or 1
    self.savedVars.quests = self.savedVars.quests or {}
    self.savedVars.ingestedMailIds = self.savedVars.ingestedMailIds or {}
    self.savedVars.worldProfiles = self.savedVars.worldProfiles or {}
    if type(self.savedVars.settings) ~= "table" then
        self.savedVars.settings = {}
    end
    local defaultSettings = {
        autoDeleteMail = true,
        autoAcceptMail = false,
        autoOpenJournalOnReceive = true,
        autoSendCompletionMail = true,
        showSearchAreas = false,
        showLocationAreas = false,
        showDiscoveryAreas = false,
    }
    for k, v in pairs(defaultSettings) do
        if self.savedVars.settings[k] == nil then
            self.savedVars.settings[k] = v
        end
    end
    self.savedVars.draft = Addon.QuestDraftStore:EnsureDraft(self.savedVars.draft)
    self._questById = {}
    self._shareCodeCache = {}
    self._completionCodeCache = {}
    self._activeTargetCache = nil
    local roles = Addon.Constants.QUEST_ROLE
    if Addon.QuestMigration then
        Addon.QuestMigration:MigrateQuestList(self.savedVars.quests)
    end
    for _, q in ipairs(self.savedVars.quests) do
        q.targets = q.targets or {}
        if q.role ~= roles.PREPARED and q.role ~= roles.RECEIVED then
            q.role = roles.RECEIVED
        end
        if q.id then
            self._questById[q.id] = q
        end
    end
    if Addon.TutorialQuest then
        Addon.TutorialQuest:InitializeForRepository(self)
    end
    if self.savedVars.activeQuestId then
        local active = self._questById[self.savedVars.activeQuestId]
        if not active or active.needsMigration then
            self.savedVars.activeQuestId = nil
        end
    end
    if type(self.savedVars.uiState) ~= "table" then
        self.savedVars.uiState = {}
    end
    if self.savedVars.uiState.lastSectionKey ~= nil and type(self.savedVars.uiState.lastSectionKey) ~= "string" then
        self.savedVars.uiState.lastSectionKey = nil
    end
    if self.savedVars.uiState.lastSelectedQuestId and not self._questById[self.savedVars.uiState.lastSelectedQuestId] then
        self.savedVars.uiState.lastSelectedQuestId = nil
    end
    self._listeners = self._listeners or {}
end

function QuestRepository:InvalidateActiveTargetCache()
    self._activeTargetCache = nil
end

function QuestRepository:RegisterListener(callback)
    self._listeners = self._listeners or {}
    table.insert(self._listeners, callback)
end

function QuestRepository:NotifyListeners(eventType, quest)
    if not self._listeners then return end
    for _, cb in ipairs(self._listeners) do
        cb(eventType, quest)
    end
end

BindDelegates(Addon.QuestDraftStore, {
    "GetDraft", "ResetDraft", "ClearDraftTargets", "AddDraftDiscoveryPoint",
    "ClearDraftDiscoveries", "UpdateDraftDiscoveryPoint", "RemoveDraftDiscoveryPoint", "MoveDraftDiscoveryPoint",
    "AddDraftDialogue", "AddDraftDialogueFromLastNpc", "UpdateDraftDialogue",
    "RemoveDraftDialogue", "ClearDraftDialogues", "LoadQuestIntoDraft",
    "UpdateDraftFields", "SetDraftCapturedTarget", "SaveDraft",
    "CreateNewPreparedDraft", "CommitDraftChanges",
    "UpdateDraftTarget", "RemoveDraftTarget", "CaptureDraftTargetLocation", "ClearDraftTargetLocation",
})

BindDelegates(Addon.QuestRecord, {
    "NormalizeName", "NormalizeAccountName", "NormalizeCharacterName",
    "GetPlayerCharacterName", "GetAccountCharacterNames",
    "FormatTargetEntry", "FormatTargetsSummary",
    "BuildQuestRecord", "DuplicateQuest", "MigratePreparedQuest",
})

BindDelegates(Addon.QuestLifecycle, {
    "AreAllObjectivesCompleted", "CanManuallyCompleteQuest", "CompleteQuest",
    "GetQuestLifecycle", "GetQuestResolution", "IsPreparedQuest", "IsOfferedQuest",
    "AcceptOfferedQuest", "RejectOfferedQuest",
    "GetActiveQuest", "HasPlayableObjectives", "HasMissingDiscoveryMessage",
    "SetActiveQuest", "ResetQuest",
})

BindDelegates(Addon.QuestExchange, {
    "HasIngestedMail", "FindAlreadyIngestedQuest", "NormalizeImportedTargets",
    "ApplyImportedSenderMetadata", "FinalizeImportedQuest", "ImportQuestFromCode",
    "ExportQuestToCode", "ExportCompletionCode", "ExportRejectionCode",
    "ExportAcceptanceCode", "ExportFailureCode", "ValidateResultCode",
    "RecordMailDelivery", "MarkPreparedQuestSent",
    "MarkCompletionReported", "MarkFailureReported",
    "SaveWorldProfile", "GetWorldProfile",
})

BindDelegates(Addon.QuestRuntime, {
    "ComputeOffsetCenter", "SetLastInteractedNpc", "GetLastInteractedNpc",
    "HasTargetLocation", "HasQuestTargetLocation", "HasQuestSearchAreas",
    "HasQuestDiscoveryPoints", "SetQuestMapVisibility",
    "IsPlayerInsideTargetLocation", "IsPlayerInsideQuestArea",
    "FindPendingTarget", "RecordTargetEliminated",
    "HasPendingDiscoveries", "MarkDiscoveryTriggered", "MarkDialogueTriggered",
    "RecordPlayerDetected", "FindDialogueForActiveQuest",
})

function QuestRepository:GetSetting(key)
    if not self.savedVars or type(self.savedVars.settings) ~= "table" then
        return nil
    end
    return self.savedVars.settings[key]
end

function QuestRepository:SetSetting(key, value)
    if not self.savedVars then return end
    if type(self.savedVars.settings) ~= "table" then
        self.savedVars.settings = {}
    end
    self.savedVars.settings[key] = value
    self:NotifyListeners("SETTINGS_UPDATED", self.savedVars.settings)
end

function QuestRepository:GetJournalUiState()
    if not self.savedVars then
        return { lastSectionKey = nil, lastSelectedQuestId = nil }
    end
    if type(self.savedVars.uiState) ~= "table" then
        self.savedVars.uiState = { lastSectionKey = nil, lastSelectedQuestId = nil }
    end
    return self.savedVars.uiState
end

function QuestRepository:SetLastSectionKey(sectionKey)
    local uiState = self:GetJournalUiState()
    uiState.lastSectionKey = sectionKey
end

function QuestRepository:SetLastSelectedQuestId(questId)
    local uiState = self:GetJournalUiState()
    uiState.lastSelectedQuestId = questId
end

function QuestRepository:GetAllQuests()
    if not self.savedVars then return {} end
    return self.savedVars.quests or {}
end

local function FilterQuests(self, predicate)
    local result = {}
    for _, q in ipairs(self:GetAllQuests()) do
        if predicate(q) then
            table.insert(result, q)
        end
    end
    return result
end

function QuestRepository:GetQuestsByRole(role)
    return FilterQuests(self, function(q) return q.role == role end)
end

function QuestRepository:GetCompletedQuests()
    return FilterQuests(self, function(q) return q.completed end)
end

function QuestRepository:GetQuestById(questId)
    if not questId then return nil end
    if self._questById and self._questById[questId] then
        return self._questById[questId]
    end
    for _, q in ipairs(self:GetAllQuests()) do
        if q.id == questId then
            if self._questById then
                self._questById[questId] = q
            end
            return q
        end
    end
    return nil
end

function QuestRepository:DeleteQuest(questId)
    if not self.savedVars or not questId then return false end
    for i, q in ipairs(self.savedVars.quests) do
        if q.id == questId then
            local wasActive = (self.savedVars.activeQuestId == questId)
            table.remove(self.savedVars.quests, i)
            if self._questById then
                self._questById[questId] = nil
            end
            if self._shareCodeCache then
                self._shareCodeCache[questId] = nil
            end
            if self._completionCodeCache then
                self._completionCodeCache[questId] = nil
            end
            if self.savedVars.draft and self.savedVars.draft.editingQuestId == questId then
                self:ResetDraft()
            end
            if self.savedVars.uiState and self.savedVars.uiState.lastSelectedQuestId == questId then
                self.savedVars.uiState.lastSelectedQuestId = nil
            end
            if wasActive then
                self.savedVars.activeQuestId = nil
                self:InvalidateActiveTargetCache()
                for _, cand in ipairs(self.savedVars.quests) do
                    if not cand.completed then
                        self.savedVars.activeQuestId = cand.id
                        break
                    end
                end
            end
            if q.isTutorial == true and Addon.TutorialQuest then
                Addon.TutorialQuest:OnQuestResolved(self, q, q.resolution or "deleted")
            end
            self:NotifyListeners("QUEST_DELETED", q)
            return true
        end
    end
    return false
end

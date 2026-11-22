-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.QuestRepository = {}
local QuestRepository = Addon.QuestRepository

local function Clamp(val, minVal, maxVal)
    if val < minVal then return minVal end
    if val > maxVal then return maxVal end
    return val
end

function QuestRepository:NormalizeName(name)
    if type(name) ~= "string" or name == "" then return "" end
    local clean = zo_strformat("<<C:1>>", (name:gsub("%^%a+$", "")))
    clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
    return clean
end

function QuestRepository:NormalizeAccountName(raw)
    if type(raw) ~= "string" then return "" end
    local clean = raw:gsub("^%s+", ""):gsub("%s+$", "")
    if clean == "" then return "" end
    if clean:sub(1, 1) ~= "@" then
        clean = "@" .. clean
    end
    return clean
end

function QuestRepository:FormatTargetEntry(target)
    if type(target) ~= "table" or not target.name or target.name == "" then
        return ""
    end
    local req = math.max(1, math.floor(tonumber(target.requiredCount) or 1))
    if req > 1 then
        return string.format("%s x%d", target.name, req)
    end
    return target.name
end

function QuestRepository:FormatTargetsSummary(targets)
    if type(targets) ~= "table" or #targets == 0 then
        return ""
    end
    local parts = {}
    for _, t in ipairs(targets) do
        local formatted = self:FormatTargetEntry(t)
        if formatted ~= "" then
            table.insert(parts, formatted)
        end
    end
    return table.concat(parts, ", ")
end

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

function QuestRepository:AreAllObjectivesCompleted(targets, discoveries)
    local hasTargets = type(targets) == "table" and #targets > 0
    local hasDiscoveries = type(discoveries) == "table" and #discoveries > 0
    if not hasTargets and not hasDiscoveries then
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

function QuestRepository:BuildQuestRecord(id, title, description, targets, data, role)
    return {
        id = id,
        title = title,
        description = description,
        clue = type(data.clue) == "string" and data.clue or "",
        completionMessage = data.completionMessage or "",
        targets = targets,
        discoveries = data.discoveries or {},
        dialogues = Addon.QuestDraftStore:CloneDialoguesList(data.dialogues, data.clue),
        completed = false,
        role = role or Addon.Constants.QUEST_ROLE.RECEIVED,
        mapId = data.mapId or 0,
        zoneId = data.zoneId or 0,
        mapName = data.mapName or "",
        targetX = data.targetX,
        targetY = data.targetY,
        areaCenterX = data.areaCenterX,
        areaCenterY = data.areaCenterY,
        areaRadius = data.areaRadius,
        hideMapArea = data.hideMapArea and true or false,
        requireUndetected = data.requireUndetected and true or false,
        wasDetected = false,
        failed = false,
        senderDisplayName = type(data.senderDisplayName) == "string" and data.senderDisplayName or nil,
        recipientAccount = self:NormalizeAccountName(data.recipientAccount),
        sentTo = type(data.sentTo) == "string" and data.sentTo or nil,
        sentAt = data.sentAt,
        lastResult = type(data.lastResult) == "table" and data.lastResult or nil,
        status = data.status,
        sourceMailId = data.sourceMailId,
        completionReported = (data.completionReported == true),
        deliveries = type(data.deliveries) == "table" and data.deliveries or {},
    }
end

function QuestRepository:GetDefaults()
    return {
        nextId = 1,
        activeQuestId = nil,
        quests = {},
        ingestedMailIds = {},
        draft = Addon.QuestDraftStore:CreateDefaultDraft(),
        settings = {
            autoDeleteMail = true,
            autoAcceptMail = false,
            autoSendCompletionMail = true,
        },
    }
end

function QuestRepository:Initialize(savedVars)
    self.savedVars = savedVars or self:GetDefaults()
    self.savedVars.nextId = self.savedVars.nextId or 1
    self.savedVars.quests = self.savedVars.quests or {}
    self.savedVars.ingestedMailIds = self.savedVars.ingestedMailIds or {}
    if type(self.savedVars.settings) ~= "table" then
        self.savedVars.settings = { autoDeleteMail = true, autoAcceptMail = false, autoSendCompletionMail = true }
    else
        if self.savedVars.settings.autoDeleteMail == nil then
            self.savedVars.settings.autoDeleteMail = true
        end
        if self.savedVars.settings.autoAcceptMail == nil then
            self.savedVars.settings.autoAcceptMail = false
        end
        if self.savedVars.settings.autoSendCompletionMail == nil then
            self.savedVars.settings.autoSendCompletionMail = true
        end
    end
    self.savedVars.draft = Addon.QuestDraftStore:EnsureDraft(self.savedVars.draft)
    self._questById = {}
    self._shareCodeCache = {}
    self._completionCodeCache = {}
    self._activeTargetCache = nil
    local roles = Addon.Constants.QUEST_ROLE
    for _, q in ipairs(self.savedVars.quests) do
        q.targets = q.targets or {}
        if q.role ~= roles.PREPARED and q.role ~= roles.RECEIVED then
            q.role = roles.RECEIVED
        end
        if q.id then
            self._questById[q.id] = q
        end
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

-- Calcula un centro desplazado aleatorio para que (targetX, targetY) quede
-- garantizadamente dentro del círculo de radio `radius`, pero no en su centro exacto.
function QuestRepository:ComputeOffsetCenter(targetX, targetY, radius, randomAngle01, randomDist01)
    local r = tonumber(radius) or 0.075
    if r <= 0 then r = 0.075 end

    local tx = Clamp(tonumber(targetX) or 0.5, 0.01, 0.99)
    local ty = Clamp(tonumber(targetY) or 0.5, 0.01, 0.99)

    local minRatio = Addon.Constants.AREA_OFFSET.MIN_RATIO
    local maxRatio = Addon.Constants.AREA_OFFSET.MAX_RATIO

    local uAngle = (randomAngle01 ~= nil) and randomAngle01 or math.random()
    local uDist = (randomDist01 ~= nil) and randomDist01 or math.random()

    local angle = uAngle * 2 * math.pi
    local dist = (minRatio + (uDist * (maxRatio - minRatio))) * r

    local cx = tx + (dist * math.cos(angle))
    local cy = ty + (dist * math.sin(angle))

    local minBound = math.max(0.02, r * 0.5)
    local maxBound = math.min(0.98, 1.0 - (r * 0.5))

    cx = Clamp(cx, minBound, maxBound)
    cy = Clamp(cy, minBound, maxBound)

    -- Garantizar matemáticamente que la distancia entre (tx, ty) y (cx, cy) sea <= 0.80 * r
    local dx = tx - cx
    local dy = ty - cy
    local actualDist = math.sqrt((dx * dx) + (dy * dy))
    local maxAllowedDist = r * 0.80
    if actualDist > maxAllowedDist and actualDist > 0 then
        local scale = maxAllowedDist / actualDist
        cx = tx - (dx * scale)
        cy = ty - (dy * scale)
    end

    return cx, cy
end

function QuestRepository:GetDraft()
    return Addon.QuestDraftStore:GetDraft(self)
end

function QuestRepository:ResetDraft()
    return Addon.QuestDraftStore:ResetDraft(self)
end

function QuestRepository:ClearDraftTargets()
    return Addon.QuestDraftStore:ClearDraftTargets(self)
end

function QuestRepository:AddDraftDiscoveryPoint(data)
    return Addon.QuestDraftStore:AddDraftDiscoveryPoint(self, data)
end

function QuestRepository:ClearDraftDiscoveries()
    return Addon.QuestDraftStore:ClearDraftDiscoveries(self)
end

function QuestRepository:UpdateDraftDiscoveryPoint(index, fields, silent)
    return Addon.QuestDraftStore:UpdateDraftDiscoveryPoint(self, index, fields, silent)
end

function QuestRepository:RemoveDraftDiscoveryPoint(index)
    return Addon.QuestDraftStore:RemoveDraftDiscoveryPoint(self, index)
end

function QuestRepository:SetLastInteractedNpc(npcName, zoneId)
    local cleanName = self:NormalizeName(npcName)
    if cleanName == "" then
        return nil
    end
    self._lastInteractedNpc = {
        name = cleanName,
        zoneId = math.floor(tonumber(zoneId) or 0),
    }
    self:NotifyListeners("LAST_NPC_UPDATED", self._lastInteractedNpc)
    return self._lastInteractedNpc
end

function QuestRepository:GetLastInteractedNpc()
    return self._lastInteractedNpc
end

function QuestRepository:AddDraftDialogue(npcName, zoneId, responseText, clueText)
    return Addon.QuestDraftStore:AddDraftDialogue(self, npcName, zoneId, responseText, clueText)
end

function QuestRepository:AddDraftDialogueFromLastNpc(responseText, clueText)
    return Addon.QuestDraftStore:AddDraftDialogueFromLastNpc(self, responseText, clueText)
end

function QuestRepository:UpdateDraftDialogue(index, fields, silent)
    return Addon.QuestDraftStore:UpdateDraftDialogue(self, index, fields, silent)
end

function QuestRepository:RemoveDraftDialogue(index)
    return Addon.QuestDraftStore:RemoveDraftDialogue(self, index)
end

function QuestRepository:ClearDraftDialogues()
    return Addon.QuestDraftStore:ClearDraftDialogues(self)
end

function QuestRepository:LoadQuestIntoDraft(questId)
    return Addon.QuestDraftStore:LoadQuestIntoDraft(self, questId)
end

function QuestRepository:UpdateDraftFields(fields, silent)
    return Addon.QuestDraftStore:UpdateDraftFields(self, fields, silent)
end

function QuestRepository:SetDraftCapturedTarget(captureData)
    return Addon.QuestDraftStore:SetDraftCapturedTarget(self, captureData)
end

function QuestRepository:SaveDraft(titleInput, descriptionInput, areaRadiusInput, completionMessageInput, requireUndetectedInput, recipientAccountInput)
    return Addon.QuestDraftStore:SaveDraft(
        self,
        titleInput,
        descriptionInput,
        areaRadiusInput,
        completionMessageInput,
        requireUndetectedInput,
        recipientAccountInput
    )
end

function QuestRepository:IsOfferedQuest(quest)
    return quest ~= nil and quest.status == Addon.Constants.QUEST_STATUS.OFFERED
end

function QuestRepository:HasIngestedMail(mailKey)
    if type(mailKey) ~= "string" or mailKey == "" then
        return false
    end
    if self.savedVars and self.savedVars.ingestedMailIds and self.savedVars.ingestedMailIds[mailKey] then
        return true
    end
    for _, q in ipairs((self.savedVars and self.savedVars.quests) or {}) do
        if q.sourceMailId == mailKey then
            return true
        end
    end
    return false
end

function QuestRepository:ImportQuestFromCode(codeString, senderDisplayName, options)
    options = type(options) == "table" and options or {}
    if type(options.sourceMailId) == "string" and options.sourceMailId ~= "" then
        if self:HasIngestedMail(options.sourceMailId) then
            for _, q in ipairs(self.savedVars.quests or {}) do
                if q.sourceMailId == options.sourceMailId then
                    return q, nil, true
                end
            end
            return nil, nil, true
        end
    end

    local decoded, errKey = Addon.ShareCodec:DecodeQuest(codeString)
    if not decoded then
        return nil, Addon.Locale:Get(type(errKey) == "string" and errKey or "ERR_INVALID_CODE")
    end

    local newId = self.savedVars.nextId
    self.savedVars.nextId = newId + 1

    local cleanTitle = (decoded.title or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cleanTitle == "" then
        cleanTitle = Addon.Locale:Get("DEFAULT_QUEST_TITLE", newId)
    end

    local importedTargets = {}
    for _, t in ipairs(decoded.targets or {}) do
        local cleanTName = self:NormalizeName(t.name)
        if cleanTName ~= "" then
            local hasLoc = (t.worldX ~= nil and t.worldZ ~= nil)
            local defaultRad = Addon.Constants.DISCOVERY_RADIUS.MEDIUM
            table.insert(importedTargets, {
                name = cleanTName,
                currentCount = 0,
                requiredCount = math.max(1, math.floor(tonumber(t.requiredCount) or 1)),
                targetX = decoded.targetX,
                targetY = decoded.targetY,
                zoneId = hasLoc and math.floor(tonumber(t.zoneId) or 0) or nil,
                worldX = hasLoc and tonumber(t.worldX) or nil,
                worldZ = hasLoc and tonumber(t.worldZ) or nil,
                radius = hasLoc and math.max(100, math.floor(tonumber(t.radius) or defaultRad)) or nil,
                locationRequired = (t.locationRequired == true),
                customMessage = type(t.customMessage) == "string" and t.customMessage or "",
            })
        end
    end

    decoded.discoveries = Addon.QuestDraftStore:CloneDiscoveriesList(decoded.discoveries, false)
    decoded.dialogues = Addon.QuestDraftStore:CloneDialoguesList(decoded.dialogues, decoded.clue)
    local cleanSender = self:NormalizeAccountName(senderDisplayName)
    if cleanSender ~= "" then
        decoded.senderDisplayName = cleanSender
    end
    decoded.status = options.status or Addon.Constants.QUEST_STATUS.ACTIVE
    decoded.sourceMailId = options.sourceMailId

    local importedQuest = self:BuildQuestRecord(
        newId,
        cleanTitle,
        decoded.description or "",
        importedTargets,
        decoded,
        Addon.Constants.QUEST_ROLE.RECEIVED
    )

    table.insert(self.savedVars.quests, importedQuest)
    if self._questById then
        self._questById[importedQuest.id] = importedQuest
    end
    if type(options.sourceMailId) == "string" and options.sourceMailId ~= "" then
        self.savedVars.ingestedMailIds = self.savedVars.ingestedMailIds or {}
        self.savedVars.ingestedMailIds[options.sourceMailId] = true
    end

    if importedQuest.status == Addon.Constants.QUEST_STATUS.OFFERED then
        self:NotifyListeners("QUEST_OFFERED", importedQuest)
    else
        if options.setActive ~= false then
            self.savedVars.activeQuestId = importedQuest.id
            self:InvalidateActiveTargetCache()
        end
        self:NotifyListeners("QUEST_IMPORTED", importedQuest)
    end
    return importedQuest, nil, false
end

function QuestRepository:AcceptOfferedQuest(questId)
    local q = self:GetQuestById(questId)
    if not q or not self:IsOfferedQuest(q) then
        return false, nil
    end
    q.status = Addon.Constants.QUEST_STATUS.ACTIVE
    self:SetActiveQuest(q.id)
    self:NotifyListeners("QUEST_ACCEPTED", q)
    return true, q
end

function QuestRepository:RejectOfferedQuest(questId)
    local q = self:GetQuestById(questId)
    if not q or not self:IsOfferedQuest(q) then
        return false, nil
    end
    self:DeleteQuest(q.id)
    self:NotifyListeners("QUEST_REJECTED", q)
    return true, q
end

function QuestRepository:ExportQuestToCode(questId)
    local quest = self:GetQuestById(questId)
    if not quest then
        return nil
    end
    self._shareCodeCache = self._shareCodeCache or {}
    local cached = self._shareCodeCache[questId]
    if cached then
        return cached
    end
    local code, err = Addon.ShareCodec:EncodeQuest(quest)
    if code then
        self._shareCodeCache[questId] = code
    end
    return code, err
end

function QuestRepository:ExportCompletionCode(questId)
    local quest = self:GetQuestById(questId)
    if not quest or not quest.completed then
        return nil, "Quest is not completed"
    end

    self._completionCodeCache = self._completionCodeCache or {}
    local cached = self._completionCodeCache[questId]
    if cached then
        return cached
    end

    local rawName = GetUnitName and GetUnitName("player") or ""
    local charName = rawName
    if zo_strformat and rawName ~= "" then
        charName = zo_strformat("<<C:1>>", rawName)
    end
    local ts = GetTimeStamp and GetTimeStamp() or 0

    local code, err = Addon.ShareCodec:EncodeCompletion(quest, charName, ts)
    if code then
        self._completionCodeCache[questId] = code
    end
    return code, err
end

function QuestRepository:ExportRejectionCode(quest)
    if type(quest) ~= "table" then
        return nil, "Invalid quest"
    end
    local rawName = GetUnitName("player") or ""
    local charName = (rawName ~= "" and zo_strformat) and zo_strformat("<<C:1>>", rawName) or rawName
    local ts = GetTimeStamp and GetTimeStamp() or 0
    return Addon.ShareCodec:EncodeRejection(quest, charName, ts)
end

function QuestRepository:ValidateResultCode(questId, codeString)
    local quest = self:GetQuestById(questId)
    if not quest then
        return false, "VALIDATE_ERR_INVALID_CODE"
    end
    return Addon.ShareCodec:ValidateResultForQuest(quest, codeString)
end

function QuestRepository:RecordMailDelivery(questId, senderDisplayName, validationResult)
    local quest = self:GetQuestById(questId)
    if not quest or type(validationResult) ~= "table" then
        return nil
    end
    quest.deliveries = quest.deliveries or {}
    local status = (validationResult.completed == false) and "rejected" or "completed"
    local entry = {
        senderDisplayName = type(senderDisplayName) == "string" and senderDisplayName or "",
        characterName = validationResult.characterName or "",
        completedAt = tonumber(validationResult.completedAt) or 0,
        wasDetected = validationResult.wasDetected,
        status = status,
    }
    -- Avoid duplicate entries for same characterName + completedAt + status
    for _, existing in ipairs(quest.deliveries) do
        if existing.characterName == entry.characterName
            and existing.completedAt == entry.completedAt
            and (existing.status or "completed") == status then
            return existing, false
        end
    end
    table.insert(quest.deliveries, entry)
    quest.lastResult = entry
    self:NotifyListeners("DELIVERY_RECORDED", { quest = quest, delivery = entry })
    return entry, true
end

function QuestRepository:MarkPreparedQuestSent(questId, recipient)
    local quest = self:GetQuestById(questId)
    if not quest then return false end
    local cleanRecipient = self:NormalizeAccountName(recipient)
    if cleanRecipient == "" then return false end
    quest.sentTo = cleanRecipient
    if (quest.recipientAccount or "") == "" then
        quest.recipientAccount = cleanRecipient
    end
    quest.sentAt = GetTimeStamp()
    self:NotifyListeners("QUEST_SENT", quest)
    return true
end

function QuestRepository:GetPreparedQuestStatus(quest)
    if type(quest) ~= "table" then
        return "draft", nil
    end
    if type(quest.lastResult) == "table" then
        if quest.lastResult.status == "rejected" then
            return "rejected", quest.lastResult
        end
        return "completed", quest.lastResult
    end
    if type(quest.deliveries) == "table" and #quest.deliveries > 0 then
        return "completed", quest.deliveries[#quest.deliveries]
    end
    if type(quest.sentTo) == "string" and quest.sentTo ~= "" then
        return "sent", { recipient = quest.sentTo, sentAt = quest.sentAt }
    end
    return "draft", nil
end

function QuestRepository:MarkCompletionReported(questId)
    local quest = self:GetQuestById(questId)
    if not quest then return false end
    quest.completionReported = true
    self:NotifyListeners("COMPLETION_REPORTED", quest)
    return true
end

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

function QuestRepository:IsPreparedQuest(quest)
    return quest ~= nil and quest.role == Addon.Constants.QUEST_ROLE.PREPARED
end

function QuestRepository:GetAllQuests()
    if not self.savedVars then return {} end
    return self.savedVars.quests or {}
end

function QuestRepository:GetQuestsByRole(role)
    local result = {}
    for _, q in ipairs(self:GetAllQuests()) do
        if q.role == role then
            table.insert(result, q)
        end
    end
    return result
end

function QuestRepository:GetCompletedQuests()
    local result = {}
    for _, q in ipairs(self:GetAllQuests()) do
        if q.completed then
            table.insert(result, q)
        end
    end
    return result
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

function QuestRepository:UpdateDraftTarget(index, fields, silent)
    return Addon.QuestDraftStore:UpdateDraftTarget(self, index, fields, silent)
end

function QuestRepository:CaptureDraftTargetLocation(index, zoneId, worldX, worldZ, radius)
    return Addon.QuestDraftStore:CaptureDraftTargetLocation(self, index, zoneId, worldX, worldZ, radius)
end

function QuestRepository:ClearDraftTargetLocation(index)
    return Addon.QuestDraftStore:ClearDraftTargetLocation(self, index)
end

function QuestRepository:HasTargetLocation(target)
    return type(target) == "table" and target.worldX ~= nil and target.worldZ ~= nil
end

function QuestRepository:IsPlayerInsideTargetLocation(target, playerZoneId, playerWorldX, playerWorldZ)
    if not self:HasTargetLocation(target) then
        return true
    end
    if not playerWorldX or not playerWorldZ then
        return false
    end
    local targetZone = tonumber(target.zoneId) or 0
    local pZone = tonumber(playerZoneId) or 0
    if targetZone > 0 and pZone > 0 and targetZone ~= pZone then
        return false
    end
    local dx = playerWorldX - target.worldX
    local dz = playerWorldZ - target.worldZ
    local radius = tonumber(target.radius) or Addon.Constants.DISCOVERY_RADIUS.MEDIUM
    return ((dx * dx) + (dz * dz)) <= (radius * radius)
end

function QuestRepository:GetActiveQuest()
    if not self.savedVars or not self.savedVars.activeQuestId then
        return nil
    end
    local q = self:GetQuestById(self.savedVars.activeQuestId)
    if q and not q.completed and not q.failed and not self:IsOfferedQuest(q) then
        return q
    end
    return nil
end

function QuestRepository:SetActiveQuest(questId)
    if questId == nil then
        self.savedVars.activeQuestId = nil
        self:InvalidateActiveTargetCache()
        self:NotifyListeners("ACTIVE_QUEST_CHANGED", nil)
        return true
    end

    local q = self:GetQuestById(questId)
    if not q or q.completed or q.failed or self:IsOfferedQuest(q) then
        return false
    end

    self.savedVars.activeQuestId = q.id
    self:InvalidateActiveTargetCache()
    self:NotifyListeners("ACTIVE_QUEST_CHANGED", q)
    return true
end

function QuestRepository:ResetQuest(questId)
    local q = self:GetQuestById(questId)
    if not q then return false end

    for _, t in ipairs(q.targets or {}) do
        t.currentCount = 0
    end
    for _, d in ipairs(q.discoveries or {}) do
        d.discovered = false
    end
    q.completed = false
    q.failed = false
    q.wasDetected = false
    q.completionReported = false
    if self._completionCodeCache then
        self._completionCodeCache[questId] = nil
    end
    self.savedVars.activeQuestId = q.id
    self:InvalidateActiveTargetCache()
    self:NotifyListeners("QUEST_RESET", q)
    return true
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
            self:NotifyListeners("QUEST_DELETED", q)
            return true
        end
    end
    return false
end

function QuestRepository:IsPlayerInsideQuestArea(quest, playerMapId, playerZoneId, playerX, playerY)
    if not quest then return false end

    -- Si la misión tiene mapId o zoneId definidos (> 0), validar coincidencia de mapa o zona
    local mapMatches = true
    if (quest.mapId and quest.mapId > 0) and (playerMapId and playerMapId > 0) then
        mapMatches = (quest.mapId == playerMapId)
        if not mapMatches and (quest.zoneId and quest.zoneId > 0) and (playerZoneId and playerZoneId > 0) then
            mapMatches = (quest.zoneId == playerZoneId)
        end
    elseif (quest.zoneId and quest.zoneId > 0) and (playerZoneId and playerZoneId > 0) then
        mapMatches = (quest.zoneId == playerZoneId)
    end

    if not mapMatches then
        return false
    end

    -- Si tenemos coordenadas del jugador en el mismo mapa, verificar que esté dentro de un radio generoso del área de búsqueda
    if (quest.mapId and quest.mapId > 0 and playerMapId == quest.mapId) and playerX and playerY and quest.areaCenterX and quest.areaCenterY then
        local dx = playerX - quest.areaCenterX
        local dy = playerY - quest.areaCenterY
        local dist = math.sqrt((dx * dx) + (dy * dy))
        local toleranceRadius = (quest.areaRadius or 0.075) * 1.35
        return dist <= toleranceRadius
    end

    return true
end

function QuestRepository:FindPendingTarget(rawTargetName)
    if type(rawTargetName) ~= "string" or rawTargetName == "" then
        return nil, nil
    end

    local activeQuest = self:GetActiveQuest()
    if not activeQuest or activeQuest.completed or activeQuest.failed or not activeQuest.targets or #activeQuest.targets == 0 then
        return nil, nil
    end

    local cleanKilled = self:NormalizeName(rawTargetName):lower()
    if cleanKilled == "" then
        return nil, nil
    end

    local cache = self._activeTargetCache
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
        self._activeTargetCache = cache
    end

    local matched = cache.byLowerName[cleanKilled]
    if matched and (matched.currentCount or 0) < (matched.requiredCount or 1) then
        return activeQuest, matched
    end

    return nil, nil
end

function QuestRepository:RecordTargetEliminated(rawTargetName, playerContext, preMatchedQuest, preMatchedTarget)
    local activeQuest, matchedTarget = preMatchedQuest, preMatchedTarget
    if not activeQuest or not matchedTarget then
        activeQuest, matchedTarget = self:FindPendingTarget(rawTargetName)
    end
    if not activeQuest or not matchedTarget then
        return false, nil, false, nil
    end

    if type(playerContext) == "table" then
        local inArea = self:IsPlayerInsideQuestArea(
            activeQuest,
            playerContext.mapId,
            playerContext.zoneId,
            playerContext.x,
            playerContext.y
        )
        if not inArea then
            return false, nil, false, nil
        end
    end

    local hasTargetLoc = self:HasTargetLocation(matchedTarget)
    local inTargetLoc = true
    if hasTargetLoc then
        local pZone = type(playerContext) == "table" and playerContext.worldZoneId or nil
        local pWX = type(playerContext) == "table" and playerContext.worldX or nil
        local pWZ = type(playerContext) == "table" and playerContext.worldZ or nil
        inTargetLoc = self:IsPlayerInsideTargetLocation(matchedTarget, pZone, pWX, pWZ)
    end

    if hasTargetLoc and matchedTarget.locationRequired and not inTargetLoc then
        activeQuest.failed = true
        if self.savedVars.activeQuestId == activeQuest.id then
            self.savedVars.activeQuestId = nil
        end
        self:InvalidateActiveTargetCache()
        self:NotifyListeners("QUEST_FAILED", activeQuest)
        return false, activeQuest, false, matchedTarget, true, false
    end

    matchedTarget.currentCount = math.min(matchedTarget.requiredCount or 1, (matchedTarget.currentCount or 0) + 1)

    local customMsg = type(matchedTarget.customMessage) == "string"
        and matchedTarget.customMessage:gsub("^%s+", ""):gsub("%s+$", "")
        or ""
    local showCustomMessage = (customMsg ~= "") and (not hasTargetLoc or inTargetLoc)

    if self:AreAllObjectivesCompleted(activeQuest.targets, activeQuest.discoveries) then
        activeQuest.completed = true
        if self.savedVars.activeQuestId == activeQuest.id then
            self.savedVars.activeQuestId = nil
        end
        self:InvalidateActiveTargetCache()
        self:NotifyListeners("QUEST_COMPLETED", activeQuest)
    else
        self:NotifyListeners("QUEST_PROGRESS", activeQuest)
    end

    return true, activeQuest, activeQuest.completed, matchedTarget, false, showCustomMessage
end

function QuestRepository:HasPendingDiscoveries(quest)
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

function QuestRepository:MarkDiscoveryTriggered(questId, discoveryIndex)
    local quest = self:GetQuestById(questId)
    if not quest or quest.completed or quest.failed or type(quest.discoveries) ~= "table" then
        return false, nil, false, nil
    end
    local point = quest.discoveries[discoveryIndex]
    if not point or point.discovered then
        return false, nil, false, nil
    end

    point.discovered = true

    if self:AreAllObjectivesCompleted(quest.targets, quest.discoveries) then
        quest.completed = true
        if self.savedVars.activeQuestId == quest.id then
            self.savedVars.activeQuestId = nil
        end
        self:InvalidateActiveTargetCache()
        self:NotifyListeners("DISCOVERY_TRIGGERED", quest)
        self:NotifyListeners("QUEST_COMPLETED", quest)
    else
        self:NotifyListeners("DISCOVERY_TRIGGERED", quest)
    end

    return true, quest, quest.completed, point
end

function QuestRepository:RecordPlayerDetected(playerContext)
    local activeQuest = self:GetActiveQuest()
    if not activeQuest or activeQuest.completed or activeQuest.failed or not activeQuest.requireUndetected or activeQuest.wasDetected then
        return false, nil
    end

    if type(playerContext) == "table" then
        local inArea = self:IsPlayerInsideQuestArea(
            activeQuest,
            playerContext.mapId,
            playerContext.zoneId,
            playerContext.x,
            playerContext.y
        )
        if not inArea then
            return false, nil
        end
    end

    activeQuest.wasDetected = true
    self:NotifyListeners("QUEST_DETECTED", activeQuest)
    return true, activeQuest
end

function QuestRepository:FindDialogueForActiveQuest(rawNpcName, zoneId)
    local activeQuest = self:GetActiveQuest()
    if not activeQuest or activeQuest.completed or activeQuest.failed then
        return nil
    end

    local questClue = type(activeQuest.clue) == "string" and activeQuest.clue:gsub("^%s+", ""):gsub("%s+$", "") or ""

    local dialogues = activeQuest.dialogues
    if type(dialogues) ~= "table" or #dialogues == 0 then
        return nil
    end

    local cleanNpc = self:NormalizeName(rawNpcName)
    if cleanNpc == "" then
        return nil
    end

    local lowerNpc = cleanNpc:lower()
    local z = math.floor(tonumber(zoneId) or 0)

    for _, entry in ipairs(dialogues) do
        if type(entry) == "table" and type(entry.npcName) == "string" and entry.npcName ~= "" then
            local entryName = self:NormalizeName(entry.npcName):lower()
            local entryZone = math.floor(tonumber(entry.zoneId) or 0)
            if entryName == lowerNpc and (entryZone == 0 or z == 0 or entryZone == z) then
                local entryClue = type(entry.clue) == "string" and entry.clue:gsub("^%s+", ""):gsub("%s+$", "") or ""
                local resolvedClue = (entryClue ~= "" and entryClue) or (entry.clue == nil and questClue) or ""
                if resolvedClue == "" then
                    return nil
                end
                return {
                    questId = activeQuest.id,
                    clue = resolvedClue,
                    npcName = entry.npcName,
                    zoneId = entryZone,
                    response = type(entry.response) == "string" and entry.response or "",
                }
            end
        end
    end

    return nil
end

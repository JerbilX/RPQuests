-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0012-savedvars-account-wide-y-migracion-por-personaje.md
-- Ref: docs/adr/0015-separacion-ciclo-de-vida-y-estado-de-resolucion.md
-- Ref: docs/adr/0019-protocolo-world-profile-rpqw1-y-sincronizacion-correo.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.QuestExchange = {}
local QuestExchange = Addon.QuestExchange

function QuestExchange:HasIngestedMail(repo, mailKey)
    if type(mailKey) ~= "string" or mailKey == "" then
        return false
    end
    if repo.savedVars and repo.savedVars.ingestedMailIds and repo.savedVars.ingestedMailIds[mailKey] then
        return true
    end
    for _, q in ipairs((repo.savedVars and repo.savedVars.quests) or {}) do
        if q.sourceMailId == mailKey then
            return true
        end
    end
    return false
end

function QuestExchange:FindAlreadyIngestedQuest(repo, sourceMailId)
    if type(sourceMailId) ~= "string" or sourceMailId == "" then
        return false, nil
    end
    if not repo:HasIngestedMail(sourceMailId) then
        return false, nil
    end
    for _, q in ipairs((repo.savedVars and repo.savedVars.quests) or {}) do
        if q.sourceMailId == sourceMailId then
            return true, q
        end
    end
    return true, nil
end

function QuestExchange:NormalizeImportedTargets(repo, rawTargets, targetX, targetY)
    local importedTargets = {}
    local defaultRad = Addon.Constants.DISCOVERY_RADIUS.MEDIUM
    for _, t in ipairs(rawTargets or {}) do
        local cleanTName = repo:NormalizeName(t.name)
        if cleanTName ~= "" then
            local hasLoc = (t.worldX ~= nil and t.worldZ ~= nil)
            local tAreaRad = tonumber(t.areaRadius)
            table.insert(importedTargets, {
                name = cleanTName,
                currentCount = 0,
                requiredCount = math.max(1, math.floor(tonumber(t.requiredCount) or 1)),
                targetX = targetX,
                targetY = targetY,
                areaCenterX = tonumber(t.areaCenterX),
                areaCenterY = tonumber(t.areaCenterY),
                areaRadius = (tAreaRad and tAreaRad > 0) and tAreaRad or nil,
                zoneId = hasLoc and math.floor(tonumber(t.zoneId) or 0) or nil,
                worldX = hasLoc and tonumber(t.worldX) or nil,
                worldZ = hasLoc and tonumber(t.worldZ) or nil,
                radius = hasLoc and math.max(100, math.floor(tonumber(t.radius) or defaultRad)) or nil,
                locationRequired = (t.locationRequired == true),
                optional = (t.optional == true),
                isPlayer = (t.isPlayer == true),
                customMessage = type(t.customMessage) == "string" and t.customMessage or "",
                customMessageInLocation = type(t.customMessageInLocation) == "string" and t.customMessageInLocation or "",
            })
        end
    end
    return importedTargets
end

function QuestExchange:ApplyImportedSenderMetadata(repo, decoded, senderDisplayName, options)
    local cleanSender = repo:NormalizeAccountName(senderDisplayName)
    if cleanSender ~= "" then
        decoded.senderDisplayName = cleanSender
    end
    local cleanPayloadChar = repo:NormalizeCharacterName(decoded.senderCharacterName)
    if cleanPayloadChar ~= "" then
        decoded.senderCharacterName = cleanPayloadChar
    else
        local cleanMailChar = repo:NormalizeCharacterName(options.senderCharacterName)
        if cleanMailChar ~= "" then
            decoded.senderCharacterName = cleanMailChar
        else
            decoded.senderCharacterName = nil
        end
    end
    if type(decoded.recipientCharacterName) == "string" then
        decoded.recipientCharacterName = repo:NormalizeCharacterName(decoded.recipientCharacterName)
    end
    decoded.status = options.status or Addon.Constants.QUEST_STATUS.ACTIVE
    decoded.lifecycle = Addon.Constants.QUEST_LIFECYCLE.RECEIVED
    decoded.role = Addon.Constants.QUEST_ROLE.RECEIVED
    decoded.resolution = (decoded.status == Addon.Constants.QUEST_STATUS.OFFERED)
        and nil
        or Addon.Constants.QUEST_RESOLUTION.ACCEPTED
    decoded.sourceMailId = options.sourceMailId
end

function QuestExchange:FinalizeImportedQuest(repo, importedQuest, options)
    table.insert(repo.savedVars.quests, importedQuest)
    if repo._questById then
        repo._questById[importedQuest.id] = importedQuest
    end
    if type(options.sourceMailId) == "string" and options.sourceMailId ~= "" then
        repo.savedVars.ingestedMailIds = repo.savedVars.ingestedMailIds or {}
        repo.savedVars.ingestedMailIds[options.sourceMailId] = true
    end

    if importedQuest.status == Addon.Constants.QUEST_STATUS.OFFERED then
        repo:NotifyListeners("QUEST_OFFERED", importedQuest)
    else
        if options.setActive ~= false then
            repo.savedVars.activeQuestId = importedQuest.id
            repo:InvalidateActiveTargetCache()
        end
        repo:NotifyListeners("QUEST_IMPORTED", importedQuest)
    end
end

function QuestExchange:ImportQuestFromCode(repo, codeString, senderDisplayName, options)
    options = type(options) == "table" and options or {}
    local alreadyIngested, existingQuest = repo:FindAlreadyIngestedQuest(options.sourceMailId)
    if alreadyIngested then
        return existingQuest, nil, true
    end

    local decoded, errKey = Addon.ShareCodec:DecodeQuest(codeString)
    if not decoded then
        return nil, Addon.Locale:Get(type(errKey) == "string" and errKey or "ERR_INVALID_CODE")
    end

    local newId = repo.savedVars.nextId
    repo.savedVars.nextId = newId + 1

    local cleanTitle = (decoded.title or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cleanTitle == "" then
        cleanTitle = Addon.Locale:Get("DEFAULT_QUEST_TITLE", newId)
    end

    local importedTargets = repo:NormalizeImportedTargets(decoded.targets, decoded.targetX, decoded.targetY)
    decoded.discoveries = Addon.QuestDraftStore:CloneDiscoveriesList(decoded.discoveries, false)
    decoded.dialogues = Addon.QuestDraftStore:CloneDialoguesList(decoded.dialogues, decoded.clue)
    repo:ApplyImportedSenderMetadata(decoded, senderDisplayName, options)

    local importedQuest = repo:BuildQuestRecord(
        newId,
        cleanTitle,
        decoded.description or "",
        importedTargets,
        decoded,
        Addon.Constants.QUEST_ROLE.RECEIVED
    )

    repo:FinalizeImportedQuest(importedQuest, options)
    return importedQuest, nil, false
end

function QuestExchange:ExportQuestToCode(repo, questId)
    local quest = repo:GetQuestById(questId)
    if not quest then
        return nil
    end
    if repo:IsPreparedQuest(quest) and (type(quest.senderCharacterName) ~= "string" or quest.senderCharacterName == "") then
        local playerChar = repo:GetPlayerCharacterName()
        if playerChar ~= "" then
            quest.senderCharacterName = playerChar
        end
    end
    repo._shareCodeCache = repo._shareCodeCache or {}
    local cached = repo._shareCodeCache[questId]
    if cached then
        return cached
    end
    local code, err = Addon.ShareCodec:EncodeQuest(quest)
    if code then
        repo._shareCodeCache[questId] = code
    end
    return code, err
end

local function ReadPlayerExportContext()
    local rawName = GetUnitName("player") or ""
    local charName = rawName ~= "" and zo_strformat("<<C:1>>", rawName) or rawName
    return charName, GetTimeStamp() or 0
end

function QuestExchange:ExportCompletionCode(repo, questId)
    local quest = repo:GetQuestById(questId)
    if not quest or not quest.completed then
        return nil, "Quest is not completed"
    end

    repo._completionCodeCache = repo._completionCodeCache or {}
    local cached = repo._completionCodeCache[questId]
    if cached then
        return cached
    end

    local charName, ts = ReadPlayerExportContext()
    local code, err = Addon.ShareCodec:EncodeCompletion(quest, charName, ts)
    if code then
        repo._completionCodeCache[questId] = code
    end
    return code, err
end

function QuestExchange:ExportRejectionCode(_repo, quest)
    if type(quest) ~= "table" then
        return nil, "Invalid quest"
    end
    local charName, ts = ReadPlayerExportContext()
    return Addon.ShareCodec:EncodeRejection(quest, charName, ts)
end

function QuestExchange:ExportAcceptanceCode(_repo, quest)
    if type(quest) ~= "table" then
        return nil, "Invalid quest"
    end
    local charName, ts = ReadPlayerExportContext()
    return Addon.ShareCodec:EncodeAcceptance(quest, charName, ts)
end

function QuestExchange:ExportFailureCode(repo, questOrId)
    local quest = type(questOrId) == "table" and questOrId or repo:GetQuestById(questOrId)
    if type(quest) ~= "table" or not quest.failed then
        return nil, "Quest has not failed"
    end
    local charName, ts = ReadPlayerExportContext()
    return Addon.ShareCodec:EncodeFailure(quest, charName, ts)
end

function QuestExchange:ValidateResultCode(repo, questId, codeString)
    local quest = repo:GetQuestById(questId)
    if not quest then
        return false, "VALIDATE_ERR_INVALID_CODE"
    end
    return Addon.ShareCodec:ValidateResultForQuest(quest, codeString)
end

function QuestExchange:RecordMailDelivery(repo, questId, senderDisplayName, validationResult)
    local quest = repo:GetQuestById(questId)
    if not quest or type(validationResult) ~= "table" then
        return nil
    end
    quest.deliveries = quest.deliveries or {}
    local status
    if validationResult.resultType == "accepted" or validationResult.accepted == true then
        status = "accepted"
    elseif validationResult.resultType == "failed" or validationResult.failed == true then
        status = "failed"
    elseif validationResult.resultType == "rejected" or validationResult.rejected == true or validationResult.completed == false then
        status = "rejected"
    else
        status = "completed"
    end
    local entry = {
        senderDisplayName = type(senderDisplayName) == "string" and senderDisplayName or "",
        characterName = validationResult.characterName or "",
        completedAt = tonumber(validationResult.completedAt) or 0,
        wasDetected = validationResult.wasDetected,
        optionalTargets = validationResult.optionalTargets,
        status = status,
    }
    for _, existing in ipairs(quest.deliveries) do
        if existing.characterName == entry.characterName
            and existing.completedAt == entry.completedAt
            and (existing.status or "completed") == status then
            return existing, false
        end
    end
    table.insert(quest.deliveries, entry)
    if repo:IsPreparedQuest(quest) then
        quest.lifecycle = Addon.Constants.QUEST_LIFECYCLE.SENT
    end
    local prevResolution = quest.resolution or (type(quest.lastResult) == "table" and (quest.lastResult.status or "completed") or nil)
    local isTerminal = (prevResolution == "completed" or prevResolution == "rejected" or prevResolution == "failed")
    if not (status == "accepted" and isTerminal) then
        quest.lastResult = entry
        quest.resolution = status
    end
    repo:NotifyListeners("DELIVERY_RECORDED", { quest = quest, delivery = entry })
    return entry, true
end

function QuestExchange:MarkPreparedQuestSent(repo, questId, recipient)
    local quest = repo:GetQuestById(questId)
    if not quest then return false end
    local cleanRecipient = repo:NormalizeAccountName(recipient)
    if cleanRecipient == "" then return false end
    quest.lifecycle = Addon.Constants.QUEST_LIFECYCLE.SENT
    quest.role = Addon.Constants.QUEST_ROLE.PREPARED
    quest.sentTo = cleanRecipient
    if (quest.recipientAccount or "") == "" then
        quest.recipientAccount = cleanRecipient
    end
    quest.sentAt = GetTimeStamp()
    repo:NotifyListeners("QUEST_SENT", quest)
    return true
end

function QuestExchange:MarkCompletionReported(repo, questId)
    local quest = repo:GetQuestById(questId)
    if not quest then return false end
    quest.completionReported = true
    repo:NotifyListeners("COMPLETION_REPORTED", quest)
    return true
end

function QuestExchange:MarkFailureReported(repo, questId)
    local quest = repo:GetQuestById(questId)
    if not quest then return false end
    quest.failureReported = true
    repo:NotifyListeners("FAILURE_REPORTED", quest)
    return true
end

function QuestExchange:SaveWorldProfile(repo, accountName, profile)
    if type(profile) ~= "table" then return nil end
    local normAccount = repo:NormalizeAccountName(accountName)
    local charName = repo:NormalizeCharacterName(profile.characterName)
    if normAccount == "" or charName == "" then
        return nil
    end

    repo.savedVars.worldProfiles = repo.savedVars.worldProfiles or {}
    local entry = repo.savedVars.worldProfiles[normAccount]
    if type(entry) ~= "table" then
        entry = {
            dlcMask = "",
            esoPlus = false,
            updatedAt = 0,
            characters = {},
        }
        repo.savedVars.worldProfiles[normAccount] = entry
    end
    if type(entry.characters) ~= "table" then
        entry.characters = {}
    end

    local now = GetTimeStamp() or 0
    if type(profile.dlcMask) == "string" and profile.dlcMask ~= "" then
        entry.dlcMask = profile.dlcMask
    end
    if profile.esoPlus ~= nil then
        entry.esoPlus = (profile.esoPlus == true)
    end
    entry.updatedAt = now
    entry.characters[charName] = {
        poiMask = type(profile.poiMask) == "string" and profile.poiMask or "",
        updatedAt = now,
    }

    repo:NotifyListeners("WORLD_PROFILE_UPDATED", {
        accountName = normAccount,
        characterName = charName,
        profile = entry,
    })
    return entry
end

function QuestExchange:GetWorldProfile(repo, accountName)
    local normAccount = repo:NormalizeAccountName(accountName)
    if normAccount == "" or not repo.savedVars or type(repo.savedVars.worldProfiles) ~= "table" then
        return nil
    end
    return repo.savedVars.worldProfiles[normAccount]
end

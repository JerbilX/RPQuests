-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0013-protocolo-versionado-de-esquema-y-migraciones-de-misiones.md
-- Ref: docs/adr/0014-areas-por-objetivo-mensajes-eliminacion-y-visibilidad-mapa.md
-- Ref: docs/adr/0015-separacion-ciclo-de-vida-y-estado-de-resolucion.md
-- Ref: docs/adr/0018-ejes-de-victoria-modo-freeform-y-objetivos-requeridos.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.QuestRecord = {}
local QuestRecord = Addon.QuestRecord

local VALID_RESOLUTION = {
    accepted = true,
    rejected = true,
    completed = true,
    failed = true,
}

function QuestRecord:NormalizeName(_repo, name)
    if type(name) ~= "string" or name == "" then return "" end
    local clean = zo_strformat("<<C:1>>", (name:gsub("%^%a+$", "")))
    clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
    return clean
end

function QuestRecord:NormalizeAccountName(_repo, raw)
    if type(raw) ~= "string" then return "" end
    local clean = raw:gsub("^%s+", ""):gsub("%s+$", "")
    if clean == "" then return "" end
    if clean:sub(1, 1) ~= "@" then
        clean = "@" .. clean
    end
    return clean
end

function QuestRecord:NormalizeCharacterName(_repo, raw)
    if type(raw) ~= "string" then return "" end
    local clean = raw:gsub("%^%a+$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return clean
end

function QuestRecord:GetPlayerCharacterName(repo)
    return repo:NormalizeCharacterName(GetUnitName("player"))
end

function QuestRecord:GetAccountCharacterNames(repo)
    local names = {}
    local seen = {}
    local count = tonumber(GetNumCharacters()) or 0
    for i = 1, count do
        local rawName = GetCharacterInfo(i)
        local clean = repo:NormalizeCharacterName(rawName)
        if clean ~= "" and not seen[clean] then
            seen[clean] = true
            table.insert(names, clean)
        end
    end
    local playerChar = repo:GetPlayerCharacterName()
    if playerChar ~= "" and not seen[playerChar] then
        table.insert(names, 1, playerChar)
    end
    return names
end

function QuestRecord:FormatTargetEntry(_repo, target)
    if type(target) ~= "table" or not target.name or target.name == "" then
        return ""
    end
    local req = math.max(1, math.floor(tonumber(target.requiredCount) or 1))
    local label = target.name
    if target.isPlayer == true then
        local duelTag = (Addon.Locale and Addon.Locale:Get("LABEL_DUEL_TAG")) or "Duel"
        label = string.format("%s (%s)", label, duelTag)
    end
    if req > 1 then
        return string.format("%s x%d", label, req)
    end
    return label
end

function QuestRecord:FormatTargetsSummary(repo, targets)
    if type(targets) ~= "table" or #targets == 0 then
        return ""
    end
    local parts = {}
    for _, t in ipairs(targets) do
        local formatted = repo:FormatTargetEntry(t)
        if formatted ~= "" then
            table.insert(parts, formatted)
        end
    end
    return table.concat(parts, ", ")
end

local function ResolveRecommendHideMapAreas(data)
    if type(data) ~= "table" then
        return true
    end
    if data.recommendHideMapAreas ~= nil then
        return data.recommendHideMapAreas == true
    end
    if data.hideMapArea ~= nil then
        return data.hideMapArea == true
    end
    return true
end

function QuestRecord:BuildQuestRecord(repo, id, title, description, targets, data, role)
    data = type(data) == "table" and data or {}
    local schemaVersion = (Addon.QuestMigration and Addon.QuestMigration:GetCurrentSchemaVersion()) or 1
    local roles = Addon.Constants.QUEST_ROLE
    local statuses = Addon.Constants.QUEST_STATUS
    local lifecycles = Addon.Constants.QUEST_LIFECYCLE
    local resolutions = Addon.Constants.QUEST_RESOLUTION

    local resolvedRole = role or roles.RECEIVED
    local lifecycle
    local resolution

    if resolvedRole == roles.PREPARED or data.lifecycle == lifecycles.DRAFT or data.lifecycle == lifecycles.SENT then
        resolvedRole = roles.PREPARED
        local hasSent = data.lifecycle == lifecycles.SENT
            or (type(data.sentTo) == "string" and data.sentTo ~= "")
            or type(data.lastResult) == "table"
            or (type(data.deliveries) == "table" and #data.deliveries > 0)
        if hasSent then
            lifecycle = lifecycles.SENT
            resolution = VALID_RESOLUTION[data.resolution] and data.resolution or nil
        else
            lifecycle = lifecycles.DRAFT
            resolution = nil
        end
    else
        resolvedRole = roles.RECEIVED
        lifecycle = lifecycles.RECEIVED
        if data.status == statuses.OFFERED then
            resolution = nil
        elseif VALID_RESOLUTION[data.resolution] then
            resolution = data.resolution
        elseif data.failed == true then
            resolution = resolutions.FAILED
        elseif data.completed == true then
            resolution = resolutions.COMPLETED
        else
            resolution = resolutions.ACCEPTED
        end
    end

    local discoveries = type(data.discoveries) == "table" and data.discoveries or {}
    for _, d in ipairs(discoveries) do
        if type(d) == "table" then
            d.required = (d.required == true)
            d.discovered = (d.discovered == true)
        end
    end

    return {
        id = id,
        schemaVersion = schemaVersion,
        title = title,
        description = description,
        clue = type(data.clue) == "string" and data.clue or "",
        completionMessage = data.completionMessage or "",
        targets = targets,
        discoveries = discoveries,
        dialogues = Addon.QuestDraftStore:CloneDialoguesList(data.dialogues, data.clue),
        sequentialDiscoveries = (data.sequentialDiscoveries == true),
        completed = false,
        role = resolvedRole,
        lifecycle = lifecycle,
        resolution = resolution,
        mapId = data.mapId or 0,
        zoneId = data.zoneId or 0,
        mapName = data.mapName or "",
        targetX = data.targetX,
        targetY = data.targetY,
        worldX = data.worldX,
        worldY = data.worldY,
        worldZ = data.worldZ,
        recommendHideMapAreas = ResolveRecommendHideMapAreas(data),
        stealthMode = Addon.QuestDraftStore:NormalizeStealthMode(data.stealthMode, data.requireUndetected),
        icon = Addon.QuestDraftStore:NormalizeQuestIcon(data.icon),
        wasDetected = false,
        failed = false,
        senderDisplayName = type(data.senderDisplayName) == "string" and data.senderDisplayName or nil,
        senderCharacterName = (type(data.senderCharacterName) == "string" and data.senderCharacterName ~= "") and data.senderCharacterName or nil,
        recipientAccount = repo:NormalizeAccountName(data.recipientAccount),
        recipientCharacterName = (type(data.recipientCharacterName) == "string" and data.recipientCharacterName ~= "") and data.recipientCharacterName or nil,
        sentTo = type(data.sentTo) == "string" and data.sentTo or nil,
        sentAt = data.sentAt,
        lastResult = type(data.lastResult) == "table" and data.lastResult or nil,
        status = data.status,
        sourceMailId = data.sourceMailId,
        completionReported = (data.completionReported == true),
        failureReported = (data.failureReported == true),
        deliveries = type(data.deliveries) == "table" and data.deliveries or {},
    }
end

local function ClonePreparedQuestRecord(repo, source)
    local newId = repo.savedVars.nextId or 1
    repo.savedVars.nextId = newId + 1

    local clonedTargets = Addon.QuestDraftStore:CloneTargetsList(source.targets)
    for _, t in ipairs(clonedTargets) do
        t.currentCount = 0
    end

    local isTutorialSource = (source.isTutorial == true)
    local senderChar = (not isTutorialSource and type(source.senderCharacterName) == "string" and source.senderCharacterName ~= "")
        and source.senderCharacterName
        or repo:GetPlayerCharacterName()

    local questData = {
        senderDisplayName = isTutorialSource and nil or source.senderDisplayName,
        senderCharacterName = senderChar,
        recipientAccount = isTutorialSource and "" or source.recipientAccount,
        recipientCharacterName = isTutorialSource and nil or source.recipientCharacterName,
        clue = source.clue,
        completionMessage = source.completionMessage,
        discoveries = Addon.QuestDraftStore:CloneDiscoveriesList(source.discoveries, false),
        dialogues = Addon.QuestDraftStore:CloneDialoguesList(source.dialogues, source.clue),
        sequentialDiscoveries = (source.sequentialDiscoveries == true),
        mapId = source.mapId,
        zoneId = source.zoneId,
        mapName = source.mapName,
        targetX = source.targetX,
        targetY = source.targetY,
        recommendHideMapAreas = (source.recommendHideMapAreas ~= false),
        stealthMode = Addon.QuestDraftStore:NormalizeStealthMode(source.stealthMode, source.requireUndetected),
        icon = Addon.QuestDraftStore:NormalizeQuestIcon(source.icon),
    }

    local newQuest = repo:BuildQuestRecord(
        newId,
        source.title or "",
        source.description or "",
        clonedTargets,
        questData,
        Addon.Constants.QUEST_ROLE.PREPARED
    )
    newQuest.createdAt = GetTimeStamp() or 0
    newQuest.lifecycle = Addon.Constants.QUEST_LIFECYCLE.DRAFT
    newQuest.resolution = nil
    newQuest.sentTo = nil
    newQuest.lastResult = nil
    newQuest.deliveries = {}
    newQuest.needsMigration = nil
    newQuest.migrationReason = nil
    newQuest.isTutorial = nil
    newQuest.tutorialStep = nil

    table.insert(repo.savedVars.quests, newQuest)
    if repo._questById then
        repo._questById[newQuest.id] = newQuest
    end

    repo:NotifyListeners("QUEST_CREATED", newQuest)
    return newQuest
end

function QuestRecord:DuplicateQuest(repo, questId)
    if not repo.savedVars then return nil end
    local source = repo:GetQuestById(questId)
    if not source then return nil end
    if not repo:IsPreparedQuest(source) and source.isTutorial ~= true then
        return nil, Addon.Locale:Get("ERR_CANNOT_COPY_RECEIVED")
    end
    return ClonePreparedQuestRecord(repo, source)
end

function QuestRecord:MigratePreparedQuest(repo, questId)
    if not repo.savedVars then return nil end
    local source = repo:GetQuestById(questId)
    if not source then return nil end
    if not repo:IsPreparedQuest(source) then
        return nil, Addon.Locale:Get("ERR_CANNOT_MIGRATE_RECEIVED")
    end
    return ClonePreparedQuestRecord(repo, source)
end

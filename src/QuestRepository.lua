-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md

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
    local clean = name:gsub("%^%a+$", "")
    if zo_strformat then
        clean = zo_strformat("<<C:1>>", clean)
    end
    clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
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

local function CreateDefaultDraft()
    return {
        editingQuestId = nil,
        title = "",
        description = "",
        completionMessage = "",
        targets = {},
        lastCapturedDisplay = nil,
        mapId = 0,
        zoneId = 0,
        mapName = "",
        targetX = nil,
        targetY = nil,
        areaCenterX = nil,
        areaCenterY = nil,
        areaRadius = Addon.Constants.AREA_RADIUS.MEDIUM,
    }
end

local function BuildQuestRecord(id, title, description, targets, data, role)
    return {
        id = id,
        title = title,
        description = description,
        completionMessage = data.completionMessage or "",
        targets = targets,
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
    }
end

local function CloneTargetsList(targets, existingTargetsByName)
    local out = {}
    if type(targets) ~= "table" then return out end
    for _, t in ipairs(targets) do
        if type(t) == "table" and type(t.name) == "string" and t.name ~= "" then
            local req = math.max(1, math.floor(tonumber(t.requiredCount) or 1))
            local cur = math.max(0, math.floor(tonumber(t.currentCount) or 0))
            if existingTargetsByName and existingTargetsByName[t.name:lower()] ~= nil then
                cur = math.min(req, existingTargetsByName[t.name:lower()])
            end
            table.insert(out, {
                name = t.name,
                currentCount = cur,
                requiredCount = req,
                targetX = t.targetX,
                targetY = t.targetY,
            })
        end
    end
    return out
end

function QuestRepository:GetDefaults()
    return {
        nextId = 1,
        activeQuestId = nil,
        quests = {},
        draft = CreateDefaultDraft(),
    }
end

function QuestRepository:Initialize(savedVars)
    self.savedVars = savedVars or self:GetDefaults()
    self.savedVars.nextId = self.savedVars.nextId or 1
    self.savedVars.quests = self.savedVars.quests or {}
    if not self.savedVars.draft then
        self.savedVars.draft = CreateDefaultDraft()
    else
        self.savedVars.draft.targets = self.savedVars.draft.targets or {}
    end
    local roles = Addon.Constants.QUEST_ROLE
    for _, q in ipairs(self.savedVars.quests) do
        q.targets = q.targets or {}
        if q.role ~= roles.PREPARED and q.role ~= roles.RECEIVED then
            q.role = roles.RECEIVED
        end
    end
    self._listeners = self._listeners or {}
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
    if not self.savedVars then
        self:Initialize()
    end
    self.savedVars.draft.targets = self.savedVars.draft.targets or {}
    return self.savedVars.draft
end

function QuestRepository:ResetDraft()
    if not self.savedVars then
        self:Initialize()
    end
    self.savedVars.draft = CreateDefaultDraft()
    self:NotifyListeners("DRAFT_UPDATED", self.savedVars.draft)
    return self.savedVars.draft
end

function QuestRepository:ClearDraftTargets()
    local draft = self:GetDraft()
    draft.targets = {}
    draft.lastCapturedDisplay = nil
    draft.mapId = 0
    draft.zoneId = 0
    draft.mapName = ""
    draft.targetX = nil
    draft.targetY = nil
    draft.areaCenterX = nil
    draft.areaCenterY = nil
    self:NotifyListeners("DRAFT_UPDATED", draft)
    return draft
end

function QuestRepository:LoadQuestIntoDraft(questId)
    local quest = self:GetQuestById(questId)
    if not quest then return nil end
    if not self:IsPreparedQuest(quest) then
        return nil, Addon.Locale:Get("ERR_CANNOT_EDIT_RECEIVED")
    end

    self.savedVars.draft = {
        editingQuestId = quest.id,
        title = quest.title or "",
        description = quest.description or "",
        completionMessage = quest.completionMessage or "",
        targets = CloneTargetsList(quest.targets),
        lastCapturedDisplay = nil,
        mapId = quest.mapId or 0,
        zoneId = quest.zoneId or 0,
        mapName = quest.mapName or "",
        targetX = quest.targetX,
        targetY = quest.targetY,
        areaCenterX = quest.areaCenterX,
        areaCenterY = quest.areaCenterY,
        areaRadius = quest.areaRadius or 0.075,
    }
    self:NotifyListeners("DRAFT_UPDATED", self.savedVars.draft)
    return self.savedVars.draft
end

function QuestRepository:UpdateDraftFields(fields, silent)
    local draft = self:GetDraft()
    if type(fields) ~= "table" then return draft end

    if fields.title ~= nil then draft.title = tostring(fields.title) end
    if fields.description ~= nil then draft.description = tostring(fields.description) end
    if fields.completionMessage ~= nil then draft.completionMessage = tostring(fields.completionMessage) end
    if fields.areaRadius ~= nil then
        local newRadius = tonumber(fields.areaRadius) or draft.areaRadius
        if newRadius > 0 then
            draft.areaRadius = newRadius
            if draft.targetX and draft.targetY then
                draft.areaCenterX, draft.areaCenterY = self:ComputeOffsetCenter(draft.targetX, draft.targetY, draft.areaRadius)
            end
        end
    end
    if not silent then
        self:NotifyListeners("DRAFT_UPDATED", draft)
    end
    return draft
end

function QuestRepository:SetDraftCapturedTarget(captureData)
    if type(captureData) ~= "table" then return nil end
    local cleanName = self:NormalizeName(captureData.targetName)
    if cleanName == "" then return nil end

    local draft = self:GetDraft()
    local newMapId = tonumber(captureData.mapId) or 0
    if draft.mapId and draft.mapId > 0 and newMapId > 0 and draft.mapId ~= newMapId then
        draft.targets = {}
    else
        draft.targets = draft.targets or {}
    end

    local tx = tonumber(captureData.targetX) or 0.5
    local ty = tonumber(captureData.targetY) or 0.5

    local matchedEntry = nil
    local cleanKey = cleanName:lower()
    for _, entry in ipairs(draft.targets) do
        if (entry.name or ""):lower() == cleanKey then
            matchedEntry = entry
            break
        end
    end

    if matchedEntry then
        matchedEntry.requiredCount = math.min(999, (tonumber(matchedEntry.requiredCount) or 1) + 1)
        matchedEntry.targetX = tx
        matchedEntry.targetY = ty
    else
        matchedEntry = {
            name = cleanName,
            currentCount = 0,
            requiredCount = 1,
            targetX = tx,
            targetY = ty,
        }
        table.insert(draft.targets, matchedEntry)
    end

    draft.lastCapturedDisplay = self:FormatTargetEntry(matchedEntry)
    draft.mapId = tonumber(captureData.mapId) or draft.mapId or 0
    draft.zoneId = tonumber(captureData.zoneId) or draft.zoneId or 0
    draft.mapName = tostring(captureData.mapName or draft.mapName or "")

    -- Calcular centroide de los objetivos capturados para situar el área de búsqueda
    local sumX, sumY, countCoords = 0, 0, 0
    for _, entry in ipairs(draft.targets) do
        if entry.targetX and entry.targetY then
            sumX = sumX + entry.targetX
            sumY = sumY + entry.targetY
            countCoords = countCoords + 1
        end
    end
    if countCoords > 0 then
        draft.targetX = sumX / countCoords
        draft.targetY = sumY / countCoords
    else
        draft.targetX = tx
        draft.targetY = ty
    end

    local radius = draft.areaRadius or Addon.Constants.AREA_RADIUS.MEDIUM
    draft.areaRadius = radius
    draft.areaCenterX, draft.areaCenterY = self:ComputeOffsetCenter(draft.targetX, draft.targetY, radius)

    self:NotifyListeners("DRAFT_TARGET_CAPTURED", draft)
    return draft
end

function QuestRepository:SaveDraft(titleInput, descriptionInput, areaRadiusInput, completionMessageInput)
    local draft = self:GetDraft()

    if titleInput ~= nil then draft.title = tostring(titleInput) end
    if descriptionInput ~= nil then draft.description = tostring(descriptionInput) end
    if completionMessageInput ~= nil then draft.completionMessage = tostring(completionMessageInput) end
    if areaRadiusInput ~= nil and tonumber(areaRadiusInput) and tonumber(areaRadiusInput) > 0 then
        draft.areaRadius = tonumber(areaRadiusInput)
    end

    draft.targets = draft.targets or {}

    if #draft.targets == 0 or not draft.targetX or not draft.targetY then
        return nil, Addon.Locale:Get("ERR_MISSING_TARGET")
    end

    if not draft.areaCenterX or not draft.areaCenterY then
        draft.areaCenterX, draft.areaCenterY = self:ComputeOffsetCenter(draft.targetX, draft.targetY, draft.areaRadius)
    end

    local existing = draft.editingQuestId and self:GetQuestById(draft.editingQuestId) or nil
    local targetId = existing and existing.id or self.savedVars.nextId

    local cleanTitle = (draft.title or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cleanTitle == "" then
        cleanTitle = Addon.Locale:Get("DEFAULT_QUEST_TITLE", targetId)
    end

    local cleanDesc = (draft.description or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cleanCompMsg = (draft.completionMessage or ""):gsub("^%s+", ""):gsub("%s+$", "")
    draft.completionMessage = cleanCompMsg

    if existing then
        local prevProgress = {}
        for _, t in ipairs(existing.targets or {}) do
            prevProgress[t.name:lower()] = t.currentCount or 0
        end

        existing.title = cleanTitle
        existing.description = cleanDesc
        existing.completionMessage = cleanCompMsg
        existing.targets = CloneTargetsList(draft.targets, prevProgress)
        existing.mapId = draft.mapId or 0
        existing.zoneId = draft.zoneId or 0
        existing.mapName = draft.mapName or ""
        existing.targetX = draft.targetX
        existing.targetY = draft.targetY
        existing.areaCenterX = draft.areaCenterX
        existing.areaCenterY = draft.areaCenterY
        existing.areaRadius = draft.areaRadius
        existing.completed = AreAllTargetsCompleted(existing.targets)

        self:ResetDraft()
        self:NotifyListeners("QUEST_UPDATED", existing)
        return existing
    end

    self.savedVars.nextId = targetId + 1

    local newQuest = BuildQuestRecord(
        targetId,
        cleanTitle,
        cleanDesc,
        CloneTargetsList(draft.targets),
        draft,
        Addon.Constants.QUEST_ROLE.PREPARED
    )

    table.insert(self.savedVars.quests, newQuest)

    self:ResetDraft()
    self:NotifyListeners("QUEST_CREATED", newQuest)
    return newQuest
end

function QuestRepository:ImportQuestFromCode(codeString)
    local decoded = Addon.ShareCodec:DecodeQuest(codeString)
    if not decoded then
        return nil, Addon.Locale:Get("ERR_INVALID_CODE")
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
            table.insert(importedTargets, {
                name = cleanTName,
                currentCount = 0,
                requiredCount = math.max(1, math.floor(tonumber(t.requiredCount) or 1)),
                targetX = decoded.targetX,
                targetY = decoded.targetY,
            })
        end
    end

    local importedQuest = BuildQuestRecord(
        newId,
        cleanTitle,
        decoded.description or "",
        importedTargets,
        decoded,
        Addon.Constants.QUEST_ROLE.RECEIVED
    )

    table.insert(self.savedVars.quests, importedQuest)
    self.savedVars.activeQuestId = importedQuest.id

    self:NotifyListeners("QUEST_IMPORTED", importedQuest)
    return importedQuest
end

function QuestRepository:ExportQuestToCode(questId)
    local quest = self:GetQuestById(questId)
    if not quest then
        return nil
    end
    return Addon.ShareCodec:EncodeQuest(quest)
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

function QuestRepository:GetActiveAndAvailableQuests()
    local result = {}
    for _, q in ipairs(self:GetAllQuests()) do
        if not q.completed then
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
    for _, q in ipairs(self:GetAllQuests()) do
        if q.id == questId then
            return q
        end
    end
    return nil
end

function QuestRepository:GetActiveQuest()
    if not self.savedVars or not self.savedVars.activeQuestId then
        return nil
    end
    local q = self:GetQuestById(self.savedVars.activeQuestId)
    if q and not q.completed then
        return q
    end
    return nil
end

function QuestRepository:SetActiveQuest(questId)
    if questId == nil then
        self.savedVars.activeQuestId = nil
        self:NotifyListeners("ACTIVE_QUEST_CHANGED", nil)
        return true
    end

    local q = self:GetQuestById(questId)
    if not q or q.completed then
        return false
    end

    self.savedVars.activeQuestId = q.id
    self:NotifyListeners("ACTIVE_QUEST_CHANGED", q)
    return true
end

function QuestRepository:ResetQuest(questId)
    local q = self:GetQuestById(questId)
    if not q then return false end

    for _, t in ipairs(q.targets or {}) do
        t.currentCount = 0
    end
    q.completed = false
    self.savedVars.activeQuestId = q.id
    self:NotifyListeners("QUEST_RESET", q)
    return true
end

function QuestRepository:DeleteQuest(questId)
    if not self.savedVars or not questId then return false end
    for i, q in ipairs(self.savedVars.quests) do
        if q.id == questId then
            local wasActive = (self.savedVars.activeQuestId == questId)
            table.remove(self.savedVars.quests, i)
            if self.savedVars.draft and self.savedVars.draft.editingQuestId == questId then
                self:ResetDraft()
            end
            if wasActive then
                self.savedVars.activeQuestId = nil
                local nextAvailable = self:GetActiveAndAvailableQuests()[1]
                if nextAvailable then
                    self.savedVars.activeQuestId = nextAvailable.id
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
    local activeQuest = self:GetActiveQuest()
    if not activeQuest or activeQuest.completed then
        return nil, nil
    end

    local cleanKilled = self:NormalizeName(rawTargetName):lower()
    if cleanKilled == "" then
        return nil, nil
    end

    for _, entry in ipairs(activeQuest.targets or {}) do
        if (entry.name or ""):lower() == cleanKilled and (entry.currentCount or 0) < (entry.requiredCount or 1) then
            return activeQuest, entry
        end
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

    matchedTarget.currentCount = math.min(matchedTarget.requiredCount or 1, (matchedTarget.currentCount or 0) + 1)

    if AreAllTargetsCompleted(activeQuest.targets) then
        activeQuest.completed = true
        if self.savedVars.activeQuestId == activeQuest.id then
            self.savedVars.activeQuestId = nil
        end
        self:NotifyListeners("QUEST_COMPLETED", activeQuest)
    else
        self:NotifyListeners("QUEST_PROGRESS", activeQuest)
    end

    return true, activeQuest, activeQuest.completed, matchedTarget
end

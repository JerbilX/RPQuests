-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md

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

local function CreateDefaultDraft()
    local defaultRadius = (Addon.Constants and Addon.Constants.AREA_RADIUS and Addon.Constants.AREA_RADIUS.MEDIUM) or 0.075
    return {
        editingQuestId = nil,
        title = "",
        description = "",
        targetName = "",
        requiredCount = 1,
        mapId = 0,
        zoneId = 0,
        mapName = "",
        targetX = nil,
        targetY = nil,
        areaCenterX = nil,
        areaCenterY = nil,
        areaRadius = defaultRadius,
    }
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

    local minRatio = (Addon.Constants and Addon.Constants.AREA_OFFSET and Addon.Constants.AREA_OFFSET.MIN_RATIO) or 0.25
    local maxRatio = (Addon.Constants and Addon.Constants.AREA_OFFSET and Addon.Constants.AREA_OFFSET.MAX_RATIO) or 0.65

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

    -- Garantizar matemáticamente que la distancia entre (tx, ty) y (cx, cy) sea <= 0.85 * r
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

function QuestRepository:LoadQuestIntoDraft(questId)
    local quest = self:GetQuestById(questId)
    if not quest then return nil end

    self.savedVars.draft = {
        editingQuestId = quest.id,
        title = quest.title or "",
        description = quest.description or "",
        targetName = quest.targetName or "",
        requiredCount = quest.requiredCount or 1,
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

function QuestRepository:UpdateDraftFields(fields)
    local draft = self:GetDraft()
    if type(fields) ~= "table" then return draft end

    if fields.title ~= nil then draft.title = tostring(fields.title) end
    if fields.description ~= nil then draft.description = tostring(fields.description) end
    if fields.requiredCount ~= nil then
        local count = math.floor(tonumber(fields.requiredCount) or 1)
        draft.requiredCount = math.max(1, math.min(999, count))
    end
    if fields.areaRadius ~= nil then
        local newRadius = tonumber(fields.areaRadius) or draft.areaRadius
        if newRadius > 0 then
            draft.areaRadius = newRadius
            if draft.targetX and draft.targetY then
                draft.areaCenterX, draft.areaCenterY = self:ComputeOffsetCenter(draft.targetX, draft.targetY, draft.areaRadius)
            end
        end
    end
    self:NotifyListeners("DRAFT_UPDATED", draft)
    return draft
end

function QuestRepository:SetDraftCapturedTarget(captureData)
    if type(captureData) ~= "table" then return nil end
    local cleanName = self:NormalizeName(captureData.targetName)
    if cleanName == "" then return nil end

    local draft = self:GetDraft()
    draft.targetName = cleanName
    draft.mapId = tonumber(captureData.mapId) or 0
    draft.zoneId = tonumber(captureData.zoneId) or 0
    draft.mapName = tostring(captureData.mapName or "")
    draft.targetX = tonumber(captureData.targetX) or 0.5
    draft.targetY = tonumber(captureData.targetY) or 0.5

    local radius = draft.areaRadius or ((Addon.Constants and Addon.Constants.AREA_RADIUS and Addon.Constants.AREA_RADIUS.MEDIUM) or 0.075)
    draft.areaRadius = radius
    draft.areaCenterX, draft.areaCenterY = self:ComputeOffsetCenter(draft.targetX, draft.targetY, radius)

    self:NotifyListeners("DRAFT_TARGET_CAPTURED", draft)
    return draft
end

function QuestRepository:SaveDraft(titleInput, descriptionInput, requiredCountInput, areaRadiusInput)
    local draft = self:GetDraft()

    if titleInput ~= nil then draft.title = tostring(titleInput) end
    if descriptionInput ~= nil then draft.description = tostring(descriptionInput) end
    if requiredCountInput ~= nil then
        draft.requiredCount = math.max(1, math.min(999, math.floor(tonumber(requiredCountInput) or draft.requiredCount or 1)))
    end
    if areaRadiusInput ~= nil and tonumber(areaRadiusInput) and tonumber(areaRadiusInput) > 0 then
        draft.areaRadius = tonumber(areaRadiusInput)
    end

    local cleanTarget = self:NormalizeName(draft.targetName)
    if cleanTarget == "" or not draft.targetX or not draft.targetY then
        local errMsg = (Addon.Locale and Addon.Locale:Get("ERR_MISSING_TARGET")) or "Missing target"
        return nil, errMsg
    end

    if not draft.areaCenterX or not draft.areaCenterY then
        draft.areaCenterX, draft.areaCenterY = self:ComputeOffsetCenter(draft.targetX, draft.targetY, draft.areaRadius)
    end

    local cleanTitle = (draft.title or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cleanTitle == "" then
        local nextIndex = #self.savedVars.quests + 1
        cleanTitle = (Addon.Locale and Addon.Locale:Get("DEFAULT_QUEST_TITLE", nextIndex)) or ("Custom Quest #" .. tostring(nextIndex))
    end

    local cleanDesc = (draft.description or ""):gsub("^%s+", ""):gsub("%s+$", "")

    if draft.editingQuestId then
        local existing = self:GetQuestById(draft.editingQuestId)
        if existing then
            existing.title = cleanTitle
            existing.description = cleanDesc
            existing.targetName = cleanTarget
            existing.requiredCount = math.max(1, draft.requiredCount or 1)
            existing.mapId = draft.mapId or 0
            existing.zoneId = draft.zoneId or 0
            existing.mapName = draft.mapName or ""
            existing.targetX = draft.targetX
            existing.targetY = draft.targetY
            existing.areaCenterX = draft.areaCenterX
            existing.areaCenterY = draft.areaCenterY
            existing.areaRadius = draft.areaRadius
            if (existing.currentCount or 0) >= existing.requiredCount then
                existing.completed = true
            else
                existing.completed = false
            end

            self:ResetDraft()
            self:NotifyListeners("QUEST_UPDATED", existing)
            return existing
        end
    end

    local newId = self.savedVars.nextId or (#self.savedVars.quests + 1)
    self.savedVars.nextId = newId + 1

    local newQuest = {
        id = newId,
        title = cleanTitle,
        description = cleanDesc,
        targetName = cleanTarget,
        currentCount = 0,
        requiredCount = math.max(1, draft.requiredCount or 1),
        completed = false,
        mapId = draft.mapId or 0,
        zoneId = draft.zoneId or 0,
        mapName = draft.mapName or "",
        targetX = draft.targetX,
        targetY = draft.targetY,
        areaCenterX = draft.areaCenterX,
        areaCenterY = draft.areaCenterY,
        areaRadius = draft.areaRadius,
    }

    table.insert(self.savedVars.quests, newQuest)
    self.savedVars.activeQuestId = newQuest.id

    self:ResetDraft()
    self:NotifyListeners("QUEST_CREATED", newQuest)
    return newQuest
end

function QuestRepository:ImportQuestFromCode(codeString)
    if not Addon.ShareCodec then
        return nil, "ShareCodec not available"
    end

    local decoded, err = Addon.ShareCodec:DecodeQuest(codeString)
    if not decoded then
        local msg = (Addon.Locale and Addon.Locale:Get("ERR_INVALID_CODE")) or err
        return nil, msg
    end

    local newId = self.savedVars.nextId or (#self.savedVars.quests + 1)
    self.savedVars.nextId = newId + 1

    local cleanTitle = (decoded.title or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cleanTitle == "" then
        cleanTitle = (Addon.Locale and Addon.Locale:Get("DEFAULT_QUEST_TITLE", newId)) or ("Custom Quest #" .. tostring(newId))
    end

    local importedQuest = {
        id = newId,
        title = cleanTitle,
        description = decoded.description or "",
        targetName = self:NormalizeName(decoded.targetName),
        currentCount = 0,
        requiredCount = math.max(1, decoded.requiredCount or 1),
        completed = false,
        mapId = decoded.mapId or 0,
        zoneId = decoded.zoneId or 0,
        mapName = decoded.mapName or "",
        targetX = decoded.targetX,
        targetY = decoded.targetY,
        areaCenterX = decoded.areaCenterX,
        areaCenterY = decoded.areaCenterY,
        areaRadius = decoded.areaRadius,
    }

    table.insert(self.savedVars.quests, importedQuest)
    self.savedVars.activeQuestId = importedQuest.id

    self:NotifyListeners("QUEST_IMPORTED", importedQuest)
    return importedQuest
end

function QuestRepository:ExportQuestToCode(questId)
    local quest = self:GetQuestById(questId)
    if not quest or not Addon.ShareCodec then
        return nil
    end
    return Addon.ShareCodec:EncodeQuest(quest)
end

function QuestRepository:GetAllQuests()
    if not self.savedVars then return {} end
    return self.savedVars.quests or {}
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

    q.currentCount = 0
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

function QuestRepository:RecordTargetEliminated(rawTargetName, playerContext)
    local activeQuest = self:GetActiveQuest()
    if not activeQuest or activeQuest.completed then
        return false, nil, false
    end

    local cleanKilled = self:NormalizeName(rawTargetName):lower()
    local cleanExpected = self:NormalizeName(activeQuest.targetName):lower()
    if cleanKilled == "" or cleanKilled ~= cleanExpected then
        return false, nil, false
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
            return false, nil, false
        end
    end

    activeQuest.currentCount = (activeQuest.currentCount or 0) + 1
    if activeQuest.currentCount >= (activeQuest.requiredCount or 1) then
        activeQuest.currentCount = activeQuest.requiredCount or 1
        activeQuest.completed = true
        if self.savedVars.activeQuestId == activeQuest.id then
            self.savedVars.activeQuestId = nil
        end
        self:NotifyListeners("QUEST_COMPLETED", activeQuest)
    else
        self:NotifyListeners("QUEST_PROGRESS", activeQuest)
    end

    return true, activeQuest, activeQuest.completed
end

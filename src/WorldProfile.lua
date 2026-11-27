-- Ref: docs/adr/0019-protocolo-world-profile-rpqw1-y-sincronizacion-correo.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.WorldProfile = {}
local WorldProfile = Addon.WorldProfile

--- Captures the local account's DLC zone access and current character's discovered POI bitmasks.
function WorldProfile:CaptureLocalSnapshot()
    local esoPlus = (IsESOPlusSubscriber() == true)
    local rawCharName = GetUnitName("player")
    local charName = (Addon.QuestRepository and Addon.QuestRepository.NormalizeCharacterName)
        and Addon.QuestRepository:NormalizeCharacterName(rawCharName)
        or tostring(rawCharName or "")
    local numZones = math.max(0, math.floor(tonumber(GetNumZones()) or 0))

    local dlcBits = {}
    local poiBits = {}
    local totalPois = 0

    for zoneIndex = 1, numZones do
        dlcBits[zoneIndex] = (IsZoneCollectibleLocked(zoneIndex) ~= true)
        local numPois = math.max(0, math.floor(tonumber(GetNumPOIs(zoneIndex)) or 0))
        for poiIndex = 1, numPois do
            local _, _, _, _, _, _, isDiscovered = GetPOIMapInfo(zoneIndex, poiIndex)
            totalPois = totalPois + 1
            poiBits[totalPois] = (isDiscovered == true)
        end
    end

    local dlcMask = Addon.BinaryCodec:EncodeBitsetBase85(dlcBits, numZones)
    local poiMask = Addon.BinaryCodec:EncodeBitsetBase85(poiBits, totalPois)

    return {
        version = Addon.Constants.SHARE_CODEC.WORLD_PROFILE_VERSION or 1,
        esoPlus = esoPlus,
        characterName = charName,
        numZones = numZones,
        dlcBits = dlcBits,
        dlcMask = dlcMask,
        totalPois = totalPois,
        poiBits = poiBits,
        poiMask = poiMask,
        updatedAt = GetTimeStamp() or 0,
    }
end

--- Encodes a captured WorldProfile snapshot into an RPQW1 string.
function WorldProfile:EncodeSnapshot(snapshot)
    return Addon.ShareCodec:EncodeWorldProfile(snapshot)
end

--- Decodes an RPQW1 string into a WorldProfile snapshot table.
function WorldProfile:DecodeSnapshot(codeString)
    return Addon.ShareCodec:DecodeWorldProfile(codeString)
end

--- Captures the local WorldProfile snapshot and returns its RPQW1 code and snapshot table.
function WorldProfile:CaptureAndEncode()
    local snapshot = self:CaptureLocalSnapshot()
    local code, err = self:EncodeSnapshot(snapshot)
    if not code then
        return nil, err
    end
    return code, snapshot
end

--- Returns total POI count across all zones in the current client.
function WorldProfile:GetTotalPoiCount()
    local numZones = math.max(0, math.floor(tonumber(GetNumZones()) or 0))
    local totalPois = 0
    for zoneIndex = 1, numZones do
        totalPois = totalPois + math.max(0, math.floor(tonumber(GetNumPOIs(zoneIndex)) or 0))
    end
    return totalPois, numZones
end

--- Returns the 1-based global POI bit index for (zoneIndex, poiIndex), or nil if invalid.
function WorldProfile:GetGlobalPoiBitIndex(zoneIndex, poiIndex)
    local zIdx = math.floor(tonumber(zoneIndex) or 0)
    local pIdx = math.floor(tonumber(poiIndex) or 0)
    if zIdx < 1 or pIdx < 1 then
        return nil
    end
    local numZones = math.max(0, math.floor(tonumber(GetNumZones()) or 0))
    if zIdx > numZones then
        return nil
    end
    local zonePois = math.max(0, math.floor(tonumber(GetNumPOIs(zIdx)) or 0))
    if pIdx > zonePois then
        return nil
    end
    local offset = 0
    for z = 1, zIdx - 1 do
        offset = offset + math.max(0, math.floor(tonumber(GetNumPOIs(z)) or 0))
    end
    return offset + pIdx
end

--- Finds the nearest POI in `zoneId` to normalized coordinates (normX, normY) and returns poiIndex, isDiscovered.
function WorldProfile:FindNearestZonePOI(zoneId, normX, normY)
    local zId = math.floor(tonumber(zoneId) or 0)
    if zId <= 0 then
        return nil, nil
    end
    local zoneIndex = GetZoneIndex(zId)
    if not zoneIndex or zoneIndex <= 0 then
        return nil, nil
    end
    local numPois = math.max(0, math.floor(tonumber(GetNumPOIs(zoneIndex)) or 0))
    if numPois <= 0 then
        return nil, nil
    end

    local px = tonumber(normX) or 0.5
    local pz = tonumber(normY) or 0.5
    local bestPoiIndex = nil
    local bestDistSq = nil
    local bestDiscovered = false

    for poiIndex = 1, numPois do
        local nx, nz, _, _, _, _, isDiscovered = GetPOIMapInfo(zoneIndex, poiIndex)
        if type(nx) == "number" and type(nz) == "number" then
            local dx = nx - px
            local dz = nz - pz
            local distSq = (dx * dx) + (dz * dz)
            if not bestDistSq or distSq < bestDistSq then
                bestDistSq = distSq
                bestPoiIndex = poiIndex
                bestDiscovered = (isDiscovered == true)
            end
        end
    end

    if not bestPoiIndex then
        return nil, nil
    end
    return bestPoiIndex, bestDiscovered
end

--- Collects unique zoneIds and POI fingerprint checks from a quest or draft table.
function WorldProfile:CollectQuestRequirements(quest)
    local zones = {}
    local seenZones = {}
    local poiChecks = {}

    local function AddZone(z)
        local zid = math.floor(tonumber(z) or 0)
        if zid > 0 and not seenZones[zid] then
            seenZones[zid] = true
            table.insert(zones, zid)
        end
    end

    local function AddPoi(item, fallbackZoneId)
        if type(item) ~= "table" then return end
        local pIdx = math.floor(tonumber(item.poiIndex) or 0)
        local zId = math.floor(tonumber(item.zoneId) or tonumber(fallbackZoneId) or 0)
        if zId > 0 then
            AddZone(zId)
            if pIdx > 0 then
                table.insert(poiChecks, {
                    zoneId = zId,
                    poiIndex = pIdx,
                    masterPoiCompleted = (item.masterPoiCompleted == true),
                })
            end
        end
    end

    if type(quest) == "table" then
        AddZone(quest.zoneId)
        for _, t in ipairs(quest.targets or {}) do
            AddPoi(t, quest.zoneId)
        end
        for _, d in ipairs(quest.discoveries or {}) do
            AddPoi(d, quest.zoneId)
        end
        for _, dlg in ipairs(quest.dialogues or {}) do
            AddPoi(dlg, quest.zoneId)
        end
    end

    return zones, poiChecks
end

--- Validates a quest/draft against a recipient's cached WorldProfile in the Master Editor.
--- Returns { status = "none"|"green"|"yellow"|"red", reason = string, ... }.
function WorldProfile:ValidateQuestForMaster(quest, accountName, charName, worldProfiles)
    local repo = Addon.QuestRepository
    local normAccount = (repo and repo.NormalizeAccountName)
        and repo:NormalizeAccountName(accountName)
        or tostring(accountName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if normAccount == "" then
        return { status = "none", reason = "no_account" }
    end

    local profiles = worldProfiles
        or (repo and repo.savedVars and repo.savedVars.worldProfiles)
        or nil
    local profile = type(profiles) == "table" and profiles[normAccount] or nil
    if type(profile) ~= "table" or type(profile.dlcMask) ~= "string" or profile.dlcMask == "" then
        return { status = "yellow", reason = "no_profile", accountName = normAccount }
    end

    local zones, poiChecks = self:CollectQuestRequirements(quest)
    local totalPois, numZones = self:GetTotalPoiCount()
    local dlcBits = Addon.BinaryCodec:DecodeBitsetBase85(profile.dlcMask, numZones)

    for _, zoneId in ipairs(zones) do
        local zoneIndex = GetZoneIndex(zoneId)
        if zoneIndex and zoneIndex > 0 and dlcBits and dlcBits[zoneIndex] == false then
            return {
                status = "red",
                reason = "missing_dlc",
                accountName = normAccount,
                zoneId = zoneId,
                zoneIndex = zoneIndex,
            }
        end
    end

    local normChar = (repo and repo.NormalizeCharacterName)
        and repo:NormalizeCharacterName(charName)
        or tostring(charName or ""):gsub("^%s+", ""):gsub("%s+$", "")

    if normChar ~= "" and #poiChecks > 0 then
        local charEntry = type(profile.characters) == "table" and profile.characters[normChar] or nil
        if type(charEntry) ~= "table" or type(charEntry.poiMask) ~= "string" or charEntry.poiMask == "" then
            return {
                status = "yellow",
                reason = "no_char_profile",
                accountName = normAccount,
                characterName = normChar,
            }
        end
        local poiBits = Addon.BinaryCodec:DecodeBitsetBase85(charEntry.poiMask, totalPois)
        for _, check in ipairs(poiChecks) do
            local zoneIndex = GetZoneIndex(check.zoneId)
            local bitIdx = zoneIndex and self:GetGlobalPoiBitIndex(zoneIndex, check.poiIndex) or nil
            if bitIdx and poiBits and poiBits[bitIdx] ~= nil then
                local playerCompleted = (poiBits[bitIdx] == true)
                if playerCompleted ~= check.masterPoiCompleted then
                    return {
                        status = "yellow",
                        reason = "phasing_mismatch",
                        accountName = normAccount,
                        characterName = normChar,
                        zoneId = check.zoneId,
                        poiIndex = check.poiIndex,
                    }
                end
            end
        end
    end

    return { status = "green", reason = "compatible", accountName = normAccount, characterName = normChar }
end

--- Validates an OFFERED or ACTIVE quest locally against the player's currently logged-in character.
function WorldProfile:ValidateQuestForLocalPlayer(quest)
    local zones, poiChecks = self:CollectQuestRequirements(quest)

    for _, zoneId in ipairs(zones) do
        local zoneIndex = GetZoneIndex(zoneId)
        if zoneIndex and zoneIndex > 0 and IsZoneCollectibleLocked(zoneIndex) == true then
            return {
                status = "red",
                reason = "missing_dlc",
                zoneId = zoneId,
                zoneIndex = zoneIndex,
            }
        end
    end

    for _, check in ipairs(poiChecks) do
        local zoneIndex = GetZoneIndex(check.zoneId)
        if zoneIndex and zoneIndex > 0 then
            local _, _, _, _, _, _, isDiscovered = GetPOIMapInfo(zoneIndex, check.poiIndex)
            if (isDiscovered == true) ~= check.masterPoiCompleted then
                return {
                    status = "yellow",
                    reason = "phasing_mismatch",
                    zoneId = check.zoneId,
                    poiIndex = check.poiIndex,
                }
            end
        end
    end

    return { status = "green", reason = "compatible" }
end

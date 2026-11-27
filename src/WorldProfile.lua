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

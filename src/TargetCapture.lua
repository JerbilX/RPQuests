-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.TargetCapture = {}
local TargetCapture = Addon.TargetCapture

function TargetCapture:GetPlayerMapContext(forceSync)
    if SetMapToPlayerLocation then
        local mapSceneShowing = SCENE_MANAGER and SCENE_MANAGER.IsShowing and SCENE_MANAGER:IsShowing("worldMap")
        if forceSync or not mapSceneShowing then
            SetMapToPlayerLocation()
        end
    end

    local mapId = (GetCurrentMapId and GetCurrentMapId()) or 0
    local zoneIndex = (GetUnitZoneIndex and GetUnitZoneIndex("player")) or (GetCurrentMapZoneIndex and GetCurrentMapZoneIndex()) or 0
    local zoneId = (zoneIndex and zoneIndex > 0 and GetZoneId and GetZoneId(zoneIndex)) or 0
    local mapName = (GetMapName and GetMapName()) or ""
    local normX, normY = 0.5, 0.5
    if GetMapPlayerPosition then
        local x, y = GetMapPlayerPosition("player")
        if x and y then
            normX = x
            normY = y
        end
    end

    return {
        mapId = mapId,
        zoneId = zoneId,
        mapName = mapName,
        x = normX,
        y = normY,
    }
end

function TargetCapture:ValidateReticleTarget()
    if not DoesUnitExist or not DoesUnitExist("reticleover") then
        return false, Addon.Locale:Get("ALERT_NO_RETICLE_TARGET")
    end

    if IsUnitPlayer and IsUnitPlayer("reticleover") then
        return false, Addon.Locale:Get("ALERT_INVALID_TARGET_PLAYER")
    end

    if IsUnitDead and IsUnitDead("reticleover") then
        return false, Addon.Locale:Get("ALERT_INVALID_TARGET_DEAD")
    end

    if GetUnitReaction then
        local reaction = GetUnitReaction("reticleover")
        if reaction == UNIT_REACTION_PLAYER_ALLY
            or reaction == UNIT_REACTION_COMPANION
            or reaction == UNIT_REACTION_NPC_ALLY then
            return false, Addon.Locale:Get("ALERT_INVALID_TARGET_FRIENDLY")
        end
        if IsUnitAttackable and not IsUnitAttackable("reticleover") and reaction ~= UNIT_REACTION_HOSTILE then
            return false, Addon.Locale:Get("ALERT_INVALID_TARGET_FRIENDLY")
        end
    end

    local rawName = GetUnitName and GetUnitName("reticleover") or ""
    local cleanName = Addon.QuestRepository:NormalizeName(rawName)
    if cleanName == "" then
        return false, Addon.Locale:Get("ALERT_NO_RETICLE_TARGET")
    end

    return true, cleanName
end

function TargetCapture:CaptureFromReticle()
    local isValid, nameOrErr = self:ValidateReticleTarget()
    if not isValid then
        Addon.Announcements:ShowAlert(nameOrErr, true)
        return nil, nameOrErr
    end

    local ctx = self:GetPlayerMapContext(true)
    local draft = Addon.QuestRepository:SetDraftCapturedTarget({
        targetName = nameOrErr,
        mapId = ctx.mapId,
        zoneId = ctx.zoneId,
        mapName = ctx.mapName,
        targetX = ctx.x,
        targetY = ctx.y,
    })

    if draft then
        local locText = (draft.mapName ~= "" and draft.mapName) or Addon.Locale:Get("LABEL_UNKNOWN_LOCATION")
        local displayTarget = draft.lastCapturedDisplay or (draft.targets and draft.targets[1] and draft.targets[1].name) or ""
        local msg = Addon.Locale:Get("ALERT_TARGET_CAPTURED", displayTarget, locText)
        Addon.Announcements:ShowAlert(msg, false)
    end

    return draft
end

-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.Announcements = {}
local Announcements = Addon.Announcements

function Announcements:ShowAlert(message, isError)
    if not message or message == "" then return end

    local soundId = nil
    local category = UI_ALERT_CATEGORY_ALERT
    if isError then
        category = UI_ALERT_CATEGORY_ERROR or UI_ALERT_CATEGORY_ALERT
        soundId = SOUNDS and SOUNDS.GENERAL_ALERT_ERROR or nil
    else
        soundId = SOUNDS and SOUNDS.QUEST_OBJECTIVE_INCREMENT or nil
    end

    if ZO_Alert then
        ZO_Alert(category, soundId, message)
    elseif d then
        d(tostring(message))
    end
end

function Announcements:AnnounceQuestProgress(quest)
    if not quest then return end

    local text = Addon.Locale:Get("CSA_QUEST_PROGRESS", quest.targetName, quest.currentCount or 0, quest.requiredCount or 1)
    local soundId = SOUNDS and SOUNDS.QUEST_OBJECTIVE_INCREMENT or nil

    if CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.CreateMessageParams and CENTER_SCREEN_ANNOUNCE.AddMessageWithParams then
        local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, soundId)
        params:SetText(text)
        if CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_CONDITION_COMPLETED then
            params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_CONDITION_COMPLETED)
        end
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
    elseif CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.AddMessage then
        CENTER_SCREEN_ANNOUNCE:AddMessage(nil, CSA_CATEGORY_SMALL_TEXT, soundId, text)
    else
        self:ShowAlert(text, false)
    end
end

function Announcements:AnnounceQuestCompleted(quest)
    if not quest then return end

    local mainText = Addon.Locale:Get("CSA_QUEST_COMPLETED", quest.title or "")
    local subText = Addon.Locale:Get("OBJECTIVE_KILL_FORMAT", quest.targetName or "", quest.currentCount or 1, quest.requiredCount or 1)
    local soundId = SOUNDS and SOUNDS.QUEST_COMPLETED or nil

    if CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.CreateMessageParams and CENTER_SCREEN_ANNOUNCE.AddMessageWithParams then
        local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, soundId)
        params:SetText(mainText, subText)
        if CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_COMPLETED then
            params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_COMPLETED)
        end
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
    elseif CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.AddMessage then
        CENTER_SCREEN_ANNOUNCE:AddMessage(nil, CSA_CATEGORY_LARGE_TEXT, soundId, mainText)
        if PlaySound and soundId then
            PlaySound(soundId)
        end
    else
        if PlaySound and soundId then
            PlaySound(soundId)
        end
        self:ShowAlert(mainText, false)
    end
end

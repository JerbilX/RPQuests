-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

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

function Announcements:AnnounceQuestProgress(quest, matchedTarget)
    if not quest then return end

    local tName = (matchedTarget and matchedTarget.name) or quest.targetName or ""
    local tCur = (matchedTarget and matchedTarget.currentCount) or quest.currentCount or 0
    local tReq = (matchedTarget and matchedTarget.requiredCount) or quest.requiredCount or 1

    local text = Addon.Locale:Get("CSA_QUEST_PROGRESS", tName, tCur, tReq)
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

function Announcements:AnnounceQuestCompleted(quest, matchedTarget)
    if not quest then return end

    local mainText = Addon.Locale:Get("CSA_QUEST_COMPLETED", quest.title or "")
    local targets = (Addon.QuestRepository and Addon.QuestRepository:EnsureQuestTargets(quest)) or {}
    local subText
    if #targets == 1 then
        local t = targets[1]
        subText = Addon.Locale:Get("OBJECTIVE_KILL_FORMAT", t.name or "", t.currentCount or 1, t.requiredCount or 1)
    elseif matchedTarget and matchedTarget.name then
        subText = Addon.Locale:Get("OBJECTIVE_KILL_FORMAT", matchedTarget.name, matchedTarget.currentCount or 1, matchedTarget.requiredCount or 1)
    else
        subText = Addon.Locale:Get("OBJECTIVE_KILL_FORMAT", quest.targetName or "", quest.currentCount or 1, quest.requiredCount or 1)
    end
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

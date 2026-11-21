-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.MailTransport = {}
local MailTransport = Addon.MailTransport

local LISTENER_SEND_SUCCESS = "RPQuest_Mail_SendSuccess"
local LISTENER_SEND_FAILED = "RPQuest_Mail_SendFailed"
local LISTENER_INBOX_UPDATE = "RPQuest_Mail_InboxUpdate"
local LISTENER_MAIL_READABLE = "RPQuest_Mail_Readable"
local LISTENER_MAIL_REMOVED = "RPQuest_Mail_Removed"

local MAX_RECIPIENTS = 4
local DEFAULT_MAX_BODY_CHARS = 700
local QUEST_SUBJECT_PREFIX = "[RPQuest] "
local COMPLETION_SUBJECT_PREFIX = "[RPQuest:Done] "

function MailTransport:Initialize()
    self._listeners = self._listeners or {}
    self._sendQueue = {}
    self._isSending = false
    self._sendTotal = 0
    self._sendDone = 0
    self._sendSuccessCount = 0
    self._sendFailCount = 0
    self._openedMailbox = false
    self._receivedMails = {}
    self._receivedById = {}
    self._dismissedMailIds = {}

    if not self._eventsRegistered and EVENT_MANAGER then
        if EVENT_MAIL_SEND_SUCCESS then
            EVENT_MANAGER:RegisterForEvent(LISTENER_SEND_SUCCESS, EVENT_MAIL_SEND_SUCCESS, function(_, playerName)
                self:OnMailSendSuccess(playerName)
            end)
        end
        if EVENT_MAIL_SEND_FAILED then
            EVENT_MANAGER:RegisterForEvent(LISTENER_SEND_FAILED, EVENT_MAIL_SEND_FAILED, function(_, reason)
                self:OnMailSendFailed(reason)
            end)
        end
        if EVENT_MAIL_INBOX_UPDATE then
            EVENT_MANAGER:RegisterForEvent(LISTENER_INBOX_UPDATE, EVENT_MAIL_INBOX_UPDATE, function()
                self:ScanInbox()
            end)
        end
        if EVENT_MAIL_READABLE then
            EVENT_MANAGER:RegisterForEvent(LISTENER_MAIL_READABLE, EVENT_MAIL_READABLE, function(_, mailId)
                self:OnMailReadable(mailId)
            end)
        end
        if EVENT_MAIL_REMOVED then
            EVENT_MANAGER:RegisterForEvent(LISTENER_MAIL_REMOVED, EVENT_MAIL_REMOVED, function(_, mailId)
                self:OnMailRemoved(mailId)
            end)
        end
        self._eventsRegistered = true
    end

    if not self._repoListenerAdded and Addon.QuestRepository and Addon.QuestRepository.RegisterListener then
        Addon.QuestRepository:RegisterListener(function(evType, payload)
            if evType == "QUEST_COMPLETED" and type(payload) == "table" then
                if Addon.QuestRepository:GetSetting("autoSendCompletionMail")
                    and type(payload.senderDisplayName) == "string"
                    and payload.senderDisplayName ~= ""
                    and not payload.completionReported then
                    self:SendCompletionReport(payload)
                end
            end
        end)
        self._repoListenerAdded = true
    end

    self.isInitialized = true
end

function MailTransport:RegisterListener(fn)
    if type(fn) ~= "function" then return end
    self._listeners = self._listeners or {}
    table.insert(self._listeners, fn)
end

function MailTransport:NotifyListeners(eventType, payload)
    if not self._listeners then return end
    for _, fn in ipairs(self._listeners) do
        fn(eventType, payload)
    end
end

function MailTransport:GetMaxBodyLength()
    return (type(MAIL_MAX_BODY_CHARACTERS) == "number" and MAIL_MAX_BODY_CHARACTERS > 0)
        and MAIL_MAX_BODY_CHARACTERS
        or DEFAULT_MAX_BODY_CHARS
end

function MailTransport:ComposeQuestMailBody(roleMessage, questCode)
    local code = type(questCode) == "string" and questCode:gsub("^%s+", ""):gsub("%s+$", "") or ""
    local msg = type(roleMessage) == "string" and roleMessage:gsub("^%s+", ""):gsub("%s+$", "") or ""
    local body = (msg ~= "") and (msg .. "\n\n" .. code) or code
    local maxLen = self:GetMaxBodyLength()
    return body, #body, maxLen, (#body <= maxLen)
end

function MailTransport:ParseRecipients(rawInput)
    if type(rawInput) ~= "string" then
        return {}, "ERR_MAIL_NO_RECIPIENTS"
    end

    local recipients = {}
    local seen = {}
    for token in string.gmatch(rawInput, "[^,;\r\n]+") do
        local clean = token:gsub("^%s+", ""):gsub("%s+$", "")
        if clean ~= "" then
            if clean:sub(1, 1) ~= "@" then
                clean = "@" .. clean
            end
            local key = clean:lower()
            if not seen[key] then
                seen[key] = true
                table.insert(recipients, clean)
            end
        end
    end

    if #recipients == 0 then
        return {}, "ERR_MAIL_NO_RECIPIENTS"
    end
    if #recipients > MAX_RECIPIENTS then
        return {}, "ERR_MAIL_TOO_MANY_RECIPIENTS"
    end
    return recipients, nil
end

function MailTransport:IsNativeMailboxOpen()
    if not SCENE_MANAGER or not SCENE_MANAGER.IsShowing then
        return false
    end
    return SCENE_MANAGER:IsShowing("mailInbox")
        or SCENE_MANAGER:IsShowing("mailSend")
        or false
end

function MailTransport:EnsureMailboxOpen()
    if not self:IsNativeMailboxOpen() and RequestOpenMailbox then
        RequestOpenMailbox()
        self._openedMailbox = true
    end
end

function MailTransport:CloseMailboxIfOwned()
    if self._openedMailbox and not self._isSending and not self:IsNativeMailboxOpen() and CloseMailbox then
        CloseMailbox()
        self._openedMailbox = false
    end
end

function MailTransport:SendQuestToRecipients(quest, rawRecipients, roleMessage)
    if type(quest) ~= "table" then
        return false, "ERR_INVALID_CODE"
    end
    if self._isSending then
        return false, "ERR_MAIL_SEND_IN_PROGRESS"
    end

    local recipients, recErr = self:ParseRecipients(rawRecipients)
    if recErr then
        return false, recErr
    end

    local questCode = Addon.QuestRepository:ExportQuestToCode(quest.id)
    if not questCode or questCode == "" then
        return false, "ERR_INVALID_CODE"
    end

    local body, len, maxLen, fits = self:ComposeQuestMailBody(roleMessage, questCode)
    if not fits then
        return false, "ERR_MAIL_BODY_TOO_LONG", len, maxLen
    end

    if not SendMail then
        return false, "ERR_MAIL_API_UNAVAILABLE"
    end

    local subject = QUEST_SUBJECT_PREFIX .. (quest.title or "RPQuest")
    self._sendQueue = {}
    for _, to in ipairs(recipients) do
        table.insert(self._sendQueue, {
            to = to,
            subject = subject,
            body = body,
        })
    end

    self._isSending = true
    self._sendTotal = #self._sendQueue
    self._sendDone = 0
    self._sendSuccessCount = 0
    self._sendFailCount = 0

    self:EnsureMailboxOpen()
    self:DispatchNextQueuedMail()
    return true, nil, len, maxLen
end

function MailTransport:DispatchNextQueuedMail()
    if not self._isSending then return end

    local nextItem = table.remove(self._sendQueue, 1)
    if not nextItem then
        self._isSending = false
        local summary = {
            total = self._sendTotal,
            sent = self._sendSuccessCount,
            failed = self._sendFailCount,
        }
        self:CloseMailboxIfOwned()
        self:NotifyListeners("MAIL_SEND_COMPLETE", summary)
        return
    end

    self._currentSendItem = nextItem
    self._currentSendTarget = nextItem.to
    self:NotifyListeners("MAIL_SEND_PROGRESS", {
        current = self._sendDone + 1,
        total = self._sendTotal,
        to = nextItem.to,
    })
    SendMail(nextItem.to, nextItem.subject, nextItem.body)
end

function MailTransport:SendCompletionReport(quest)
    if type(quest) ~= "table" or not quest.completed then
        return false, "ERR_INVALID_CODE"
    end
    local recipient = type(quest.senderDisplayName) == "string"
        and quest.senderDisplayName:gsub("^%s+", ""):gsub("%s+$", "")
        or ""
    if recipient == "" then
        return false, "ERR_MAIL_NO_RECIPIENTS"
    end
    if not SendMail then
        return false, "ERR_MAIL_API_UNAVAILABLE"
    end

    local rpqc1Code, err = Addon.QuestRepository:ExportCompletionCode(quest.id)
    if not rpqc1Code or rpqc1Code == "" then
        return false, err or "ERR_INVALID_CODE"
    end

    local subject = COMPLETION_SUBJECT_PREFIX .. (quest.title or "RPQuest")
    local item = {
        to = recipient,
        subject = subject,
        body = rpqc1Code,
        completionQuestId = quest.id,
    }

    if self._isSending then
        table.insert(self._sendQueue, item)
        self._sendTotal = self._sendTotal + 1
        return true
    end

    self._sendQueue = { item }
    self._isSending = true
    self._sendTotal = 1
    self._sendDone = 0
    self._sendSuccessCount = 0
    self._sendFailCount = 0

    self:EnsureMailboxOpen()
    self:DispatchNextQueuedMail()
    return true
end

function MailTransport:OnMailSendSuccess(playerName)
    if not self._isSending then return end
    if self._currentSendItem and self._currentSendItem.completionQuestId then
        Addon.QuestRepository:MarkCompletionReported(self._currentSendItem.completionQuestId)
        self:NotifyListeners("MAIL_COMPLETION_SENT", {
            questId = self._currentSendItem.completionQuestId,
            to = self._currentSendItem.to,
        })
    end
    self._sendDone = self._sendDone + 1
    self._sendSuccessCount = self._sendSuccessCount + 1
    self:DispatchNextQueuedMail()
end

function MailTransport:OnMailSendFailed(reason)
    if not self._isSending then return end
    self._sendDone = self._sendDone + 1
    self._sendFailCount = self._sendFailCount + 1
    self:NotifyListeners("MAIL_SEND_ERROR", {
        to = self._currentSendTarget,
        reason = reason,
    })
    self:DispatchNextQueuedMail()
end

function MailTransport:ParseQuestMailBody(body)
    if type(body) ~= "string" or body == "" then
        return nil, ""
    end

    local sIdx, eIdx, code = string.find(body, "(RPQ[123]:[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]:[^%s]+)")
    if not code then
        return nil, ""
    end

    local before = (sIdx > 1) and string.sub(body, 1, sIdx - 1) or ""
    local roleMessage = before:gsub("^%s+", ""):gsub("%s+$", "")
    return code, roleMessage
end

function MailTransport:IsQuestMailSubject(subject)
    if type(subject) ~= "string" then return false end
    if string.sub(subject, 1, #COMPLETION_SUBJECT_PREFIX) == COMPLETION_SUBJECT_PREFIX then
        return false
    end
    return string.sub(subject, 1, #QUEST_SUBJECT_PREFIX) == QUEST_SUBJECT_PREFIX
end

function MailTransport:IsCompletionMailSubject(subject)
    if type(subject) ~= "string" then return false end
    return string.sub(subject, 1, #COMPLETION_SUBJECT_PREFIX) == COMPLETION_SUBJECT_PREFIX
end

function MailTransport:ParseCompletionMailBody(body)
    if type(body) ~= "string" or body == "" then
        return nil
    end
    local _, _, code = string.find(body, "(RPQC1:[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]:[^%s]+)")
    return code
end

function MailTransport:ProcessCompletionMail(mailId, senderDisplayName, subject, body)
    local idKey = tostring(mailId)
    if self._dismissedMailIds and self._dismissedMailIds[idKey] then
        return false
    end

    local rpqc1Code = self:ParseCompletionMailBody(body)
    if not rpqc1Code then
        return false
    end

    local preparedQuests = Addon.QuestRepository:GetQuestsByRole(Addon.Constants.QUEST_ROLE.PREPARED)
    for _, q in ipairs(preparedQuests) do
        local ok, res = Addon.QuestRepository:ValidateCompletionCode(q.id, rpqc1Code)
        if ok and type(res) == "table" then
            local _, isNew = Addon.QuestRepository:RecordMailDelivery(q.id, senderDisplayName, res)
            if isNew and Addon.Announcements and Addon.Announcements.ShowAlert then
                local who = (type(senderDisplayName) == "string" and senderDisplayName ~= "")
                    and senderDisplayName
                    or (res.characterName or "")
                Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_MAIL_DELIVERY_VALIDATED", who, q.title or ""), false)
            end
            if Addon.QuestRepository:GetSetting("autoDeleteMail") and DeleteMail then
                DeleteMail(mailId)
            else
                self._dismissedMailIds[idKey] = true
            end
            return true
        end
    end
    return false
end

function MailTransport:UpsertReceivedMail(mailId, senderDisplayName, senderCharacterName, subject, body, secsSinceReceived)
    local idKey = tostring(mailId)
    if self._dismissedMailIds and self._dismissedMailIds[idKey] then
        return false
    end

    local code, roleMessage = self:ParseQuestMailBody(body)
    if not code then
        return false
    end

    local decoded, errKey = Addon.ShareCodec:DecodeQuest(code)
    if not decoded then
        return false, errKey
    end

    local entry = {
        mailId = mailId,
        idKey = idKey,
        senderDisplayName = senderDisplayName or "",
        senderCharacterName = senderCharacterName or "",
        subject = subject or "",
        title = decoded.title or "",
        roleMessage = roleMessage,
        questCode = code,
        decodedQuest = decoded,
        secsSinceReceived = secsSinceReceived or 0,
    }

    local existingIdx = self._receivedById[idKey]
    if existingIdx then
        self._receivedMails[existingIdx] = entry
    else
        table.insert(self._receivedMails, entry)
        self._receivedById[idKey] = #self._receivedMails
    end
    self:NotifyListeners("MAIL_INBOX_UPDATED", self._receivedMails)
    return true
end

function MailTransport:RebuildReceivedIndex()
    self._receivedById = {}
    for idx, entry in ipairs(self._receivedMails) do
        self._receivedById[entry.idKey] = idx
    end
end

function MailTransport:ScanInbox(requestOpen)
    if requestOpen then
        self:EnsureMailboxOpen()
    end
    if not GetNextMailId or not GetMailItemInfo then
        return self._receivedMails
    end

    local mailId = GetNextMailId(nil)
    while mailId ~= nil do
        local senderDisplayName, senderCharacterName, subject, _, _, _, _, _, _, _, _, _, secsSinceReceived = GetMailItemInfo(mailId)
        local isQuest = self:IsQuestMailSubject(subject)
        local isCompletion = (not isQuest) and self:IsCompletionMailSubject(subject)
        if isQuest or isCompletion then
            local body = ReadMail and ReadMail(mailId) or ""
            if type(body) == "string" and body ~= "" then
                if isQuest then
                    self:UpsertReceivedMail(mailId, senderDisplayName, senderCharacterName, subject, body, secsSinceReceived)
                else
                    self:ProcessCompletionMail(mailId, senderDisplayName, subject, body)
                end
            elseif RequestReadMail then
                RequestReadMail(mailId)
            end
        end
        mailId = GetNextMailId(mailId)
    end

    return self._receivedMails
end

function MailTransport:OnMailReadable(mailId)
    if not mailId or not GetMailItemInfo or not ReadMail then return end
    local senderDisplayName, senderCharacterName, subject, _, _, _, _, _, _, _, _, _, secsSinceReceived = GetMailItemInfo(mailId)
    local isQuest = self:IsQuestMailSubject(subject)
    local isCompletion = (not isQuest) and self:IsCompletionMailSubject(subject)
    if isQuest or isCompletion then
        local body = ReadMail(mailId)
        if type(body) == "string" and body ~= "" then
            if isQuest then
                self:UpsertReceivedMail(mailId, senderDisplayName, senderCharacterName, subject, body, secsSinceReceived)
            else
                self:ProcessCompletionMail(mailId, senderDisplayName, subject, body)
            end
        end
    end
end

function MailTransport:OnMailRemoved(mailId)
    if not mailId then return end
    local idKey = tostring(mailId)
    local idx = self._receivedById and self._receivedById[idKey]
    if idx then
        table.remove(self._receivedMails, idx)
        self:RebuildReceivedIndex()
        self:NotifyListeners("MAIL_INBOX_UPDATED", self._receivedMails)
    end
end

function MailTransport:GetReceivedMails()
    return self._receivedMails or {}
end

function MailTransport:GetReceivedMailCount()
    return #(self._receivedMails or {})
end

function MailTransport:RemoveEntryById(mailId)
    local idKey = tostring(mailId)
    local idx = self._receivedById and self._receivedById[idKey]
    if not idx then return nil end
    local entry = table.remove(self._receivedMails, idx)
    self:RebuildReceivedIndex()
    return entry
end

function MailTransport:AcceptReceivedMail(mailId)
    local entry = self:RemoveEntryById(mailId)
    if not entry then
        return nil, "ERR_INVALID_CODE"
    end

    local imported, err = Addon.QuestRepository:ImportQuestFromCode(entry.questCode, entry.senderDisplayName)
    if not imported then
        table.insert(self._receivedMails, entry)
        self:RebuildReceivedIndex()
        return nil, err
    end

    if Addon.QuestRepository:GetSetting("autoDeleteMail") and DeleteMail then
        DeleteMail(entry.mailId)
    else
        self._dismissedMailIds[entry.idKey] = true
    end

    self:NotifyListeners("MAIL_INBOX_UPDATED", self._receivedMails)
    return imported, nil, entry
end

function MailTransport:RejectReceivedMail(mailId)
    local entry = self:RemoveEntryById(mailId)
    if not entry then
        return false
    end

    if Addon.QuestRepository:GetSetting("autoDeleteMail") and DeleteMail then
        DeleteMail(entry.mailId)
    else
        self._dismissedMailIds[entry.idKey] = true
    end

    self:NotifyListeners("MAIL_INBOX_UPDATED", self._receivedMails)
    return true
end

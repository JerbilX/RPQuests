-- ============================================================================
-- RPQuest Test Suite: MailTransport Queue, Direct Send, Normalization & Metadata
-- ============================================================================
return function(T)
    local RunTest = T.RunTest
    local AssertEqual = T.AssertEqual
    local AssertTrue = T.AssertTrue
    local mockState = T.mockState

    RunTest("MailTransport: sequential send queue, body limit, inbox parsing, Accept/Reject and autoDeleteMail (Issue #101)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()

        -- Mock ESO Mail API
        local sentMails = {}
        local deletedMails = {}
        local openCalls = 0
        local closeCalls = 0
        local nativeMailOpen = false

        local origSendMail = _G.SendMail
        local origReqOpen = _G.RequestOpenMailbox
        local origClose = _G.CloseMailbox
        local origGetNext = _G.GetNextMailId
        local origGetInfo = _G.GetMailItemInfo
        local origReqRead = _G.RequestReadMail
        local origReadMail = _G.ReadMail
        local origDeleteMail = _G.DeleteMail
        local origMaxBody = _G.MAIL_MAX_BODY_CHARACTERS
        local origScene = _G.SCENE_MANAGER

        _G.MAIL_MAX_BODY_CHARACTERS = 700
        _G.SendMail = function(to, subject, body)
            table.insert(sentMails, { to = to, subject = subject, body = body })
        end
        _G.RequestOpenMailbox = function() openCalls = openCalls + 1 end
        _G.CloseMailbox = function() closeCalls = closeCalls + 1 end
        _G.DeleteMail = function(mailId) table.insert(deletedMails, mailId) end
        _G.SCENE_MANAGER = {
            IsShowing = function(_, name)
                return nativeMailOpen and (name == "mailInbox" or name == "mailSend")
            end,
        }

        -- Create a prepared quest
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Guardia",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        local q = RPQuest.QuestRepository:SaveDraft("Misión por Correo", "Descripción corta")

        -- 1. Reject > 1 recipient (1-to-1 model)
        local okMany, errMany = RPQuest.MailTransport:SendQuestToRecipients(q, "@A, @B", "Hola")
        AssertEqual(okMany, false, "Rejects more than 1 recipient")
        AssertEqual(errMany, "ERR_MAIL_TOO_MANY_RECIPIENTS", "Returns too many recipients error")

        -- 2. Reject body exceeding max multi-part limit (MAX_MAIL_PARTS * chunkSize)
        local hugeMsg = string.rep("A", 4200)
        local okLong, errLong = RPQuest.MailTransport:SendQuestToRecipients(q, "@PlayerOne", hugeMsg)
        AssertEqual(okLong, false, "Rejects mail exceeding multi-part mail limit")
        AssertEqual(errLong, "ERR_MAIL_BODY_TOO_LONG", "Returns body too long error")

        -- 3. Single recipient send (waits for EVENT_MAIL_OPEN_MAILBOX, normalizes @ prefix, deduplicates)
        local okSend, errSend = RPQuest.MailTransport:SendQuestToRecipients(q, "One, @one", "Mensaje de rol.")
        AssertEqual(okSend, true, "Single recipient mail send started: " .. tostring(errSend))
        AssertEqual(openCalls, 1, "RequestOpenMailbox called when native UI closed")
        AssertEqual(#sentMails, 0, "SendMail deferred until EVENT_MAIL_OPEN_MAILBOX fires")
        AssertEqual(closeCalls, 0, "CloseMailbox not called while waiting for mailbox open")

        RPQuest.MailTransport:OnMailboxOpened()
        AssertEqual(#sentMails, 1, "Mail dispatched after EVENT_MAIL_OPEN_MAILBOX")
        AssertEqual(sentMails[1].to, "@One", "Recipient normalized with @ prefix")
        AssertEqual(sentMails[1].subject, "[RPQuest] Misión por Correo", "Subject uses [RPQuest] prefix")

        RPQuest.MailTransport:OnMailSendSuccess("@One")
        AssertEqual(closeCalls, 1, "CloseMailbox called after queue finishes when native UI is closed")

        -- 3b. Unexpected mailbox close mid-send aborts cleanly without hanging
        local lastComplete = nil
        RPQuest.MailTransport:RegisterListener(function(evType, payload)
            if evType == "MAIL_SEND_COMPLETE" then
                lastComplete = payload
            end
        end)
        local okAbort = RPQuest.MailTransport:SendQuestToRecipients(q, "@One", "Hola")
        AssertEqual(okAbort, true, "Second send batch started")
        RPQuest.MailTransport:OnMailboxClosed()
        AssertEqual(RPQuest.MailTransport._isSending, false, "Sending flag cleared on unexpected mailbox close")
        AssertTrue(lastComplete ~= nil and lastComplete.failed == 1 and lastComplete.sent == 0, "MAIL_SEND_COMPLETE reports remaining mail as failed")

        -- 4. Native mailbox open coordination: do not close if native UI is showing
        nativeMailOpen = true
        openCalls = 0
        closeCalls = 0
        local okNative = RPQuest.MailTransport:SendQuestToRecipients(q, "@Four", "")
        AssertEqual(okNative, true, "Send succeeds when native mailbox already open")
        AssertEqual(openCalls, 0, "RequestOpenMailbox skipped when native UI open")
        RPQuest.MailTransport:OnMailSendSuccess("@Four")
        AssertEqual(closeCalls, 0, "CloseMailbox NOT called when native mailbox UI is open")

        -- 5. Inbox scanning & async EVENT_MAIL_READABLE parsing + Accept/Reject + autoDeleteMail
        local rpq3Code = RPQuest.QuestRepository:ExportQuestToCode(q.id)
        local mockInbox = {
            [101] = { sender = "@QuestMaster", char = "Master", subject = "[RPQuest] Misión por Correo", body = "Te encomiendo esta tarea.\n\n" .. rpq3Code },
            [102] = { sender = "@Other", char = "Other", subject = "Normal Mail", body = "Nothing here" },
            [103] = { sender = "@RejectMe", char = "Reject", subject = "[RPQuest] Otra", body = rpq3Code },
        }
        _G.GetNextMailId = function(lastId)
            if lastId == nil then return 101 end
            if lastId == 101 then return 102 end
            if lastId == 102 then return 103 end
            return nil
        end
        _G.GetMailItemInfo = function(id)
            local m = mockInbox[id]
            if not m then return nil end
            return m.sender, m.char, m.subject, "", true, false, false, false, 0, 0, 0, 30, 10, 0
        end
        _G.ReadMail = function(id)
            if id == 103 then return "" end -- simulate async load for 103
            return mockInbox[id] and mockInbox[id].body or ""
        end
        _G.RequestReadMail = function(id)
            -- simulate EVENT_MAIL_READABLE later
        end

        RPQuest.MailTransport:ScanInbox(false)
        AssertEqual(RPQuest.MailTransport:GetReceivedMailCount(), 0, "101 auto-ingested from inbox, 102 ignored")
        local receivedQuests = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
        AssertEqual(#receivedQuests, 1, "101 auto-ingested as OFFERED quest")
        AssertEqual(RPQuest.QuestRepository:IsOfferedQuest(receivedQuests[1]), true, "Ingested quest has OFFERED status")
        AssertEqual(receivedQuests[1].senderDisplayName, "@QuestMaster", "Sender displayName preserved")
        AssertEqual(#deletedMails, 1, "DeleteMail called on auto-ingest when autoDeleteMail is true")
        AssertEqual(deletedMails[1], 101, "Deleted mail 101")

        -- Simulate async readable for 103 with autoDeleteMail = false
        RPQuest.QuestRepository:SetSetting("autoDeleteMail", false)
        _G.ReadMail = function(id) return mockInbox[id] and mockInbox[id].body or "" end
        RPQuest.MailTransport:OnMailReadable(103)
        receivedQuests = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
        AssertEqual(#receivedQuests, 2, "103 auto-ingested via OnMailReadable")
        AssertEqual(#deletedMails, 1, "DeleteMail NOT called when autoDeleteMail is false")

        -- Re-scan does not duplicate 103
        RPQuest.MailTransport:ScanInbox(false)
        AssertEqual(#RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED), 2, "No duplicate on re-scan")

        -- Accept 101 and Reject 103
        local accOk = RPQuest.QuestRepository:AcceptOfferedQuest(receivedQuests[1].id)
        AssertEqual(accOk, true, "AcceptOfferedQuest succeeds")
        AssertEqual(RPQuest.QuestRepository:IsOfferedQuest(receivedQuests[1]), false, "Accepted quest is no longer OFFERED")
        local rejOk = RPQuest.QuestRepository:RejectOfferedQuest(receivedQuests[2].id)
        AssertEqual(rejOk, true, "RejectOfferedQuest succeeds")
        AssertEqual(#RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED), 1, "Rejected quest removed from list")

        -- Restore globals
        _G.SendMail = origSendMail
        _G.RequestOpenMailbox = origReqOpen
        _G.CloseMailbox = origClose
        _G.GetNextMailId = origGetNext
        _G.GetMailItemInfo = origGetInfo
        _G.RequestReadMail = origReqRead
        _G.ReadMail = origReadMail
        _G.DeleteMail = origDeleteMail
        _G.MAIL_MAX_BODY_CHARACTERS = origMaxBody
        _G.SCENE_MANAGER = origScene
    end)

    RunTest("39. Master single recipient persistence, direct send, and status transitions (Issue #145)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()
        RPQuest.JournalTab:Initialize()

        -- Create prepared quest with single recipient (normalized with @)
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Mercenario",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        local prepared = RPQuest.QuestRepository:SaveDraft("Contrato Directo", "Cuerpo", nil, "", false, "PlayerTarget")
        AssertEqual(prepared.recipientAccount, "@PlayerTarget", "Recipient normalized and persisted on prepared quest")

        local lifecycle1 = RPQuest.QuestRepository:GetQuestLifecycle(prepared)
        local res1 = RPQuest.QuestRepository:GetQuestResolution(prepared)
        AssertEqual(lifecycle1, "draft", "Initial lifecycle is draft")
        AssertEqual(res1, nil, "Initial resolution is nil")

        RPQuest.JournalTab:SelectQuest(prepared.id)
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.btnSendDirect:IsHidden(), false, "Direct send button visible on prepared quest")
        AssertTrue(RPQuest.JournalTab.detailStatus:GetText():find("@PlayerTarget", 1, true) ~= nil, "Detail status shows assigned recipient in draft")

        -- Direct send from prepared quest detail view
        local sentMails = {}
        local origSendMail = _G.SendMail
        local origReqOpen = _G.RequestOpenMailbox
        local origClose = _G.CloseMailbox
        _G.SendMail = function(to, subject, body) table.insert(sentMails, { to = to, subject = subject, body = body }) end
        _G.RequestOpenMailbox = function() end
        _G.CloseMailbox = function() end

        local okSend = RPQuest.JournalTab:SendSelectedPreparedQuest()
        AssertEqual(okSend, true, "SendSelectedPreparedQuest starts send directly")
        RPQuest.MailTransport:OnMailboxOpened()
        AssertEqual(#sentMails, 1, "Mail dispatched to assigned recipient")
        AssertEqual(sentMails[1].to, "@PlayerTarget", "Mail sent to @PlayerTarget")
        RPQuest.MailTransport:OnMailSendSuccess("@PlayerTarget")

        local lifecycle2 = RPQuest.QuestRepository:GetQuestLifecycle(prepared)
        local res2 = RPQuest.QuestRepository:GetQuestResolution(prepared)
        AssertEqual(lifecycle2, "sent", "Lifecycle transitions to sent after mail dispatch")
        AssertEqual(res2, nil, "Resolution remains nil until player responds")
        AssertTrue(RPQuest.JournalTab.detailStatus:GetText():find("@PlayerTarget", 1, true) ~= nil, "Detail status shows sent recipient")

        -- Transition to completed
        RPQuest.QuestRepository:RecordMailDelivery(prepared.id, "@PlayerTarget", {
            characterName = "TargetChar",
            completedAt = 999,
            completed = true,
            wasDetected = false,
        })
        local res3 = RPQuest.QuestRepository:GetQuestResolution(prepared)
        AssertEqual(RPQuest.QuestRepository:GetQuestLifecycle(prepared), "sent", "Lifecycle remains sent")
        AssertEqual(res3, "completed", "Resolution transitions to completed")
        AssertTrue(RPQuest.JournalTab.detailStatus:GetText():find("TargetChar", 1, true) ~= nil, "Detail status includes character name")

        -- Transition to rejected
        RPQuest.QuestRepository:RecordMailDelivery(prepared.id, "@PlayerTarget", {
            characterName = "TargetChar",
            completedAt = 1000,
            completed = false,
        })
        local res4 = RPQuest.QuestRepository:GetQuestResolution(prepared)
        AssertEqual(RPQuest.QuestRepository:GetQuestLifecycle(prepared), "sent", "Lifecycle remains sent")
        AssertEqual(res4, "rejected", "Resolution transitions to rejected")

        _G.SendMail = origSendMail
        _G.RequestOpenMailbox = origReqOpen
        _G.CloseMailbox = origClose
    end)

    RunTest("40. Issue #162: Completion mail normalization, mailbox retry, self-mail & error alerts", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()
        RPQuest.JournalTab:Initialize()

        local sentMails = {}
        local openCalls = 0
        local nativeMailOpen = false
        local origSendMail = _G.SendMail
        local origReqOpen = _G.RequestOpenMailbox
        local origClose = _G.CloseMailbox
        local origGetNext = _G.GetNextMailId
        local origGetInfo = _G.GetMailItemInfo
        local origReadMail = _G.ReadMail
        local origDeleteMail = _G.DeleteMail
        local origScene = _G.SCENE_MANAGER
        local origShowAlert = RPQuest.Announcements.ShowAlert

        local alerts = {}
        RPQuest.Announcements.ShowAlert = function(_, msg, isErr)
            table.insert(alerts, { msg = msg, isErr = isErr })
        end

        _G.SCENE_MANAGER = {
            IsShowing = function(_, name)
                return nativeMailOpen and (name == "mailInbox" or name == "mailSend")
            end,
        }
        _G.SendMail = function(to, subject, body)
            table.insert(sentMails, { to = to, subject = subject, body = body })
        end
        _G.RequestOpenMailbox = function() openCalls = openCalls + 1 end
        _G.CloseMailbox = function() end
        _G.DeleteMail = function() end

        -- 1. senderDisplayName without @ and with spaces is normalized on import and completion send
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Lobo",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        local prep = RPQuest.QuestRepository:SaveDraft("Misión Normalizada", "Desc")
        local code = RPQuest.QuestRepository:ExportQuestToCode(prep.id)

        _G.GetNextMailId = function(lastId) return (lastId == nil) and 401 or nil end
        _G.GetMailItemInfo = function(id)
            if id == 401 then return "  QuestMaster  ", "MasterChar", "[RPQuest] Misión Normalizada", "", true, false, false, false, 0, 0, 0, 30, 1, 0 end
            return nil
        end
        _G.ReadMail = function(id) return (id == 401) and code or "" end

        RPQuest.MailTransport:ScanInbox(false)
        local received = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
        local q = received[1]
        AssertEqual(q.senderDisplayName, "@QuestMaster", "senderDisplayName normalized on import")
        RPQuest.QuestRepository:AcceptOfferedQuest(q.id)
        RPQuest.MailTransport:OnMailboxOpened()
        RPQuest.MailTransport:OnMailSendSuccess("@QuestMaster")
        sentMails = {}
        openCalls = 0

        -- 2. Simulate native scene showing before EVENT_MAIL_OPEN_MAILBOX -> MAIL_SEND_RESULT_MAILBOX_NOT_OPEN retry
        nativeMailOpen = true
        RPQuest.QuestRepository:SetActiveQuest(q.id)
        RPQuest.QuestRepository:RecordTargetEliminated("Lobo", { mapId = 32, zoneId = 381, x = q.areaCenterX, y = q.areaCenterY })
        AssertEqual(#sentMails, 1, "Initial SendMail attempted when native UI reported open")
        AssertEqual(sentMails[1].to, "@QuestMaster", "Normalized @QuestMaster used as recipient")

        -- Server rejects first attempt with MAIL_SEND_RESULT_MAILBOX_NOT_OPEN -> should re-queue and RequestOpenMailbox
        RPQuest.MailTransport:OnMailSendFailed(MAIL_SEND_RESULT_MAILBOX_NOT_OPEN)
        AssertEqual(openCalls, 1, "RequestOpenMailbox called on MAIL_SEND_RESULT_MAILBOX_NOT_OPEN retry")
        AssertEqual(RPQuest.MailTransport._isSending, true, "Send queue remains active during mailbox retry")

        RPQuest.MailTransport:OnMailboxOpened()
        AssertEqual(#sentMails, 2, "SendMail retried after EVENT_MAIL_OPEN_MAILBOX")
        RPQuest.MailTransport:OnMailSendSuccess("@QuestMaster")
        AssertEqual(q.completionReported, true, "completionReported marked true after retry succeeds")

        -- 3. Self-mail on QUEST_COMPLETED surfaces actionable error instead of failing silently
        local mailErrors = {}
        RPQuest.MailTransport:RegisterListener(function(evType, payload)
            if evType == "MAIL_SEND_ERROR" then
                table.insert(mailErrors, payload)
            end
        end)

        nativeMailOpen = false
        alerts = {}
        RPQuest.QuestRepository:ResetQuest(q.id)
        q.completionReported = false
        q.senderDisplayName = "@TestPlayer" -- matches GetDisplayName()
        RPQuest.QuestRepository:RecordTargetEliminated("Lobo", { mapId = 32, zoneId = 381, x = q.areaCenterX, y = q.areaCenterY })
        AssertEqual(#mailErrors, 1, "Self-mail emits MAIL_SEND_ERROR instead of failing silently")
        AssertEqual(mailErrors[1].reason, "ERR_MAIL_SELF_RECIPIENT", "Self-mail reason is ERR_MAIL_SELF_RECIPIENT")
        AssertEqual(mailErrors[1].to, "@TestPlayer", "MAIL_SEND_ERROR includes recipient")
        AssertTrue(#alerts >= 1 and alerts[#alerts].isErr == true, "Self-mail surfaces error alert")

        -- 4. Mailbox closed mid-wait emits MAIL_SEND_ERROR with non-nil target
        q.senderDisplayName = "@OtherMaster"
        RPQuest.QuestRepository:ResetQuest(q.id)
        q.completionReported = false
        RPQuest.QuestRepository:RecordTargetEliminated("Lobo", { mapId = 32, zoneId = 381, x = q.areaCenterX, y = q.areaCenterY })
        RPQuest.MailTransport:OnMailboxClosed()
        AssertEqual(#mailErrors, 2, "Mailbox close during wait emits MAIL_SEND_ERROR")
        AssertEqual(mailErrors[2].to, "@OtherMaster", "MAIL_SEND_ERROR preserves target while waiting for mailbox")
        AssertEqual(mailErrors[2].reason, "MAILBOX_CLOSED", "MAIL_SEND_ERROR reports MAILBOX_CLOSED")

        RPQuest.Announcements.ShowAlert = origShowAlert
        _G.SCENE_MANAGER = origScene
        _G.SendMail = origSendMail
        _G.RequestOpenMailbox = origReqOpen
        _G.CloseMailbox = origClose
        _G.GetNextMailId = origGetNext
        _G.GetMailItemInfo = origGetInfo
        _G.ReadMail = origReadMail
        _G.DeleteMail = origDeleteMail
    end)

    RunTest("41. Sender and recipient character names (From/To) in Editor, ShareCodec, Mail, and DetailPane (Issue #157)", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        RPQuest.MailTransport:Initialize()
        RPQuest.JournalTab:Initialize()

        local origUnitName = _G.GetUnitName
        _G.GetUnitName = function(tag)
            if tag == "player" then return "Nerevar^Mx" end
            return origUnitName(tag)
        end

        -- 1. Editor captures recipientAccount and recipientCharacterName independently, and persists senderCharacterName
        RPQuest.JournalTab:OpenCreateEditor()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Dagoth",
            mapId = 32,
            zoneId = 381,
            mapName = "Vvardenfell",
            targetX = 0.4,
            targetY = 0.4,
        })
        RPQuest.JournalTab.titleEdit:SetText("Red Mountain")
        RPQuest.JournalTab.descEdit:SetText("Confront the Sixth House.")
        RPQuest.JournalTab.recipientEdit:SetText("VivecAcct")
        RPQuest.JournalTab.recipientCharEdit:SetText("Lord Vivec")
        RPQuest.JournalTab:OnSaveDraftClicked()

        local prepared = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.PREPARED)[1]
        AssertEqual(prepared.senderCharacterName, "Nerevar", "senderCharacterName captured from GetUnitName('player') and stripped of grammar suffix")
        AssertEqual(prepared.recipientAccount, "@VivecAcct", "recipientAccount normalized and preserved")
        AssertEqual(prepared.recipientCharacterName, "Lord Vivec", "recipientCharacterName preserved")

        -- 2. Detail pane displays From: and To: below Status: while keeping @AccountName in Status:
        RPQuest.JournalTab:SelectQuest(prepared.id)
        RPQuest.JournalTab:Refresh()
        AssertTrue(RPQuest.JournalTab.detailStatus:GetText():find("@VivecAcct", 1, true) ~= nil, "Prepared status preserves @AccountName")
        AssertEqual(RPQuest.JournalTab.detailFrom:GetText(), "From: Nerevar", "Detail From shows sender character name")
        AssertEqual(RPQuest.JournalTab.detailTo:GetText(), "To: Lord Vivec", "Detail To shows recipient character name")

        -- 3. ShareCodec preserves senderCharacterName and recipientCharacterName without altering quest signature
        local sigBefore = RPQuest.ShareCodec:ComputeQuestSignature(prepared)
        local code = RPQuest.QuestRepository:ExportQuestToCode(prepared.id)
        local decoded = RPQuest.ShareCodec:DecodeQuest(code)
        AssertEqual(decoded.senderCharacterName, "Nerevar", "ShareCodec decodes senderCharacterName")
        AssertEqual(decoded.recipientCharacterName, "Lord Vivec", "ShareCodec decodes recipientCharacterName")
        local sigAfter = RPQuest.ShareCodec:ComputeQuestSignature(decoded)
        AssertEqual(sigAfter, sigBefore, "Quest signature unchanged when character names are encoded")

        -- 4. Offered mail quest displays From: <CharacterName> and To: <CharacterName> below Status: without inline From in Status:
        local imported = RPQuest.QuestRepository:ImportQuestFromCode(code, "@MasterAcct", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            senderCharacterName = "Sotha Sil^Mx",
        })
        AssertEqual(imported.senderDisplayName, "@MasterAcct", "Imported quest keeps senderDisplayName")
        AssertEqual(imported.senderCharacterName, "Sotha Sil", "Imported quest prefers normalized mail metadata senderCharacterName")
        AssertEqual(imported.recipientCharacterName, "Lord Vivec", "Imported quest keeps recipientCharacterName")

        RPQuest.JournalTab:SelectQuest(imported.id)
        RPQuest.JournalTab:Refresh()
        AssertEqual(RPQuest.JournalTab.detailStatus:GetText():find("From:", 1, true), nil, "Offered status no longer embeds inline From:")
        AssertEqual(RPQuest.JournalTab.detailFrom:GetText(), "From: Sotha Sil", "Offered detail From shows sender character name")
        AssertEqual(RPQuest.JournalTab.detailTo:GetText(), "To: Lord Vivec", "Offered detail To shows recipient character name")

        _G.GetUnitName = origUnitName
    end)

    RunTest("Issue #295 & #311: worst-case uncompressible 4/10/4 quest + max MAIL_ROLE_MESSAGE fits within 6 mails (<= 4104 chars)", function()
        local limits = RPQuest.Constants.TEXT_LIMITS
        local seed = 13579
        local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+[]{}"
        local alphaLen = #alphabet
        local function RandomAscii(len)
            local out = {}
            for i = 1, len do
                seed = (seed * 1103515245 + 12345) % 2147483648
                local idx = (seed % alphaLen) + 1
                out[i] = string.sub(alphabet, idx, idx)
            end
            return table.concat(out)
        end

        local targets = {}
        for i = 1, RPQuest.Constants.TARGET.MAX_TARGETS do
            targets[i] = {
                name = RandomAscii(32),
                requiredCount = 10,
                areaCenterX = 0.4512,
                areaCenterY = 0.6543,
                areaRadius = RPQuest.Constants.AREA_RADIUS.LARGE,
                zoneId = 381,
                worldX = -123456 + i * 1000,
                worldZ = -78901 + i * 1000,
                radius = RPQuest.Constants.DISCOVERY_RADIUS.LARGE,
                locationRequired = true,
                optional = true,
                customMessageInLocation = RandomAscii(limits.SHORT_MESSAGE),
                customMessageOutsideLocation = RandomAscii(limits.SHORT_MESSAGE),
            }
        end

        local discoveries = {}
        for i = 1, RPQuest.Constants.DISCOVERY.MAX_POINTS do
            discoveries[i] = {
                zoneId = 381,
                worldX = -50000 + i * 1500,
                worldY = 1200 + i * 50,
                worldZ = 80000 + i * 1500,
                mapId = 32,
                x = 0.41 + i * 0.05,
                y = 0.61 + i * 0.05,
                radius = RPQuest.Constants.DISCOVERY_RADIUS.LARGE,
                message = RandomAscii(limits.SHORT_MESSAGE),
            }
        end

        local dialogues = {}
        for i = 1, RPQuest.Constants.DIALOGUE.MAX_NPCS do
            dialogues[i] = {
                npcName = RandomAscii(32),
                zoneId = 381,
                clue = RandomAscii(limits.DIALOGUE_OPTION),
                response = RandomAscii(limits.DIALOGUE_RESPONSE),
            }
        end

        local worstCaseQuest = {
            title = RandomAscii(limits.TITLE),
            description = RandomAscii(limits.DESCRIPTION),
            completionMessage = RandomAscii(limits.SHORT_MESSAGE),
            senderCharacterName = RandomAscii(limits.CHARACTER_NAME),
            recipientCharacterName = RandomAscii(limits.CHARACTER_NAME),
            mapId = 32,
            zoneId = 381,
            mapName = RandomAscii(32),
            targetX = 0.4321,
            targetY = 0.6789,
            stealthMode = RPQuest.Constants.STEALTH_MODE.REQUIRED,
            recommendHideMapAreas = true,
            targets = targets,
            discoveries = discoveries,
            dialogues = dialogues,
        }

        local code, encErr = RPQuest.ShareCodec:EncodeQuest(worstCaseQuest)
        AssertTrue(code ~= nil, "Worst-case quest encodes cleanly: " .. tostring(encErr))

        local roleMsg = RandomAscii(limits.MAIL_ROLE_MESSAGE)
        local plan = RPQuest.MailTransport:BuildQuestMailPackets(roleMsg, code, worstCaseQuest.title)
        AssertEqual(plan.fits, true, string.format("Worst-case uncompressible quest must fit in 6 mails (totalLen=%d, maxTotalChars=%d)", plan.totalLen, plan.maxTotalChars))
        AssertTrue(plan.partCount <= 6, "Worst-case partCount <= 6, got " .. tostring(plan.partCount))
        AssertTrue(plan.totalLen <= 4104, "Worst-case totalLen <= 4104, got " .. tostring(plan.totalLen))
    end)

end

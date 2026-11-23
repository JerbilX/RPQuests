-- ============================================================================
-- RPQuest Test Suite: MailTransport & MailInbox Suites
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

    RunTest("MailTransport completion report (manual/auto) and creator auto-validation (Issue #102)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()

        local sentMails = {}
        local deletedMails = {}
        local origSendMail = _G.SendMail
        local origDeleteMail = _G.DeleteMail
        local origGetNext = _G.GetNextMailId
        local origGetInfo = _G.GetMailItemInfo
        local origReadMail = _G.ReadMail
        local origReqOpen = _G.RequestOpenMailbox
        local origClose = _G.CloseMailbox

        _G.SendMail = function(to, subject, body)
            table.insert(sentMails, { to = to, subject = subject, body = body })
        end
        _G.DeleteMail = function(mailId) table.insert(deletedMails, mailId) end
        _G.RequestOpenMailbox = function() end
        _G.CloseMailbox = function() end

        -- Creator prepares quest
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandido",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        local preparedQuest = RPQuest.QuestRepository:SaveDraft("Entrega por Correo", "Desc")
        local rpq3Code = RPQuest.QuestRepository:ExportQuestToCode(preparedQuest.id)

        -- Player receives quest via mail from @Creator
        _G.GetNextMailId = function(lastId) return (lastId == nil) and 201 or nil end
        _G.GetMailItemInfo = function(id)
            if id == 201 then return "@Creator", "CreatorChar", "[RPQuest] Entrega por Correo", "", true, false, false, false, 0, 0, 0, 30, 5, 0 end
            return nil
        end
        _G.ReadMail = function(id) return (id == 201) and rpq3Code or "" end

        RPQuest.MailTransport:ScanInbox(false)
        local receivedList = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
        local imported = receivedList[1]
        AssertTrue(imported ~= nil, "Quest auto-ingested from mail")
        RPQuest.QuestRepository:AcceptOfferedQuest(imported.id)
        AssertEqual(imported.senderDisplayName, "@Creator", "senderDisplayName persisted on imported quest")
        RPQuest.MailTransport:OnMailboxOpened()
        AssertEqual(#sentMails, 1, "Acceptance mail auto-sent to creator")
        AssertEqual(sentMails[1].subject, "[RPQuest:Accepted] Entrega por Correo", "Uses [RPQuest:Accepted] subject")
        RPQuest.MailTransport:OnMailSendSuccess("@Creator")

        -- Automatic mode (default): completing quest auto-sends completion report to @Creator
        AssertEqual(RPQuest.QuestRepository:GetSetting("autoSendCompletionMail"), true, "autoSendCompletionMail defaults to true")
        RPQuest.QuestRepository:SetActiveQuest(imported.id)
        RPQuest.QuestRepository:RecordTargetEliminated("Bandido", { mapId = 32, zoneId = 381, x = imported.areaCenterX, y = imported.areaCenterY })
        AssertEqual(imported.completed, true, "Imported quest completed")
        RPQuest.MailTransport:OnMailboxOpened()
        AssertEqual(#sentMails, 2, "Completion mail auto-sent to creator")
        AssertEqual(sentMails[2].to, "@Creator", "Sent to @Creator")
        AssertEqual(sentMails[2].subject, "[RPQuest:Done] Entrega por Correo", "Uses [RPQuest:Done] subject")
        local rpqc1Code = sentMails[2].body
        AssertTrue(rpqc1Code:sub(1, 6) == "RPQC1:", "Body contains RPQC1 code")
        RPQuest.MailTransport:OnMailSendSuccess("@Creator")
        AssertEqual(imported.completionReported, true, "completionReported marked true after send success")

        -- Manual re-send if reset & not yet reported
        RPQuest.QuestRepository:ResetQuest(imported.id)
        imported.completionReported = false
        RPQuest.QuestRepository:RecordTargetEliminated("Bandido", { mapId = 32, zoneId = 381, x = imported.areaCenterX, y = imported.areaCenterY })
        RPQuest.MailTransport:OnMailboxOpened()
        AssertEqual(#sentMails, 3, "Automatic mode sends completion mail upon QUEST_COMPLETED")
        RPQuest.JournalTab:SelectQuest(imported.id)
        AssertEqual(RPQuest.JournalTab.btnReportCompletionMail, nil, "Manual report button removed in mail-only UX")
        RPQuest.MailTransport:OnMailSendSuccess("@Creator")

        -- Creator receives [RPQuest:Done] mail and auto-validates RPQC1
        deletedMails = {}
        _G.GetNextMailId = function(lastId) return (lastId == nil) and 301 or nil end
        _G.GetMailItemInfo = function(id)
            if id == 301 then return "@Finisher", "FinisherChar", "[RPQuest:Done] Entrega por Correo", "", true, false, false, false, 0, 0, 0, 30, 2, 0 end
            return nil
        end
        _G.ReadMail = function(id) return (id == 301) and rpqc1Code or "" end

        RPQuest.MailTransport:ScanInbox(false)
        AssertEqual(#(preparedQuest.deliveries or {}), 1, "Creator recorded 1 verified delivery from [RPQuest:Done] mail")
        AssertEqual(preparedQuest.deliveries[1].senderDisplayName, "@Finisher", "Recorded finisher @AccountName")
        AssertEqual(#deletedMails, 1, "Completion mail auto-deleted when autoDeleteMail is true")
        AssertEqual(deletedMails[1], 301, "Deleted completion mail 301")

        _G.SendMail = origSendMail
        _G.DeleteMail = origDeleteMail
        _G.GetNextMailId = origGetNext
        _G.GetMailItemInfo = origGetInfo
        _G.ReadMail = origReadMail
        _G.RequestOpenMailbox = origReqOpen
        _G.CloseMailbox = origClose
    end)

    RunTest("MailTransport: multi-part RPQP chunking, out-of-order reassembly, incomplete state, and batch delete (Issue #113)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()
        RPQuest.QuestRepository:SetSetting("autoDeleteMail", true)

        local sentMails = {}
        local inbox = {}
        local deletedIds = {}

        _G.MAIL_MAX_BODY_CHARACTERS = 700
        _G.RequestOpenMailbox = function() end
        _G.CloseMailbox = function() end
        _G.SendMail = function(to, subject, body)
            table.insert(sentMails, { to = to, subject = subject, body = body })
        end
        _G.GetNextMailId = function(cur)
            local keys = {}
            for k in pairs(inbox) do table.insert(keys, k) end
            table.sort(keys)
            if cur == nil then return keys[1] end
            for i, k in ipairs(keys) do
                if k == cur then return keys[i + 1] end
            end
            return nil
        end
        _G.GetMailItemInfo = function(id)
            local m = inbox[id]
            if not m then return nil end
            return m.sender, m.charName, m.subject, nil, nil, nil, nil, nil, nil, nil, nil, nil, m.secs
        end
        _G.ReadMail = function(id)
            return inbox[id] and inbox[id].body or ""
        end
        _G.DeleteMail = function(id)
            table.insert(deletedIds, id)
            inbox[id] = nil
        end

        -- Build a quest whose RPQ3 code + roleplay message exceeds 700 chars
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Farseer Kuamta",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.5,
            targetY = 0.5,
        })
        local q = RPQuest.QuestRepository:SaveDraft(
            "House Quest: Multi-Part",
            "Investigate the northern ruins and speak with the informants about the missing relic.",
            nil,
            "You have uncovered the truth behind the House Quest!"
        )
        local roleMsg = string.rep("Greetings agent, this mission requires utmost discretion. ", 18)
        local code = RPQuest.QuestRepository:ExportQuestToCode(q.id)
        local plan = RPQuest.MailTransport:BuildQuestMailPackets(roleMsg, code, q.title)
        AssertTrue(plan.fits, "Multi-part plan fits within MAX_MAIL_PARTS")
        AssertTrue(plan.partCount >= 2, "Splits into >= 2 parts (got " .. tostring(plan.partCount) .. ")")
        for i, pkt in ipairs(plan.packets) do
            AssertTrue(#pkt.body <= 700, "Part " .. i .. " body <= 700 chars (got " .. #pkt.body .. ")")
        end

        -- Send all parts sequentially
        local okSend, errSend = RPQuest.MailTransport:SendQuestToRecipients(q, "@Receiver", roleMsg)
        AssertEqual(okSend, true, "Multi-part send started: " .. tostring(errSend))
        RPQuest.MailTransport:OnMailboxOpened()
        for i = 1, plan.partCount do
            AssertEqual(#sentMails, i, "Dispatched part " .. i)
            RPQuest.MailTransport:OnMailSendSuccess("@Receiver")
        end

        -- Simulate receiving parts out of order (last part first, then remaining)
        RPQuest.MailTransport:Initialize()
        inbox[500 + plan.partCount] = {
            sender = "@Sender",
            charName = "Sender Char",
            subject = sentMails[plan.partCount].subject,
            body = sentMails[plan.partCount].body,
            secs = 5,
        }
        RPQuest.MailTransport:ScanInbox(false)
        AssertEqual(RPQuest.MailTransport:GetReceivedMailCount(), 1, "Shows 1 partial entry in inbox")
        AssertEqual(#RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED), 0, "Incomplete multi-part mail is not auto-ingested")
        local partialEntry = RPQuest.MailTransport._receivedMails[1]
        AssertEqual(partialEntry.isIncomplete, true, "Entry marked incomplete while missing parts")
        AssertEqual(partialEntry.partsReceived, 1, "1 part received so far")

        local ingFail, ingErr = RPQuest.MailTransport:IngestReceivedMail(partialEntry.mailId)
        AssertEqual(ingFail, nil, "Cannot ingest incomplete multi-part mail")
        AssertEqual(ingErr, "ERR_MAIL_INCOMPLETE", "Returns ERR_MAIL_INCOMPLETE")

        -- Deliver remaining parts
        for i = 1, plan.partCount - 1 do
            inbox[500 + i] = {
                sender = "@Sender",
                charName = "Sender Char",
                subject = sentMails[i].subject,
                body = sentMails[i].body,
                secs = 5 + i,
            }
        end
        RPQuest.MailTransport:ScanInbox(false)
        local receivedMulti = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
        AssertEqual(#receivedMulti, 1, "Multi-part quest auto-ingested once all parts arrive")
        local imported = receivedMulti[1]
        AssertEqual(RPQuest.QuestRepository:IsOfferedQuest(imported), true, "Multi-part quest starts in OFFERED status")
        AssertEqual(imported.title, q.title, "Decoded title matches original")
        AssertEqual(#deletedIds, plan.partCount, "All part mails deleted on auto-ingest")
        AssertEqual(RPQuest.MailTransport:GetReceivedMailCount(), 0, "Inbox empty after auto-ingest")
    end)

    RunTest("MailTransport: surfaces decode errors once per mailId on ScanInbox/OnMailReadable (Issue #125)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()

        local inbox = {
            [901] = { sender = "@Sender", charName = "Sender", subject = "[RPQuest] Corrupt", body = "RPQ3:FFFF:badpayload", secs = 10 },
            [902] = { sender = "@Sender", charName = "Sender", subject = "[RPQuest] Future", body = "RPQ4:1234:futurepayload", secs = 10 },
        }
        _G.GetNextMailId = function(cur)
            if cur == nil then return 901 end
            if cur == 901 then return 902 end
            return nil
        end
        _G.GetMailItemInfo = function(id)
            local m = inbox[id]
            if not m then return nil end
            return m.sender, m.charName, m.subject, nil, false, false, true, false, 0, 0, 0, 0, m.secs
        end
        _G.ReadMail = function(id)
            local m = inbox[id]
            return m and m.body or ""
        end

        local alerts = {}
        local origShowAlert = RPQuest.Announcements.ShowAlert
        RPQuest.Announcements.ShowAlert = function(_, msg, isErr)
            table.insert(alerts, { msg = msg, isErr = isErr })
        end

        local events = {}
        RPQuest.MailTransport:RegisterListener(function(ev, payload)
            if ev == "MAIL_DECODE_ERROR" then
                table.insert(events, payload)
            end
        end)

        RPQuest.MailTransport:ScanInbox(false)
        AssertEqual(#alerts, 2, "2 decode error alerts shown on first ScanInbox")
        AssertEqual(alerts[1].isErr, true, "Corrupt mail alert is error")
        AssertEqual(alerts[1].msg, RPQuest.Locale:Get("ERR_IMPORT_TRUNCATED_OR_CORRUPT"), "Corrupt mail shows ERR_IMPORT_TRUNCATED_OR_CORRUPT")
        AssertEqual(alerts[2].msg, RPQuest.Locale:Get("ERR_IMPORT_UNSUPPORTED_VERSION"), "Future RPQ4 mail shows ERR_IMPORT_UNSUPPORTED_VERSION")
        AssertEqual(#events, 2, "MAIL_DECODE_ERROR emitted for both mails")

        -- Re-scan and OnMailReadable must not duplicate alerts for the same mailIds
        RPQuest.MailTransport:ScanInbox(false)
        RPQuest.MailTransport:OnMailReadable(901)
        AssertEqual(#alerts, 2, "No duplicate alerts on re-scan or OnMailReadable")

        RPQuest.Announcements.ShowAlert = origShowAlert
    end)

    RunTest("MailTransport: alerts on incoming quest mail without duplicates and supports autoAcceptMail (Issue #124)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()

        AssertEqual(RPQuest.QuestRepository:GetSetting("autoAcceptMail"), false, "autoAcceptMail defaults to false")

        -- Create a valid RPQ3 code
        local code = RPQuest.ShareCodec:EncodeQuest({
            title = "Misión de Correo",
            description = "Prueba de correo.",
            mapId = 1,
            zoneId = 1,
            mapName = "Auridon",
            targets = { { name = "Guardia" } },
        })

        local inbox = {
            [951] = { sender = "@SenderA", charName = "SenderA", subject = "[RPQuest] Misión de Correo", body = code, secs = 5 },
        }
        local deletedIds = {}
        _G.GetNextMailId = function(cur) return (cur == nil and inbox[951]) and 951 or nil end
        _G.GetMailItemInfo = function(id)
            local m = inbox[id]
            if not m then return nil end
            return m.sender, m.charName, m.subject, nil, false, false, true, false, 0, 0, 0, 0, m.secs
        end
        _G.ReadMail = function(id) return inbox[id] and inbox[id].body or "" end
        _G.DeleteMail = function(id)
            table.insert(deletedIds, id)
            inbox[id] = nil
        end

        local alerts = {}
        local origShowAlert = RPQuest.Announcements.ShowAlert
        RPQuest.Announcements.ShowAlert = function(_, msg, isErr)
            table.insert(alerts, { msg = msg, isErr = isErr })
        end

        -- 1. Manual mode (autoAcceptMail = false): auto-ingests as OFFERED
        RPQuest.MailTransport:ScanInbox(false)
        local offeredList = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
        AssertEqual(#offeredList, 1, "Quest auto-ingested as OFFERED in manual mode")
        AssertEqual(RPQuest.QuestRepository:IsOfferedQuest(offeredList[1]), true, "Ingested quest is OFFERED")
        AssertEqual(#alerts, 1, "1 notification alert shown")
        AssertEqual(alerts[1].isErr, false, "Notification alert is not an error")
        AssertEqual(alerts[1].msg, RPQuest.Locale:Get("ALERT_MAIL_QUEST_OFFERED", "Misión de Correo", "@SenderA"), "Notification message matches")

        -- Re-scan does not duplicate quest or alert
        RPQuest.MailTransport:ScanInbox(false)
        AssertEqual(#RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED), 1, "No duplicate OFFERED quest on re-scan")
        AssertEqual(#alerts, 1, "No duplicate notification alert on re-scan")

        -- 2. Auto-accept mode (autoAcceptMail = true)
        RPQuest.QuestRepository:SetSetting("autoAcceptMail", true)
        local qCountBefore = #RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
        inbox[952] = { sender = "@SenderB", charName = "SenderB", subject = "[RPQuest] Misión de Correo", body = code, secs = 2 }
        _G.GetNextMailId = function(cur)
            if cur == nil and inbox[952] then return 952 end
            return nil
        end

        local acceptedCount = 0
        local origAnnounce = RPQuest.Announcements.AnnounceQuestAccepted
        RPQuest.Announcements.AnnounceQuestAccepted = function() acceptedCount = acceptedCount + 1 end

        RPQuest.MailTransport:ScanInbox(false)
        local qCountAfter = #RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
        AssertEqual(qCountAfter, qCountBefore + 1, "Quest auto-imported when autoAcceptMail=true")
        AssertEqual(#deletedIds, 2, "Both ingested and auto-accepted mails deleted when autoDeleteMail=true")
        AssertEqual(deletedIds[2], 952, "Deleted mailId matches auto-accepted mail")
        AssertEqual(acceptedCount, 1, "AnnounceQuestAccepted called on auto-accept")

        RPQuest.Announcements.ShowAlert = origShowAlert
        RPQuest.Announcements.AnnounceQuestAccepted = origAnnounce
    end)

    RunTest("38. Auto-report rejection and completion results to Master via mail (Issue #144)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()

        -- Master creates prepared quest
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Esqueleto",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.4,
            targetY = 0.4,
        })
        local prepared = RPQuest.QuestRepository:SaveDraft("Misión Rechazo", "Prueba de rechazo.")
        local rpq3Code = RPQuest.QuestRepository:ExportQuestToCode(prepared.id)

        -- Encode/Decode rejection via ShareCodec
        local rejCode, rejErr = RPQuest.ShareCodec:EncodeRejection(prepared, "JugadorUno", 123456)
        AssertTrue(rejCode ~= nil and rejCode:sub(1, 6) == "RPQC1:", "EncodeRejection produces RPQC1 code: " .. tostring(rejErr))
        local decodedRej = RPQuest.ShareCodec:DecodeCompletion(rejCode)
        AssertTrue(decodedRej ~= nil, "DecodeCompletion decodes rejection payload")
        AssertEqual(decodedRej.completed, false, "Rejection has completed=false")
        AssertEqual(decodedRej.rejected, true, "Rejection has rejected=true")
        AssertEqual(decodedRej.characterName, "JugadorUno", "Rejection preserves characterName")
        AssertEqual(decodedRej.completedAt, 123456, "Rejection preserves timestamp")

        local okCompOnly, errCompOnly = RPQuest.ShareCodec:ValidateCompletionForQuest(prepared, rejCode)
        AssertEqual(okCompOnly, false, "ValidateCompletionForQuest rejects a rejection code")
        AssertEqual(errCompOnly, "VALIDATE_ERR_NOT_COMPLETED", "Returns VALIDATE_ERR_NOT_COMPLETED")

        local okResult, resPayload = RPQuest.ShareCodec:ValidateResultForQuest(prepared, rejCode)
        AssertEqual(okResult, true, "ValidateResultForQuest accepts rejection code")
        AssertEqual(resPayload.rejected, true, "ValidateResultForQuest returns rejected=true")

        -- Player receives quest as OFFERED and rejects it -> auto-sends rejection mail to @Master
        local sentMails = {}
        local origSendMail = _G.SendMail
        local origReqOpen = _G.RequestOpenMailbox
        local origClose = _G.CloseMailbox
        local origGetNext = _G.GetNextMailId
        local origGetInfo = _G.GetMailItemInfo
        local origReadMail = _G.ReadMail
        local origDeleteMail = _G.DeleteMail
        local origShowAlert = RPQuest.Announcements.ShowAlert

        _G.SendMail = function(to, subject, body)
            table.insert(sentMails, { to = to, subject = subject, body = body })
        end
        _G.RequestOpenMailbox = function() end
        _G.CloseMailbox = function() end

        local offered = RPQuest.QuestRepository:ImportQuestFromCode(rpq3Code, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            sourceMailId = "mail_rej_1",
        })
        RPQuest.QuestRepository:RejectOfferedQuest(offered.id)
        RPQuest.MailTransport:OnMailboxOpened()
        AssertEqual(#sentMails, 1, "Rejection mail auto-queued and sent on RejectOfferedQuest")
        AssertEqual(sentMails[1].to, "@Master", "Rejection mail sent to @Master")
        AssertEqual(sentMails[1].subject, "[RPQuest:Rejected] Misión Rechazo", "Uses [RPQuest:Rejected] subject")
        RPQuest.MailTransport:OnMailSendSuccess("@Master")

        -- Master receives rejection mail -> auto-records result and shows alert
        local alerts = {}
        RPQuest.Announcements.ShowAlert = function(_, msg, isErr)
            table.insert(alerts, { msg = msg, isErr = isErr })
        end
        local deletedIds = {}
        _G.DeleteMail = function(id) table.insert(deletedIds, id) end
        _G.GetNextMailId = function(cur) return (cur == nil) and 401 or nil end
        _G.GetMailItemInfo = function(id)
            if id == 401 then return "@PlayerRej", "PlayerRejChar", sentMails[1].subject, "", true, false, false, false, 0, 0, 0, 30, 1, 0 end
            return nil
        end
        _G.ReadMail = function(id) return (id == 401) and sentMails[1].body or "" end

        RPQuest.MailTransport:ScanInbox(false)
        AssertEqual(#alerts, 1, "Master receives alert for rejection mail")
        AssertEqual(alerts[1].msg, RPQuest.Locale:Get("ALERT_MAIL_REJECTION_RECEIVED", "@PlayerRej", prepared.title), "Rejection alert text matches")
        AssertTrue(prepared.lastResult ~= nil and prepared.lastResult.status == "rejected", "Prepared quest records lastResult.status == 'rejected'")
        AssertEqual(prepared.lastResult.senderDisplayName, "@PlayerRej", "Prepared quest records rejecting player")
        AssertEqual(#deletedIds, 1, "Rejection mail auto-deleted on Master")

        _G.SendMail = origSendMail
        _G.RequestOpenMailbox = origReqOpen
        _G.CloseMailbox = origClose
        _G.GetNextMailId = origGetNext
        _G.GetMailItemInfo = origGetInfo
        _G.ReadMail = origReadMail
        _G.DeleteMail = origDeleteMail
        RPQuest.Announcements.ShowAlert = origShowAlert
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

        local status1 = RPQuest.QuestRepository:GetPreparedQuestStatus(prepared)
        AssertEqual(status1, "draft", "Initial status is draft")

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

        local status2 = RPQuest.QuestRepository:GetPreparedQuestStatus(prepared)
        AssertEqual(status2, "sent", "Status transitions to sent after mail dispatch")
        AssertTrue(RPQuest.JournalTab.detailStatus:GetText():find("@PlayerTarget", 1, true) ~= nil, "Detail status shows sent recipient")

        -- Transition to completed
        RPQuest.QuestRepository:RecordMailDelivery(prepared.id, "@PlayerTarget", {
            characterName = "TargetChar",
            completedAt = 999,
            completed = true,
            wasDetected = false,
        })
        local status3 = RPQuest.QuestRepository:GetPreparedQuestStatus(prepared)
        AssertEqual(status3, "completed", "Status transitions to completed")
        AssertTrue(RPQuest.JournalTab.detailStatus:GetText():find("TargetChar", 1, true) ~= nil, "Detail status includes character name")

        -- Transition to rejected
        RPQuest.QuestRepository:RecordMailDelivery(prepared.id, "@PlayerTarget", {
            characterName = "TargetChar",
            completedAt = 1000,
            completed = false,
        })
        local status4 = RPQuest.QuestRepository:GetPreparedQuestStatus(prepared)
        AssertEqual(status4, "rejected", "Status transitions to rejected")

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

    RunTest("42. Automatic acceptance mail report on QUEST_ACCEPTED and status lifecycle (Issue #159)", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()
        RPQuest.JournalTab:Initialize()

        -- Master creates prepared quest
        RPQuest.QuestRepository:ResetDraft()
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            targetName = "Bandit",
            mapId = 32,
            zoneId = 381,
            mapName = "Auridon",
            targetX = 0.4,
            targetY = 0.4,
        })
        local prepared = RPQuest.QuestRepository:SaveDraft("Scout the Camp", "Accept and report.", nil, "", false, "@PlayerAcc")
        local rpq3Code = RPQuest.QuestRepository:ExportQuestToCode(prepared.id)

        -- 1. ShareCodec EncodeAcceptance / DecodeCompletion
        local accCode, accErr = RPQuest.ShareCodec:EncodeAcceptance(prepared, "HeroChar", 222333)
        AssertTrue(accCode ~= nil and accCode:sub(1, 6) == "RPQC1:", "EncodeAcceptance produces RPQC1 code: " .. tostring(accErr))
        local decodedAcc = RPQuest.ShareCodec:DecodeCompletion(accCode)
        AssertTrue(decodedAcc ~= nil, "DecodeCompletion decodes acceptance payload")
        AssertEqual(decodedAcc.completed, false, "Acceptance has completed=false")
        AssertEqual(decodedAcc.rejected, false, "Acceptance has rejected=false")
        AssertEqual(decodedAcc.accepted, true, "Acceptance has accepted=true")
        AssertEqual(decodedAcc.resultType, "accepted", "Acceptance has resultType='accepted'")
        AssertEqual(decodedAcc.characterName, "HeroChar", "Acceptance preserves characterName")
        AssertEqual(decodedAcc.completedAt, 222333, "Acceptance preserves timestamp")

        local okCompOnly, errCompOnly = RPQuest.ShareCodec:ValidateCompletionForQuest(prepared, accCode)
        AssertEqual(okCompOnly, false, "ValidateCompletionForQuest rejects an acceptance code")
        AssertEqual(errCompOnly, "VALIDATE_ERR_NOT_COMPLETED", "Returns VALIDATE_ERR_NOT_COMPLETED for acceptance")

        local okResult, resPayload = RPQuest.ShareCodec:ValidateResultForQuest(prepared, accCode)
        AssertEqual(okResult, true, "ValidateResultForQuest accepts acceptance code")
        AssertEqual(resPayload.accepted, true, "ValidateResultForQuest returns accepted=true")
        AssertEqual(resPayload.resultType, "accepted", "ValidateResultForQuest returns resultType='accepted'")

        -- 2. Player accepts offered mail quest -> auto-sends acceptance report to @Master
        local sentMails = {}
        local origSendMail = _G.SendMail
        local origReqOpen = _G.RequestOpenMailbox
        local origClose = _G.CloseMailbox
        local origGetNext = _G.GetNextMailId
        local origGetInfo = _G.GetMailItemInfo
        local origReadMail = _G.ReadMail
        local origDeleteMail = _G.DeleteMail
        local origShowAlert = RPQuest.Announcements.ShowAlert

        _G.SendMail = function(to, subject, body)
            table.insert(sentMails, { to = to, subject = subject, body = body })
        end
        _G.RequestOpenMailbox = function() end
        _G.CloseMailbox = function() end

        local offered = RPQuest.QuestRepository:ImportQuestFromCode(rpq3Code, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.OFFERED,
            sourceMailId = "mail_acc_1",
        })
        RPQuest.QuestRepository:AcceptOfferedQuest(offered.id)
        RPQuest.MailTransport:OnMailboxOpened()
        AssertEqual(#sentMails, 1, "Acceptance mail auto-queued and sent on AcceptOfferedQuest")
        AssertEqual(sentMails[1].to, "@Master", "Acceptance mail sent to @Master")
        AssertEqual(sentMails[1].subject, "[RPQuest:Accepted] Scout the Camp", "Uses [RPQuest:Accepted] subject")
        RPQuest.MailTransport:OnMailSendSuccess("@Master")
        AssertEqual(offered.completionReported or false, false, "Acceptance send does not mark completionReported=true")

        -- 3. Master receives acceptance mail -> updates prepared status to accepted & shows alert
        local alerts = {}
        RPQuest.Announcements.ShowAlert = function(_, msg, isErr)
            table.insert(alerts, { msg = msg, isErr = isErr })
        end
        local deletedIds = {}
        _G.DeleteMail = function(id) table.insert(deletedIds, id) end
        _G.GetNextMailId = function(cur) return (cur == nil) and 501 or nil end
        _G.GetMailItemInfo = function(id)
            if id == 501 then return "@PlayerAcc", "HeroChar", sentMails[1].subject, "", true, false, false, false, 0, 0, 0, 30, 1, 0 end
            return nil
        end
        _G.ReadMail = function(id) return (id == 501) and sentMails[1].body or "" end

        RPQuest.MailTransport:ScanInbox(false)
        AssertEqual(#alerts, 1, "Master receives alert for acceptance mail")
        AssertEqual(alerts[1].msg, RPQuest.Locale:Get("ALERT_MAIL_ACCEPTANCE_RECEIVED", "@PlayerAcc", prepared.title), "Acceptance alert text matches")
        AssertTrue(prepared.lastResult ~= nil and prepared.lastResult.status == "accepted", "Prepared quest records lastResult.status == 'accepted'")
        AssertEqual(RPQuest.QuestRepository:GetPreparedQuestStatus(prepared), "accepted", "GetPreparedQuestStatus returns 'accepted'")
        AssertEqual(#deletedIds, 1, "Acceptance mail auto-deleted on Master")

        RPQuest.JournalTab:SelectQuest(prepared.id)
        RPQuest.JournalTab:Refresh()
        AssertTrue(RPQuest.JournalTab.detailStatus:GetText():find("Accepted", 1, true) ~= nil, "Detail status displays Accepted label")

        -- 4. Subsequent completion overwrites accepted status
        RPQuest.QuestRepository:RecordMailDelivery(prepared.id, "@PlayerAcc", {
            characterName = "HeroChar",
            completedAt = 222400,
            completed = true,
            resultType = "completed",
            wasDetected = false,
        })
        AssertEqual(RPQuest.QuestRepository:GetPreparedQuestStatus(prepared), "completed", "Completion overwrites accepted status")

        -- 5. Late acceptance arriving after completion does not overwrite completed status
        local lateEntry, isNewLate = RPQuest.QuestRepository:RecordMailDelivery(prepared.id, "@PlayerAcc", {
            characterName = "HeroChar",
            completedAt = 222500,
            completed = false,
            accepted = true,
            resultType = "accepted",
        })
        AssertEqual(isNewLate, true, "Late acceptance recorded in deliveries")
        AssertEqual(lateEntry.status, "accepted", "Late delivery entry has status='accepted'")
        AssertEqual(RPQuest.QuestRepository:GetPreparedQuestStatus(prepared), "completed", "Late acceptance does not overwrite completed status")
        AssertEqual(prepared.lastResult.status, "completed", "lastResult remains completed")

        _G.SendMail = origSendMail
        _G.RequestOpenMailbox = origReqOpen
        _G.CloseMailbox = origClose
        _G.GetNextMailId = origGetNext
        _G.GetMailItemInfo = origGetInfo
        _G.ReadMail = origReadMail
        _G.DeleteMail = origDeleteMail
        RPQuest.Announcements.ShowAlert = origShowAlert
    end)

end

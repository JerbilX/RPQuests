-- ============================================================================
-- RPQuest Test Suite: MailInbox Chunking, Reassembly, Decode Errors & Alerts
-- ============================================================================
return function(T)
    local RunTest = T.RunTest
    local AssertEqual = T.AssertEqual
    local AssertTrue = T.AssertTrue
    local mockState = T.mockState

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

    RunTest("MailInbox: emits localized on-screen CSA announcement on new mail quest without duplicates (Issue #166)", function()
        local prevLang = mockState.language
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")
        AssertEqual(RPQuest.Locale:Get("CSA_QUEST_RECEIVED"), "You have received a new quest", "English CSA_QUEST_RECEIVED text")

        mockState.language = "es"
        RPQuest.Locale:Initialize("es")
        AssertEqual(RPQuest.Locale:Get("CSA_QUEST_RECEIVED"), "Has recibido una nueva misión", "Spanish CSA_QUEST_RECEIVED text")

        mockState.language = prevLang or "en"
        RPQuest.Locale:Initialize(mockState.language)

        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()
        mockState.csaMessages = {}

        local code = RPQuest.ShareCodec:EncodeQuest({
            title = "Anuncio por Correo",
            description = "Prueba de anuncio en pantalla.",
            mapId = 1,
            zoneId = 1,
            mapName = "Auridon",
            targets = { { name = "Guardia" } },
        })

        local inbox = {
            [961] = { sender = "@SenderCSA", charName = "SenderCSA", subject = "[RPQuest] Anuncio por Correo", body = code, secs = 3 },
        }
        _G.GetNextMailId = function(cur) return (cur == nil and inbox[961]) and 961 or nil end
        _G.GetMailItemInfo = function(id)
            local m = inbox[id]
            if not m then return nil end
            return m.sender, m.charName, m.subject, nil, false, false, true, false, 0, 0, 0, 0, m.secs
        end
        _G.ReadMail = function(id) return inbox[id] and inbox[id].body or "" end
        _G.DeleteMail = function(id) inbox[id] = nil end

        RPQuest.MailTransport:ScanInbox(false)
        AssertEqual(#mockState.csaMessages, 1, "1 CENTER_SCREEN_ANNOUNCE banner emitted on new offered mail quest")
        AssertEqual(mockState.csaMessages[1].category, CSA_CATEGORY_LARGE_TEXT, "Mail quest received CSA uses large text category")
        AssertEqual(mockState.csaMessages[1].csaType, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED, "Mail quest received CSA uses QUEST_ADDED type")
        AssertEqual(mockState.csaMessages[1].mainText, RPQuest.Locale:Get("CSA_QUEST_RECEIVED"), "Mail quest received CSA mainText is localized")
        AssertEqual(mockState.csaMessages[1].subText, "Anuncio por Correo", "Mail quest received CSA subText shows quest title")

        -- Re-scan and duplicate UpsertReceivedEntry must not duplicate CSA banner
        RPQuest.MailTransport:ScanInbox(false)
        RPQuest.MailInbox:UpsertReceivedEntry({
            idKey = "961",
            mailId = 961,
            senderDisplayName = "@SenderCSA",
            senderCharacterName = "SenderCSA",
            title = "Anuncio por Correo",
            questCode = code,
            isIncomplete = false,
        })
        AssertEqual(#mockState.csaMessages, 1, "No duplicate CSA banner on re-scan or duplicate UpsertReceivedEntry")
    end)

end

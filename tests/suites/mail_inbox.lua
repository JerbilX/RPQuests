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

    RunTest("MailInbox: prominent decode error (CSA + chat) and inbox cleanup on failed/language-mismatch quest mails (Issue #229)", function()
        local prevLang = mockState.language
        mockState.language = "en"
        RPQuest.Locale:Initialize("en")

        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()
        RPQuest.QuestRepository:SetSetting("autoDeleteMail", true)

        -- Encode a quest in "de" while client is "en" -> triggers ERR_IMPORT_LANGUAGE_MISMATCH
        mockState.language = "de"
        local deCode = RPQuest.ShareCodec:EncodeQuest({
            title = "Fremde Quest",
            description = "Nur auf Deutsch.",
            mapId = 1,
            zoneId = 1,
            mapName = "Auridon",
            targets = { { name = "Wache" } },
        })
        mockState.language = "en"

        local enCode = RPQuest.ShareCodec:EncodeQuest({
            title = "Valid English Quest",
            description = "Works on EN client.",
            mapId = 1,
            zoneId = 1,
            mapName = "Auridon",
            targets = { { name = "Guard" } },
        })

        local inbox = {
            [971] = { sender = "@GermanSender", charName = "Hans", subject = "[RPQuest] Fremde Quest", body = deCode, secs = 5 },
            [972] = { sender = "@EnglishSender", charName = "John", subject = "[RPQuest] Valid English Quest", body = enCode, secs = 3 },
        }
        local deletedIds = {}
        local origDeleteMail = _G.DeleteMail
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
            return m.sender, m.charName, m.subject, nil, false, false, true, false, 0, 0, 0, 0, m.secs
        end
        _G.ReadMail = function(id) return inbox[id] and inbox[id].body or "" end
        _G.DeleteMail = function(id)
            table.insert(deletedIds, id)
            inbox[id] = nil
        end

        mockState.csaMessages = {}
        mockState.chatMessages = {}
        local events = {}
        RPQuest.MailTransport:RegisterListener(function(ev, payload)
            if ev == "MAIL_DECODE_ERROR" then
                table.insert(events, payload)
            end
        end)

        RPQuest.MailTransport:ScanInbox(false)

        -- 1. Prominent CSA + chat error emitted for the language mismatch mail
        AssertEqual(#events, 1, "MAIL_DECODE_ERROR emitted once for language mismatch mail")
        AssertEqual(events[1].errKey, "ERR_IMPORT_LANGUAGE_MISMATCH", "errKey is ERR_IMPORT_LANGUAGE_MISMATCH")
        AssertEqual(events[1].senderDisplayName, "@GermanSender", "Sender included in MAIL_DECODE_ERROR payload")

        local foundErrorCsa = false
        for _, csa in ipairs(mockState.csaMessages) do
            if csa.mainText == RPQuest.Locale:Get("CSA_MAIL_DECODE_ERROR") then
                foundErrorCsa = true
                AssertEqual(csa.category, CSA_CATEGORY_LARGE_TEXT, "Decode error CSA uses large text category")
                AssertEqual(csa.sound, SOUNDS.GENERAL_ALERT_ERROR, "Decode error CSA uses error sound")
                AssertTrue(string.find(csa.subText or "", "@GermanSender", 1, true) ~= nil, "CSA subText includes sender name")
                AssertTrue(string.find(csa.subText or "", RPQuest.Locale:Get("ERR_IMPORT_LANGUAGE_MISMATCH"), 1, true) ~= nil, "CSA subText includes localized error")
            end
        end
        AssertTrue(foundErrorCsa, "Prominent CSA banner emitted for mail decode error")

        local foundChatError = false
        for _, chatMsg in ipairs(mockState.chatMessages) do
            if string.find(chatMsg, RPQuest.Locale:Get("CSA_MAIL_DECODE_ERROR"), 1, true)
                and string.find(chatMsg, "@GermanSender", 1, true) then
                foundChatError = true
            end
        end
        AssertTrue(foundChatError, "Persistent red chat error message emitted for mail decode error")

        -- 2. Failed mail deleted from inbox AND subsequent valid mail still processed
        AssertEqual(inbox[971], nil, "Failed language-mismatch mail removed from inbox")
        AssertEqual(inbox[972], nil, "Subsequent valid mail also processed and removed from inbox")
        AssertEqual(#deletedIds, 2, "Both failed mail and valid mail deleted when autoDeleteMail=true")
        local received = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
        AssertEqual(#received, 1, "Valid quest still ingested after failed mail cleanup")
        AssertEqual(received[1].title, "Valid English Quest", "Valid quest title matches")

        -- 3. When autoDeleteMail = false, failed mail is dismissed without calling DeleteMail
        RPQuest.QuestRepository:SetSetting("autoDeleteMail", false)
        inbox[973] = { sender = "@SenderNoDel", charName = "NoDel", subject = "[RPQuest] Corrupt", body = "RPQ3:FFFF:badpayload", secs = 2 }
        local deletedBefore = #deletedIds
        RPQuest.MailTransport:ScanInbox(false)
        AssertEqual(#deletedIds, deletedBefore, "DeleteMail NOT called for failed mail when autoDeleteMail=false")
        AssertEqual(RPQuest.MailInbox._dismissedMailIds["973"], true, "Failed mail marked dismissed when autoDeleteMail=false")

        -- 4. Multi-part failed RPQP mail cleans up all parts and incomplete entry
        RPQuest.QuestRepository:SetSetting("autoDeleteMail", true)
        local half = math.floor(#deCode / 2)
        inbox[981] = { sender = "@MultiSender", charName = "Multi", subject = "[RPQuest 1/2] Fremde Quest", body = "RPQP:ABCD12:1/2\n" .. string.sub(deCode, 1, half), secs = 4 }
        inbox[982] = { sender = "@MultiSender", charName = "Multi", subject = "[RPQuest 2/2] Fremde Quest", body = "RPQP:ABCD12:2/2\n" .. string.sub(deCode, half + 1), secs = 4 }
        RPQuest.MailTransport:ScanInbox(false)
        AssertEqual(inbox[981], nil, "Multi-part failed mail part 1 deleted")
        AssertEqual(inbox[982], nil, "Multi-part failed mail part 2 deleted")
        AssertEqual(RPQuest.MailTransport:GetReceivedMailCount(), 0, "No stale incomplete entry left in _receivedMails")

        _G.DeleteMail = origDeleteMail
        mockState.language = prevLang or "en"
        RPQuest.Locale:Initialize(mockState.language)
    end)

    RunTest("MailInbox cleans up orphan incomplete parts on successful resend without incomplete alerts (Issue #334)", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        RPQuest.MailTransport:Initialize()
        RPQuest.QuestRepository:SetSetting("autoDeleteMail", true)

        local questCode = RPQuest.ShareCodec:EncodeQuest({
            title = "Orphan Cleanup Quest",
            description = string.rep("Detailed lore for multi-part delivery. ", 25),
            mapId = 1,
            zoneId = 1,
            mapName = "Auridon",
            targets = {
                { name = "Guard", requiredCount = 2, customMessage = string.rep("Note ", 20) },
            },
        })
        local plan = RPQuest.MailTransport:BuildQuestMailPackets(string.rep("RP intro for multi-part test. ", 35), questCode, "Orphan Cleanup Quest")
        AssertTrue(plan.fits and plan.partCount >= 2, "Test quest splits into at least 2 parts")

        local otherCode = RPQuest.ShareCodec:EncodeQuest({
            title = "Unrelated Quest",
            description = "Other lore.",
            mapId = 1,
            zoneId = 1,
            mapName = "Auridon",
            targets = { { name = "Wolf" } },
        })
        local otherPlan = RPQuest.MailTransport:BuildQuestMailPackets(string.rep("Other intro for multi-part test. ", 35), otherCode, "Unrelated Quest")
        AssertTrue(otherPlan.fits and otherPlan.partCount >= 2, "Unrelated quest splits into at least 2 parts")

        local inbox = {}
        local deletedIds = {}
        local origGetNext = _G.GetNextMailId
        local origGetInfo = _G.GetMailItemInfo
        local origReadMail = _G.ReadMail
        local origDeleteMail = _G.DeleteMail
        local origShowAlert = RPQuest.Announcements.ShowAlert

        local alerts = {}
        RPQuest.Announcements.ShowAlert = function(_, msg, isErr)
            table.insert(alerts, { msg = msg, isErr = isErr })
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
            return m.sender, m.charName, m.subject, nil, false, false, true, false, 0, 0, 0, 0, m.secs
        end
        _G.ReadMail = function(id) return inbox[id] and inbox[id].body or "" end
        _G.DeleteMail = function(id)
            table.insert(deletedIds, id)
            inbox[id] = nil
        end

        -- 1. Deliver incomplete parts (1..N-1) from @Master for "Orphan Cleanup Quest" (txId=AAAA)
        --    plus unrelated incomplete parts from @OtherMaster and for "Unrelated Quest".
        for i = 1, plan.partCount - 1 do
            local body = plan.packets[i].body:gsub("^RPQP:[0-9A-Fa-f]+:", "RPQP:AAAA:")
            inbox[100 + i] = {
                sender = "@Master",
                charName = "MasterChar",
                subject = plan.packets[i].subject,
                body = body,
                secs = 10,
            }
        end
        inbox[201] = {
            sender = "@OtherMaster",
            charName = "OtherChar",
            subject = plan.packets[1].subject,
            body = plan.packets[1].body:gsub("^RPQP:[0-9A-Fa-f]+:", "RPQP:BBBB:"),
            secs = 10,
        }
        inbox[202] = {
            sender = "@Master",
            charName = "MasterChar",
            subject = otherPlan.packets[1].subject,
            body = otherPlan.packets[1].body:gsub("^RPQP:[0-9A-Fa-f]+:", "RPQP:CCCC:"),
            secs = 10,
        }

        RPQuest.MailTransport:ScanInbox(false)

        AssertEqual(#alerts, 0, "No alerts triggered for incomplete in-flight parts")
        AssertEqual(#deletedIds, 0, "No mails deleted while parts are incomplete")
        AssertTrue(RPQuest.MailInbox._partGroups["part:@master:AAAA:" .. plan.partCount] ~= nil, "Orphan group tracked")

        -- 2. Deliver complete resend (txId=DDDD) from @Master for "Orphan Cleanup Quest"
        for i = 1, plan.partCount do
            local body = plan.packets[i].body:gsub("^RPQP:[0-9A-Fa-f]+:", "RPQP:DDDD:")
            inbox[300 + i] = {
                sender = "@Master",
                charName = "MasterChar",
                subject = plan.packets[i].subject,
                body = body,
                secs = 1,
            }
        end

        RPQuest.MailTransport:ScanInbox(false)

        local received = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
        AssertEqual(#received, 1, "Complete resend imported")
        AssertEqual(received[1].title, "Orphan Cleanup Quest", "Imported quest title matches")

        for i = 1, plan.partCount - 1 do
            AssertEqual(inbox[100 + i], nil, "Orphan incomplete part " .. i .. " deleted from inbox")
        end
        for i = 1, plan.partCount do
            AssertEqual(inbox[300 + i], nil, "Resent complete part " .. i .. " deleted from inbox")
        end
        AssertEqual(RPQuest.MailInbox._partGroups["part:@master:AAAA:" .. plan.partCount], nil, "Orphan group removed from _partGroups")
        AssertTrue(inbox[201] ~= nil, "Incomplete part from different sender preserved")
        AssertTrue(inbox[202] ~= nil, "Incomplete part for different quest title preserved")

        RPQuest.Announcements.ShowAlert = origShowAlert
        _G.GetNextMailId = origGetNext
        _G.GetMailItemInfo = origGetInfo
        _G.ReadMail = origReadMail
        _G.DeleteMail = origDeleteMail
    end)

    RunTest("MailInbox: sequential async DeleteMail queue via EVENT_MAIL_REMOVED for multi-part RPQP mails (Issue #339)", function()
        mockState.language = "en"
        RPQuest.Locale:Initialize()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        RPQuest.MailTransport:Initialize()
        RPQuest.QuestRepository:SetSetting("autoDeleteMail", true)

        local questCode = RPQuest.ShareCodec:EncodeQuest({
            title = "Async Delete Quest",
            description = string.rep("Detailed lore for async multi-part deletion. ", 45),
            mapId = 1,
            zoneId = 1,
            mapName = "Auridon",
            targets = {
                { name = "Guard", requiredCount = 3, customMessage = string.rep("Note ", 30) },
            },
        })
        local plan = RPQuest.MailTransport:BuildQuestMailPackets(string.rep("RP intro for async delete test. ", 40), questCode, "Async Delete Quest")
        AssertTrue(plan.fits and plan.partCount >= 3, "Test quest splits into at least 3 parts (got " .. tostring(plan.partCount) .. ")")

        local inbox = {}
        local deleteCalls = {}
        local pendingDeleteId = nil
        local origGetNext = _G.GetNextMailId
        local origGetInfo = _G.GetMailItemInfo
        local origReadMail = _G.ReadMail
        local origDeleteMail = _G.DeleteMail

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
            return m.sender, m.charName, m.subject, nil, false, false, true, false, 0, 0, 0, 0, m.secs
        end
        _G.ReadMail = function(id) return inbox[id] and inbox[id].body or "" end
        -- Simulate ESO's async DeleteMail: drops concurrent calls while one deletion is in flight
        _G.DeleteMail = function(id)
            table.insert(deleteCalls, id)
            if pendingDeleteId ~= nil then
                return
            end
            pendingDeleteId = id
        end

        local function fireMailRemoved(id)
            inbox[id] = nil
            if pendingDeleteId == id then
                pendingDeleteId = nil
            end
            RPQuest.MailTransport:OnMailRemoved(id)
        end

        -- 1. Deliver all N parts and scan inbox
        for i = 1, plan.partCount do
            inbox[400 + i] = {
                sender = "@Master",
                charName = "MasterChar",
                subject = plan.packets[i].subject,
                body = plan.packets[i].body,
                secs = 1,
            }
        end
        RPQuest.MailTransport:ScanInbox(false)

        local received = RPQuest.QuestRepository:GetQuestsByRole(RPQuest.Constants.QUEST_ROLE.RECEIVED)
        AssertEqual(#received, 1, "Multi-part quest imported")
        AssertEqual(#deleteCalls, 1, "Only 1 DeleteMail issued immediately while awaiting EVENT_MAIL_REMOVED")
        AssertEqual(deleteCalls[1], 401, "First DeleteMail targets part 1")

        -- Simulate an unrelated mail removal while 401 is still deleting: must not advance queue
        RPQuest.MailTransport:OnMailRemoved(9999)
        AssertEqual(#deleteCalls, 1, "Unrelated EVENT_MAIL_REMOVED does not advance delete queue")

        -- Remove part 2 externally before part 1 finishes -> queue should skip missing part 2 and jump to part 3
        inbox[402] = nil
        fireMailRemoved(401)
        AssertEqual(#deleteCalls, 2, "Advancing after part 1 skips missing part 2 and calls DeleteMail for part 3")
        AssertEqual(deleteCalls[2], 403, "Second DeleteMail targets part 3")

        -- Finish remaining parts sequentially
        for i = 3, plan.partCount do
            fireMailRemoved(400 + i)
        end
        AssertEqual(#deleteCalls, plan.partCount - 1, "All existing parts deleted sequentially")
        for i = 1, plan.partCount do
            AssertEqual(inbox[400 + i], nil, "No orphan part " .. i .. " left in inbox")
        end
        AssertEqual(RPQuest.MailInbox._deletingMailId, nil, "No active _deletingMailId after queue drains")

        -- 2. Mailbox close clears pending delete queue safely
        RPQuest.MailTransport:Initialize()
        RPQuest.QuestRepository:SetSetting("autoDeleteMail", true)
        inbox[501] = { sender = "@Master", charName = "M", subject = "[RPQuest 1/2] Q", body = "RPQP:AA11:1/2\nabc", secs = 1 }
        inbox[502] = { sender = "@Master", charName = "M", subject = "[RPQuest 2/2] Q", body = "RPQP:AA11:2/2\ndef", secs = 1 }
        RPQuest.MailInbox:DisposeMailIds({ 501, 502 })
        AssertTrue(RPQuest.MailInbox._deletingMailId ~= nil, "Deletion in progress before mailbox close")
        RPQuest.MailTransport:OnMailboxClosed()
        AssertEqual(RPQuest.MailInbox._deletingMailId, nil, "OnMailboxClosed clears _deletingMailId")
        AssertEqual(#(RPQuest.MailInbox._deleteQueue or {}), 0, "OnMailboxClosed clears _deleteQueue")
        pendingDeleteId = nil

        -- 3. autoDeleteMail = false records all part IDs in _dismissedMailIds without calling DeleteMail
        RPQuest.MailTransport:Initialize()
        RPQuest.QuestRepository:Initialize(RPQuest.QuestRepository:GetDefaults())
        RPQuest.QuestRepository:SetSetting("autoDeleteMail", false)
        local callsBefore = #deleteCalls
        for i = 1, plan.partCount do
            inbox[600 + i] = {
                sender = "@Master",
                charName = "MasterChar",
                subject = plan.packets[i].subject,
                body = plan.packets[i].body,
                secs = 1,
            }
        end
        RPQuest.MailTransport:ScanInbox(false)
        AssertEqual(#deleteCalls, callsBefore, "DeleteMail NOT called when autoDeleteMail = false")
        for i = 1, plan.partCount do
            AssertEqual(RPQuest.MailInbox._dismissedMailIds[tostring(600 + i)], true, "Part " .. i .. " recorded in _dismissedMailIds")
        end

        _G.GetNextMailId = origGetNext
        _G.GetMailItemInfo = origGetInfo
        _G.ReadMail = origReadMail
        _G.DeleteMail = origDeleteMail
    end)

    RunTest("MailInbox: autoOpenJournalOnReceive opens and selects new quest when enabled and out of combat (Issue #340)", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()

        AssertEqual(RPQuest.QuestRepository:GetSetting("autoOpenJournalOnReceive"), false, "autoOpenJournalOnReceive defaults to false")

        local openCalls = 0
        local selectedIds = {}
        local origOpenTab = RPQuest.JournalTab.OpenTab
        local origSelectQuest = RPQuest.JournalTab.SelectQuest
        RPQuest.JournalTab.OpenTab = function()
            openCalls = openCalls + 1
        end
        RPQuest.JournalTab.SelectQuest = function(_, questId)
            table.insert(selectedIds, questId)
        end

        local origShowAlert = RPQuest.Announcements.ShowAlert
        local origAnnounceReceived = RPQuest.Announcements.AnnounceQuestReceived
        local origAnnounceAccepted = RPQuest.Announcements.AnnounceQuestAccepted
        RPQuest.Announcements.ShowAlert = function() end
        RPQuest.Announcements.AnnounceQuestReceived = function() end
        RPQuest.Announcements.AnnounceQuestAccepted = function() end

        local code = RPQuest.ShareCodec:EncodeQuest({
            title = "Auto Open Quest",
            description = "Test auto open on receive.",
            mapId = 1,
            zoneId = 1,
            mapName = "Auridon",
            targets = { { name = "Bandit" } },
        })

        local function MakeEntry(idNum, sender)
            return {
                mailId = idNum,
                idKey = tostring(idNum),
                senderDisplayName = sender or "@Sender",
                senderCharacterName = "SenderChar",
                subject = "[RPQuest] Auto Open Quest",
                questCode = code,
                title = "Auto Open Quest",
                isIncomplete = false,
            }
        end

        local origPlayerInCombat = mockState.playerInCombat
        mockState.playerInCombat = false

        -- 1. Setting disabled (default): does not open journal
        RPQuest.MailInbox:UpsertReceivedEntry(MakeEntry(961, "@SenderOne"))
        AssertEqual(openCalls, 0, "OpenTab not called when autoOpenJournalOnReceive is false")
        AssertEqual(#selectedIds, 0, "SelectQuest not called when autoOpenJournalOnReceive is false")

        -- 2. Setting enabled, out of combat, pending mode (autoAcceptMail = false)
        RPQuest.QuestRepository:SetSetting("autoOpenJournalOnReceive", true)
        RPQuest.QuestRepository:SetSetting("autoAcceptMail", false)
        RPQuest.MailInbox:UpsertReceivedEntry(MakeEntry(962, "@SenderTwo"))
        AssertEqual(openCalls, 1, "OpenTab called for new pending quest when setting enabled")
        AssertEqual(#selectedIds, 1, "SelectQuest called once for new pending quest")
        local pendingQuest = RPQuest.QuestRepository:GetQuestById(selectedIds[1])
        AssertTrue(pendingQuest ~= nil and RPQuest.QuestRepository:IsOfferedQuest(pendingQuest), "Selected quest is the newly imported pending quest")

        -- 3. Duplicate quest (same sourceMailId re-ingested) does NOT open journal again
        RPQuest.MailInbox._notifiedMailIds["962"] = nil
        RPQuest.MailInbox:UpsertReceivedEntry(MakeEntry(962, "@SenderTwo"))
        AssertEqual(openCalls, 1, "OpenTab not called for duplicate quest")
        AssertEqual(#selectedIds, 1, "SelectQuest not called for duplicate quest")

        -- 4. Setting enabled, out of combat, autoAcceptMail = true
        RPQuest.QuestRepository:SetSetting("autoAcceptMail", true)
        RPQuest.MailInbox:UpsertReceivedEntry(MakeEntry(964, "@SenderThree"))
        AssertEqual(openCalls, 2, "OpenTab called for new auto-accepted quest when setting enabled")
        AssertEqual(#selectedIds, 2, "SelectQuest called for new auto-accepted quest")
        local acceptedQuest = RPQuest.QuestRepository:GetQuestById(selectedIds[2])
        AssertTrue(acceptedQuest ~= nil and not RPQuest.QuestRepository:IsOfferedQuest(acceptedQuest), "Selected quest is the newly auto-accepted quest")

        -- 5. Player in combat: does NOT open journal even when setting enabled
        mockState.playerInCombat = true
        RPQuest.MailInbox:UpsertReceivedEntry(MakeEntry(965, "@SenderFour"))
        AssertEqual(openCalls, 2, "OpenTab not called while player is in combat")
        AssertEqual(#selectedIds, 2, "SelectQuest not called while player is in combat")

        mockState.playerInCombat = origPlayerInCombat
        RPQuest.JournalTab.OpenTab = origOpenTab
        RPQuest.JournalTab.SelectQuest = origSelectQuest
        RPQuest.Announcements.ShowAlert = origShowAlert
        RPQuest.Announcements.AnnounceQuestReceived = origAnnounceReceived
        RPQuest.Announcements.AnnounceQuestAccepted = origAnnounceAccepted
    end)

end

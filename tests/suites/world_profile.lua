-- ============================================================================
-- RPQuest Test Suite: WorldProfile Scanner, RPQW1 Codec & Mail Sync
-- ============================================================================
return function(T)
    local RunTest = T.RunTest
    local AssertEqual = T.AssertEqual
    local AssertTrue = T.AssertTrue
    local mockState = T.mockState

    RunTest("WorldProfile: CaptureLocalSnapshot, RPQW1 round-trip, < 200 chars & < 5 ms", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)

        local origPlayer = mockState.playerName
        local origNumZones = mockState.numZones
        local origDefaultPois = mockState.defaultPoisPerZone
        local origLocked = mockState.lockedZones
        local origEsoPlus = mockState.esoPlus
        local origDiscovered = mockState.discoveredPois

        mockState.playerName = "Lyra Vance^f"
        mockState.numZones = 100
        mockState.defaultPoisPerZone = 12
        mockState.esoPlus = true
        mockState.lockedZones = { [5] = true, [6] = true, [99] = true }
        mockState.discoveredPois = {
            [1] = { [1] = true, [2] = true, [3] = true },
            [42] = { [7] = true, [12] = true },
        }

        local t0 = os.clock()
        local code, snap = RPQuest.WorldProfile:CaptureAndEncode()
        local decoded, err = RPQuest.WorldProfile:DecodeSnapshot(code)
        local elapsedMs = (os.clock() - t0) * 1000

        AssertTrue(type(code) == "string" and code:sub(1, 6) == "RPQW1:", "RPQW1 prefix expected")
        AssertTrue(#code < 200, string.format("Expected < 200 chars, got %d", #code))
        AssertTrue(elapsedMs < 5.0, string.format("Expected < 5 ms, got %.3f ms", elapsedMs))
        AssertTrue(decoded ~= nil, "DecodeSnapshot failed: " .. tostring(err))
        AssertEqual(true, decoded.esoPlus, "esoPlus should be true")
        AssertEqual("Lyra Vance", decoded.characterName, "characterName should be normalized")
        AssertEqual(100, decoded.numZones, "numZones should match")
        AssertEqual(1200, decoded.totalPois, "totalPois should match")
        AssertEqual(true, decoded.dlcBits[1], "zone 1 should be unlocked")
        AssertEqual(false, decoded.dlcBits[5], "zone 5 should be locked")
        AssertEqual(false, decoded.dlcBits[99], "zone 99 should be locked")
        AssertEqual(true, decoded.poiBits[1], "zone 1 poi 1 discovered")
        AssertEqual(false, decoded.poiBits[4], "zone 1 poi 4 undiscovered")
        local z42p7 = (41 * 12) + 7
        AssertEqual(true, decoded.poiBits[z42p7], "zone 42 poi 7 discovered")
        AssertEqual(snap.dlcMask, decoded.dlcMask, "dlcMask should round-trip")
        AssertEqual(snap.poiMask, decoded.poiMask, "poiMask should round-trip")

        mockState.playerName = origPlayer
        mockState.numZones = origNumZones
        mockState.defaultPoisPerZone = origDefaultPois
        mockState.lockedZones = origLocked
        mockState.esoPlus = origEsoPlus
        mockState.discoveredPois = origDiscovered
    end)

    RunTest("QuestRepository: SaveWorldProfile preserves multiple characters per account", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)

        RPQuest.QuestRepository:SaveWorldProfile("PlayerOne", {
            characterName = "CharA^m",
            dlcMask = "MASK1",
            esoPlus = false,
            poiMask = "POIA",
        })
        RPQuest.QuestRepository:SaveWorldProfile("@PlayerOne", {
            characterName = "CharB^f",
            dlcMask = "MASK2",
            esoPlus = true,
            poiMask = "POIB",
        })

        local acc = RPQuest.QuestRepository:GetWorldProfile("@PlayerOne")
        AssertTrue(acc ~= nil, "Account profile should exist")
        AssertEqual("MASK2", acc.dlcMask, "Account dlcMask should update")
        AssertEqual(true, acc.esoPlus, "Account esoPlus should update")
        AssertTrue(acc.characters["CharA"] ~= nil, "CharA should be preserved")
        AssertEqual("POIA", acc.characters["CharA"].poiMask, "CharA poiMask preserved")
        AssertTrue(acc.characters["CharB"] ~= nil, "CharB should be stored")
        AssertEqual("POIB", acc.characters["CharB"].poiMask, "CharB poiMask stored")
    end)

    RunTest("MailTransport & MailInbox: dedicated [RPQuest:Profile] send and silent ingestion", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()

        local sentMails = {}
        local deletedMails = {}
        local inbox = {}

        local origSendMail = _G.SendMail
        local origReqOpen = _G.RequestOpenMailbox
        local origClose = _G.CloseMailbox
        local origGetNext = _G.GetNextMailId
        local origGetInfo = _G.GetMailItemInfo
        local origReadMail = _G.ReadMail
        local origDeleteMail = _G.DeleteMail
        local origIsShowing = SCENE_MANAGER.IsShowing

        _G.SendMail = function(to, subject, body)
            table.insert(sentMails, { to = to, subject = subject, body = body })
            RPQuest.MailTransport:OnMailSendSuccess(to)
        end
        _G.RequestOpenMailbox = function() RPQuest.MailTransport:OnMailboxOpened() end
        _G.CloseMailbox = function() end
        SCENE_MANAGER.IsShowing = function() return false end

        local ok, err = RPQuest.MailTransport:SendWorldProfile("MasterOne")
        AssertTrue(ok == true, "SendWorldProfile should succeed: " .. tostring(err))
        AssertEqual(1, #sentMails, "One profile mail sent")
        AssertTrue(sentMails[1].subject:sub(1, 18) == "[RPQuest:Profile] ", "Profile subject prefix")
        AssertTrue(sentMails[1].body:sub(1, 6) == "RPQW1:", "Profile body should be RPQW1")

        -- Simulate Master receiving that mail
        local masterSv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(masterSv)
        RPQuest.MailTransport:Initialize()

        inbox[1] = {
            id = 501,
            senderDisplay = "@PlayerOne",
            senderChar = "Jugador",
            subject = sentMails[1].subject,
            body = sentMails[1].body,
        }
        _G.GetNextMailId = function(prev)
            if prev == nil and inbox[1] then return 501 end
            return nil
        end
        _G.GetMailItemInfo = function(mailId)
            if mailId == 501 and inbox[1] then
                return inbox[1].senderDisplay, inbox[1].senderChar, inbox[1].subject, nil, nil, nil, nil, nil, nil, nil, nil, nil, 1
            end
            return nil
        end
        _G.ReadMail = function(mailId)
            return (mailId == 501 and inbox[1]) and inbox[1].body or ""
        end
        _G.DeleteMail = function(mailId)
            table.insert(deletedMails, mailId)
            inbox[1] = nil
            RPQuest.MailTransport:OnMailRemoved(mailId)
        end

        RPQuest.MailInbox:ScanInbox()
        local cached = RPQuest.QuestRepository:GetWorldProfile("@PlayerOne")
        AssertTrue(cached ~= nil, "Master should cache @PlayerOne profile")
        AssertTrue(cached.characters["Jugador"] ~= nil, "Master should cache Jugador POIs")
        AssertEqual(0, #RPQuest.QuestRepository:GetAllQuests(), "No quests should be created from profile mail")
        AssertEqual(1, #deletedMails, "Profile mail should be auto-disposed")

        _G.SendMail = origSendMail
        _G.RequestOpenMailbox = origReqOpen
        _G.CloseMailbox = origClose
        _G.GetNextMailId = origGetNext
        _G.GetMailItemInfo = origGetInfo
        _G.ReadMail = origReadMail
        _G.DeleteMail = origDeleteMail
        SCENE_MANAGER.IsShowing = origIsShowing
    end)

    RunTest("MailTransport & MailInbox: piggyback RPQW1 in Accepted/Done reports within 700-char limit", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()

        local prepared = RPQuest.QuestRepository:CreateNewPreparedDraft()
        RPQuest.QuestRepository:UpdateDraftFields({
            title = "Piggyback Test",
            zoneId = 381,
            zoneName = "Auridon",
            recipientAccount = "@PlayerTwo",
        })
        RPQuest.QuestRepository:SetDraftCapturedTarget({
            name = "Bandit",
            requiredCount = 1,
            zoneId = 381,
            zoneName = "Auridon",
        })
        prepared = RPQuest.QuestRepository:CommitDraftChanges()
        prepared.senderDisplayName = "@MasterOne"
        prepared.senderCharacterName = "MasterChar"
        local qCode = RPQuest.QuestRepository:ExportQuestToCode(prepared.id)
        local received = RPQuest.QuestRepository:ImportQuestFromCode(qCode, "@MasterOne", {
            status = RPQuest.Constants.QUEST_STATUS.ACTIVE,
        })

        local sentMails = {}
        local origSendMail = _G.SendMail
        local origReqOpen = _G.RequestOpenMailbox
        local origClose = _G.CloseMailbox
        local origMaxBody = _G.MAIL_MAX_BODY_CHARACTERS
        local origIsShowing = SCENE_MANAGER.IsShowing

        _G.MAIL_MAX_BODY_CHARACTERS = 700
        _G.SendMail = function(to, subject, body)
            table.insert(sentMails, { to = to, subject = subject, body = body })
            RPQuest.MailTransport:OnMailSendSuccess(to)
        end
        _G.RequestOpenMailbox = function() RPQuest.MailTransport:OnMailboxOpened() end
        _G.CloseMailbox = function() end
        SCENE_MANAGER.IsShowing = function() return false end

        local okAcc = RPQuest.MailTransport:SendAcceptanceReport(received)
        AssertTrue(okAcc == true, "SendAcceptanceReport should succeed")
        AssertEqual(1, #sentMails, "Acceptance mail sent")
        AssertTrue(#sentMails[1].body <= 700, "Piggybacked acceptance body <= 700 chars")
        AssertTrue(sentMails[1].body:find("RPQC1:", 1, true) ~= nil, "Contains RPQC1")
        AssertTrue(sentMails[1].body:find("RPQW1:", 1, true) ~= nil, "Contains piggybacked RPQW1")

        -- Verify piggyback is omitted when body limit is too small
        _G.MAIL_MAX_BODY_CHARACTERS = 75
        received.completed = true
        local okComp = RPQuest.MailTransport:SendCompletionReport(received)
        AssertTrue(okComp == true, "SendCompletionReport should succeed under tight limit")
        AssertEqual(2, #sentMails, "Completion mail sent")
        AssertTrue(sentMails[2].body:find("RPQC1:", 1, true) ~= nil, "Contains RPQC1")
        AssertTrue(sentMails[2].body:find("RPQW1:", 1, true) == nil, "Omits RPQW1 when exceeding limit")

        -- Master processes the piggybacked acceptance mail
        local origDeleteMail = _G.DeleteMail
        _G.DeleteMail = function() end
        local processed = RPQuest.MailInbox:ProcessCompletionMail(901, "@PlayerTwo", sentMails[1].subject, sentMails[1].body)
        AssertTrue(processed == true, "Master should process piggybacked acceptance mail")
        local cached = RPQuest.QuestRepository:GetWorldProfile("@PlayerTwo")
        AssertTrue(cached ~= nil, "Master should ingest piggybacked WorldProfile")
        AssertTrue(cached.characters["Jugador"] ~= nil, "Piggybacked character POI mask saved")

        _G.DeleteMail = origDeleteMail
        _G.SendMail = origSendMail
        _G.RequestOpenMailbox = origReqOpen
        _G.CloseMailbox = origClose
        _G.MAIL_MAX_BODY_CHARACTERS = origMaxBody
        SCENE_MANAGER.IsShowing = origIsShowing
    end)
end

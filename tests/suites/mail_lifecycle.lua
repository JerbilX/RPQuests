-- ============================================================================
-- RPQuest Test Suite: Mail Quest Acceptance, Completion & Sent Lifecycle
-- ============================================================================
return function(T)
    local RunTest = T.RunTest
    local AssertEqual = T.AssertEqual
    local AssertTrue = T.AssertTrue
    local mockState = T.mockState

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
        AssertEqual(RPQuest.QuestRepository:GetQuestLifecycle(prepared), "sent", "GetQuestLifecycle remains 'sent'")
        AssertEqual(RPQuest.QuestRepository:GetQuestResolution(prepared), "accepted", "GetQuestResolution returns 'accepted'")
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
        AssertEqual(RPQuest.QuestRepository:GetQuestLifecycle(prepared), "sent", "Lifecycle remains sent")
        AssertEqual(RPQuest.QuestRepository:GetQuestResolution(prepared), "completed", "Completion overwrites accepted resolution")

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
        AssertEqual(RPQuest.QuestRepository:GetQuestResolution(prepared), "completed", "Late acceptance does not overwrite completed resolution")
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

    RunTest("43. Issue #160: Sent accordion section & detail progress/results", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.JournalTab:Initialize()

        mockState.reticleExists = true
        mockState.reticleName = "Guard"
        mockState.mapId = 32
        mockState.zoneId = 381
        mockState.mapName = "Auridon"
        mockState.playerX = 0.5
        mockState.playerY = 0.5

        -- 1. Unsent draft stays in Preparing
        RPQuest.TargetCapture:CaptureFromReticle()
        local draftQuest = RPQuest.QuestRepository:SaveDraft("Unsent Draft", "Still preparing", nil, "", false, "@PlayerA")
        AssertEqual(RPQuest.QuestRepository:GetQuestLifecycle(draftQuest), "draft", "Draft starts with lifecycle 'draft'")
        AssertEqual(RPQuest.QuestRepository:GetQuestResolution(draftQuest), nil, "Draft has nil resolution")

        -- 2. Prepared quest with requireUndetected + optional target
        RPQuest.TargetCapture:CaptureFromReticle()
        RPQuest.QuestRepository:UpdateDraftTarget(1, { optional = true })
        mockState.reticleName = "Captain"
        RPQuest.TargetCapture:CaptureFromReticle()
        local sentQuest = RPQuest.QuestRepository:SaveDraft("Sent Contract", "Stealth + optional", nil, "", true, "@PlayerB")

        local function hasRowInSection(sectionKey, questId)
            local inSection = false
            for _, b in pairs(RPQuest.JournalTab.rowBindings) do
                if b.isHeader then
                    inSection = (b.sectionKey == sectionKey)
                elseif inSection and b.questId == questId then
                    return true
                end
            end
            return false
        end

        RPQuest.JournalTab:ToggleSection("preparing")
        AssertEqual(hasRowInSection("preparing", draftQuest.id), true, "Unsent draft appears in Preparing")
        AssertEqual(hasRowInSection("preparing", sentQuest.id), true, "Unsent contract appears in Preparing before send")

        -- 3. MarkPreparedQuestSent emits QUEST_SENT, expands Sent, and moves quest out of Preparing
        local okSent = RPQuest.QuestRepository:MarkPreparedQuestSent(sentQuest.id, "@PlayerB")
        AssertEqual(okSent, true, "MarkPreparedQuestSent succeeds")
        AssertEqual(RPQuest.JournalTab.collapsedSections.sent, false, "Sent section expands on QUEST_SENT")
        AssertEqual(RPQuest.JournalTab.collapsedSections.preparing, true, "Preparing collapses when Sent expands")
        AssertEqual(hasRowInSection("sent", sentQuest.id), true, "Sent quest appears in Sent section")
        AssertTrue(RPQuest.JournalTab.detailStatus:GetText():find("Sent", 1, true) ~= nil, "Detail status shows Sent")

        -- 4. Accepted state stays in Sent and shows Accepted
        RPQuest.QuestRepository:RecordMailDelivery(sentQuest.id, "@PlayerB", {
            characterName = "ShadowChar",
            completedAt = 1001,
            completed = false,
            accepted = true,
            resultType = "accepted",
        })
        RPQuest.JournalTab:SelectQuest(sentQuest.id)
        AssertEqual(hasRowInSection("sent", sentQuest.id), true, "Accepted quest stays in Sent section")
        AssertTrue(RPQuest.JournalTab.detailStatus:GetText():find("Accepted", 1, true) ~= nil, "Detail status shows Accepted")

        -- 5. Rejected state stays in Sent and shows Rejected
        RPQuest.QuestRepository:RecordMailDelivery(sentQuest.id, "@PlayerB", {
            characterName = "ShadowChar",
            completedAt = 1002,
            completed = false,
            resultType = "rejected",
        })
        AssertEqual(hasRowInSection("sent", sentQuest.id), true, "Rejected quest stays in Sent section")
        AssertTrue(RPQuest.JournalTab.detailStatus:GetText():find("Rejected", 1, true) ~= nil, "Detail status shows Rejected")

        -- 6. Completed undetected with optional fulfilled
        RPQuest.QuestRepository:RecordMailDelivery(sentQuest.id, "@PlayerB", {
            characterName = "ShadowChar",
            completedAt = 1003,
            completed = true,
            resultType = "completed",
            wasDetected = false,
            optionalTargets = { true },
        })
        AssertEqual(hasRowInSection("sent", sentQuest.id), true, "Completed sent quest stays in Sent section")
        local statusUndetected = RPQuest.JournalTab.detailStatus:GetText()
        AssertTrue(statusUndetected:find("Completed", 1, true) ~= nil, "Detail status shows Completed")
        AssertTrue(statusUndetected:find("Undetected", 1, true) ~= nil, "Detail status shows Undetected result")
        AssertTrue(statusUndetected:find("1/1", 1, true) ~= nil, "Detail status shows optional 1/1 result")
        local objUndetected = RPQuest.JournalTab.detailObjText:GetText()
        AssertTrue(objUndetected:find("Undetected", 1, true) ~= nil, "Objective lines reflect Undetected completion result")
        AssertTrue(objUndetected:find("(Completed)", 1, true) ~= nil, "Objective lines reflect completed targets")

        -- 7. Completed detected with optional missed
        RPQuest.QuestRepository:RecordMailDelivery(sentQuest.id, "@PlayerB", {
            characterName = "ShadowChar",
            completedAt = 1004,
            completed = true,
            resultType = "completed",
            wasDetected = true,
            optionalTargets = { false },
        })
        local statusDetected = RPQuest.JournalTab.detailStatus:GetText()
        AssertTrue(statusDetected:find("Detected", 1, true) ~= nil, "Detail status shows Detected result")
        AssertTrue(statusDetected:find("0/1", 1, true) ~= nil, "Detail status shows optional 0/1 result")
        local objDetected = RPQuest.JournalTab.detailObjText:GetText()
        AssertTrue(objDetected:find("Detected", 1, true) ~= nil, "Objective lines reflect Detected completion result")
    end)

    RunTest("Issue #255: End-to-end QUEST_FAILED (location & stealth) auto-mail, Master inbox processing, and retry precedence", function()
        local sv = RPQuest.QuestRepository:GetDefaults()
        sv.settings.autoSendCompletionMail = true
        sv.settings.autoDeleteMail = true
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.MailTransport:Initialize()
        RPQuest.JournalTab:Initialize()

        local sentMails = {}
        local alerts = {}
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
        RPQuest.Announcements.ShowAlert = function(_, msg, isErr)
            table.insert(alerts, { msg = msg, isErr = isErr })
        end

        -- 1. Master prepares stealth-required quest and sends to player
        local masterPrep = RPQuest.QuestRepository:BuildQuestRecord(1, "Stealth Failure", "Do not get caught",
            RPQuest.QuestDraftStore:CloneTargetsList({
                { name = "Sentry", requiredCount = 1, areaCenterX = 0.5, areaCenterY = 0.5, areaRadius = 0.125 },
            }), {
            mapId = 10,
            zoneId = 20,
            targetX = 0.5,
            targetY = 0.5,
            stealthMode = "required",
            recipientAccount = "@PlayerAcc",
        }, RPQuest.Constants.QUEST_ROLE.PREPARED)
        table.insert(sv.quests, masterPrep)
        sv.nextId = 2
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.QuestRepository:MarkPreparedQuestSent(masterPrep.id, "@PlayerAcc")

        local stealthCode = RPQuest.QuestRepository:ExportQuestToCode(masterPrep.id)
        local stealthQuest = RPQuest.QuestRepository:ImportQuestFromCode(stealthCode, "@Master", {
            status = RPQuest.Constants.QUEST_STATUS.ACTIVE,
            sourceMailId = "mail_fail_stealth",
        })
        RPQuest.QuestRepository:SetActiveQuest(stealthQuest.id)

        RPQuest.QuestRepository:RecordPlayerDetected({ mapId = 10, zoneId = 20, x = 0.5, y = 0.5 })
        RPQuest.MailTransport:OnMailboxOpened()
        RPQuest.MailTransport:OnMailSendSuccess("@Master")

        AssertEqual(stealthQuest.failed, true, "Stealth quest marked failed")
        AssertEqual(RPQuest.QuestRepository:GetQuestResolution(stealthQuest), "failed", "Received quest resolution is 'failed'")
        AssertEqual(stealthQuest.failureReported, true, "failureReported marked true after mail send")
        AssertEqual(#sentMails, 1, "Auto-sent 1 failure mail to @Master")
        AssertTrue(sentMails[1].subject:find("[RPQuest:Failed] ", 1, true) == 1, "Failure mail has [RPQuest:Failed] prefix")

        -- Reset clears failureReported
        RPQuest.QuestRepository:ResetQuest(stealthQuest.id)
        AssertEqual(stealthQuest.failureReported, false, "ResetQuest clears failureReported")
        AssertEqual(RPQuest.QuestRepository:GetQuestResolution(stealthQuest), "accepted", "ResetQuest restores accepted resolution on received quest")

        -- 2. Player receives location-required quest and fails outside location
        local locQuest = RPQuest.QuestRepository:BuildQuestRecord(10, "Location Failure", "Eliminate inside area", {
            { name = "Target", requiredCount = 1, locationRequired = true, locationZoneId = 20, worldX = 1000, worldZ = 1000, locationRadius = 800 },
        }, {
            mapId = 10,
            zoneId = 20,
            senderDisplayName = "@Master",
            status = RPQuest.Constants.QUEST_STATUS.ACTIVE,
        }, RPQuest.Constants.QUEST_ROLE.RECEIVED)
        table.insert(sv.quests, locQuest)
        sv.nextId = 11
        RPQuest.QuestRepository:Initialize(sv)
        RPQuest.QuestRepository:SetActiveQuest(locQuest.id)
        RPQuest.QuestRepository:RecordTargetEliminated("Target", { worldZoneId = 20, worldX = 99999, worldZ = 99999 })
        RPQuest.MailTransport:OnMailboxOpened()
        RPQuest.MailTransport:OnMailSendSuccess("@Master")
        AssertEqual(#sentMails, 2, "Location failure auto-sends second failure mail")
        AssertEqual(locQuest.failureReported, true, "Location failure sets failureReported=true")

        -- 3. Master side: process [RPQuest:Failed] mail
        masterPrep = RPQuest.QuestRepository:GetQuestById(1)

        local mailRead = false
        _G.GetNextMailId = function(prev)
            if not prev and not mailRead then return 701 end
            return nil
        end
        _G.GetMailItemInfo = function(id)
            if id == 701 then
                return "@PlayerAcc", "ShadowChar", sentMails[1].subject, "", true, false, false, false, 0, 0, 0, 30, 1, 0
            end
        end
        _G.ReadMail = function(id) return (id == 701) and sentMails[1].body or "" end
        _G.DeleteMail = function(id)
            if id == 701 then mailRead = true end
        end

        RPQuest.MailTransport:ScanInbox(false)
        AssertEqual(RPQuest.QuestRepository:GetQuestLifecycle(masterPrep), "sent", "Master quest stays in 'sent' lifecycle")
        AssertEqual(RPQuest.QuestRepository:GetQuestResolution(masterPrep), "failed", "Master quest resolution updated to 'failed'")
        AssertTrue(alerts[#alerts].msg == RPQuest.Locale:Get("ALERT_MAIL_FAILURE_RECEIVED", "@PlayerAcc", masterPrep.title), "Master receives ALERT_MAIL_FAILURE_RECEIVED")

        -- UI reflects Sent — Failed in detail and [Failed] in Sent list
        RPQuest.JournalTab:SelectQuest(masterPrep.id)
        if RPQuest.JournalTab.collapsedSections and RPQuest.JournalTab.collapsedSections.sent then
            RPQuest.JournalTab:ToggleSection("sent")
        end
        RPQuest.JournalTab:Refresh()
        AssertTrue(RPQuest.JournalTab.detailStatus:GetText():find("Sent", 1, true) ~= nil, "Detail status shows Sent")
        AssertTrue(RPQuest.JournalTab.detailStatus:GetText():find("Failed", 1, true) ~= nil, "Detail status shows Failed")
        local foundSentFailedRow = false
        for _, b in pairs(RPQuest.JournalTab.rowBindings) do
            if b.questId == masterPrep.id then
                local rowText = b.text or ""
                foundSentFailedRow = rowText:find(RPQuest.Locale:Get("LIST_SENT_STATUS_FAILED"), 1, true) ~= nil
            end
        end
        AssertTrue(foundSentFailedRow, "Sent list row displays [Failed]")

        -- 4. Late acceptance does not overwrite failed, but later completion after retry DOES overwrite failed
        RPQuest.QuestRepository:RecordMailDelivery(masterPrep.id, "@PlayerAcc", {
            characterName = "ShadowChar",
            completedAt = 2000,
            accepted = true,
            resultType = "accepted",
        })
        AssertEqual(RPQuest.QuestRepository:GetQuestResolution(masterPrep), "failed", "Late acceptance does not overwrite failed")

        RPQuest.QuestRepository:RecordMailDelivery(masterPrep.id, "@PlayerAcc", {
            characterName = "ShadowChar",
            completedAt = 2001,
            completed = true,
            resultType = "completed",
            wasDetected = false,
        })
        AssertEqual(RPQuest.QuestRepository:GetQuestResolution(masterPrep), "completed", "Later completion after retry overwrites failed")

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

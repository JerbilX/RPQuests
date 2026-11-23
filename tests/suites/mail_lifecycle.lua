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
        AssertEqual(RPQuest.QuestRepository:GetPreparedQuestStatus(draftQuest), "draft", "Draft starts with status 'draft'")

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

end

-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0015-separacion-ciclo-de-vida-y-estado-de-resolucion.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalActions = {}
local JournalActions = Addon.JournalActions

local VIEW_MODE = Addon.JournalWidgets.VIEW_MODE
local QuestList = Addon.JournalQuestList

function JournalActions:RegisterRepositoryListener(tab)
    Addon.QuestRepository:RegisterListener(function(eventType, quest)
        if eventType == "QUEST_CREATED" or eventType == "QUEST_UPDATED" or eventType == "QUEST_SENT" then
            if quest and quest.id then
                QuestList:ExpandOnlySection(tab, QuestList:GetQuestSectionKey(quest))
                tab.listOffset = 0
                QuestList:SetSelectedQuestId(tab, quest.id)
            end
            tab.viewMode = VIEW_MODE.DETAIL
        elseif eventType == "QUEST_DRAFT_CREATED" then
            if quest and quest.id then
                QuestList:ExpandOnlySection(tab, QuestList:GetQuestSectionKey(quest))
                tab.listOffset = 0
                QuestList:SetSelectedQuestId(tab, quest.id)
            end
            tab.viewMode = VIEW_MODE.EDITOR
        elseif eventType == "QUEST_IMPORTED" or eventType == "QUEST_ACCEPTED" then
            if quest and quest.id then
                QuestList:ExpandOnlySection(tab, "missions")
                tab.listOffset = 0
                QuestList:SetSelectedQuestId(tab, quest.id)
            end
            tab.viewMode = VIEW_MODE.DETAIL
        elseif eventType == "QUEST_OFFERED" then
            if quest and quest.id then
                QuestList:ExpandOnlySection(tab, "pending")
                tab.listOffset = 0
                if not tab.selectedQuestId then
                    QuestList:SetSelectedQuestId(tab, quest.id)
                end
            end
        elseif eventType == "QUEST_DELETED" or eventType == "QUEST_REJECTED" then
            if quest and tab.selectedQuestId == quest.id then
                QuestList:SetSelectedQuestId(tab, nil)
            end
            local draft = Addon.QuestRepository:GetDraft()
            if quest and (tab.viewMode == VIEW_MODE.EDITOR or draft.editingQuestId == quest.id) then
                Addon.QuestRepository:ResetDraft()
                tab:ClearEditorInputs()
                tab.viewMode = VIEW_MODE.DETAIL
            end
        elseif eventType == "DRAFT_TARGET_CAPTURED" then
            if tab.viewMode ~= VIEW_MODE.EDITOR then
                tab.viewMode = VIEW_MODE.EDITOR
            end
        elseif eventType == "DRAFT_UPDATED" or eventType == "LAST_NPC_UPDATED" or eventType == "WORLD_PROFILE_UPDATED" then
            if tab._suppressRepositoryRefresh then
                return
            end
            if tab.viewMode == VIEW_MODE.EDITOR and not tab.panel:IsHidden() then
                tab:RefreshEditorPane()
            else
                tab._dirty = true
            end
            return
        end
        if tab._suppressRepositoryRefresh then
            return
        end
        if tab.panel:IsHidden() then
            tab._dirty = true
        else
            tab:Refresh()
        end
    end)
end

function JournalActions:SyncEditorInputsToDraft(tab)
    local draft = Addon.QuestRepository:GetDraft()
    local fields = {}
    if tab.titleEdit then fields.title = tab.titleEdit:GetText() end
    if tab.descEdit then fields.description = tab.descEdit:GetText() end
    if tab.recipientEdit then fields.recipientAccount = tab.recipientEdit:GetText() end
    if tab.recipientCharEdit then fields.recipientCharacterName = tab.recipientCharEdit:GetText() end
    if tab.completionEdit then fields.completionMessage = tab.completionEdit:GetText() end
    if next(fields) ~= nil then
        Addon.QuestRepository:UpdateDraftFields(fields, true)
    end
    local dlgIdx = tab.selectedDialogueIndex
    if dlgIdx and draft.dialogues and draft.dialogues[dlgIdx] then
        local dlgFields = {}
        if tab.clueEdit then dlgFields.clue = tab.clueEdit:GetText() end
        if tab.dlgResponseEdit then dlgFields.response = tab.dlgResponseEdit:GetText() end
        Addon.QuestRepository:UpdateDraftDialogue(dlgIdx, dlgFields, true)
    end
    local discIdx = tab.selectedDiscoveryIndex
    if discIdx and draft.discoveries and draft.discoveries[discIdx] and tab.discoveryMsgEdit then
        Addon.QuestRepository:UpdateDraftDiscoveryPoint(discIdx, { message = tab.discoveryMsgEdit:GetText() }, true)
    end
    local targetIdx = tab.selectedTargetIndex
    if targetIdx and draft.targets and draft.targets[targetIdx] then
        local targetFields = {}
        if tab.targetCustomEdit then targetFields.customMessage = tab.targetCustomEdit:GetText() end
        if tab.targetInLocEdit then targetFields.customMessageInLocation = tab.targetInLocEdit:GetText() end
        if next(targetFields) ~= nil then
            Addon.QuestRepository:UpdateDraftTarget(targetIdx, targetFields, true)
        end
    end
end

function JournalActions:AutoPreserveDraft(tab)
    if tab.viewMode ~= VIEW_MODE.EDITOR then
        return nil
    end
    local draft = Addon.QuestRepository:GetDraft()
    if not draft or not draft.editingQuestId then
        return nil
    end
    tab:SyncEditorInputsToDraft()
    return Addon.QuestRepository:CommitDraftChanges()
end

function JournalActions:SelectQuest(tab, questId)
    tab:AutoPreserveDraft()
    tab._suppressRepositoryRefresh = true
    if Addon.QuestRepository:GetDraft().editingQuestId then
        Addon.QuestRepository:ResetDraft()
    end
    tab._suppressRepositoryRefresh = false
    QuestList:SetSelectedQuestId(tab, questId)
    tab.viewMode = VIEW_MODE.DETAIL
    if tab.detailScroll and tab.detailScroll.scroll and tab.detailScroll.scroll.SetVerticalScroll then
        tab.detailScroll.scroll:SetVerticalScroll(0)
    end
    tab:Refresh()
end

local function ApplyDraftToEditor(tab, draft)
    tab.selectedDiscoveryIndex = nil
    tab.titleEdit:SetText(draft.title or "")
    tab.descEdit:SetText(draft.description or "")
    if tab.recipientEdit then tab.recipientEdit:SetText(draft.recipientAccount or "") end
    if tab.recipientCharEdit then tab.recipientCharEdit:SetText(draft.recipientCharacterName or "") end
    if tab.clueEdit then tab.clueEdit:SetText("") end
    tab.completionEdit:SetText(draft.completionMessage or "")
    tab.selectedDialogueIndex = (#(draft.dialogues or {}) > 0) and 1 or nil
    tab.editorSectionsCollapsed = {
        header = false,
        target = true,
        discovery = true,
        dialogue = true,
        options = true,
    }
    tab.viewMode = VIEW_MODE.EDITOR
    tab:Refresh()
end

function JournalActions:OpenCreateEditor(tab)
    tab:AutoPreserveDraft()
    tab._suppressRepositoryRefresh = true
    local newQuest = Addon.QuestRepository:CreateNewPreparedDraft()
    tab._suppressRepositoryRefresh = false
    if newQuest then
        QuestList:ExpandOnlySection(tab, QuestList:GetQuestSectionKey(newQuest))
        tab.listOffset = 0
        QuestList:SetSelectedQuestId(tab, newQuest.id)
    end
    local draft = Addon.QuestRepository:GetDraft()
    ApplyDraftToEditor(tab, draft)
end

function JournalActions:OpenEditEditor(tab, questId)
    local quest = Addon.QuestRepository:GetQuestById(questId)
    tab._suppressRepositoryRefresh = true
    local draft, err = Addon.QuestRepository:LoadQuestIntoDraft(questId)
    tab._suppressRepositoryRefresh = false
    if not draft then
        if err then
            Addon.Announcements:ShowAlert(err, true)
        end
        return
    end
    if quest then
        QuestList:ExpandOnlySection(tab, QuestList:GetQuestSectionKey(quest))
        tab.listOffset = 0
        QuestList:SetSelectedQuestId(tab, quest.id)
    end
    ApplyDraftToEditor(tab, draft)
end

function JournalActions:ClearEditorInputs(tab)
    if tab.titleEdit then tab.titleEdit:SetText("") end
    if tab.descEdit then tab.descEdit:SetText("") end
    if tab.recipientEdit then tab.recipientEdit:SetText("") end
    if tab.recipientCharEdit then tab.recipientCharEdit:SetText("") end
    if tab.clueEdit then tab.clueEdit:SetText("") end
    if tab.completionEdit then tab.completionEdit:SetText("") end
    if tab.discoveryMsgEdit then tab.discoveryMsgEdit:SetText("") end
    if tab.dlgResponseEdit then tab.dlgResponseEdit:SetText("") end
    tab.selectedDialogueIndex = nil
    tab.selectedDiscoveryIndex = nil
end

function JournalActions:OnSaveDraftClicked(tab)
    local titleText = tab.titleEdit:GetText()
    local descText = tab.descEdit:GetText()
    local recipientText = tab.recipientEdit and tab.recipientEdit:GetText() or ""
    local recipientCharText = tab.recipientCharEdit and tab.recipientCharEdit:GetText() or ""
    local compMsgText = tab.completionEdit and tab.completionEdit:GetText() or ""
    local draft = Addon.QuestRepository:GetDraft()
    local dlgIdx = tab.selectedDialogueIndex
    if dlgIdx and draft.dialogues and draft.dialogues[dlgIdx] then
        local dlgFields = {}
        if tab.clueEdit then dlgFields.clue = tab.clueEdit:GetText() end
        if tab.dlgResponseEdit then dlgFields.response = tab.dlgResponseEdit:GetText() end
        Addon.QuestRepository:UpdateDraftDialogue(dlgIdx, dlgFields, true)
    end
    local discIdx = tab.selectedDiscoveryIndex
    if discIdx and draft.discoveries and draft.discoveries[discIdx] and tab.discoveryMsgEdit then
        Addon.QuestRepository:UpdateDraftDiscoveryPoint(discIdx, { message = tab.discoveryMsgEdit:GetText() }, true)
    end

    local savedQuest, err = Addon.QuestRepository:SaveDraft(titleText, descText, nil, compMsgText, nil, recipientText, recipientCharText)
    if not savedQuest then
        if err then
            Addon.Announcements:ShowAlert(err, true)
        end
        return
    end

    tab:ClearEditorInputs()
    Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_SAVED", savedQuest.title), false)
end

function JournalActions:AcceptSelectedOfferedQuest(tab)
    if not tab.selectedQuestId then return false end
    local ok, q = Addon.QuestRepository:AcceptOfferedQuest(tab.selectedQuestId)
    if ok and q then
        Addon.Announcements:AnnounceQuestAccepted(q)
        return true
    end
    return false
end

function JournalActions:RejectSelectedOfferedQuest(tab)
    if not tab.selectedQuestId then return false end
    local ok, q = Addon.QuestRepository:RejectOfferedQuest(tab.selectedQuestId)
    if ok and q then
        Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_REJECTED", q.title or ""), false)
        return true
    end
    return false
end

function JournalActions:DuplicateSelectedQuest(tab)
    if not tab.selectedQuestId then return nil end
    local newQuest, err = Addon.QuestRepository:DuplicateQuest(tab.selectedQuestId)
    if not newQuest then
        if err then
            Addon.Announcements:ShowAlert(err, true)
        end
        return nil
    end
    Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_COPIED", newQuest.title or ""), false)
    return newQuest
end

function JournalActions:MigrateSelectedQuest(tab)
    if not tab.selectedQuestId then return nil end
    tab._suppressRepositoryRefresh = true
    local newQuest, err = Addon.QuestRepository:MigratePreparedQuest(tab.selectedQuestId)
    tab._suppressRepositoryRefresh = false
    if not newQuest then
        if err then
            Addon.Announcements:ShowAlert(err, true)
        end
        return nil
    end
    QuestList:SetSelectedQuestId(tab, newQuest.id)
    Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_MIGRATED", newQuest.title or ""), false)
    tab:OpenEditEditor(newQuest.id)
    return newQuest
end

function JournalActions:OnToggleActiveClicked(tab)
    local q = Addon.QuestRepository:GetQuestById(tab.selectedQuestId)
    if not q then return end

    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    local isPrepared = Addon.QuestRepository:IsPreparedQuest(q)
    if activeQuest and activeQuest.id == q.id then
        if isPrepared then
            Addon.QuestRepository:ResetQuest(q.id, { activate = false })
        else
            Addon.QuestRepository:SetActiveQuest(nil)
        end
    else
        local activated, errKey
        if q.completed or q.failed or isPrepared then
            activated, errKey = Addon.QuestRepository:ResetQuest(q.id)
        else
            activated, errKey = Addon.QuestRepository:SetActiveQuest(q.id)
        end
        if not activated then
            if errKey then
                Addon.Announcements:ShowAlert(Addon.Locale:Get(errKey), true)
            end
            return
        end
        if isPrepared then
            Addon.Announcements:AnnounceQuestAccepted(q)
        end
    end
end

function JournalActions:OnCompleteQuestClicked(tab)
    local q = Addon.QuestRepository:GetQuestById(tab.selectedQuestId)
    if not q then return end

    local ok, resolvedQuest, questFailed, failReason = Addon.QuestRepository:CompleteQuest(q.id)
    if questFailed and resolvedQuest then
        Addon.Announcements:AnnounceQuestFailed(resolvedQuest, nil, failReason)
    elseif ok and resolvedQuest then
        Addon.Announcements:AnnounceQuestCompleted(resolvedQuest)
    end
end

function JournalActions:ConfirmAbandonQuest(_tab, questId)
    local q = Addon.QuestRepository:GetQuestById(questId)
    if not q or (Addon.QuestRepository:IsOfferedQuest(q) and q.isTutorial ~= true) then return false end

    ZO_Dialogs_ShowDialog("RPQUEST_ABANDON_QUEST", { questId = questId }, { mainTextParams = { q.title or "" } })
    return true
end

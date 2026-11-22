-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalTab = {}
local JournalTab = Addon.JournalTab

local PANEL_NAME = Addon.JournalWidgets.PANEL_NAME
local MAX_VISIBLE_ROWS = 15

local VIEW_MODE = {
    DETAIL = "DETAIL",
    EDITOR = "EDITOR",
    MAIL_SEND = "MAIL_SEND",
}
JournalTab.VIEW_MODE = VIEW_MODE

local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton

function JournalTab:RegisterRepositoryListener()
    Addon.QuestRepository:RegisterListener(function(eventType, quest)
        if eventType == "QUEST_CREATED" or eventType == "QUEST_UPDATED" then
            if quest and quest.id then
                if quest.role == Addon.Constants.QUEST_ROLE.PREPARED then
                    self.collapsedSections.preparing = false
                elseif quest.completed then
                    self.collapsedSections.completed = false
                else
                    self.collapsedSections.missions = false
                end
                self.listOffset = 0
                self.selectedQuestId = quest.id
            end
            self.viewMode = VIEW_MODE.DETAIL
        elseif eventType == "QUEST_IMPORTED" or eventType == "QUEST_ACCEPTED" then
            if quest and quest.id then
                self.collapsedSections.missions = false
                self.listOffset = 0
                self.selectedQuestId = quest.id
            end
            self.viewMode = VIEW_MODE.DETAIL
        elseif eventType == "QUEST_OFFERED" then
            if quest and quest.id then
                self.collapsedSections.pending = false
                self.listOffset = 0
                if not self.selectedQuestId then
                    self.selectedQuestId = quest.id
                end
            end
        elseif eventType == "QUEST_DELETED" or eventType == "QUEST_REJECTED" then
            if quest and self.selectedQuestId == quest.id then
                self.selectedQuestId = nil
            end
        elseif eventType == "DRAFT_TARGET_CAPTURED" then
            if self.viewMode ~= VIEW_MODE.EDITOR then
                self.viewMode = VIEW_MODE.EDITOR
            end
        elseif eventType == "DRAFT_UPDATED" or eventType == "LAST_NPC_UPDATED" then
            if self.viewMode == VIEW_MODE.EDITOR and not self.panel:IsHidden() then
                self:RefreshEditorPane()
            else
                self._dirty = true
            end
            return
        end
        if self.panel:IsHidden() then
            self._dirty = true
        else
            self:Refresh()
        end
    end)
end

function JournalTab:Initialize()
    if self.isInitialized then
        return
    end

    self.viewMode = VIEW_MODE.DETAIL
    self.collapsedSections = {
        missions = false,
        completed = true,
        preparing = true,
    }
    self.editorSectionsCollapsed = {
        target = true,
        discovery = true,
        dialogue = true,
        options = true,
    }
    self.selectedQuestId = nil
    self.listOffset = 0

    local panel = WINDOW_MANAGER:CreateControl(PANEL_NAME, GuiRoot, CT_TOPLEVELCONTROL)
    panel:SetDimensions(980, 680)
    panel:SetAnchor(TOPLEFT, ZO_QuestJournal, TOPLEFT, 0, 0)
    panel:SetAnchor(BOTTOMRIGHT, ZO_QuestJournal, BOTTOMRIGHT, 0, 0)
    panel:SetHidden(true)
    self.panel = panel

    local versionLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_VersionLabel", panel, CT_LABEL)
    versionLabel:SetDimensions(140, 20)
    versionLabel:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -33, 38)
    if versionLabel.SetFont then versionLabel:SetFont("ZoFontGameSmall") end
    if versionLabel.SetColor then versionLabel:SetColor(0.68, 0.68, 0.68, 1) end
    if versionLabel.SetHorizontalAlignment then
        versionLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    end
    local versionStr = (Addon.Constants and Addon.Constants.METADATA and Addon.Constants.METADATA.VERSION) or ""
    versionLabel:SetText(versionStr ~= "" and ("v" .. tostring(versionStr)) or "")
    self.versionLabel = versionLabel

    self:BuildLeftColumn(panel)
    self:BuildRightColumn(panel)

    -- Use ZO_SimpleSceneFragment instead of ZO_FadeSceneFragment so ESO does not create
    -- per-instance animation OnStop closures in untrusted addon context (which taints
    -- transitions to protected scenes such as TamrielTomesSceneKeyboard).
    self.fragment = ZO_SimpleSceneFragment:New(panel)

    self:IntegrateIntoQuestJournalModeBar()
    self:RegisterRepositoryListener()

    if Addon.MailTransport and Addon.MailTransport.RegisterListener then
        Addon.MailTransport:RegisterListener(function(evType, payload)
            self:OnMailTransportEvent(evType, payload)
        end)
    end

    self.isInitialized = true
    self._dirty = true
end

function JournalTab:BuildLeftColumn(panel)
    local leftCol = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LeftCol", panel, CT_CONTROL)
    leftCol:SetDimensions(335, 620)
    leftCol:SetAnchor(TOPLEFT, panel, TOPLEFT, 5, 7)
    leftCol:SetMouseEnabled(true)
    leftCol:SetHandler("OnMouseWheel", function(_, delta)
        self:ScrollQuestList(-delta)
    end)
    self.leftCol = leftCol

    self.newBtn = CreateStyledButton(
        PANEL_NAME .. "_NewBtn",
        leftCol,
        320,
        28,
        Addon.Locale:Get("BTN_NEW_QUEST"),
        function()
            self:OpenCreateEditor()
        end
    )
    self.newBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 4, 4)

    local emptyLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EmptyList", leftCol, CT_LABEL)
    emptyLabel:SetDimensions(310, 80)
    emptyLabel:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 4, 44)
    if emptyLabel.SetFont then emptyLabel:SetFont("ZoFontGame") end
    if emptyLabel.SetColor then emptyLabel:SetColor(0.75, 0.75, 0.75, 1) end
    emptyLabel:SetHidden(true)
    self.emptyLabel = emptyLabel

    self.rowControls = {}
    self.rowBindings = {}

    for i = 1, MAX_VISIBLE_ROWS do
        local rowBtn = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_Row" .. i, leftCol, CT_BUTTON)
        rowBtn:SetDimensions(320, 28)
        rowBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 0, 42 + ((i - 1) * 30))
        if rowBtn.SetFont then rowBtn:SetFont("ZoFontHeader") end
        if rowBtn.SetHorizontalAlignment then
            rowBtn:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        end
        if rowBtn.SetVerticalAlignment then
            rowBtn:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        end
        local rowIndex = i
        rowBtn:SetHandler("OnClicked", function()
            local binding = self.rowBindings[rowIndex]
            if not binding then return end
            if binding.isHeader and binding.sectionKey then
                PlaySound(SOUNDS.DEFAULT_CLICK)
                self:ToggleSection(binding.sectionKey)
            elseif binding.questId then
                PlaySound(SOUNDS.DEFAULT_CLICK)
                self:SelectQuest(binding.questId)
            end
        end)
        rowBtn:SetHidden(true)
        self.rowControls[i] = rowBtn
    end

    self.btnListPrev = CreateStyledButton(PANEL_NAME .. "_ListPrevBtn", leftCol, 60, 26, "<", function()
        self:ScrollQuestList(-1)
    end)
    self.btnListPrev:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 0, 554)
    self.btnListPrev:SetHidden(true)

    local scrollInfoLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ListScrollInfo", leftCol, CT_LABEL)
    scrollInfoLabel:SetDimensions(180, 26)
    scrollInfoLabel:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 66, 558)
    if scrollInfoLabel.SetFont then scrollInfoLabel:SetFont("ZoFontGame") end
    if scrollInfoLabel.SetColor then scrollInfoLabel:SetColor(0.82, 0.82, 0.82, 1) end
    scrollInfoLabel:SetHidden(true)
    self.scrollInfoLabel = scrollInfoLabel

    self.btnListNext = CreateStyledButton(PANEL_NAME .. "_ListNextBtn", leftCol, 60, 26, ">", function()
        self:ScrollQuestList(1)
    end)
    self.btnListNext:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 250, 554)
    self.btnListNext:SetHidden(true)
end

function JournalTab:ScrollQuestList(step)
    local delta = tonumber(step) or 0
    if delta == 0 then return end
    local prevOffset = self.listOffset or 0
    local maxOffset = self._maxListOffset or 0
    local nextOffset = math.min(math.max(0, prevOffset + delta), maxOffset)
    if nextOffset == prevOffset then return end
    self.listOffset = nextOffset
    self:RefreshQuestList()
end

function JournalTab:BuildRightColumn(panel)
    local rightCol = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_RightCol", panel, CT_CONTROL)
    rightCol:SetDimensions(550, 600)
    rightCol:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -33, 60)
    rightCol:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -33, -25)
    self.rightCol = rightCol

    self:BuildDetailPane(rightCol)
    self:BuildEditorPane(rightCol)
    self:BuildMailSendPane(rightCol)
end

function JournalTab:BuildDetailPane(parent)
    Addon.JournalDetailPane.Build(self, parent)
end

function JournalTab:BuildEditorPane(parent)
    Addon.JournalEditorPane.Build(self, parent)
end

function JournalTab:BuildMailSendPane(parent)
    Addon.JournalMailSendPane.Build(self, parent)
end

function JournalTab:OnMailTransportEvent(evType, payload)
    Addon.JournalMailSendPane.OnTransportEvent(self, evType, payload)
end

function JournalTab:AcceptSelectedOfferedQuest()
    if not self.selectedQuestId then return false end
    local ok, q = Addon.QuestRepository:AcceptOfferedQuest(self.selectedQuestId)
    if ok and q then
        Addon.Announcements:AnnounceQuestAccepted(q)
        return true
    end
    return false
end

function JournalTab:RejectSelectedOfferedQuest()
    if not self.selectedQuestId then return false end
    local ok, q = Addon.QuestRepository:RejectOfferedQuest(self.selectedQuestId)
    if ok and q then
        Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_REJECTED", q.title or ""), false)
        return true
    end
    return false
end

function JournalTab:SendSelectedPreparedQuest()
    return Addon.JournalMailSendPane.SendSelectedPrepared(self)
end

function JournalTab:OpenMailSendView()
    Addon.JournalMailSendPane.OpenView(self)
end

function JournalTab:RefreshMailSendCounter()
    Addon.JournalMailSendPane.RefreshCounter(self)
end

function JournalTab:OnConfirmSendMailClicked()
    Addon.JournalMailSendPane.OnConfirmSendClicked(self)
end

function JournalTab:IntegrateIntoQuestJournalModeBar()
    local qj = QUEST_JOURNAL_KEYBOARD or SYSTEMS:GetKeyboardObject("questJournal")
    if not qj then return end

    local tabDescriptor = Addon.Constants.UI.TAB_DESCRIPTOR
    local tabCategoryName = "SI_RPQUEST_JOURNAL_TAB_TITLE"
    ZO_CreateStringId(tabCategoryName, Addon.Locale:Get("TAB_TITLE"))
    self.tabCategoryName = _G[tabCategoryName] or tabCategoryName
    self.tabDescriptor = tabDescriptor

    local uiConsts = Addon.Constants.UI
    local tabData = {
        categoryName = self.tabCategoryName,
        descriptor = tabDescriptor,
        normal = uiConsts.ICON_TAB_UP,
        pressed = uiConsts.ICON_TAB_DOWN,
        highlight = uiConsts.ICON_TAB_OVER,
        disabled = uiConsts.ICON_TAB_DISABLED,
        callback = function()
            if qj.SetMode then
                qj:SetMode(tabDescriptor)
            end
            if self._dirty then
                self:Refresh()
            end
        end,
    }

    local function EnsureTabAdded()
        if qj.tabs and not self.isTabAdded and self.fragment then
            qj.tabs:Add(self.tabCategoryName, { self.fragment }, tabData, self.keybindStripDescriptor)
            self.isTabAdded = true
        end
    end

    if qj.initializedTabs then
        EnsureTabAdded()
    end

    ZO_PostHook(qj, "OnShowing", function(qjSelf)
        EnsureTabAdded()
        if qjSelf.mode == tabDescriptor and qjSelf.tabs and qjSelf.tabs.SelectFragment then
            qjSelf.tabs:SelectFragment(self.tabCategoryName)
            if self._dirty then
                self:Refresh()
            end
        end
        if qjSelf.tabs and qjSelf.tabs.UpdateButtons then
            qjSelf.tabs:UpdateButtons()
        end
    end)
end

function JournalTab:SelectQuest(questId)
    if Addon.QuestRepository:GetDraft().editingQuestId then
        Addon.QuestRepository:ResetDraft()
    end
    self.selectedQuestId = questId
    self.viewMode = VIEW_MODE.DETAIL
    if self.detailScroll and self.detailScroll.scroll and self.detailScroll.scroll.SetVerticalScroll then
        self.detailScroll.scroll:SetVerticalScroll(0)
    end
    self:Refresh()
end

local function ApplyDraftToEditor(self, draft)
    self.selectedDiscoveryIndex = nil
    self.titleEdit:SetText(draft.title or "")
    self.descEdit:SetText(draft.description or "")
    if self.recipientEdit then self.recipientEdit:SetText(draft.recipientAccount or "") end
    if self.recipientCharEdit then self.recipientCharEdit:SetText(draft.recipientCharacterName or "") end
    if self.clueEdit then self.clueEdit:SetText("") end
    self.completionEdit:SetText(draft.completionMessage or "")
    self.selectedDialogueIndex = (#(draft.dialogues or {}) > 0) and 1 or nil
    self.editorSectionsCollapsed = {
        target = true,
        discovery = true,
        dialogue = true,
        options = true,
    }
    self.viewMode = VIEW_MODE.EDITOR
    self:Refresh()
end

function JournalTab:OpenCreateEditor()
    local draft = Addon.QuestRepository:ResetDraft()
    ApplyDraftToEditor(self, draft)
end

local function GetQuestSectionKey(quest)
    if not quest then return nil end
    if Addon.QuestRepository:IsPreparedQuest(quest) then
        return "preparing"
    elseif quest.completed then
        return "completed"
    end
    return "missions"
end

function JournalTab:IsSectionLockedExpanded(sectionKey)
    if not sectionKey then return false end
    if self.selectedQuestId then
        local selected = Addon.QuestRepository:GetQuestById(self.selectedQuestId)
        if GetQuestSectionKey(selected) == sectionKey then
            return true
        end
    end
    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    if activeQuest and GetQuestSectionKey(activeQuest) == sectionKey then
        return true
    end
    return false
end

function JournalTab:ToggleSection(sectionKey)
    if not sectionKey or not self.collapsedSections then return end
    if not self.collapsedSections[sectionKey] and self:IsSectionLockedExpanded(sectionKey) then
        return
    end
    self.collapsedSections[sectionKey] = not self.collapsedSections[sectionKey]
    self.listOffset = 0
    self:RefreshQuestList()
end

function JournalTab:OpenEditEditor(questId)
    local draft, err = Addon.QuestRepository:LoadQuestIntoDraft(questId)
    if not draft then
        if err then
            Addon.Announcements:ShowAlert(err, true)
        end
        return
    end
    ApplyDraftToEditor(self, draft)
end

function JournalTab:ClearEditorInputs()
    if self.titleEdit then self.titleEdit:SetText("") end
    if self.descEdit then self.descEdit:SetText("") end
    if self.recipientEdit then self.recipientEdit:SetText("") end
    if self.recipientCharEdit then self.recipientCharEdit:SetText("") end
    if self.clueEdit then self.clueEdit:SetText("") end
    if self.completionEdit then self.completionEdit:SetText("") end
    if self.discoveryMsgEdit then self.discoveryMsgEdit:SetText("") end
    if self.dlgResponseEdit then self.dlgResponseEdit:SetText("") end
    self.selectedDialogueIndex = nil
    self.selectedDiscoveryIndex = nil
end

function JournalTab:OnSaveDraftClicked()
    local titleText = self.titleEdit:GetText()
    local descText = self.descEdit:GetText()
    local recipientText = self.recipientEdit and self.recipientEdit:GetText() or ""
    local recipientCharText = self.recipientCharEdit and self.recipientCharEdit:GetText() or ""
    local compMsgText = self.completionEdit and self.completionEdit:GetText() or ""
    local draft = Addon.QuestRepository:GetDraft()
    local dlgIdx = self.selectedDialogueIndex
    if dlgIdx and draft.dialogues and draft.dialogues[dlgIdx] then
        local dlgFields = {}
        if self.clueEdit then dlgFields.clue = self.clueEdit:GetText() end
        if self.dlgResponseEdit then dlgFields.response = self.dlgResponseEdit:GetText() end
        Addon.QuestRepository:UpdateDraftDialogue(dlgIdx, dlgFields, true)
    end

    local savedQuest, err = Addon.QuestRepository:SaveDraft(titleText, descText, nil, compMsgText, nil, recipientText, recipientCharText)
    if not savedQuest then
        Addon.Announcements:ShowAlert(err or Addon.Locale:Get("ERR_MISSING_TARGET"), true)
        return
    end

    self:ClearEditorInputs()

    Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_SAVED", savedQuest.title), false)
end

function JournalTab:OnToggleActiveClicked()
    local q = Addon.QuestRepository:GetQuestById(self.selectedQuestId)
    if not q then return end

    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    if activeQuest and activeQuest.id == q.id then
        Addon.QuestRepository:SetActiveQuest(nil)
    else
        if q.completed then
            Addon.QuestRepository:ResetQuest(q.id)
        else
            Addon.QuestRepository:SetActiveQuest(q.id)
        end
    end
end

function JournalTab:ConfirmAbandonQuest(questId)
    local q = Addon.QuestRepository:GetQuestById(questId)
    if not q or Addon.QuestRepository:IsOfferedQuest(q) then return false end

    ZO_Dialogs_ShowDialog("RPQUEST_ABANDON_QUEST", { questId = questId }, { mainTextParams = { q.title or "" } })
    return true
end

function JournalTab:OpenTab()
    if not self.isInitialized then
        self:Initialize()
    end

    local qj = QUEST_JOURNAL_KEYBOARD or SYSTEMS:GetKeyboardObject("questJournal")
    if qj and qj.SetMode then
        qj:SetMode(self.tabDescriptor or Addon.Constants.UI.TAB_DESCRIPTOR)
    end

    local wasShowing = SCENE_MANAGER:IsShowing("questJournal")

    SCENE_MANAGER:Show("questJournal")

    -- Solo seleccionar el fragmento de forma síncrona si questJournal ya está visible;
    -- si estamos transicionando desde otra escena (p. ej. Notificaciones o Correo),
    -- OnShowing lo seleccionará cuando la escena previa termine de ocultarse y libere su keybind strip.
    local isShowingNow = SCENE_MANAGER:IsShowing("questJournal")
    if wasShowing or isShowingNow then
        if qj and qj.tabs and qj.tabs.SelectFragment and self.tabCategoryName then
            qj.tabs:SelectFragment(self.tabCategoryName)
        elseif self.panel then
            self.panel:SetHidden(false)
        end
    end

    if self._dirty then
        self:Refresh()
    end
end

function JournalTab:ToggleTab()
    if not self.isInitialized then
        self:Initialize()
    end

    local qj = QUEST_JOURNAL_KEYBOARD or SYSTEMS:GetKeyboardObject("questJournal")
    local sceneShowing = SCENE_MANAGER:IsShowing("questJournal")

    if sceneShowing and qj and qj.mode == (self.tabDescriptor or Addon.Constants.UI.TAB_DESCRIPTOR) then
        SCENE_MANAGER:Hide("questJournal")
        if self.panel then
            self.panel:SetHidden(true)
        end
    else
        self:OpenTab()
    end
end

local function PartitionQuestsBySection(allQuests)
    local roles = Addon.Constants.QUEST_ROLE
    local buckets = {
        pending = {},
        missions = {},
        completed = {},
        preparing = {},
    }
    for _, q in ipairs(allQuests) do
        if q.role == roles.PREPARED then
            table.insert(buckets.preparing, q)
        elseif Addon.QuestRepository:IsOfferedQuest(q) then
            table.insert(buckets.pending, q)
        elseif q.completed then
            table.insert(buckets.completed, q)
        else
            table.insert(buckets.missions, q)
        end
    end
    return buckets
end

local function AppendQuestSectionRows(tab, displayRows, sectionKey, localeKey, quests, isCompleted, activeQuest)
    if #quests == 0 then return end
    local isLocked = tab:IsSectionLockedExpanded(sectionKey)
    local isCollapsed = (not isLocked) and tab.collapsedSections and tab.collapsedSections[sectionKey]
    local arrowTex = isCollapsed and "/esoui/art/buttons/tree_closed_up.dds" or "/esoui/art/buttons/tree_open_up.dds"
    local headerColor = isCollapsed and "|cC5C29E" or "|cFFFFFF"
    table.insert(displayRows, {
        isHeader = true,
        sectionKey = sectionKey,
        text = string.format("|t28:28:%s|t %s%s|r", arrowTex, headerColor, Addon.Locale:Get(localeKey, #quests)),
    })
    if isCollapsed then return end

    for _, q in ipairs(quests) do
        local isSelected = (tab.selectedQuestId == q.id)
        local prefix, selColor
        if isCompleted then
            prefix = "      |t16:16:/esoui/art/cadwell/check.dds|t "
            selColor = isSelected and "|cFFFFFF" or "|c8899AA"
        elseif Addon.QuestRepository:IsOfferedQuest(q) then
            prefix = "      |t18:18:/esoui/art/mail/mail_tabicon_inbox_up.dds|t "
            selColor = isSelected and "|cFFFFFF" or "|cFFD155"
        else
            local isAct = (activeQuest and activeQuest.id == q.id)
            prefix = isAct and "      |t18:18:/esoui/art/journal/journal_quest_selected.dds|t " or "          "
            selColor = isSelected and "|cFFFFFF" or "|cC5C29E"
        end
        local suffix = q.failed and Addon.Locale:Get("LIST_FAILED_SUFFIX") or ""
        table.insert(displayRows, {
            isHeader = false,
            questId = q.id,
            text = prefix .. selColor .. (q.title or "") .. "|r" .. suffix,
        })
    end
end

function JournalTab:RefreshQuestList(allQuests, activeQuest)
    if not self.panel then return end

    allQuests = allQuests or Addon.QuestRepository:GetAllQuests()
    activeQuest = activeQuest or Addon.QuestRepository:GetActiveQuest()
    self.rowBindings = {}

    if #allQuests == 0 then
        self.listOffset = 0
        self._maxListOffset = 0
        self.emptyLabel:SetText(Addon.Locale:Get("EMPTY_QUEST_LIST"))
        self.emptyLabel:SetHidden(false)
        for i = 1, MAX_VISIBLE_ROWS do
            self.rowControls[i]:SetHidden(true)
        end
        if self.btnListPrev then self.btnListPrev:SetHidden(true) end
        if self.btnListNext then self.btnListNext:SetHidden(true) end
        if self.scrollInfoLabel then self.scrollInfoLabel:SetHidden(true) end
        return
    end

    self.emptyLabel:SetHidden(true)
    local buckets = PartitionQuestsBySection(allQuests)
    local displayRows = {}
    AppendQuestSectionRows(self, displayRows, "pending", "SECTION_PENDING_QUESTS", buckets.pending, false, activeQuest)
    AppendQuestSectionRows(self, displayRows, "missions", "SECTION_ACTIVE_QUESTS", buckets.missions, false, activeQuest)
    AppendQuestSectionRows(self, displayRows, "completed", "SECTION_COMPLETED_QUESTS", buckets.completed, true, activeQuest)
    AppendQuestSectionRows(self, displayRows, "preparing", "SECTION_PREPARED_QUESTS", buckets.preparing, false, activeQuest)

    local maxOffset = math.max(0, #displayRows - MAX_VISIBLE_ROWS)
    self._maxListOffset = maxOffset
    self.listOffset = math.min(math.max(0, self.listOffset or 0), maxOffset)

    for i = 1, MAX_VISIBLE_ROWS do
        local rowCtrl = self.rowControls[i]
        local rowData = displayRows[self.listOffset + i]
        if rowData then
            rowCtrl:SetHidden(false)
            if rowCtrl.SetFont then
                rowCtrl:SetFont(rowData.isHeader and "ZoFontHeader3" or "ZoFontHeader")
            end
            rowCtrl:SetText(rowData.text)
            rowCtrl:SetMouseEnabled(true)
            self.rowBindings[i] = rowData
        else
            rowCtrl:SetHidden(true)
        end
    end

    local needsScroll = (#displayRows > MAX_VISIBLE_ROWS)
    if self.btnListPrev then self.btnListPrev:SetHidden(not needsScroll) end
    if self.btnListNext then self.btnListNext:SetHidden(not needsScroll) end
    if self.scrollInfoLabel then
        if needsScroll then
            local firstRow = self.listOffset + 1
            local lastRow = math.min(#displayRows, self.listOffset + MAX_VISIBLE_ROWS)
            self.scrollInfoLabel:SetText(string.format("%d-%d / %d", firstRow, lastRow, #displayRows))
            self.scrollInfoLabel:SetHidden(false)
        else
            self.scrollInfoLabel:SetHidden(true)
        end
    end
end

function JournalTab:UpdateShowOnMapVisibility()
    if not self.showOnMapKeybindButton then return end
    if self.showOnMapKeybindButton.UpdateVisibility then
        self.showOnMapKeybindButton:UpdateVisibility()
    else
        local visible = self.showOnMapDescriptor and self.showOnMapDescriptor.visible
        local isVisible
        if type(visible) == "function" then
            isVisible = visible(self.showOnMapKeybindButton) ~= false
        else
            isVisible = visible ~= false
        end
        self.showOnMapKeybindButton:SetHidden(not isVisible)
    end
end

function JournalTab:Refresh()
    if not self.panel then return end

    local allQuests = Addon.QuestRepository:GetAllQuests()
    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    self._dirty = false

    local selectedQuest = nil
    if self.viewMode == VIEW_MODE.DETAIL then
        selectedQuest = self.selectedQuestId and Addon.QuestRepository:GetQuestById(self.selectedQuestId)
        if not selectedQuest then
            if activeQuest then
                selectedQuest = activeQuest
                self.selectedQuestId = activeQuest.id
            elseif allQuests[1] then
                selectedQuest = allQuests[1]
                self.selectedQuestId = allQuests[1].id
            else
                selectedQuest = nil
                self.selectedQuestId = nil
            end
        end
    end

    -- 1. Actualizar columna izquierda
    self:RefreshQuestList(allQuests, activeQuest)

    -- 2. Actualizar columna derecha según el modo de vista
    self.detailPane:SetHidden(true)
    self.editorPane:SetHidden(true)
    if self.mailSendPane then self.mailSendPane:SetHidden(true) end

    if self.viewMode == VIEW_MODE.EDITOR then
        self.editorPane:SetHidden(false)
        self:RefreshEditorPane()
        self:UpdateShowOnMapVisibility()
        if self.keybindStripDescriptor then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
        end
    elseif self.viewMode == VIEW_MODE.MAIL_SEND and self.mailSendPane then
        self.mailSendPane:SetHidden(false)
        self:RefreshMailSendCounter()
        self:UpdateShowOnMapVisibility()
        if self.keybindStripDescriptor then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
        end
    else
        self.detailPane:SetHidden(false)
        self:RefreshDetailPane(selectedQuest, activeQuest)
    end
end

function JournalTab:RefreshDetailPane(selectedQuest, activeQuest)
    Addon.JournalDetailPane.Refresh(self, selectedQuest, activeQuest)
end

function JournalTab:ToggleEditorSection(sectionKey)
    Addon.JournalEditorPane.ToggleSection(self, sectionKey)
end

function JournalTab:LayoutEditorSections()
    Addon.JournalEditorPane.LayoutSections(self)
end

function JournalTab:RefreshEditorPane()
    Addon.JournalEditorPane.Refresh(self)
end

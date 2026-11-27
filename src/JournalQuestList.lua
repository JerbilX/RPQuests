-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0015-separacion-ciclo-de-vida-y-estado-de-resolucion.md
-- Ref: docs/adr/0019-protocolo-world-profile-rpqw1-y-sincronizacion-correo.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalQuestList = {}
local JournalQuestList = Addon.JournalQuestList

local PANEL_NAME = Addon.JournalWidgets.PANEL_NAME
local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton
local Accordion = Addon.JournalAccordion
local QUEST_SECTIONS = Accordion.QUEST_SECTIONS
local SECTION_DEFINITIONS = Accordion.SECTION_DEFINITIONS
local MAX_VISIBLE_ROWS = Accordion.MAX_VISIBLE_ROWS
local ROW_STEP = Accordion.ROW_STEP
local LIST_WIDTH = Accordion.LIST_WIDTH
local LIST_VIEWPORT_HEIGHT = Accordion.LIST_VIEWPORT_HEIGHT

function JournalQuestList:IsValidSectionKey(sectionKey)
    if not sectionKey then return false end
    for _, key in ipairs(QUEST_SECTIONS) do
        if key == sectionKey then
            return true
        end
    end
    return false
end

function JournalQuestList:SetSelectedQuestId(tab, questId)
    tab.selectedQuestId = questId
    if Addon.QuestRepository and Addon.QuestRepository.SetLastSelectedQuestId then
        Addon.QuestRepository:SetLastSelectedQuestId(questId)
    end
end

function JournalQuestList:GetExpandedSectionKey(tab)
    if not tab.collapsedSections then return nil end
    for _, key in ipairs(QUEST_SECTIONS) do
        if tab.collapsedSections[key] == false then
            return key
        end
    end
    return nil
end

function JournalQuestList:ExpandOnlySection(tab, sectionKey)
    if not sectionKey or not tab.collapsedSections then return end
    for _, key in ipairs(QUEST_SECTIONS) do
        tab.collapsedSections[key] = (key ~= sectionKey)
    end
    if Addon.QuestRepository and Addon.QuestRepository.SetLastSectionKey then
        Addon.QuestRepository:SetLastSectionKey(sectionKey)
    end
end

function JournalQuestList:GetQuestSectionKey(quest)
    if not quest then return nil end
    if Addon.QuestRepository:IsPreparedQuest(quest) then
        local lifecycle = Addon.QuestRepository:GetQuestLifecycle(quest)
        return (lifecycle == Addon.Constants.QUEST_LIFECYCLE.DRAFT) and "preparing" or "sent"
    elseif Addon.QuestRepository:IsOfferedQuest(quest) then
        return "pending"
    elseif quest.completed then
        return "completed"
    end
    return "missions"
end

function JournalQuestList:PartitionQuestsBySection(allQuests)
    local lifecycles = Addon.Constants.QUEST_LIFECYCLE
    local buckets = {
        pending = {},
        missions = {},
        completed = {},
        preparing = {},
        sent = {},
    }
    for _, q in ipairs(allQuests) do
        if Addon.QuestRepository:IsPreparedQuest(q) then
            local lifecycle = Addon.QuestRepository:GetQuestLifecycle(q)
            if lifecycle == lifecycles.DRAFT then
                table.insert(buckets.preparing, q)
            else
                table.insert(buckets.sent, q)
            end
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

function JournalQuestList:EnsureExpandedSectionWithQuests(tab, buckets, activeQuest)
    if not tab.collapsedSections then return end
    for _, key in ipairs(QUEST_SECTIONS) do
        if #buckets[key] > 0 and tab.collapsedSections[key] == false then
            return
        end
    end

    local targetKey = nil
    if tab.selectedQuestId then
        local selected = Addon.QuestRepository:GetQuestById(tab.selectedQuestId)
        local selectedKey = self:GetQuestSectionKey(selected)
        if selectedKey and buckets[selectedKey] and #buckets[selectedKey] > 0 then
            targetKey = selectedKey
        end
    end

    if not targetKey and activeQuest then
        local activeKey = self:GetQuestSectionKey(activeQuest)
        if activeKey and buckets[activeKey] and #buckets[activeKey] > 0 then
            targetKey = activeKey
        end
    end

    if not targetKey then
        for _, key in ipairs(QUEST_SECTIONS) do
            if #buckets[key] > 0 then
                targetKey = key
                break
            end
        end
    end

    if targetKey then
        self:ExpandOnlySection(tab, targetKey)
    end
end

function JournalQuestList:RestoreUiState(tab)
    local uiState = Addon.QuestRepository and Addon.QuestRepository.GetJournalUiState and Addon.QuestRepository:GetJournalUiState() or {}
    local targetSection = self:IsValidSectionKey(uiState.lastSectionKey) and uiState.lastSectionKey or "missions"
    tab.collapsedSections = {}
    for _, key in ipairs(QUEST_SECTIONS) do
        tab.collapsedSections[key] = (key ~= targetSection)
    end
    local savedQuestId = uiState.lastSelectedQuestId
    if savedQuestId and Addon.QuestRepository and Addon.QuestRepository:GetQuestById(savedQuestId) then
        tab.selectedQuestId = savedQuestId
    else
        tab.selectedQuestId = nil
    end
end

local function EnsureShareWorldProfileDialog()
    if ESO_Dialogs["RPQUEST_SHARE_WORLD_PROFILE"] then
        return
    end
    ESO_Dialogs["RPQUEST_SHARE_WORLD_PROFILE"] = {
        title = { text = Addon.Locale:Get("DLG_SHARE_WORLD_PROFILE_TITLE") },
        mainText = { text = Addon.Locale:Get("DLG_SHARE_WORLD_PROFILE_TEXT") },
        editBox = {
            maxInputCharacters = Addon.Constants.TEXT_LIMITS.ACCOUNT_NAME,
        },
        buttons = {
            {
                requiresTextInput = true,
                text = Addon.Locale:Get("BTN_MAIL_SEND_CONFIRM"),
                callback = function(dialog)
                    local target = ZO_Dialogs_GetEditBoxText(dialog)
                    if target and Addon.MailTransport and Addon.MailTransport.SendWorldProfile then
                        local ok, errKey = Addon.MailTransport:SendWorldProfile(target)
                        if not ok and errKey and Addon.Announcements and Addon.Announcements.ShowAlert then
                            Addon.Announcements:ShowAlert(Addon.Locale:Get(errKey), true)
                        end
                    end
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    }
end

function JournalQuestList:BuildLeftColumn(tab, panel)
    local leftCol = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LeftCol", panel, CT_CONTROL)
    leftCol:SetDimensions(335, 620)
    leftCol:SetAnchor(TOPLEFT, panel, TOPLEFT, 5, 7)
    leftCol:SetMouseEnabled(true)
    leftCol:SetHandler("OnMouseWheel", function(_, delta)
        tab:ScrollQuestList(-delta)
    end)
    tab.leftCol = leftCol

    tab.newBtn = CreateStyledButton(
        PANEL_NAME .. "_NewBtn",
        leftCol,
        130,
        28,
        Addon.Locale:Get("BTN_NEW_QUEST"),
        function()
            tab:OpenCreateEditor()
        end
    )
    tab.newBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 4, 4)

    tab.shareProfileBtn = CreateStyledButton(
        PANEL_NAME .. "_ShareProfileBtn",
        leftCol,
        182,
        28,
        Addon.Locale:Get("BTN_SHARE_WORLD_PROFILE"),
        function()
            local defaultMaster = ""
            local selected = tab.selectedQuestId and Addon.QuestRepository and Addon.QuestRepository:GetQuestById(tab.selectedQuestId)
            if selected and type(selected.senderDisplayName) == "string" and selected.senderDisplayName ~= "" then
                defaultMaster = selected.senderDisplayName
            end
            ZO_Dialogs_ShowDialog("RPQUEST_SHARE_WORLD_PROFILE", nil, { initialEditText = defaultMaster })
        end
    )
    tab.shareProfileBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 142, 4)

    local emptyLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EmptyList", leftCol, CT_LABEL)
    emptyLabel:SetDimensions(310, 80)
    emptyLabel:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 4, 44)
    if emptyLabel.SetFont then emptyLabel:SetFont("ZoFontGame") end
    if emptyLabel.SetColor then emptyLabel:SetColor(0.75, 0.75, 0.75, 1) end
    emptyLabel:SetHidden(true)
    tab.emptyLabel = emptyLabel

    tab.rowBindings = {}

    local listViewport = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ListViewport", leftCol, CT_SCROLL)
    listViewport:SetDimensions(LIST_WIDTH + 5, LIST_VIEWPORT_HEIGHT)
    listViewport:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 0, 42)
    listViewport:SetHidden(true)
    tab.listViewport = listViewport

    local listScrollChild = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ListScrollChild", listViewport, CT_CONTROL)
    listScrollChild:SetDimensions(LIST_WIDTH, 1)
    listScrollChild:SetAnchor(TOPLEFT, listViewport, TOPLEFT, 0, 0)
    tab.listScrollChild = listScrollChild

    Accordion:CreateSections(tab, listScrollChild)

    tab.btnListPrev = CreateStyledButton(PANEL_NAME .. "_ListPrevBtn", leftCol, 60, 26, "<", function()
        tab:ScrollQuestList(-1)
    end)
    tab.btnListPrev:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 0, 554)
    tab.btnListPrev:SetHidden(true)

    local scrollInfoLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ListScrollInfo", leftCol, CT_LABEL)
    scrollInfoLabel:SetDimensions(180, 26)
    scrollInfoLabel:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 66, 558)
    if scrollInfoLabel.SetFont then scrollInfoLabel:SetFont("ZoFontGame") end
    if scrollInfoLabel.SetColor then scrollInfoLabel:SetColor(0.82, 0.82, 0.82, 1) end
    scrollInfoLabel:SetHidden(true)
    tab.scrollInfoLabel = scrollInfoLabel

    tab.btnListNext = CreateStyledButton(PANEL_NAME .. "_ListNextBtn", leftCol, 60, 26, ">", function()
        tab:ScrollQuestList(1)
    end)
    tab.btnListNext:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 250, 554)
    tab.btnListNext:SetHidden(true)

    local chkAutoOpen = Addon.JournalWidgets.CreateCheckButton(
        PANEL_NAME .. "_ChkAutoOpenOnReceive",
        leftCol,
        Addon.Locale:Get("CHK_AUTO_OPEN_ON_RECEIVE"),
        function(isChecked)
            if Addon.QuestRepository then
                Addon.QuestRepository:SetSetting("autoOpenJournalOnReceive", isChecked)
            end
        end
    )
    chkAutoOpen:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 4, 590)
    local chkLabel = chkAutoOpen.GetNamedChild and chkAutoOpen:GetNamedChild("Label")
    if chkLabel and chkLabel.SetWidth then
        chkLabel:SetWidth(295)
    end
    ZO_CheckButton_SetCheckState(
        chkAutoOpen,
        Addon.QuestRepository and Addon.QuestRepository:GetSetting("autoOpenJournalOnReceive") == true
    )
    tab.chkAutoOpenJournalOnReceive = chkAutoOpen

    EnsureShareWorldProfileDialog()
end

function JournalQuestList:ScrollQuestList(tab, step)
    local delta = tonumber(step) or 0
    if delta == 0 then return end
    local prevOffset = tab.listOffset or 0
    local maxOffset = tab._maxListOffset or 0
    local nextOffset = math.min(math.max(0, prevOffset + delta), maxOffset)
    if nextOffset == prevOffset then return end
    tab.listOffset = nextOffset
    tab:RefreshQuestList()
end

function JournalQuestList:ToggleSection(tab, sectionKey)
    if not sectionKey or not tab.collapsedSections then return end
    if tab.collapsedSections[sectionKey] == false then
        return
    end
    self:ExpandOnlySection(tab, sectionKey)
    tab.listOffset = 0
    tab:RefreshQuestList()
end

local function RenderEmptyQuestList(tab)
    tab.listOffset = 0
    tab._maxListOffset = 0
    tab.emptyLabel:SetText(Addon.Locale:Get("EMPTY_QUEST_LIST"))
    tab.emptyLabel:SetHidden(false)
    if tab.listViewport then
        tab.listViewport:SetHidden(true)
    end
    if tab.accordionSections then
        for _, sectionKey in ipairs(QUEST_SECTIONS) do
            local section = tab.accordionSections[sectionKey]
            if section then
                section.hasQuests = false
                section.fullHeight = 0
                if section.timeline and section.timeline:IsPlaying() then
                    section.timeline:Stop()
                end
                section.headerBtn:SetHidden(true)
                section.childContainer:SetHidden(true)
            end
        end
    end
    if tab.btnListPrev then tab.btnListPrev:SetHidden(true) end
    if tab.btnListNext then tab.btnListNext:SetHidden(true) end
    if tab.scrollInfoLabel then tab.scrollInfoLabel:SetHidden(true) end
end

function JournalQuestList:RefreshQuestList(tab, allQuests, activeQuest)
    if not tab.panel then return end

    allQuests = allQuests or Addon.QuestRepository:GetAllQuests()
    activeQuest = activeQuest or Addon.QuestRepository:GetActiveQuest()
    tab.rowBindings = {}

    if #allQuests == 0 then
        RenderEmptyQuestList(tab)
        return
    end

    tab.emptyLabel:SetHidden(true)
    if tab.listViewport then
        tab.listViewport:SetHidden(false)
    end

    local buckets = self:PartitionQuestsBySection(allQuests)
    self:EnsureExpandedSectionWithQuests(tab, buckets, activeQuest)
    local displayRows = {}

    for _, def in ipairs(SECTION_DEFINITIONS) do
        local sectionKey = def.key
        local quests = buckets[sectionKey]
        local section = tab.accordionSections and tab.accordionSections[sectionKey]
        local hasQuests = (#quests > 0)
        local targetOpen = hasQuests and (tab.collapsedSections[sectionKey] == false)

        if hasQuests then
            local headerText = Accordion:FormatSectionHeaderText(tab, sectionKey, def.localeKey, #quests)
            table.insert(displayRows, {
                isHeader = true,
                sectionKey = sectionKey,
                text = headerText,
            })

            if section then
                section.hasQuests = true
                section.fullHeight = #quests * ROW_STEP
                section.headerBtn:SetText(headerText)
                section.headerBtn:SetMouseEnabled(true)
            end

            for idx, q in ipairs(quests) do
                local titleText, suffixText = Accordion:FormatQuestRowText(tab, q, sectionKey, def.isCompleted, activeQuest)
                local rowText = titleText .. (suffixText or "")
                if not tab.collapsedSections[sectionKey] then
                    table.insert(displayRows, {
                        isHeader = false,
                        questId = q.id,
                        text = rowText,
                    })
                end
                if section then
                    local rowBtn = tab:EnsureAccordionRow(sectionKey, section, idx)
                    rowBtn._questId = q.id
                    rowBtn._titleLabel:SetText(titleText)
                    local trimmedSuffix = suffixText and suffixText:gsub("^%s+", "") or ""
                    rowBtn._titleLabel:ClearAnchors()
                    rowBtn._titleLabel:SetAnchor(TOPLEFT, rowBtn, TOPLEFT, 0, 0)
                    if trimmedSuffix ~= "" then
                        rowBtn._statusLabel:SetText(trimmedSuffix)
                        rowBtn._statusLabel:SetHidden(false)
                        rowBtn._titleLabel:SetAnchor(BOTTOMRIGHT, rowBtn._statusLabel, BOTTOMLEFT, -6, 0)
                    else
                        rowBtn._statusLabel:SetText("")
                        rowBtn._statusLabel:SetHidden(true)
                        rowBtn._titleLabel:SetAnchor(BOTTOMRIGHT, rowBtn, BOTTOMRIGHT, 0, 0)
                    end
                    rowBtn:SetMouseEnabled(true)
                    rowBtn:SetHidden(false)
                end
            end

            if section then
                for idx = #quests + 1, #section.rowPool do
                    section.rowPool[idx]._questId = nil
                    section.rowPool[idx]:SetHidden(true)
                end
            end
        elseif section then
            section.hasQuests = false
            section.fullHeight = 0
            for idx = 1, #section.rowPool do
                section.rowPool[idx]._questId = nil
                section.rowPool[idx]:SetHidden(true)
            end
        end

        if section then
            if targetOpen ~= section.isOpen then
                tab:AnimateSection(sectionKey, section, targetOpen)
            elseif not (section.timeline and section.timeline:IsPlaying()) then
                section.openPercentage = targetOpen and 1 or 0
                section.childContainer:SetAlpha(section.openPercentage)
            end
        end
    end

    local maxOffset = math.max(0, #displayRows - MAX_VISIBLE_ROWS)
    tab._maxListOffset = maxOffset
    tab.listOffset = math.min(math.max(0, tab.listOffset or 0), maxOffset)

    for i = 1, MAX_VISIBLE_ROWS do
        local rowData = displayRows[tab.listOffset + i]
        if rowData then
            tab.rowBindings[i] = rowData
        end
    end

    tab:UpdateAccordionLayout()

    local needsScroll = (#displayRows > MAX_VISIBLE_ROWS)
    if tab.btnListPrev then tab.btnListPrev:SetHidden(not needsScroll) end
    if tab.btnListNext then tab.btnListNext:SetHidden(not needsScroll) end
    if tab.scrollInfoLabel then
        if needsScroll then
            local firstRow = tab.listOffset + 1
            local lastRow = math.min(#displayRows, tab.listOffset + MAX_VISIBLE_ROWS)
            tab.scrollInfoLabel:SetText(string.format("%d-%d / %d", firstRow, lastRow, #displayRows))
            tab.scrollInfoLabel:SetHidden(false)
        else
            tab.scrollInfoLabel:SetHidden(true)
        end
    end
end

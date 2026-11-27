-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0015-separacion-ciclo-de-vida-y-estado-de-resolucion.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalAccordion = {}
local JournalAccordion = Addon.JournalAccordion

local PANEL_NAME = Addon.JournalWidgets.PANEL_NAME
local MAX_VISIBLE_ROWS = 15
local ROW_HEIGHT = 28
local ROW_STEP = 30
local LIST_WIDTH = 320
local LIST_VIEWPORT_HEIGHT = 506
local QUEST_SECTIONS = { "pending", "missions", "completed", "preparing", "sent" }

local SECTION_DEFINITIONS = {
    { key = "pending", localeKey = "SECTION_PENDING_QUESTS", isCompleted = false },
    { key = "missions", localeKey = "SECTION_ACTIVE_QUESTS", isCompleted = false },
    { key = "completed", localeKey = "SECTION_COMPLETED_QUESTS", isCompleted = true },
    { key = "preparing", localeKey = "SECTION_PREPARED_QUESTS", isCompleted = false },
    { key = "sent", localeKey = "SECTION_SENT_QUESTS", isCompleted = false },
}

local SENT_RESOLUTION_LOCALE_KEYS = {
    accepted = "LIST_SENT_STATUS_ACCEPTED",
    rejected = "LIST_SENT_STATUS_REJECTED",
    completed = "LIST_SENT_STATUS_COMPLETED",
    failed = "LIST_SENT_STATUS_FAILED",
}

JournalAccordion.MAX_VISIBLE_ROWS = MAX_VISIBLE_ROWS
JournalAccordion.ROW_HEIGHT = ROW_HEIGHT
JournalAccordion.ROW_STEP = ROW_STEP
JournalAccordion.LIST_WIDTH = LIST_WIDTH
JournalAccordion.LIST_VIEWPORT_HEIGHT = LIST_VIEWPORT_HEIGHT
JournalAccordion.QUEST_SECTIONS = QUEST_SECTIONS
JournalAccordion.SECTION_DEFINITIONS = SECTION_DEFINITIONS

function JournalAccordion:CreateSections(tab, listScrollChild)
    tab.accordionSections = {}
    for _, sectionKey in ipairs(QUEST_SECTIONS) do
        local headerBtn = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_SectionHeader_" .. sectionKey, listScrollChild, CT_BUTTON)
        headerBtn:SetDimensions(LIST_WIDTH, ROW_HEIGHT)
        if headerBtn.SetFont then headerBtn:SetFont("ZoFontHeader3") end
        if headerBtn.SetHorizontalAlignment then
            headerBtn:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        end
        if headerBtn.SetVerticalAlignment then
            headerBtn:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        end
        local key = sectionKey
        headerBtn:SetHandler("OnClicked", function()
            PlaySound(SOUNDS.DEFAULT_CLICK)
            tab:ToggleSection(key)
        end)
        headerBtn:SetHidden(true)

        local childContainer = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_SectionChildren_" .. sectionKey, listScrollChild, CT_SCROLL)
        childContainer:SetDimensions(LIST_WIDTH, 0)
        childContainer:SetHidden(true)

        local isOpen = (tab.collapsedSections and tab.collapsedSections[sectionKey] == false) or false
        local timeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ZO_TreeOpenAnimation", childContainer)
        childContainer:SetAlpha(isOpen and 1 or 0)

        tab.accordionSections[sectionKey] = {
            headerBtn = headerBtn,
            childContainer = childContainer,
            timeline = timeline,
            isOpen = isOpen,
            openPercentage = isOpen and 1 or 0,
            fullHeight = 0,
            hasQuests = false,
            rowPool = {},
        }
    end
end

function JournalAccordion:FormatSectionHeaderText(tab, sectionKey, localeKey, count)
    local isCollapsed = tab.collapsedSections and tab.collapsedSections[sectionKey]
    local arrowTex = isCollapsed and "/esoui/art/buttons/tree_closed_up.dds" or "/esoui/art/buttons/tree_open_up.dds"
    local headerColor = isCollapsed and "|cC5C29E" or "|cFFFFFF"
    return string.format("|t28:28:%s|t %s%s|r", arrowTex, headerColor, Addon.Locale:Get(localeKey, count))
end

function JournalAccordion:FormatQuestRowText(tab, q, sectionKey, isCompleted, activeQuest)
    local isSelected = (tab.selectedQuestId == q.id)
    local prefix, selColor
    local suffix = ""
    if isCompleted then
        prefix = "      |t16:16:/esoui/art/cadwell/check.dds|t "
        selColor = isSelected and "|cFFFFFF" or "|c8899AA"
    elseif sectionKey == "sent" then
        local resolution = Addon.QuestRepository:GetQuestResolution(q)
        if resolution == "completed" then
            prefix = "      |t16:16:/esoui/art/cadwell/check.dds|t "
        else
            prefix = "          "
        end
        selColor = isSelected and "|cFFFFFF" or "|cC5C29E"
        local statusLocaleKey = (resolution and SENT_RESOLUTION_LOCALE_KEYS[resolution]) or "LIST_SENT_STATUS_SENT"
        suffix = Addon.Locale:Get(statusLocaleKey)
    elseif Addon.QuestRepository:IsOfferedQuest(q) then
        prefix = "      |t18:18:/esoui/art/mail/mail_tabicon_inbox_up.dds|t "
        selColor = isSelected and "|cFFFFFF" or "|cFFD155"
    else
        local isAct = (activeQuest and activeQuest.id == q.id)
        prefix = isAct and "      |t18:18:/esoui/art/journal/journal_quest_selected.dds|t " or "          "
        selColor = isSelected and "|cFFFFFF" or "|cC5C29E"
        if sectionKey == "missions" then
            local resolution = Addon.QuestRepository:GetQuestResolution(q)
            if resolution == "failed" then
                suffix = Addon.Locale:Get("LIST_FAILED_SUFFIX")
            end
        end
    end
    local iconTex = Addon.QuestDraftStore and Addon.QuestDraftStore:GetQuestIconTexture(q.icon) or nil
    local iconMarkup = iconTex and string.format("|t18:18:%s|t ", iconTex) or ""
    return prefix .. iconMarkup .. selColor .. (q.title or "") .. "|r", suffix
end

function JournalAccordion:EnsureAccordionRow(tab, sectionKey, section, index)
    local rowBtn = section.rowPool[index]
    if rowBtn then
        return rowBtn
    end
    local rowName = PANEL_NAME .. "_SectionRow_" .. sectionKey .. "_" .. index
    rowBtn = WINDOW_MANAGER:CreateControl(rowName, section.childContainer, CT_BUTTON)
    rowBtn:SetDimensions(LIST_WIDTH, ROW_HEIGHT)
    rowBtn:SetAnchor(TOPLEFT, section.childContainer, TOPLEFT, 0, (index - 1) * ROW_STEP)

    local statusLabel = WINDOW_MANAGER:CreateControl(rowName .. "_Status", rowBtn, CT_LABEL)
    statusLabel:SetFont("ZoFontHeader")
    statusLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    statusLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    statusLabel:SetMaxLineCount(1)
    statusLabel:SetAnchor(TOPRIGHT, rowBtn, TOPRIGHT, 0, 0)
    statusLabel:SetAnchor(BOTTOMRIGHT, rowBtn, BOTTOMRIGHT, 0, 0)
    statusLabel:SetHidden(true)

    local titleLabel = WINDOW_MANAGER:CreateControl(rowName .. "_Title", rowBtn, CT_LABEL)
    titleLabel:SetFont("ZoFontHeader")
    titleLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    titleLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    titleLabel:SetMaxLineCount(1)
    titleLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    titleLabel:SetAnchor(TOPLEFT, rowBtn, TOPLEFT, 0, 0)
    titleLabel:SetAnchor(BOTTOMRIGHT, rowBtn, BOTTOMRIGHT, 0, 0)

    rowBtn._statusLabel = statusLabel
    rowBtn._titleLabel = titleLabel

    rowBtn:SetHandler("OnClicked", function(ctrl)
        if ctrl._questId then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            tab:SelectQuest(ctrl._questId)
        end
    end)
    section.rowPool[index] = rowBtn
    return rowBtn
end

function JournalAccordion:UpdateAccordionLayout(tab)
    if not tab.accordionSections or not tab.listScrollChild then return end
    local y = 0
    for _, sectionKey in ipairs(QUEST_SECTIONS) do
        local section = tab.accordionSections[sectionKey]
        if section and section.hasQuests then
            section.headerBtn:ClearAnchors()
            section.headerBtn:SetAnchor(TOPLEFT, tab.listScrollChild, TOPLEFT, 0, y)
            section.headerBtn:SetHidden(false)
            y = y + ROW_STEP

            local currentHeight = math.floor((section.fullHeight or 0) * (section.openPercentage or 0) + 0.5)
            section.childContainer:ClearAnchors()
            section.childContainer:SetAnchor(TOPLEFT, tab.listScrollChild, TOPLEFT, 0, y)
            section.childContainer:SetDimensions(LIST_WIDTH, currentHeight)
            section.childContainer:SetHidden(currentHeight <= 0)
            y = y + currentHeight
        elseif section then
            section.headerBtn:SetHidden(true)
            section.childContainer:SetDimensions(LIST_WIDTH, 0)
            section.childContainer:SetHidden(true)
        end
    end
    tab.listScrollChild:SetDimensions(LIST_WIDTH, math.max(1, y))
    if tab.listViewport then
        tab.listScrollChild:ClearAnchors()
        tab.listScrollChild:SetAnchor(TOPLEFT, tab.listViewport, TOPLEFT, 0, -((tab.listOffset or 0) * ROW_STEP))
    end
end

function JournalAccordion:SetSectionOpenPercentage(tab, sectionKey, openPercentage)
    local section = tab.accordionSections and tab.accordionSections[sectionKey]
    if not section then return end
    section.openPercentage = openPercentage
    tab:UpdateAccordionLayout()
end

function JournalAccordion:AnimateSection(tab, sectionKey, section, targetOpen)
    local timeline = section.timeline
    if tab.panel:IsHidden() or (section.fullHeight or 0) == 0 then
        if timeline and timeline:IsPlaying() then
            timeline:Stop()
        end
        section.isOpen = targetOpen
        section.childContainer:SetAlpha(targetOpen and 1 or 0)
        tab:SetSectionOpenPercentage(sectionKey, targetOpen and 1 or 0)
        return
    end

    section.isOpen = targetOpen
    if timeline:IsPlaying() then
        if targetOpen then
            timeline:PlayForward()
        else
            timeline:PlayBackward()
        end
    else
        local customAnim = timeline:GetFirstAnimation()
        customAnim:SetUpdateFunction(function(_, progress)
            tab:SetSectionOpenPercentage(sectionKey, progress)
        end)
        local numAnimations = timeline:GetNumAnimations()
        for i = 2, numAnimations do
            timeline:GetAnimation(i):SetAnimatedControl(section.childContainer)
        end
        if targetOpen then
            customAnim:SetEasingFunction(ZO_EaseOutQuadratic)
            timeline:PlayFromStart()
        else
            customAnim:SetEasingFunction(ZO_EaseInQuadratic)
            timeline:PlayFromEnd()
        end
    end
end

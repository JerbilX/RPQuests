-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalModeBar = {}
local JournalModeBar = Addon.JournalModeBar

function JournalModeBar:IntegrateIntoQuestJournalModeBar(tab)
    local qj = QUEST_JOURNAL_KEYBOARD or SYSTEMS:GetKeyboardObject("questJournal")
    if not qj then return end

    local tabDescriptor = Addon.Constants.UI.TAB_DESCRIPTOR
    local tabCategoryName = "SI_RPQUEST_JOURNAL_TAB_TITLE"
    ZO_CreateStringId(tabCategoryName, Addon.Locale:Get("TAB_TITLE"))
    tab.tabCategoryName = _G[tabCategoryName] or tabCategoryName
    tab.tabDescriptor = tabDescriptor

    local uiConsts = Addon.Constants.UI
    local tabData = {
        categoryName = tab.tabCategoryName,
        descriptor = tabDescriptor,
        normal = uiConsts.ICON_TAB_UP,
        pressed = uiConsts.ICON_TAB_DOWN,
        highlight = uiConsts.ICON_TAB_OVER,
        disabled = uiConsts.ICON_TAB_DISABLED,
        callback = function()
            if qj.SetMode then
                qj:SetMode(tabDescriptor)
            end
            if tab._dirty then
                tab:Refresh()
            end
        end,
    }

    local function EnsureTabAdded()
        if qj.tabs and not tab.isTabAdded and tab.fragment then
            qj.tabs:Add(tab.tabCategoryName, { tab.fragment }, tabData, tab.keybindStripDescriptor)
            tab.isTabAdded = true
        end
    end

    if qj.initializedTabs then
        EnsureTabAdded()
    end

    local pendingRPQuestMode = false

    ZO_PreHook(qj, "OnShowing", function(qjSelf)
        if tab._pendingRPQuestOpen then
            pendingRPQuestMode = true
            tab._pendingRPQuestOpen = false
        else
            pendingRPQuestMode = false
            if qjSelf.mode == tabDescriptor then
                if qjSelf.SetMode then
                    qjSelf:SetMode(ZO_QUEST_JOURNAL_MODE.QUESTS)
                else
                    qjSelf.mode = ZO_QUEST_JOURNAL_MODE.QUESTS
                end
            end
        end
    end)

    ZO_PostHook(qj, "OnShowing", function(qjSelf)
        EnsureTabAdded()
        if pendingRPQuestMode then
            pendingRPQuestMode = false
            if qjSelf.SetMode then
                qjSelf:SetMode(tabDescriptor)
            else
                qjSelf.mode = tabDescriptor
            end
        end
        if qjSelf.mode == tabDescriptor and qjSelf.tabs and qjSelf.tabs.SelectFragment then
            qjSelf.tabs:SelectFragment(tab.tabCategoryName)
            if tab._dirty then
                tab:Refresh()
            end
        end
        if qjSelf.tabs and qjSelf.tabs.UpdateButtons then
            qjSelf.tabs:UpdateButtons()
        end
    end)

    ZO_PostHook(qj, "OnHiding", function(qjSelf)
        if not tab._pendingRPQuestOpen and qjSelf.mode == tabDescriptor then
            if qjSelf.SetMode then
                qjSelf:SetMode(ZO_QUEST_JOURNAL_MODE.QUESTS)
            else
                qjSelf.mode = ZO_QUEST_JOURNAL_MODE.QUESTS
            end
        end
    end)
end

function JournalModeBar:OpenTab(tab)
    if not tab.isInitialized then
        tab:Initialize()
    end

    local qj = QUEST_JOURNAL_KEYBOARD or SYSTEMS:GetKeyboardObject("questJournal")
    tab._pendingRPQuestOpen = true
    if qj and qj.SetMode then
        qj:SetMode(tab.tabDescriptor or Addon.Constants.UI.TAB_DESCRIPTOR)
    end

    local wasShowing = SCENE_MANAGER:IsShowing("questJournal")

    SCENE_MANAGER:Show("questJournal")

    -- Select the fragment synchronously only when questJournal is already showing;
    -- when transitioning asynchronously from another scene (e.g. Notifications or Mail),
    -- OnShowing selects it once the previous scene finishes hiding and releases its keybind strip.
    local isShowingNow = SCENE_MANAGER:IsShowing("questJournal")
    if wasShowing or isShowingNow then
        tab._pendingRPQuestOpen = false
        if qj and qj.tabs and qj.tabs.SelectFragment and tab.tabCategoryName then
            qj.tabs:SelectFragment(tab.tabCategoryName)
        elseif tab.panel then
            tab.panel:SetHidden(false)
        end
    end

    if tab._dirty then
        tab:Refresh()
    end
end

function JournalModeBar:ToggleTab(tab)
    if not tab.isInitialized then
        tab:Initialize()
    end

    local qj = QUEST_JOURNAL_KEYBOARD or SYSTEMS:GetKeyboardObject("questJournal")
    local sceneShowing = SCENE_MANAGER:IsShowing("questJournal")

    if sceneShowing and qj and qj.mode == (tab.tabDescriptor or Addon.Constants.UI.TAB_DESCRIPTOR) then
        tab:AutoPreserveDraft()
        SCENE_MANAGER:Hide("questJournal")
        if tab.panel then
            tab.panel:SetHidden(true)
        end
    else
        tab:OpenTab()
    end
end

function JournalModeBar:UpdateShowOnMapVisibility(tab)
    if not tab.showOnMapKeybindButton then return end
    if tab.showOnMapKeybindButton.UpdateVisibility then
        tab.showOnMapKeybindButton:UpdateVisibility()
    else
        local visible = tab.showOnMapDescriptor and tab.showOnMapDescriptor.visible
        local isVisible
        if type(visible) == "function" then
            isVisible = visible(tab.showOnMapKeybindButton) ~= false
        else
            isVisible = visible ~= false
        end
        tab.showOnMapKeybindButton:SetHidden(not isVisible)
    end
end

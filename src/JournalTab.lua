-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0015-separacion-ciclo-de-vida-y-estado-de-resolucion.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalTab = {}
local JournalTab = Addon.JournalTab

local PANEL_NAME = Addon.JournalWidgets.PANEL_NAME
local VIEW_MODE = Addon.JournalWidgets.VIEW_MODE
JournalTab.VIEW_MODE = VIEW_MODE

local function BindDelegates(targetModule, methodNames)
    for _, methodName in ipairs(methodNames) do
        JournalTab[methodName] = function(self, ...)
            return targetModule[methodName](targetModule, self, ...)
        end
    end
end

BindDelegates(Addon.JournalModeBar, {
    "IntegrateIntoQuestJournalModeBar",
    "OpenTab",
    "ToggleTab",
    "UpdateShowOnMapVisibility",
})

BindDelegates(Addon.JournalAccordion, {
    "EnsureAccordionRow",
    "UpdateAccordionLayout",
    "SetSectionOpenPercentage",
    "AnimateSection",
})

BindDelegates(Addon.JournalQuestList, {
    "RestoreUiState",
    "BuildLeftColumn",
    "ScrollQuestList",
    "ToggleSection",
    "RefreshQuestList",
})

BindDelegates(Addon.JournalActions, {
    "RegisterRepositoryListener",
    "SyncEditorInputsToDraft",
    "AutoPreserveDraft",
    "SelectQuest",
    "OpenCreateEditor",
    "OpenEditEditor",
    "ClearEditorInputs",
    "OnSaveDraftClicked",
    "AcceptSelectedOfferedQuest",
    "RejectSelectedOfferedQuest",
    "DuplicateSelectedQuest",
    "MigrateSelectedQuest",
    "OnToggleActiveClicked",
    "OnCompleteQuestClicked",
    "ConfirmAbandonQuest",
})

function JournalTab:Initialize()
    if self.isInitialized then
        return
    end

    self.viewMode = VIEW_MODE.DETAIL
    self:RestoreUiState()
    self.editorSectionsCollapsed = {
        header = false,
        target = true,
        discovery = true,
        dialogue = true,
        options = true,
    }
    self.listOffset = 0

    local panel = WINDOW_MANAGER:CreateControl(PANEL_NAME, GuiRoot, CT_TOPLEVELCONTROL)
    panel:SetDimensions(980, 680)
    panel:SetAnchor(TOPLEFT, ZO_QuestJournal, TOPLEFT, 0, 0)
    panel:SetAnchor(BOTTOMRIGHT, ZO_QuestJournal, BOTTOMRIGHT, 0, 0)
    panel:SetHidden(true)
    panel:SetHandler("OnHide", function()
        self:AutoPreserveDraft()
    end)
    self.panel = panel

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

function JournalTab:Refresh()
    if not self.panel then return end

    local QuestList = Addon.JournalQuestList
    local allQuests = Addon.QuestRepository:GetAllQuests()
    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    self._dirty = false

    local selectedQuest = nil
    if self.viewMode == VIEW_MODE.DETAIL then
        selectedQuest = self.selectedQuestId and Addon.QuestRepository:GetQuestById(self.selectedQuestId)
        if not selectedQuest then
            if activeQuest then
                selectedQuest = activeQuest
            else
                local openKey = QuestList:GetExpandedSectionKey(self)
                if openKey then
                    local buckets = QuestList:PartitionQuestsBySection(allQuests)
                    if buckets[openKey] and buckets[openKey][1] then
                        selectedQuest = buckets[openKey][1]
                    end
                end
                if not selectedQuest and allQuests[1] then
                    selectedQuest = allQuests[1]
                end
            end
            QuestList:SetSelectedQuestId(self, selectedQuest and selectedQuest.id or nil)
        end
    end

    -- 1. Actualizar columna izquierda
    self:RefreshQuestList(allQuests, activeQuest)
    if self.chkAutoOpenJournalOnReceive then
        ZO_CheckButton_SetCheckState(
            self.chkAutoOpenJournalOnReceive,
            Addon.QuestRepository and Addon.QuestRepository:GetSetting("autoOpenJournalOnReceive") == true
        )
    end

    -- 2. Actualizar columna derecha según el modo de vista
    self.detailPane:SetHidden(true)
    self.editorPane:SetHidden(true)
    if self.mailSendPane then self.mailSendPane:SetHidden(true) end

    if self.viewMode == VIEW_MODE.EDITOR then
        self.editorPane:SetHidden(false)
        self:RefreshEditorPane()
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
    self:UpdateShowOnMapVisibility()
    if self.keybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
    end
end

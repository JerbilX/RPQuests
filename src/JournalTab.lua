-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalTab = {}
local JournalTab = Addon.JournalTab

local PANEL_NAME = "RPQuest_JournalPanel"
local MAX_VISIBLE_ROWS = 15

local VIEW_MODE = {
    DETAIL = "DETAIL",
    EDITOR = "EDITOR",
    IMPORT = "IMPORT",
}

local function CreateStyledButton(name, parent, width, height, text, onClick)
    local btn = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    btn:SetDimensions(width, height)
    btn:SetMouseEnabled(true)
    btn:SetFont("ZoFontGameBold")
    btn:SetNormalFontColor(0.91, 0.83, 0.63, 1)
    btn:SetMouseOverFontColor(1, 1, 1, 1)

    local bg = WINDOW_MANAGER:CreateControl(name .. "_Bg", btn, CT_BACKDROP)
    bg:SetDimensions(width, height)
    bg:SetAnchor(TOPLEFT, btn, TOPLEFT, 0, 0)
    bg:SetCenterColor(0.08, 0.08, 0.08, 0.78)
    bg:SetEdgeColor(0.65, 0.56, 0.34, 0.85)
    btn._bg = bg

    btn:SetText(text or "")
    btn:SetHandler("OnClicked", function()
        if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then
            PlaySound(SOUNDS.DEFAULT_CLICK)
        end
        if onClick then onClick() end
    end)
    return btn
end

local function CreateEditBoxWithBackdrop(name, parent, width, height, maxChars, isMultiLine, onTextChanged)
    local bg = WINDOW_MANAGER:CreateControl(name .. "_Bg", parent, CT_BACKDROP)
    bg:SetDimensions(width, height)
    bg:SetMouseEnabled(true)
    bg:SetCenterColor(0.04, 0.04, 0.04, 0.82)
    bg:SetEdgeColor(0.68, 0.58, 0.36, 0.80)

    local edit = WINDOW_MANAGER:CreateControl(name, bg, CT_EDITBOX)
    edit:SetDimensions(width - 12, height - 8)
    edit:SetAnchor(TOPLEFT, bg, TOPLEFT, 6, 4)
    edit:SetMouseEnabled(true)
    edit:SetEditEnabled(true)
    edit:SetFont("ZoFontGame")
    edit:SetColor(1, 1, 1, 1)
    edit:SetMaxInputChars(maxChars or 256)
    edit:SetMultiLine(isMultiLine)
    edit:SetNewLineEnabled(isMultiLine)
    edit:SetText("")

    local function FocusEditBox()
        edit:SetEditEnabled(true)
        edit:TakeFocus()
    end

    bg:SetHandler("OnMouseDown", FocusEditBox)
    edit:SetHandler("OnMouseDown", FocusEditBox)
    edit:SetHandler("OnEscape", function(ctrl)
        ctrl:LoseFocus()
    end)
    if not isMultiLine then
        edit:SetHandler("OnEnter", function(ctrl)
            ctrl:LoseFocus()
        end)
    end
    edit:SetHandler("OnFocusGained", function()
        edit._focused = true
        bg:SetEdgeColor(0.95, 0.85, 0.50, 1.0)
        if PlaySound and SOUNDS and SOUNDS.EDIT_CLICK then
            PlaySound(SOUNDS.EDIT_CLICK)
        end
    end)
    edit:SetHandler("OnFocusLost", function()
        edit._focused = false
        bg:SetEdgeColor(0.68, 0.58, 0.36, 0.80)
    end)
    if onTextChanged then
        edit:SetHandler("OnTextChanged", function(ctrl)
            onTextChanged(ctrl:GetText())
        end)
    end

    return bg, edit
end

function JournalTab:Initialize()
    if self.isInitialized or not WINDOW_MANAGER or not GuiRoot then
        return
    end

    self.viewMode = VIEW_MODE.DETAIL
    self.collapsedSections = {
        missions = false,
        completed = true,
        preparing = true,
    }
    self.selectedQuestId = nil
    self.shareCodeHeaderKey = nil
    self.listOffset = 0

    local panel = WINDOW_MANAGER:CreateControl(PANEL_NAME, GuiRoot, CT_TOPLEVELCONTROL)
    panel:SetDimensions(980, 680)
    if ZO_QuestJournal then
        panel:SetAnchor(TOPLEFT, ZO_QuestJournal, TOPLEFT, 0, 0)
        panel:SetAnchor(BOTTOMRIGHT, ZO_QuestJournal, BOTTOMRIGHT, 0, 0)
    else
        panel:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -30, 95)
    end
    panel:SetHidden(true)
    self.panel = panel

    self:BuildLeftColumn(panel)
    self:BuildRightColumn(panel)

    if ZO_FadeSceneFragment then
        self.fragment = ZO_FadeSceneFragment:New(panel)
    end

    self:IntegrateIntoQuestJournalModeBar()

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
        elseif eventType == "QUEST_IMPORTED" then
            if quest and quest.id then
                self.collapsedSections.missions = false
                self.listOffset = 0
                self.selectedQuestId = quest.id
            end
            self.viewMode = VIEW_MODE.DETAIL
        elseif eventType == "QUEST_DELETED" then
            if quest and self.selectedQuestId == quest.id then
                self.selectedQuestId = nil
            end
            self.shareCodeHeaderKey = nil
            if self.shareEdit then self.shareEdit:SetText("") end
            if self.validateResultLabel then self.validateResultLabel:SetText("") end
        elseif eventType == "DRAFT_TARGET_CAPTURED" then
            if self.viewMode ~= VIEW_MODE.EDITOR then
                self.viewMode = VIEW_MODE.EDITOR
            end
        elseif eventType == "DRAFT_UPDATED" then
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

    self.isInitialized = true
    self:Refresh()
end

function JournalTab:BuildLeftColumn(panel)
    local leftCol = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LeftCol", panel, CT_CONTROL)
    leftCol:SetDimensions(335, 620)
    leftCol:SetAnchor(TOPLEFT, panel, TOPLEFT, 12, 10)
    leftCol:SetMouseEnabled(true)
    leftCol:SetHandler("OnMouseWheel", function(_, delta)
        self:ScrollQuestList(-delta)
    end)
    self.leftCol = leftCol

    local headerLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_QuestCount", leftCol, CT_LABEL)
    headerLabel:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 0, 0)
    if headerLabel.SetFont then headerLabel:SetFont("ZoFontHeader3") end
    if headerLabel.SetColor then headerLabel:SetColor(0.91, 0.83, 0.63, 1) end
    self.headerLabel = headerLabel

    self.importBtn = CreateStyledButton(
        PANEL_NAME .. "_ImportBtn",
        leftCol,
        175,
        28,
        Addon.Locale:Get("BTN_IMPORT_CODE"),
        function()
            self:OpenImportView()
        end
    )
    self.importBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 0, 32)

    self.newBtn = CreateStyledButton(
        PANEL_NAME .. "_NewBtn",
        leftCol,
        125,
        28,
        Addon.Locale:Get("BTN_NEW_QUEST"),
        function()
            self:OpenCreateEditor()
        end
    )
    self.newBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 185, 32)

    local emptyLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EmptyList", leftCol, CT_LABEL)
    emptyLabel:SetDimensions(310, 80)
    emptyLabel:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 4, 74)
    if emptyLabel.SetFont then emptyLabel:SetFont("ZoFontGame") end
    if emptyLabel.SetColor then emptyLabel:SetColor(0.75, 0.75, 0.75, 1) end
    emptyLabel:SetHidden(true)
    self.emptyLabel = emptyLabel

    self.rowControls = {}
    self.rowBindings = {}

    for i = 1, MAX_VISIBLE_ROWS do
        local rowBtn = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_Row" .. i, leftCol, CT_BUTTON)
        rowBtn:SetDimensions(315, 30)
        rowBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 0, 70 + ((i - 1) * 32))
        if rowBtn.SetFont then rowBtn:SetFont("ZoFontHeader") end
        local rowIndex = i
        rowBtn:SetHandler("OnClicked", function()
            local binding = self.rowBindings[rowIndex]
            if not binding then return end
            if binding.isHeader and binding.sectionKey then
                if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then
                    PlaySound(SOUNDS.DEFAULT_CLICK)
                end
                self:ToggleSection(binding.sectionKey)
            elseif binding.questId then
                if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then
                    PlaySound(SOUNDS.DEFAULT_CLICK)
                end
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
    rightCol:SetDimensions(560, 600)
    rightCol:SetAnchor(TOPLEFT, panel, TOPLEFT, 375, 55)
    self.rightCol = rightCol

    self:BuildDetailPane(rightCol)
    self:BuildEditorPane(rightCol)
    self:BuildImportPane(rightCol)
end

function JournalTab:BuildDetailPane(parent)
    local pane = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailPane", parent, CT_CONTROL)
    pane:SetDimensions(550, 620)
    pane:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    self.detailPane = pane

    local titleLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailTitle", pane, CT_LABEL)
    titleLabel:SetDimensions(520, 34)
    titleLabel:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 0)
    if titleLabel.SetFont then titleLabel:SetFont("ZoFontWinH2") end
    if titleLabel.SetColor then titleLabel:SetColor(0.95, 0.88, 0.65, 1) end
    self.detailTitle = titleLabel

    local statusLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailStatus", pane, CT_LABEL)
    statusLabel:SetDimensions(520, 24)
    statusLabel:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 36)
    if statusLabel.SetFont then statusLabel:SetFont("ZoFontGameBold") end
    self.detailStatus = statusLabel

    local locLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailLoc", pane, CT_LABEL)
    locLabel:SetDimensions(520, 24)
    locLabel:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 60)
    if locLabel.SetFont then locLabel:SetFont("ZoFontGame") end
    if locLabel.SetColor then locLabel:SetColor(0.82, 0.82, 0.82, 1) end
    self.detailLocation = locLabel

    local descHeader = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailDescHeader", pane, CT_LABEL)
    descHeader:SetDimensions(520, 24)
    descHeader:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 96)
    if descHeader.SetFont then descHeader:SetFont("ZoFontWinH4") end
    if descHeader.SetColor then descHeader:SetColor(0.91, 0.83, 0.63, 1) end
    descHeader:SetText(Addon.Locale:Get("LABEL_DESCRIPTION_HEADER"))
    self.detailDescHeader = descHeader

    local descBody = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailDescBody", pane, CT_LABEL)
    descBody:SetDimensions(510, 120)
    descBody:SetAnchor(TOPLEFT, pane, TOPLEFT, 10, 122)
    if descBody.SetFont then descBody:SetFont("ZoFontWinH4") end
    if descBody.SetColor then descBody:SetColor(0.85, 0.83, 0.76, 1) end
    self.detailDescBody = descBody

    local divider = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailDivider", pane, CT_TEXTURE)
    divider:SetDimensions(512, 4)
    divider:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 250)
    divider:SetTexture(Addon.Constants.UI.DIVIDER_TEXTURE)

    local objHeader = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailObjHeader", pane, CT_LABEL)
    objHeader:SetDimensions(520, 24)
    objHeader:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 264)
    if objHeader.SetFont then objHeader:SetFont("ZoFontWinH3") end
    if objHeader.SetColor then objHeader:SetColor(0.91, 0.83, 0.63, 1) end
    objHeader:SetText(Addon.Locale:Get("LABEL_OBJECTIVE_HEADER"))
    self.detailObjHeader = objHeader

    local objText = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailObjText", pane, CT_LABEL)
    objText:SetDimensions(510, 48)
    objText:SetAnchor(TOPLEFT, pane, TOPLEFT, 12, 294)
    if objText.SetFont then objText:SetFont("ZoFontWinH4") end
    self.detailObjText = objText

    -- Grupo 1: Botones de acción de la misión
    self.btnActivate = CreateStyledButton(PANEL_NAME .. "_BtnActivate", pane, 160, 32, "", function()
        self:OnToggleActiveClicked()
    end)
    self.btnActivate:SetAnchor(TOPLEFT, objText, BOTTOMLEFT, -12, 16)

    self.btnShowOnMap = CreateStyledButton(PANEL_NAME .. "_BtnShowMap", pane, 160, 32, Addon.Locale:Get("BTN_SHOW_ON_MAP"), function()
        local q = Addon.QuestRepository:GetQuestById(self.selectedQuestId)
        if q then
            Addon.WorldMapArea:ShowQuestOnMap(q)
        end
    end)
    self.btnShowOnMap:SetAnchor(TOPLEFT, self.btnActivate, TOPRIGHT, 12, 0)

    self.btnEdit = CreateStyledButton(PANEL_NAME .. "_BtnEdit", pane, 160, 32, Addon.Locale:Get("BTN_EDIT"), function()
        self:OpenEditEditor(self.selectedQuestId)
    end)
    self.btnEdit:SetAnchor(TOPLEFT, self.btnActivate, BOTTOMLEFT, 0, 10)

    self.btnReset = CreateStyledButton(PANEL_NAME .. "_BtnReset", pane, 160, 32, Addon.Locale:Get("BTN_RESET"), function()
        if self.selectedQuestId and Addon.QuestRepository:ResetQuest(self.selectedQuestId) then
            Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_RESET"), false)
        end
    end)
    self.btnReset:SetAnchor(TOPLEFT, self.btnEdit, TOPRIGHT, 12, 0)

    self.btnDelete = CreateStyledButton(PANEL_NAME .. "_BtnDelete", pane, 160, 32, Addon.Locale:Get("BTN_DELETE"), function()
        if self.selectedQuestId and Addon.QuestRepository:DeleteQuest(self.selectedQuestId) then
            Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_DELETED"), false)
        end
    end)
    self.btnDelete:SetAnchor(TOPLEFT, self.btnReset, TOPRIGHT, 12, 0)

    -- Separador horizontal entre botones de misión y sección de códigos
    local codeDivider = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_CodeDivider", pane, CT_TEXTURE)
    codeDivider:SetDimensions(512, 4)
    codeDivider:SetAnchor(TOPLEFT, self.btnActivate, BOTTOMLEFT, 0, 54)
    codeDivider:SetTexture(Addon.Constants.UI.DIVIDER_TEXTURE)
    self.codeDivider = codeDivider

    -- Grupo 2: Botones de manejo de códigos (compartir / entregar / validar)
    self.btnShare = CreateStyledButton(PANEL_NAME .. "_BtnShare", pane, 160, 32, Addon.Locale:Get("BTN_SHARE"), function()
        self:OnShareClicked()
    end)
    self.btnShare:SetAnchor(TOPLEFT, codeDivider, BOTTOMLEFT, 0, 10)

    self.btnCompletionCode = CreateStyledButton(PANEL_NAME .. "_BtnCompletionCode", pane, 160, 32, Addon.Locale:Get("BTN_COMPLETION_CODE"), function()
        self:OnCompletionCodeClicked()
    end)
    self.btnCompletionCode:SetAnchor(TOPLEFT, self.btnShare, TOPRIGHT, 12, 0)
    self.btnCompletionCode:SetHidden(true)

    self.btnValidateDelivery = CreateStyledButton(PANEL_NAME .. "_BtnValidateDelivery", pane, 160, 32, Addon.Locale:Get("BTN_VALIDATE_DELIVERY"), function()
        self:OnValidateDeliveryClicked()
    end)
    self.btnValidateDelivery:SetAnchor(TOPLEFT, self.btnShare, TOPRIGHT, 12, 0)
    self.btnValidateDelivery:SetHidden(true)

    -- Cuadro único para mostrar/copiar códigos generados y pegar códigos de entrega a validar
    local shareHeader = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ShareHeader", pane, CT_LABEL)
    shareHeader:SetDimensions(520, 22)
    shareHeader:SetAnchor(TOPLEFT, self.btnShare, BOTTOMLEFT, 0, 12)
    if shareHeader.SetFont then shareHeader:SetFont("ZoFontGameBold") end
    if shareHeader.SetColor then shareHeader:SetColor(0.91, 0.83, 0.63, 1) end
    shareHeader:SetText(Addon.Locale:Get("LABEL_CODE_BOX_HEADER"))
    self.shareHeader = shareHeader

    local shareBg, shareEdit = CreateEditBoxWithBackdrop(PANEL_NAME .. "_ShareEdit", pane, 510, 34, 1024, false)
    shareBg:SetAnchor(TOPLEFT, shareHeader, BOTTOMLEFT, 0, 2)
    self.shareBg = shareBg
    self.shareEdit = shareEdit

    local resultLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ValidateResult", pane, CT_LABEL)
    resultLabel:SetDimensions(510, 44)
    resultLabel:SetAnchor(TOPLEFT, shareBg, BOTTOMLEFT, 0, 6)
    if resultLabel.SetFont then resultLabel:SetFont("ZoFontGame") end
    resultLabel:SetText("")
    self.validateResultLabel = resultLabel
end

function JournalTab:BuildEditorPane(parent)
    local pane = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EditorPane", parent, CT_CONTROL)
    pane:SetDimensions(550, 580)
    pane:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    pane:SetHidden(true)
    self.editorPane = pane

    local header = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EditorHeader", pane, CT_LABEL)
    header:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 0)
    if header.SetFont then header:SetFont("ZoFontWinH2") end
    if header.SetColor then header:SetColor(0.95, 0.88, 0.65, 1) end
    self.editorHeader = header

    local lblTitle = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblInputTitle", pane, CT_LABEL)
    lblTitle:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 42)
    if lblTitle.SetFont then lblTitle:SetFont("ZoFontGameBold") end
    lblTitle:SetText(Addon.Locale:Get("LABEL_INPUT_TITLE"))
    self.lblInputTitle = lblTitle

    local titleBg, titleEdit = CreateEditBoxWithBackdrop(
        PANEL_NAME .. "_TitleEdit",
        pane,
        510,
        34,
        90,
        false,
        function(val)
            Addon.QuestRepository:UpdateDraftFields({ title = val }, true)
        end
    )
    titleBg:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 66)
    self.titleBg = titleBg
    self.titleEdit = titleEdit

    local lblDesc = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblInputDesc", pane, CT_LABEL)
    lblDesc:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 112)
    if lblDesc.SetFont then lblDesc:SetFont("ZoFontGameBold") end
    lblDesc:SetText(Addon.Locale:Get("LABEL_INPUT_DESCRIPTION"))
    self.lblInputDesc = lblDesc

    local descBg, descEdit = CreateEditBoxWithBackdrop(
        PANEL_NAME .. "_DescEdit",
        pane,
        510,
        96,
        400,
        true,
        function(val)
            Addon.QuestRepository:UpdateDraftFields({ description = val }, true)
        end
    )
    descBg:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 136)
    self.descBg = descBg
    self.descEdit = descEdit

    local lblTargetSec = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblTargetSec", pane, CT_LABEL)
    lblTargetSec:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 246)
    if lblTargetSec.SetFont then lblTargetSec:SetFont("ZoFontGameBold") end
    lblTargetSec:SetText(Addon.Locale:Get("LABEL_TARGET_SECTION"))
    self.lblTargetSec = lblTargetSec

    self.btnClearTargets = CreateStyledButton(PANEL_NAME .. "_BtnClearTargets", pane, 150, 26, Addon.Locale:Get("BTN_CLEAR_TARGETS"), function()
        Addon.QuestRepository:ClearDraftTargets()
    end)
    self.btnClearTargets:SetAnchor(TOPLEFT, pane, TOPLEFT, 360, 242)
    self.btnClearTargets:SetHidden(true)

    local lblCapturedTarget = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblCapturedTarget", pane, CT_LABEL)
    lblCapturedTarget:SetDimensions(510, 56)
    lblCapturedTarget:SetAnchor(TOPLEFT, pane, TOPLEFT, 6, 274)
    if lblCapturedTarget.SetFont then lblCapturedTarget:SetFont("ZoFontGame") end
    self.lblCapturedTarget = lblCapturedTarget

    -- Selector de radio del área de búsqueda
    local lblAreaSize = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblAreaSize", pane, CT_LABEL)
    lblAreaSize:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 342)
    if lblAreaSize.SetFont then lblAreaSize:SetFont("ZoFontGameBold") end
    lblAreaSize:SetText(Addon.Locale:Get("LABEL_AREA_SIZE"))
    self.lblAreaSize = lblAreaSize

    local radii = Addon.Constants.AREA_RADIUS

    self.btnRadiusSmall = CreateStyledButton(PANEL_NAME .. "_BtnRadSmall", pane, 110, 30, "", function()
        Addon.QuestRepository:UpdateDraftFields({ areaRadius = radii.SMALL })
    end)
    self.btnRadiusSmall:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 368)

    self.btnRadiusMedium = CreateStyledButton(PANEL_NAME .. "_BtnRadMedium", pane, 110, 30, "", function()
        Addon.QuestRepository:UpdateDraftFields({ areaRadius = radii.MEDIUM })
    end)
    self.btnRadiusMedium:SetAnchor(TOPLEFT, pane, TOPLEFT, 120, 368)

    self.btnRadiusLarge = CreateStyledButton(PANEL_NAME .. "_BtnRadLarge", pane, 110, 30, "", function()
        Addon.QuestRepository:UpdateDraftFields({ areaRadius = radii.LARGE })
    end)
    self.btnRadiusLarge:SetAnchor(TOPLEFT, pane, TOPLEFT, 240, 368)

    local lblCompletionMsg = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblInputCompletionMsg", pane, CT_LABEL)
    lblCompletionMsg:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 412)
    if lblCompletionMsg.SetFont then lblCompletionMsg:SetFont("ZoFontGameBold") end
    lblCompletionMsg:SetText(Addon.Locale:Get("LABEL_INPUT_COMPLETION_MSG"))
    self.lblInputCompletionMsg = lblCompletionMsg

    local compBg, compEdit = CreateEditBoxWithBackdrop(
        PANEL_NAME .. "_CompletionEdit",
        pane,
        510,
        34,
        140,
        false,
        function(val)
            Addon.QuestRepository:UpdateDraftFields({ completionMessage = val }, true)
        end
    )
    compBg:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 434)
    self.completionBg = compBg
    self.completionEdit = compEdit

    self.btnSaveEditor = CreateStyledButton(PANEL_NAME .. "_BtnSaveEditor", pane, 180, 36, Addon.Locale:Get("BTN_SAVE"), function()
        self:OnSaveDraftClicked()
    end)
    self.btnSaveEditor:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 486)

    self.btnCancelEditor = CreateStyledButton(PANEL_NAME .. "_BtnCancelEditor", pane, 150, 36, Addon.Locale:Get("BTN_CANCEL"), function()
        self.viewMode = VIEW_MODE.DETAIL
        Addon.QuestRepository:ResetDraft()
        self.titleEdit:SetText("")
        self.descEdit:SetText("")
        self.completionEdit:SetText("")
        self:Refresh()
    end)
    self.btnCancelEditor:SetAnchor(TOPLEFT, pane, TOPLEFT, 195, 486)

    self.btnShowMapEditor = CreateStyledButton(PANEL_NAME .. "_BtnShowMapEditor", pane, 155, 36, Addon.Locale:Get("BTN_SHOW_ON_MAP"), function()
        local draft = Addon.QuestRepository:GetDraft()
        if draft and draft.mapId and draft.mapId > 0 then
            Addon.WorldMapArea:ShowQuestOnMap(draft)
        end
    end)
    self.btnShowMapEditor:SetAnchor(TOPLEFT, pane, TOPLEFT, 360, 486)
    self.btnShowMapEditor:SetHidden(true)
end

function JournalTab:BuildImportPane(parent)
    local pane = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ImportPane", parent, CT_CONTROL)
    pane:SetDimensions(550, 580)
    pane:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    pane:SetHidden(true)
    self.importPane = pane

    local header = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ImportHeader", pane, CT_LABEL)
    header:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 0)
    if header.SetFont then header:SetFont("ZoFontWinH2") end
    if header.SetColor then header:SetColor(0.95, 0.88, 0.65, 1) end
    header:SetText(Addon.Locale:Get("IMPORT_VIEW_TITLE"))
    self.importHeader = header

    local instr = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ImportInstr", pane, CT_LABEL)
    instr:SetDimensions(510, 48)
    instr:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 44)
    if instr.SetFont then instr:SetFont("ZoFontGame") end
    instr:SetText(Addon.Locale:Get("IMPORT_INSTRUCTIONS"))
    self.importInstr = instr

    local codeBg, codeEdit = CreateEditBoxWithBackdrop(PANEL_NAME .. "_ImportCodeEdit", pane, 510, 80, 1024, true)
    codeBg:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 96)
    self.importCodeBg = codeBg
    self.importCodeEdit = codeEdit

    self.btnConfirmImport = CreateStyledButton(PANEL_NAME .. "_BtnConfirmImport", pane, 180, 36, Addon.Locale:Get("BTN_CONFIRM_IMPORT"), function()
        self:OnConfirmImportClicked()
    end)
    self.btnConfirmImport:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 196)

    self.btnCancelImport = CreateStyledButton(PANEL_NAME .. "_BtnCancelImport", pane, 150, 36, Addon.Locale:Get("BTN_CANCEL"), function()
        self.importCodeEdit:SetText("")
        self.viewMode = VIEW_MODE.DETAIL
        self:Refresh()
    end)
    self.btnCancelImport:SetAnchor(TOPLEFT, pane, TOPLEFT, 195, 196)
end

function JournalTab:IntegrateIntoQuestJournalModeBar()
    local qj = QUEST_JOURNAL_KEYBOARD or (SYSTEMS and SYSTEMS.GetKeyboardObject and SYSTEMS:GetKeyboardObject("questJournal"))
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
            qj.tabs:Add(self.tabCategoryName, { self.fragment }, tabData)
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
    self.shareCodeHeaderKey = nil
    if self.shareEdit then self.shareEdit:SetText("") end
    if self.validateResultLabel then self.validateResultLabel:SetText("") end
    self:Refresh()
end

function JournalTab:OpenCreateEditor()
    local draft = Addon.QuestRepository:GetDraft()
    if draft.editingQuestId then
        Addon.QuestRepository:ResetDraft()
        draft = Addon.QuestRepository:GetDraft()
    end
    self.titleEdit:SetText(draft.title or "")
    self.descEdit:SetText(draft.description or "")
    self.completionEdit:SetText(draft.completionMessage or "")
    self.viewMode = VIEW_MODE.EDITOR
    self:Refresh()
end

function JournalTab:ToggleSection(sectionKey)
    if not sectionKey or not self.collapsedSections then return end
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
    self.titleEdit:SetText(draft.title or "")
    self.descEdit:SetText(draft.description or "")
    self.completionEdit:SetText(draft.completionMessage or "")
    self.viewMode = VIEW_MODE.EDITOR
    self:Refresh()
end

function JournalTab:OpenImportView()
    if Addon.QuestRepository:GetDraft().editingQuestId then
        Addon.QuestRepository:ResetDraft()
    end
    self.importCodeEdit:SetText("")
    self.viewMode = VIEW_MODE.IMPORT
    self:Refresh()
    if self.importCodeEdit.TakeFocus then
        self.importCodeEdit:TakeFocus()
    end
end

function JournalTab:OnSaveDraftClicked()
    local titleText = self.titleEdit:GetText()
    local descText = self.descEdit:GetText()
    local compMsgText = self.completionEdit and self.completionEdit:GetText() or ""

    local savedQuest, err = Addon.QuestRepository:SaveDraft(titleText, descText, nil, compMsgText)
    if not savedQuest then
        Addon.Announcements:ShowAlert(err or Addon.Locale:Get("ERR_MISSING_TARGET"), true)
        return
    end

    self.titleEdit:SetText("")
    self.descEdit:SetText("")
    if self.completionEdit then
        self.completionEdit:SetText("")
    end

    Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_SAVED", savedQuest.title), false)
end

function JournalTab:OnConfirmImportClicked()
    local rawCode = self.importCodeEdit:GetText()
    local importedQuest, err = Addon.QuestRepository:ImportQuestFromCode(rawCode)
    if not importedQuest then
        Addon.Announcements:ShowAlert(err or Addon.Locale:Get("ERR_INVALID_CODE"), true)
        return
    end

    self.importCodeEdit:SetText("")

    Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_IMPORTED", importedQuest.title), false)
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

function JournalTab:ShowCodeInDetailBox(headerKey, code, alertKey)
    self.shareCodeHeaderKey = headerKey
    self.shareHeader:SetText(Addon.Locale:Get(headerKey))
    self.shareEdit:SetText(code)
    if self.validateResultLabel then
        self.validateResultLabel:SetText("")
    end
    if self.shareEdit.TakeFocus then
        self.shareEdit:TakeFocus()
    end
    if self.shareEdit.SelectAll then
        self.shareEdit:SelectAll()
    end

    Addon.Announcements:ShowAlert(Addon.Locale:Get(alertKey), false)
end

function JournalTab:OnShareClicked()
    local q = Addon.QuestRepository:GetQuestById(self.selectedQuestId)
    if not q then return end

    local code = Addon.QuestRepository:ExportQuestToCode(q.id)
    if not code then return end

    self:ShowCodeInDetailBox("LABEL_SHARE_CODE_HEADER", code, "ALERT_SHARE_READY")
end

function JournalTab:OnCompletionCodeClicked()
    local q = Addon.QuestRepository:GetQuestById(self.selectedQuestId)
    if not q or not q.completed then return end

    local code = Addon.QuestRepository:ExportCompletionCode(q.id)
    if not code then return end

    self:ShowCodeInDetailBox("LABEL_COMPLETION_CODE_HEADER", code, "ALERT_COMPLETION_CODE_READY")
end

function JournalTab:OnValidateDeliveryClicked()
    if not self.selectedQuestId then return end
    local rawCode = (self.shareEdit and self.shareEdit:GetText()) or ""
    if rawCode:match("^%s*$") then
        self.validateResultLabel:SetText(Addon.Locale:Get("VALIDATE_ERR_EMPTY"))
        if self.shareEdit and self.shareEdit.TakeFocus then
            self.shareEdit:TakeFocus()
        end
        return
    end

    local isValid, resultOrErrKey = Addon.QuestRepository:ValidateCompletionCode(self.selectedQuestId, rawCode)
    if isValid and type(resultOrErrKey) == "table" then
        self.validateResultLabel:SetText(Addon.Locale:Get("VALIDATE_RESULT_SUCCESS", resultOrErrKey.characterName or ""))
    else
        local errKey = type(resultOrErrKey) == "string" and resultOrErrKey or "VALIDATE_ERR_INVALID_CODE"
        self.validateResultLabel:SetText(Addon.Locale:Get(errKey))
    end
end

function JournalTab:OpenTab()
    if not self.isInitialized then
        self:Initialize()
    end

    local qj = QUEST_JOURNAL_KEYBOARD or (SYSTEMS and SYSTEMS.GetKeyboardObject and SYSTEMS:GetKeyboardObject("questJournal"))
    if qj and qj.SetMode then
        qj:SetMode(self.tabDescriptor or Addon.Constants.UI.TAB_DESCRIPTOR)
    end

    if SCENE_MANAGER and SCENE_MANAGER.Show then
        SCENE_MANAGER:Show("questJournal")
    end

    if qj and qj.tabs and qj.tabs.SelectFragment and self.tabCategoryName then
        qj.tabs:SelectFragment(self.tabCategoryName)
    elseif self.panel then
        self.panel:SetHidden(false)
    end

    if self._dirty then
        self:Refresh()
    end
end

function JournalTab:ToggleTab()
    if not self.isInitialized then
        self:Initialize()
    end

    local qj = QUEST_JOURNAL_KEYBOARD or (SYSTEMS and SYSTEMS.GetKeyboardObject and SYSTEMS:GetKeyboardObject("questJournal"))
    local sceneShowing = SCENE_MANAGER and SCENE_MANAGER.IsShowing and SCENE_MANAGER:IsShowing("questJournal")

    if sceneShowing and qj and qj.mode == (self.tabDescriptor or Addon.Constants.UI.TAB_DESCRIPTOR) then
        SCENE_MANAGER:Hide("questJournal")
        if self.panel then
            self.panel:SetHidden(true)
        end
    else
        self:OpenTab()
    end
end

function JournalTab:RefreshQuestList(allQuests, activeQuest)
    if not self.panel then return end

    allQuests = allQuests or Addon.QuestRepository:GetAllQuests()
    activeQuest = activeQuest or Addon.QuestRepository:GetActiveQuest()

    local roles = Addon.Constants.QUEST_ROLE
    local activeMissions = {}
    local completedMissions = {}
    local preparingMissions = {}
    for _, q in ipairs(allQuests) do
        if q.role == roles.PREPARED then
            table.insert(preparingMissions, q)
        elseif q.completed then
            table.insert(completedMissions, q)
        else
            table.insert(activeMissions, q)
        end
    end

    self.headerLabel:SetText(Addon.Locale:Get("HEADER_QUEST_LIST", #allQuests))
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
    local displayRows = {}

    local function AppendSection(sectionKey, localeKey, quests, headerColor, isCompleted)
        if #quests == 0 then return end
        local isCollapsed = self.collapsedSections and self.collapsedSections[sectionKey]
        local arrowTex = isCollapsed and "/esoui/art/buttons/tree_closed_up.dds" or "/esoui/art/buttons/tree_open_up.dds"
        table.insert(displayRows, {
            isHeader = true,
            sectionKey = sectionKey,
            text = string.format("|t16:16:%s|t %s%s|r", arrowTex, headerColor, Addon.Locale:Get(localeKey, #quests)),
        })
        if isCollapsed then return end

        for _, q in ipairs(quests) do
            local isSelected = (self.selectedQuestId == q.id)
            local prefix
            local selColor
            if isCompleted then
                prefix = "   |c00CCFF✓ |r"
                selColor = isSelected and "|cFFFFFF" or "|c8899AA"
            else
                local isAct = (activeQuest and activeQuest.id == q.id)
                prefix = isAct and "   |c33FF33★ |r" or "      "
                selColor = isSelected and "|cFFFFFF" or "|cC5C29E"
            end
            table.insert(displayRows, {
                isHeader = false,
                questId = q.id,
                text = prefix .. selColor .. (q.title or "") .. "|r",
            })
        end
    end

    AppendSection("missions", "SECTION_ACTIVE_QUESTS", activeMissions, "|cE8D5A0", false)
    AppendSection("completed", "SECTION_COMPLETED_QUESTS", completedMissions, "|c88AAFF", true)
    AppendSection("preparing", "SECTION_PREPARED_QUESTS", preparingMissions, "|cD8B878", false)

    local maxOffset = math.max(0, #displayRows - MAX_VISIBLE_ROWS)
    self._maxListOffset = maxOffset
    self.listOffset = math.min(math.max(0, self.listOffset or 0), maxOffset)

    for i = 1, MAX_VISIBLE_ROWS do
        local rowCtrl = self.rowControls[i]
        local rowData = displayRows[self.listOffset + i]
        if rowData then
            rowCtrl:SetHidden(false)
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
    if self.viewMode == VIEW_MODE.EDITOR then
        self.detailPane:SetHidden(true)
        self.importPane:SetHidden(true)
        self.editorPane:SetHidden(false)
        self:RefreshEditorPane()
    elseif self.viewMode == VIEW_MODE.IMPORT then
        self.detailPane:SetHidden(true)
        self.editorPane:SetHidden(true)
        self.importPane:SetHidden(false)
    else
        self.editorPane:SetHidden(true)
        self.importPane:SetHidden(true)
        self.detailPane:SetHidden(false)
        self:RefreshDetailPane(selectedQuest, activeQuest)
    end
end

function JournalTab:RefreshDetailPane(selectedQuest, activeQuest)
    selectedQuest = selectedQuest or (self.selectedQuestId and Addon.QuestRepository:GetQuestById(self.selectedQuestId))
    activeQuest = activeQuest or Addon.QuestRepository:GetActiveQuest()

    if not selectedQuest then
        self.detailTitle:SetText(Addon.Locale:Get("TAB_TITLE"))
        self.detailStatus:SetText(Addon.Locale:Get("EMPTY_QUEST_LIST"))
        self.detailLocation:SetText("")
        self.detailDescHeader:SetHidden(true)
        self.detailDescBody:SetText("")
        self.detailObjHeader:SetHidden(true)
        self.detailObjText:SetText("")
        self.codeDivider:SetHidden(true)
        self.shareHeader:SetHidden(true)
        self.shareBg:SetHidden(true)
        self.validateResultLabel:SetHidden(true)
        self.btnActivate:SetHidden(true)
        self.btnShowOnMap:SetHidden(true)
        self.btnShare:SetHidden(true)
        self.btnEdit:SetHidden(true)
        self.btnReset:SetHidden(true)
        self.btnDelete:SetHidden(true)
        self.btnCompletionCode:SetHidden(true)
        self.btnValidateDelivery:SetHidden(true)
        return
    end

    self.detailDescHeader:SetHidden(false)
    self.detailObjHeader:SetHidden(false)
    self.detailTitle:SetText((selectedQuest.title or ""):upper())

    local isPrepared = Addon.QuestRepository:IsPreparedQuest(selectedQuest)
    local isCurrentActive = (activeQuest and activeQuest.id == selectedQuest.id)
    local activateLabel = isPrepared and Addon.Locale:Get("BTN_TEST_QUEST") or Addon.Locale:Get("BTN_ACTIVATE")
    local deactivateLabel = isPrepared and Addon.Locale:Get("BTN_STOP_TEST") or Addon.Locale:Get("BTN_DEACTIVATE")

    if isCurrentActive then
        self.detailStatus:SetText(Addon.Locale:Get("STATUS_ACTIVE"))
        self.btnActivate:SetText(deactivateLabel)
    elseif selectedQuest.completed then
        self.detailStatus:SetText(Addon.Locale:Get("STATUS_COMPLETED"))
        self.btnActivate:SetText(activateLabel)
    else
        self.detailStatus:SetText(Addon.Locale:Get("STATUS_AVAILABLE"))
        self.btnActivate:SetText(activateLabel)
    end

    local locText = (selectedQuest.mapName and selectedQuest.mapName ~= "" and selectedQuest.mapName)
        or Addon.Locale:Get("LABEL_UNKNOWN_LOCATION")
    self.detailLocation:SetText(Addon.Locale:Get("LABEL_LOCATION", locText))

    local descText = (selectedQuest.description and selectedQuest.description ~= "" and selectedQuest.description)
        or Addon.Locale:Get("LABEL_NO_DESCRIPTION")
    self.detailDescBody:SetText(descText)

    local targets = selectedQuest.targets or {}
    local objLines = {}
    for _, t in ipairs(targets) do
        local line = Addon.Locale:Get(
            "OBJECTIVE_KILL_FORMAT",
            t.name or "",
            t.currentCount or 0,
            t.requiredCount or 1
        )
        if (t.currentCount or 0) >= (t.requiredCount or 1) then
            line = line .. Addon.Locale:Get("OBJECTIVE_COMPLETED_SUFFIX")
        end
        table.insert(objLines, line)
    end
    self.detailObjText:SetDimensions(510, math.max(32, #objLines * 24))
    self.detailObjText:SetText(table.concat(objLines, "\n"))

    self.codeDivider:SetHidden(false)
    self.shareHeader:SetText(Addon.Locale:Get(self.shareCodeHeaderKey or "LABEL_CODE_BOX_HEADER"))
    self.shareHeader:SetHidden(false)
    self.shareBg:SetHidden(false)
    self.validateResultLabel:SetHidden(false)

    self.btnActivate:SetHidden(false)
    self.btnShowOnMap:SetHidden(false)
    self.btnShare:SetHidden(false)
    self.btnReset:ClearAnchors()
    if isPrepared then
        self.btnEdit:SetHidden(false)
        self.btnReset:SetAnchor(TOPLEFT, self.btnEdit, TOPRIGHT, 12, 0)
        self.btnCompletionCode:SetHidden(true)
        self.btnValidateDelivery:SetHidden(false)
    else
        self.btnEdit:SetHidden(true)
        self.btnReset:SetAnchor(TOPLEFT, self.btnActivate, BOTTOMLEFT, 0, 10)
        self.btnValidateDelivery:SetHidden(true)
        self.btnCompletionCode:SetHidden(not selectedQuest.completed)
    end
    self.btnReset:SetHidden(false)
    self.btnDelete:SetHidden(false)
end

function JournalTab:RefreshEditorPane()
    local draft = Addon.QuestRepository:GetDraft()

    if draft.editingQuestId then
        self.editorHeader:SetText(Addon.Locale:Get("EDITOR_EDIT_TITLE"))
    else
        self.editorHeader:SetText(Addon.Locale:Get("EDITOR_CREATE_TITLE"))
    end

    local draftTitle = draft.title or ""
    if not self.titleEdit._focused and self.titleEdit:GetText() ~= draftTitle then
        self.titleEdit:SetText(draftTitle)
    end
    local draftDesc = draft.description or ""
    if not self.descEdit._focused and self.descEdit:GetText() ~= draftDesc then
        self.descEdit:SetText(draftDesc)
    end
    local draftCompMsg = draft.completionMessage or ""
    if self.completionEdit and not self.completionEdit._focused and self.completionEdit:GetText() ~= draftCompMsg then
        self.completionEdit:SetText(draftCompMsg)
    end

    local targets = draft.targets or {}
    local summary = Addon.QuestRepository:FormatTargetsSummary(targets)
    if summary ~= "" then
        local locName = (draft.mapName and draft.mapName ~= "" and draft.mapName)
            or Addon.Locale:Get("LABEL_UNKNOWN_LOCATION")
        self.lblCapturedTarget:SetText(Addon.Locale:Get("TARGET_CAPTURED_FORMAT", summary, locName))
        self.btnClearTargets:SetHidden(false)
    else
        self.lblCapturedTarget:SetText(Addon.Locale:Get("TARGET_NOT_CAPTURED"))
        self.btnClearTargets:SetHidden(true)
    end

    if self.btnShowMapEditor then
        local hasDraftArea = summary ~= "" and draft.mapId and draft.mapId > 0 and draft.areaCenterX and draft.areaCenterY
        self.btnShowMapEditor:SetHidden(not hasDraftArea)
    end

    local radii = Addon.Constants.AREA_RADIUS
    local curRad = draft.areaRadius or radii.MEDIUM

    local function FormatSelected(label, isSelected)
        if isSelected then
            return "|c33FF33[" .. label .. "]|r"
        end
        return label
    end

    self.btnRadiusSmall:SetText(FormatSelected(Addon.Locale:Get("BTN_RADIUS_SMALL"), math.abs(curRad - radii.SMALL) < 0.005))
    self.btnRadiusMedium:SetText(FormatSelected(Addon.Locale:Get("BTN_RADIUS_MEDIUM"), math.abs(curRad - radii.MEDIUM) < 0.005))
    self.btnRadiusLarge:SetText(FormatSelected(Addon.Locale:Get("BTN_RADIUS_LARGE"), math.abs(curRad - radii.LARGE) < 0.005))
end

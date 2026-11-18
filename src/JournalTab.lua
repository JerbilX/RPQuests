-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalTab = {}
local JournalTab = Addon.JournalTab

local PANEL_NAME = "RPQuest_JournalPanel"
local MAX_VISIBLE_ROWS = 14

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
    self.selectedQuestId = nil
    self.shareCodeVisible = false
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
        if eventType == "QUEST_CREATED" or eventType == "QUEST_IMPORTED" or eventType == "QUEST_UPDATED" then
            if quest and quest.id then
                self.selectedQuestId = quest.id
            end
            self.viewMode = VIEW_MODE.DETAIL
        elseif eventType == "QUEST_DELETED" then
            if quest and self.selectedQuestId == quest.id then
                self.selectedQuestId = nil
            end
            self.shareCodeVisible = false
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

    self.newBtn = CreateStyledButton(
        PANEL_NAME .. "_NewBtn",
        leftCol,
        150,
        28,
        Addon.Locale:Get("BTN_NEW_QUEST"),
        function()
            self:OpenCreateEditor()
        end
    )
    self.newBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 0, 32)

    self.importBtn = CreateStyledButton(
        PANEL_NAME .. "_ImportBtn",
        leftCol,
        150,
        28,
        Addon.Locale:Get("BTN_IMPORT_CODE"),
        function()
            self:OpenImportView()
        end
    )
    self.importBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 160, 32)

    local emptyLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EmptyList", leftCol, CT_LABEL)
    emptyLabel:SetDimensions(310, 80)
    emptyLabel:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 4, 78)
    if emptyLabel.SetFont then emptyLabel:SetFont("ZoFontGame") end
    if emptyLabel.SetColor then emptyLabel:SetColor(0.75, 0.75, 0.75, 1) end
    emptyLabel:SetHidden(true)
    self.emptyLabel = emptyLabel

    self.rowControls = {}
    self.rowBindings = {}

    for i = 1, MAX_VISIBLE_ROWS do
        local rowBtn = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_Row" .. i, leftCol, CT_BUTTON)
        rowBtn:SetDimensions(315, 30)
        rowBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 0, 72 + ((i - 1) * 34))
        if rowBtn.SetFont then rowBtn:SetFont("ZoFontHeader") end
        local rowIndex = i
        rowBtn:SetHandler("OnClicked", function()
            local binding = self.rowBindings[rowIndex]
            if binding and binding.questId then
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
    pane:SetDimensions(550, 580)
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

    -- Contenedor para mostrar y copiar el código de compartición
    local shareHeader = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ShareHeader", pane, CT_LABEL)
    shareHeader:SetDimensions(520, 22)
    shareHeader:SetAnchor(TOPLEFT, objText, BOTTOMLEFT, -12, 8)
    if shareHeader.SetFont then shareHeader:SetFont("ZoFontGameBold") end
    if shareHeader.SetColor then shareHeader:SetColor(0.91, 0.83, 0.63, 1) end
    shareHeader:SetText(Addon.Locale:Get("LABEL_SHARE_CODE_HEADER"))
    shareHeader:SetHidden(true)
    self.shareHeader = shareHeader

    local shareBg, shareEdit = CreateEditBoxWithBackdrop(PANEL_NAME .. "_ShareEdit", pane, 510, 34, 1024, false)
    shareBg:SetAnchor(TOPLEFT, shareHeader, BOTTOMLEFT, 0, 2)
    shareBg:SetHidden(true)
    self.shareBg = shareBg
    self.shareEdit = shareEdit

    -- Fila 1 de botones de acción (anclada dinámicamente debajo de objetivos o código de compartición)
    self.btnActivate = CreateStyledButton(PANEL_NAME .. "_BtnActivate", pane, 160, 32, "", function()
        self:OnToggleActiveClicked()
    end)
    self.btnActivate:SetAnchor(TOPLEFT, objText, BOTTOMLEFT, -12, 18)

    self.btnShowOnMap = CreateStyledButton(PANEL_NAME .. "_BtnShowMap", pane, 160, 32, Addon.Locale:Get("BTN_SHOW_ON_MAP"), function()
        local q = Addon.QuestRepository:GetQuestById(self.selectedQuestId)
        if q then
            Addon.WorldMapArea:ShowQuestOnMap(q)
        end
    end)
    self.btnShowOnMap:SetAnchor(TOPLEFT, self.btnActivate, TOPRIGHT, 12, 0)

    self.btnShare = CreateStyledButton(PANEL_NAME .. "_BtnShare", pane, 160, 32, Addon.Locale:Get("BTN_SHARE"), function()
        self:OnShareClicked()
    end)
    self.btnShare:SetAnchor(TOPLEFT, self.btnShowOnMap, TOPRIGHT, 12, 0)

    -- Fila 2 de botones de acción
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

    self.btnSaveEditor = CreateStyledButton(PANEL_NAME .. "_BtnSaveEditor", pane, 180, 36, Addon.Locale:Get("BTN_SAVE"), function()
        self:OnSaveDraftClicked()
    end)
    self.btnSaveEditor:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 425)

    self.btnCancelEditor = CreateStyledButton(PANEL_NAME .. "_BtnCancelEditor", pane, 150, 36, Addon.Locale:Get("BTN_CANCEL"), function()
        self.viewMode = VIEW_MODE.DETAIL
        Addon.QuestRepository:ResetDraft()
        self.titleEdit:SetText("")
        self.descEdit:SetText("")
        self:Refresh()
    end)
    self.btnCancelEditor:SetAnchor(TOPLEFT, pane, TOPLEFT, 195, 425)
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
    self.shareCodeVisible = false
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
    self.viewMode = VIEW_MODE.EDITOR
    self:Refresh()
end

function JournalTab:OpenEditEditor(questId)
    local draft = Addon.QuestRepository:LoadQuestIntoDraft(questId)
    if not draft then return end
    self.titleEdit:SetText(draft.title or "")
    self.descEdit:SetText(draft.description or "")
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

    local savedQuest, err = Addon.QuestRepository:SaveDraft(titleText, descText)
    if not savedQuest then
        Addon.Announcements:ShowAlert(err or Addon.Locale:Get("ERR_MISSING_TARGET"), true)
        return
    end

    self.titleEdit:SetText("")
    self.descEdit:SetText("")

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

function JournalTab:OnShareClicked()
    local q = Addon.QuestRepository:GetQuestById(self.selectedQuestId)
    if not q then return end

    local code = Addon.QuestRepository:ExportQuestToCode(q.id)
    if not code then return end

    self.shareCodeVisible = true
    self:Refresh()

    self.shareEdit:SetText(code)
    if self.shareEdit.TakeFocus then
        self.shareEdit:TakeFocus()
    end
    if self.shareEdit.SelectAll then
        self.shareEdit:SelectAll()
    end

    Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_SHARE_READY"), false)
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

    local activeAndAvail = {}
    local completedQuests = {}
    for _, q in ipairs(allQuests) do
        if q.completed then
            table.insert(completedQuests, q)
        else
            table.insert(activeAndAvail, q)
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

    if #activeAndAvail > 0 then
        table.insert(displayRows, { isHeader = true, text = "|cE8D5A0— " .. Addon.Locale:Get("SECTION_ACTIVE_QUESTS") .. " —|r" })
        for _, q in ipairs(activeAndAvail) do
            local isAct = (activeQuest and activeQuest.id == q.id)
            local prefix = isAct and "|c33FF33★ |r" or "   "
            local selColor = (self.selectedQuestId == q.id) and "|cFFFFFF" or "|cC5C29E"
            table.insert(displayRows, {
                isHeader = false,
                questId = q.id,
                text = prefix .. selColor .. (q.title or "") .. "|r",
            })
        end
    end

    if #completedQuests > 0 then
        table.insert(displayRows, { isHeader = true, text = "|c88AAFF— " .. Addon.Locale:Get("SECTION_COMPLETED_QUESTS") .. " —|r" })
        for _, q in ipairs(completedQuests) do
            local selColor = (self.selectedQuestId == q.id) and "|cFFFFFF" or "|c8899AA"
            table.insert(displayRows, {
                isHeader = false,
                questId = q.id,
                text = "|c00CCFF✓ |r" .. selColor .. (q.title or "") .. "|r",
            })
        end
    end

    local maxOffset = math.max(0, #displayRows - MAX_VISIBLE_ROWS)
    self._maxListOffset = maxOffset
    self.listOffset = math.min(math.max(0, self.listOffset or 0), maxOffset)

    for i = 1, MAX_VISIBLE_ROWS do
        local rowCtrl = self.rowControls[i]
        local rowData = displayRows[self.listOffset + i]
        if rowData then
            rowCtrl:SetHidden(false)
            rowCtrl:SetText(rowData.text)
            rowCtrl:SetMouseEnabled(not rowData.isHeader)
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
        self.shareHeader:SetHidden(true)
        self.shareBg:SetHidden(true)
        self.btnActivate:SetHidden(true)
        self.btnShowOnMap:SetHidden(true)
        self.btnShare:SetHidden(true)
        self.btnEdit:SetHidden(true)
        self.btnReset:SetHidden(true)
        self.btnDelete:SetHidden(true)
        return
    end

    self.detailDescHeader:SetHidden(false)
    self.detailObjHeader:SetHidden(false)
    self.detailTitle:SetText((selectedQuest.title or ""):upper())

    local isCurrentActive = (activeQuest and activeQuest.id == selectedQuest.id)
    if isCurrentActive then
        self.detailStatus:SetText(Addon.Locale:Get("STATUS_ACTIVE"))
        self.btnActivate:SetText(Addon.Locale:Get("BTN_DEACTIVATE"))
    elseif selectedQuest.completed then
        self.detailStatus:SetText(Addon.Locale:Get("STATUS_COMPLETED"))
        self.btnActivate:SetText(Addon.Locale:Get("BTN_ACTIVATE"))
    else
        self.detailStatus:SetText(Addon.Locale:Get("STATUS_AVAILABLE"))
        self.btnActivate:SetText(Addon.Locale:Get("BTN_ACTIVATE"))
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

    self.btnActivate:ClearAnchors()
    if self.shareCodeVisible then
        self.shareHeader:SetHidden(false)
        self.shareBg:SetHidden(false)
        self.btnActivate:SetAnchor(TOPLEFT, self.shareBg, BOTTOMLEFT, 0, 14)
    else
        self.shareHeader:SetHidden(true)
        self.shareBg:SetHidden(true)
        self.btnActivate:SetAnchor(TOPLEFT, self.detailObjText, BOTTOMLEFT, -12, 18)
    end

    self.btnActivate:SetHidden(false)
    self.btnShowOnMap:SetHidden(false)
    self.btnShare:SetHidden(false)
    self.btnEdit:SetHidden(false)
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

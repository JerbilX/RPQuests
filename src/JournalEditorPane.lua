-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalEditorPane = {}
local EditorPane = Addon.JournalEditorPane

function EditorPane.Build(tab, parent)
    local EditorSections = Addon.JournalEditorSections
    local panelName = Addon.JournalWidgets.PANEL_NAME
    local pane = WINDOW_MANAGER:CreateControl(panelName .. "_EditorPane", parent, CT_CONTROL)
    pane:SetDimensions(550, 580)
    pane:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    pane:SetHidden(true)
    tab.editorPane = pane

    local header = WINDOW_MANAGER:CreateControl(panelName .. "_EditorHeader", pane, CT_LABEL)
    header:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 0)
    if header.SetFont then header:SetFont("ZoFontWinH2") end
    if header.SetColor then header:SetColor(0.95, 0.88, 0.65, 1) end
    tab.editorHeader = header

    local formParent = pane
    local scrollContainer = WINDOW_MANAGER.CreateControlFromVirtual
        and WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_EditorScroll", pane, "ZO_ScrollContainer")
    if scrollContainer then
        scrollContainer:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 32)
        scrollContainer:SetDimensions(550, 474)
        local scrollChild = scrollContainer.GetNamedChild and scrollContainer:GetNamedChild("ScrollChild")
        if scrollChild then
            scrollChild:SetDimensions(526, 474)
            formParent = scrollChild
            tab.editorScrollChild = scrollChild
        end
        tab.editorScroll = scrollContainer
    end
    tab.editorFormParent = formParent

    tab.editorSections = {}
    tab.editorSectionsByKey = {}

    local headerSec = EditorSections.CreateAccordionSection(tab, formParent, panelName, "header", "LABEL_HEADER_SECTION", 218)
    EditorSections.BuildBaseFields(tab, headerSec.body, panelName)

    local targetSec = EditorSections.CreateAccordionSection(tab, formParent, panelName, "target", "LABEL_TARGET_SECTION", 256)
    EditorSections.BuildTargetAreaControls(tab, targetSec.body, panelName)
    EditorSections.BuildTargetConfigControls(tab, targetSec.body, panelName)

    local discoverySec = EditorSections.CreateAccordionSection(tab, formParent, panelName, "discovery", "LABEL_DISCOVERY_SECTION", 142)
    EditorSections.BuildDiscoveryControls(tab, discoverySec.body, panelName)
    EditorSections.BuildDiscoveryInputs(tab, discoverySec.body, panelName)

    local dialogueSec = EditorSections.CreateAccordionSection(tab, formParent, panelName, "dialogue", "LABEL_DIALOGUE_SECTION", 240)
    EditorSections.BuildDialogueControls(tab, dialogueSec.body, panelName)
    EditorSections.BuildDialogueInputs(tab, dialogueSec.body, panelName)

    local optionsSec = EditorSections.CreateAccordionSection(tab, formParent, panelName, "options", "LABEL_OPTIONS_SECTION", 122)
    EditorSections.BuildOptionsSection(tab, optionsSec.body, panelName)

    EditorPane.LayoutSections(tab)
    EditorSections.BuildFooterButtons(tab, pane, panelName)
end

local function GetSectionBadge(draft, key)
    if key == "target" then
        local count = #(draft.targets or {})
        return count > 0 and string.format("  |c33FF33[%d]|r", count) or ""
    elseif key == "discovery" then
        local count = #(draft.discoveries or {})
        return count > 0 and string.format("  |c33FF33[%d]|r", count) or ""
    elseif key == "dialogue" then
        local count = #(draft.dialogues or {})
        if count > 0 then
            return string.format("  |c33FF33[%d/3]|r", count)
        elseif (draft.clue or "") ~= "" then
            return "  |c33FF33[*]|r"
        end
        return ""
    elseif key == "options" then
        local modes = Addon.Constants.STEALTH_MODE
        local stealthMode = draft.stealthMode or modes.DISABLED
        if (draft.completionMessage or "") ~= "" or stealthMode ~= modes.DISABLED then
            return "  |c33FF33[*]|r"
        end
        return ""
    end
    return ""
end

function EditorPane.LayoutSections(tab)
    if not tab.editorSections or not tab.editorFormParent then return end
    local draft = Addon.QuestRepository and Addon.QuestRepository:GetDraft() or {}
    local collapsedMap = tab.editorSectionsCollapsed or {}
    local y = 0

    for _, sec in ipairs(tab.editorSections) do
        local isCollapsed = collapsedMap[sec.key] and true or false
        local arrowTex = isCollapsed and "/esoui/art/buttons/tree_closed_up.dds" or "/esoui/art/buttons/tree_open_up.dds"
        local titleColor = isCollapsed and "|cC5C29E" or "|cFFFFFF"
        local badge = GetSectionBadge(draft, sec.key)

        sec.divider:ClearAnchors()
        sec.divider:SetAnchor(TOPLEFT, tab.editorFormParent, TOPLEFT, 0, y)

        sec.headerBtn:ClearAnchors()
        sec.headerBtn:SetAnchor(TOPLEFT, tab.editorFormParent, TOPLEFT, 0, y + 8)
        sec.headerBtn:SetText(string.format(" |t22:22:%s|t %s%s|r%s", arrowTex, titleColor, Addon.Locale:Get(sec.localeKey), badge))

        local openPct = sec.openPercentage
        if openPct == nil then
            openPct = isCollapsed and 0 or 1
        end
        local currentHeight = math.floor((sec.bodyHeight or 0) * openPct + 0.5)
        if currentHeight <= 0 then
            sec.body:SetDimensions(510, 0)
            sec.body:SetHidden(true)
            y = y + 54
        else
            local extraPad = math.floor(12 * openPct + 0.5)
            sec.body:SetDimensions(510, currentHeight)
            sec.body:SetHidden(false)
            y = y + 54 + currentHeight + extraPad
        end
    end

    if tab.editorScrollChild then
        tab.editorScrollChild:SetDimensions(526, math.max(474, y + 8))
    end
end

local function SetSectionOpenPercentage(tab, sec, openPercentage)
    sec.openPercentage = openPercentage
    EditorPane.LayoutSections(tab)
end

local function SnapSectionState(sec, targetOpen)
    local timeline = sec.timeline
    if timeline and timeline:IsPlaying() then
        timeline:Stop()
    end
    sec.isOpen = targetOpen
    sec.openPercentage = targetOpen and 1 or 0
    sec.body:SetAlpha(sec.openPercentage)
end

local function AnimateSection(tab, sec, targetOpen)
    local timeline = sec.timeline
    local isHidden = (tab.panel and tab.panel:IsHidden()) or (tab.editorPane and tab.editorPane:IsHidden())
    if not timeline or isHidden or (sec.bodyHeight or 0) == 0 then
        SnapSectionState(sec, targetOpen)
        return
    end

    sec.isOpen = targetOpen
    if timeline:IsPlaying() then
        if targetOpen then
            timeline:PlayForward()
        else
            timeline:PlayBackward()
        end
    else
        local customAnim = timeline:GetFirstAnimation()
        customAnim:SetUpdateFunction(function(_, progress)
            SetSectionOpenPercentage(tab, sec, progress)
        end)
        local numAnimations = timeline:GetNumAnimations()
        for i = 2, numAnimations do
            timeline:GetAnimation(i):SetAnimatedControl(sec.body)
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

function EditorPane.ToggleSection(tab, sectionKey)
    if not sectionKey then return end
    tab.editorSectionsCollapsed = tab.editorSectionsCollapsed or {}
    local willOpen = tab.editorSectionsCollapsed[sectionKey] and true or false
    if willOpen then
        for _, sec in ipairs(tab.editorSections or {}) do
            tab.editorSectionsCollapsed[sec.key] = (sec.key ~= sectionKey)
        end
    else
        tab.editorSectionsCollapsed[sectionKey] = true
    end

    for _, sec in ipairs(tab.editorSections or {}) do
        local targetOpen = not tab.editorSectionsCollapsed[sec.key]
        if targetOpen ~= sec.isOpen then
            AnimateSection(tab, sec, targetOpen)
        end
    end
    EditorPane.LayoutSections(tab)
end

local function SyncUnfocusedEdit(editCtrl, text)
    if editCtrl and not editCtrl._focused and editCtrl:GetText() ~= text then
        editCtrl:SetText(text)
    end
end

local function RefreshEditorBaseAndArea(tab, draft)
    local FormatSelected = Addon.JournalWidgets.FormatSelected

    tab.editorHeader:SetText(Addon.Locale:Get(draft.editingQuestId and "EDITOR_EDIT_TITLE" or "EDITOR_CREATE_TITLE"))
    SyncUnfocusedEdit(tab.titleEdit, draft.title or "")
    SyncUnfocusedEdit(tab.descEdit, draft.description or "")
    SyncUnfocusedEdit(tab.recipientEdit, draft.recipientAccount or "")
    SyncUnfocusedEdit(tab.recipientCharEdit, draft.recipientCharacterName or "")
    SyncUnfocusedEdit(tab.completionEdit, draft.completionMessage or "")

    local targets = draft.targets or {}
    local summary = Addon.QuestRepository:FormatTargetsSummary(targets)
    if summary ~= "" then
        local locName = (draft.mapName and draft.mapName ~= "" and draft.mapName)
            or Addon.Locale:Get("LABEL_UNKNOWN_LOCATION")
        tab.lblCapturedTarget:SetText(Addon.Locale:Get("TARGET_CAPTURED_FORMAT", summary, locName))
        tab.btnClearTargets:SetHidden(false)
    else
        tab.lblCapturedTarget:SetText(Addon.Locale:Get("TARGET_NOT_CAPTURED"))
        tab.btnClearTargets:SetHidden(true)
    end

    if tab.btnShowMapEditor then
        local hasDraftArea = summary ~= "" and not draft.hideMapArea and draft.mapId and draft.mapId > 0 and draft.areaCenterX and draft.areaCenterY
        tab.btnShowMapEditor:SetHidden(not hasDraftArea)
    end

    local radii = Addon.Constants.AREA_RADIUS
    local curRad = draft.areaRadius or radii.MEDIUM
    tab.btnRadiusSmall:SetText(FormatSelected(Addon.Locale:Get("BTN_RADIUS_SMALL"), math.abs(curRad - radii.SMALL) < 0.005))
    tab.btnRadiusMedium:SetText(FormatSelected(Addon.Locale:Get("BTN_RADIUS_MEDIUM"), math.abs(curRad - radii.MEDIUM) < 0.005))
    tab.btnRadiusLarge:SetText(FormatSelected(Addon.Locale:Get("BTN_RADIUS_LARGE"), math.abs(curRad - radii.LARGE) < 0.005))

    if tab.btnHideMapArea then
        tab.btnHideMapArea:SetText(Addon.Locale:Get(draft.hideMapArea and "OPT_HIDE_MAP_AREA_ACTIVE" or "OPT_HIDE_MAP_AREA"))
    end
end

local function RefreshEditorTargetConfig(tab, draft)
    local FormatSelected = Addon.JournalWidgets.FormatSelected
    local targets = draft.targets or {}
    local totalTargets = #targets
    if totalTargets > 0 then
        if not tab.selectedTargetIndex or tab.selectedTargetIndex < 1 or tab.selectedTargetIndex > totalTargets then
            tab.selectedTargetIndex = totalTargets
        end
    else
        tab.selectedTargetIndex = nil
    end

    local showTargetCfg = totalTargets > 0
    local selTarget = tab.selectedTargetIndex and targets[tab.selectedTargetIndex] or nil
    local hasTargetLoc = selTarget and Addon.QuestRepository:HasTargetLocation(selTarget) or false

    if tab.btnTargetPrev then tab.btnTargetPrev:SetHidden(not showTargetCfg) end
    if tab.btnTargetNext then tab.btnTargetNext:SetHidden(not showTargetCfg) end
    if tab.btnTargetOptional then
        tab.btnTargetOptional:SetHidden(not showTargetCfg)
        if selTarget then
            local optKey = selTarget.optional and "BTN_TARGET_OPTIONAL_ON" or "BTN_TARGET_OPTIONAL_OFF"
            tab.btnTargetOptional:SetText(FormatSelected(Addon.Locale:Get(optKey), selTarget.optional == true))
        end
    end
    if tab.lblTargetCfgIndex then
        tab.lblTargetCfgIndex:SetHidden(not showTargetCfg)
        if showTargetCfg and selTarget then
            tab.lblTargetCfgIndex:SetText(Addon.Locale:Get("TARGET_CFG_HEADER", tab.selectedTargetIndex, totalTargets, selTarget.name or ""))
        end
    end
    if tab.btnCaptureTargetLoc then
        tab.btnCaptureTargetLoc:SetHidden(not showTargetCfg)
        tab.btnCaptureTargetLoc:SetText(FormatSelected(Addon.Locale:Get("BTN_CAPTURE_TARGET_LOC"), hasTargetLoc))
    end
    if tab.btnClearTargetLoc then tab.btnClearTargetLoc:SetHidden(not (showTargetCfg and hasTargetLoc)) end
    if tab.btnTargetLocRequired then
        tab.btnTargetLocRequired:SetHidden(not (showTargetCfg and hasTargetLoc))
        if selTarget then
            local reqKey = selTarget.locationRequired and "BTN_TARGET_LOC_REQUIRED" or "BTN_TARGET_LOC_OPTIONAL"
            tab.btnTargetLocRequired:SetText(FormatSelected(Addon.Locale:Get(reqKey), selTarget.locationRequired == true))
        end
    end

    local discRadii = Addon.Constants.DISCOVERY_RADIUS
    local curTargetRad = (selTarget and selTarget.radius) or discRadii.MEDIUM
    if tab.btnTargetRadSmall then
        tab.btnTargetRadSmall:SetHidden(not (showTargetCfg and hasTargetLoc))
        tab.btnTargetRadSmall:SetText(FormatSelected(Addon.Locale:Get("BTN_DISCOVERY_RAD_SMALL"), curTargetRad == discRadii.SMALL))
    end
    if tab.btnTargetRadMedium then
        tab.btnTargetRadMedium:SetHidden(not (showTargetCfg and hasTargetLoc))
        tab.btnTargetRadMedium:SetText(FormatSelected(Addon.Locale:Get("BTN_DISCOVERY_RAD_MEDIUM"), curTargetRad == discRadii.MEDIUM))
    end
    if tab.btnTargetRadLarge then
        tab.btnTargetRadLarge:SetHidden(not (showTargetCfg and hasTargetLoc))
        tab.btnTargetRadLarge:SetText(FormatSelected(Addon.Locale:Get("BTN_DISCOVERY_RAD_LARGE"), curTargetRad == discRadii.LARGE))
    end
    if tab.lblTargetLocStatus then
        tab.lblTargetLocStatus:SetHidden(not showTargetCfg)
        if showTargetCfg then
            local statusText = hasTargetLoc
                and Addon.Locale:Get("TARGET_LOC_STATUS_SET", math.floor(curTargetRad / 100))
                or Addon.Locale:Get("TARGET_LOC_STATUS_NONE")
            tab.lblTargetLocStatus:SetText(statusText)
        end
    end
    if tab.targetCustomBg then tab.targetCustomBg:SetHidden(not showTargetCfg) end
    SyncUnfocusedEdit(tab.targetCustomEdit, (selTarget and selTarget.customMessage) or "")
end

local function RefreshEditorDiscoveries(tab, draft)
    local FormatSelected = Addon.JournalWidgets.FormatSelected
    local discoveries = draft.discoveries or {}
    local totalDisc = #discoveries
    if totalDisc > 0 then
        if not tab.selectedDiscoveryIndex or tab.selectedDiscoveryIndex < 1 or tab.selectedDiscoveryIndex > totalDisc then
            tab.selectedDiscoveryIndex = totalDisc
        end
    else
        tab.selectedDiscoveryIndex = nil
    end

    local selectedPoint = tab.selectedDiscoveryIndex and discoveries[tab.selectedDiscoveryIndex] or nil
    local activeDiscMsg = selectedPoint and (selectedPoint.message or "") or (draft.discoveryMessage or "")
    SyncUnfocusedEdit(tab.discoveryMsgEdit, activeDiscMsg)

    local discRadii = Addon.Constants.DISCOVERY_RADIUS
    local curDiscRad = (selectedPoint and selectedPoint.radius) or draft.discoveryRadius or discRadii.MEDIUM
    if tab.btnDiscRadSmall then
        tab.btnDiscRadSmall:SetText(FormatSelected(Addon.Locale:Get("BTN_DISCOVERY_RAD_SMALL"), curDiscRad == discRadii.SMALL))
    end
    if tab.btnDiscRadMedium then
        tab.btnDiscRadMedium:SetText(FormatSelected(Addon.Locale:Get("BTN_DISCOVERY_RAD_MEDIUM"), curDiscRad == discRadii.MEDIUM))
    end
    if tab.btnDiscRadLarge then
        tab.btnDiscRadLarge:SetText(FormatSelected(Addon.Locale:Get("BTN_DISCOVERY_RAD_LARGE"), curDiscRad == discRadii.LARGE))
    end

    local showSelector = totalDisc > 0
    if tab.btnDiscPrev then tab.btnDiscPrev:SetHidden(not showSelector) end
    if tab.btnDiscNext then tab.btnDiscNext:SetHidden(not showSelector) end
    if tab.btnDiscRemove then tab.btnDiscRemove:SetHidden(not showSelector) end
    if tab.lblDiscIndex then
        tab.lblDiscIndex:SetHidden(not showSelector)
        if showSelector then
            tab.lblDiscIndex:SetText(Addon.Locale:Get("DISCOVERY_INDEX_FORMAT", tab.selectedDiscoveryIndex, totalDisc))
        end
    end
    if tab.lblCapturedDiscoveries then
        if totalDisc > 0 then
            local msgs = {}
            for i = 1, math.min(2, totalDisc) do table.insert(msgs, discoveries[i].message or "") end
            local preview = table.concat(msgs, " | ") .. (totalDisc > 2 and string.format(" (+%d)", totalDisc - 2) or "")
            tab.lblCapturedDiscoveries:SetText(Addon.Locale:Get("DISCOVERY_CAPTURED_FORMAT", totalDisc, preview))
        else
            tab.lblCapturedDiscoveries:SetText(Addon.Locale:Get("DISCOVERY_NONE_CAPTURED"))
        end
    end
    if tab.btnClearDiscoveries then tab.btnClearDiscoveries:SetHidden(totalDisc == 0) end
end

local function RefreshEditorDialoguesAndOptions(tab, draft)
    if tab.lblLastNpc then
        local lastNpc = Addon.QuestRepository:GetLastInteractedNpc()
        local lastText = (lastNpc and lastNpc.name and lastNpc.name ~= "")
            and Addon.Locale:Get("DIALOGUE_LAST_NPC_FORMAT", lastNpc.name)
            or Addon.Locale:Get("DIALOGUE_NO_LAST_NPC")
        tab.lblLastNpc:SetText(lastText)
    end

    local dialogues = draft.dialogues or {}
    local totalDlg = #dialogues
    local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
    if totalDlg > 0 then
        if not tab.selectedDialogueIndex or tab.selectedDialogueIndex < 1 or tab.selectedDialogueIndex > totalDlg then
            tab.selectedDialogueIndex = totalDlg
        end
    else
        tab.selectedDialogueIndex = nil
    end

    local selectedDlg = tab.selectedDialogueIndex and dialogues[tab.selectedDialogueIndex] or nil
    SyncUnfocusedEdit(tab.clueEdit, selectedDlg and (selectedDlg.clue or "") or "")
    SyncUnfocusedEdit(tab.dlgResponseEdit, selectedDlg and (selectedDlg.response or "") or "")

    if tab.lblSelectedNpc then
        if selectedDlg then
            tab.lblSelectedNpc:SetText(Addon.Locale:Get("DIALOGUE_SELECTED_NPC_FORMAT", selectedDlg.npcName or ""))
            tab.lblSelectedNpc:SetHidden(false)
        else
            tab.lblSelectedNpc:SetHidden(true)
        end
    end
    if tab.lblInputClue then
        tab.lblInputClue:SetText(selectedDlg and Addon.Locale:Get("DIALOGUE_OPTION_FOR_NPC_FORMAT", selectedDlg.npcName or "") or Addon.Locale:Get("LABEL_INPUT_CLUE"))
    end
    if tab.lblDlgResponse then
        tab.lblDlgResponse:SetText(selectedDlg and Addon.Locale:Get("DIALOGUE_RESPONSE_FOR_NPC_FORMAT", selectedDlg.npcName or "") or Addon.Locale:Get("LABEL_DIALOGUE_RESPONSE"))
    end

    local showDlgSel = totalDlg > 0
    if tab.btnDlgPrev then tab.btnDlgPrev:SetHidden(not showDlgSel) end
    if tab.btnDlgNext then tab.btnDlgNext:SetHidden(not showDlgSel) end
    if tab.btnDlgRemove then tab.btnDlgRemove:SetHidden(not showDlgSel) end
    if tab.lblDlgIndex then
        tab.lblDlgIndex:SetHidden(not showDlgSel)
        if showDlgSel then tab.lblDlgIndex:SetText(Addon.Locale:Get("DIALOGUE_INDEX_FORMAT", tab.selectedDialogueIndex, totalDlg)) end
    end
    if tab.btnClearDialogues then tab.btnClearDialogues:SetHidden(totalDlg == 0) end
    if tab.lblCapturedDialogues then
        if totalDlg > 0 then
            local names = {}
            for i, d in ipairs(dialogues) do
                local n = d.npcName or ""
                table.insert(names, (i == tab.selectedDialogueIndex) and ("|cE8D5A0[" .. n .. "]|r") or n)
            end
            tab.lblCapturedDialogues:SetText(Addon.Locale:Get("DIALOGUE_CAPTURED_FORMAT", totalDlg, maxNpcs, table.concat(names, ", ")))
        else
            tab.lblCapturedDialogues:SetText(Addon.Locale:Get("DIALOGUE_NONE_CAPTURED"))
        end
    end

    if tab.stealthComboBox then
        local targetMode = Addon.QuestDraftStore:NormalizeStealthMode(draft.stealthMode, draft.requireUndetected)
        local selected = tab.stealthComboBox:GetSelectedItemData()
        if not selected or selected.stealthMode ~= targetMode then
            tab.stealthComboBox:SetSelectedItemByEval(function(item)
                return item.stealthMode == targetMode
            end, true)
        end
    end
end

function EditorPane.Refresh(tab)
    local draft = Addon.QuestRepository:GetDraft()
    RefreshEditorBaseAndArea(tab, draft)
    RefreshEditorTargetConfig(tab, draft)
    RefreshEditorDiscoveries(tab, draft)
    RefreshEditorDialoguesAndOptions(tab, draft)

    local collapsedMap = tab.editorSectionsCollapsed or {}
    for _, sec in ipairs(tab.editorSections or {}) do
        local targetOpen = not collapsedMap[sec.key]
        if targetOpen ~= sec.isOpen then
            SnapSectionState(sec, targetOpen)
        elseif not (sec.timeline and sec.timeline:IsPlaying()) then
            sec.openPercentage = targetOpen and 1 or 0
            sec.body:SetAlpha(sec.openPercentage)
        end
    end
    EditorPane.LayoutSections(tab)
end

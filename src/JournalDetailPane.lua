-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0011-flujo-solo-correo-1-a-1-y-eliminacion-codigos-manuales.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalDetailPane = {}
local DetailPane = Addon.JournalDetailPane

local function BuildDetailHeaderAndBody(tab, pane, panelName)
    local scrollContainer = WINDOW_MANAGER.CreateControlFromVirtual
        and WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_DetailScroll", pane, "ZO_ScrollContainer")
        or nil
    local contentParent = pane
    if scrollContainer then
        scrollContainer:SetDimensions(550, 565)
        scrollContainer:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 0)
        scrollContainer:SetAnchor(BOTTOMRIGHT, pane, BOTTOMRIGHT, 0, -5)
        local scrollChild = scrollContainer.GetNamedChild and scrollContainer:GetNamedChild("ScrollChild")
        if scrollChild then
            scrollChild:SetDimensions(526, 650)
            contentParent = scrollChild
            tab.detailScrollChild = scrollChild
        end
        tab.detailScroll = scrollContainer
    end

    local titleLabel = WINDOW_MANAGER:CreateControl(panelName .. "_DetailTitle", contentParent, CT_LABEL)
    titleLabel:SetDimensions(500, 34)
    titleLabel:SetAnchor(TOPLEFT, contentParent, TOPLEFT, 0, 0)
    if titleLabel.SetFont then titleLabel:SetFont("ZoFontWinH2") end
    if titleLabel.SetColor then titleLabel:SetColor(1, 1, 1, 1) end
    if titleLabel.SetModifyTextType then
        titleLabel:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    end
    tab.detailTitle = titleLabel

    local statusLabel = WINDOW_MANAGER:CreateControl(panelName .. "_DetailStatus", contentParent, CT_LABEL)
    statusLabel:SetDimensions(500, 22)
    statusLabel:SetAnchor(TOPLEFT, titleLabel, BOTTOMLEFT, 0, 5)
    if statusLabel.SetFont then statusLabel:SetFont("ZoFontWinH4") end
    tab.detailStatus = statusLabel

    local locLabel = WINDOW_MANAGER:CreateControl(panelName .. "_DetailLoc", contentParent, CT_LABEL)
    locLabel:SetDimensions(500, 22)
    locLabel:SetAnchor(TOPLEFT, statusLabel, BOTTOMLEFT, 0, 2)
    if locLabel.SetFont then locLabel:SetFont("ZoFontWinH4") end
    if locLabel.SetColor then locLabel:SetColor(0.77, 0.76, 0.62, 1) end
    tab.detailLocation = locLabel

    local descBody = WINDOW_MANAGER:CreateControl(panelName .. "_DetailDescBody", contentParent, CT_LABEL)
    descBody:SetDimensions(495, 104)
    descBody:SetAnchor(TOPLEFT, titleLabel, BOTTOMLEFT, 25, 54)
    if descBody.SetFont then descBody:SetFont("ZoFontWinH4") end
    if descBody.SetColor then descBody:SetColor(0.77, 0.76, 0.62, 1) end
    if descBody.SetMaxLineCount then descBody:SetMaxLineCount(5) end
    tab.detailDescBody = descBody

    local divider = WINDOW_MANAGER:CreateControl(panelName .. "_DetailDivider", contentParent, CT_TEXTURE)
    divider:SetDimensions(512, 4)
    divider:SetAnchor(TOPLEFT, contentParent, TOPLEFT, 0, 210)
    divider:SetTexture(Addon.Constants.UI.DIVIDER_TEXTURE)

    local objHeader = WINDOW_MANAGER:CreateControl(panelName .. "_DetailObjHeader", contentParent, CT_LABEL)
    objHeader:SetDimensions(500, 24)
    objHeader:SetAnchor(TOPLEFT, divider, BOTTOMLEFT, 0, 10)
    if objHeader.SetFont then objHeader:SetFont("ZoFontWinH3") end
    if objHeader.SetColor then objHeader:SetColor(1, 1, 1, 1) end
    if objHeader.SetModifyTextType then
        objHeader:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    end
    objHeader:SetText(Addon.Locale:Get("LABEL_OBJECTIVE_HEADER"))
    tab.detailObjHeader = objHeader

    local objText = WINDOW_MANAGER:CreateControl(panelName .. "_DetailObjText", contentParent, CT_LABEL)
    objText:SetDimensions(495, 48)
    objText:SetAnchor(TOPLEFT, objHeader, BOTTOMLEFT, 25, 10)
    if objText.SetFont then objText:SetFont("ZoFontWinH4") end
    if objText.SetColor then objText:SetColor(1, 1, 1, 1) end
    tab.detailObjText = objText

    return contentParent
end

local function BuildDetailActionButtons(tab, contentParent, panelName)
    local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton
    local objText = tab.detailObjText

    tab.btnActivate = CreateStyledButton(panelName .. "_BtnActivate", contentParent, 160, 32, "", function()
        tab:OnToggleActiveClicked()
    end)
    tab.btnActivate:SetAnchor(TOPLEFT, objText, BOTTOMLEFT, -25, 16)

    tab.btnEdit = CreateStyledButton(panelName .. "_BtnEdit", contentParent, 160, 32, Addon.Locale:Get("BTN_EDIT"), function()
        tab:OpenEditEditor(tab.selectedQuestId)
    end)
    tab.btnEdit:SetAnchor(TOPLEFT, tab.btnActivate, TOPRIGHT, 12, 0)

    tab.btnReset = CreateStyledButton(panelName .. "_BtnReset", contentParent, 160, 32, Addon.Locale:Get("BTN_RESET"), function()
        if tab.selectedQuestId and Addon.QuestRepository:ResetQuest(tab.selectedQuestId) then
            Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_RESET"), false)
        end
    end)
    tab.btnReset:SetAnchor(TOPLEFT, tab.btnActivate, BOTTOMLEFT, 0, 10)

    tab.btnSendDirect = CreateStyledButton(panelName .. "_BtnSendDirect", contentParent, 160, 32, Addon.Locale:Get("BTN_SEND_QUEST"), function()
        tab:SendSelectedPreparedQuest()
    end)
    tab.btnSendDirect:SetAnchor(TOPLEFT, tab.btnReset, TOPRIGHT, 12, 0)
    tab.btnSendDirect:SetHidden(true)

    tab.btnAcceptOffered = CreateStyledButton(panelName .. "_BtnAcceptOffered", contentParent, 160, 32, Addon.Locale:Get("BTN_MAIL_ACCEPT"), function()
        tab:AcceptSelectedOfferedQuest()
    end)
    tab.btnAcceptOffered:SetAnchor(TOPLEFT, objText, BOTTOMLEFT, -25, 16)
    tab.btnAcceptOffered:SetHidden(true)

    tab.btnRejectOffered = CreateStyledButton(panelName .. "_BtnRejectOffered", contentParent, 160, 32, Addon.Locale:Get("BTN_MAIL_REJECT"), function()
        tab:RejectSelectedOfferedQuest()
    end)
    tab.btnRejectOffered:SetAnchor(TOPLEFT, tab.btnAcceptOffered, TOPRIGHT, 12, 0)
    tab.btnRejectOffered:SetHidden(true)
end

local function RegisterAbandonDialogAndKeybinds(tab, pane, panelName)
    local DETAIL_MODE = tab.VIEW_MODE.DETAIL

    if not ESO_Dialogs["RPQUEST_ABANDON_QUEST"] then
        ESO_Dialogs["RPQUEST_ABANDON_QUEST"] = {
            title = { text = SI_PROMPT_TITLE_ABANDON_QUEST },
            mainText = { text = SI_CONFIRM_ABANDON_QUEST },
            buttons = {
                {
                    text = SI_ABANDON_QUEST_CONFIRM,
                    callback = function(dialog)
                        local qId = dialog and dialog.data and dialog.data.questId
                        if qId and Addon.QuestRepository:DeleteQuest(qId) then
                            Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_DELETED"), false)
                        end
                    end,
                },
                { text = SI_DIALOG_CANCEL },
            },
        }
    end

    local function CanAbandonSelectedQuest()
        if tab.viewMode ~= DETAIL_MODE or not tab.selectedQuestId then
            return false
        end
        local quest = Addon.QuestRepository:GetQuestById(tab.selectedQuestId)
        return quest ~= nil and not Addon.QuestRepository:IsOfferedQuest(quest)
    end

    tab.abandonQuestDescriptor = {
        name = (GetString and SI_QUEST_JOURNAL_ABANDON) and GetString(SI_QUEST_JOURNAL_ABANDON) or Addon.Locale:Get("BTN_DELETE"),
        keybind = "UI_SHORTCUT_NEGATIVE",
        callback = function()
            if CanAbandonSelectedQuest() then
                tab:ConfirmAbandonQuest(tab.selectedQuestId)
            end
        end,
        visible = CanAbandonSelectedQuest,
        enabled = CanAbandonSelectedQuest,
    }

    tab.showOnMapDescriptor = {
        name = (GetString and SI_QUEST_JOURNAL_SHOW_ON_MAP) and GetString(SI_QUEST_JOURNAL_SHOW_ON_MAP) or Addon.Locale:Get("BTN_SHOW_ON_MAP"),
        keybind = "UI_SHORTCUT_SHOW_QUEST_ON_MAP",
        ethereal = true,
        callback = function()
            local q = Addon.QuestRepository:GetQuestById(tab.selectedQuestId)
            if q then
                Addon.WorldMapArea:ShowQuestOnMap(q)
            end
        end,
        visible = function()
            return tab.viewMode == DETAIL_MODE
                and tab.selectedQuestId ~= nil
                and Addon.QuestRepository:GetQuestById(tab.selectedQuestId) ~= nil
        end,
    }
    tab.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER or 1,
        tab.abandonQuestDescriptor,
        tab.showOnMapDescriptor,
    }

    local showOnMapBtn = WINDOW_MANAGER.CreateControlFromVirtual
        and WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_ShowOnMap", pane, "ZO_KeybindButton")
        or WINDOW_MANAGER:CreateControl(panelName .. "_ShowOnMap", pane, CT_CONTROL)
    ApplyTemplateToControl(showOnMapBtn, "ZO_KeybindButton_Keyboard_Template")
    if showOnMapBtn.SetKeybindButtonDescriptor then
        showOnMapBtn:SetKeybindButtonDescriptor(tab.showOnMapDescriptor)
    end
    showOnMapBtn:SetAnchor(TOPLEFT, pane, BOTTOMLEFT, 0, 0)
    tab.showOnMapKeybindButton = showOnMapBtn
end

function DetailPane.Build(tab, parent)
    local panelName = Addon.JournalWidgets.PANEL_NAME
    local pane = WINDOW_MANAGER:CreateControl(panelName .. "_DetailPane", parent, CT_CONTROL)
    pane:SetDimensions(550, 600)
    pane:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    pane:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
    tab.detailPane = pane

    local contentParent = BuildDetailHeaderAndBody(tab, pane, panelName)
    BuildDetailActionButtons(tab, contentParent, panelName)
    RegisterAbandonDialogAndKeybinds(tab, pane, panelName)
end

local function FormatPreparedStatusText(quest)
    local pStatus, pInfo = Addon.QuestRepository:GetPreparedQuestStatus(quest)
    local recLabel = (type(quest.recipientAccount) == "string" and quest.recipientAccount ~= "")
        and quest.recipientAccount
        or Addon.Locale:Get("LABEL_NO_RECIPIENT")

    if pStatus == "completed" and type(pInfo) == "table" then
        local who = (pInfo.senderDisplayName and pInfo.senderDisplayName ~= "") and pInfo.senderDisplayName or recLabel
        local charPart = (pInfo.characterName and pInfo.characterName ~= "") and (" (" .. pInfo.characterName .. ")") or ""
        local stealthPart = ""
        if pInfo.wasDetected == false then
            stealthPart = " " .. Addon.Locale:Get("VALIDATE_STEALTH_UNDETECTED")
        elseif pInfo.wasDetected == true then
            stealthPart = " " .. Addon.Locale:Get("VALIDATE_STEALTH_DETECTED")
        end
        return Addon.Locale:Get("PREPARED_STATUS_COMPLETED", who .. charPart .. stealthPart)
    elseif pStatus == "rejected" and type(pInfo) == "table" then
        local who = (pInfo.senderDisplayName and pInfo.senderDisplayName ~= "") and pInfo.senderDisplayName or recLabel
        local charPart = (pInfo.characterName and pInfo.characterName ~= "") and (" (" .. pInfo.characterName .. ")") or ""
        return Addon.Locale:Get("PREPARED_STATUS_REJECTED", who .. charPart)
    elseif pStatus == "sent" then
        return Addon.Locale:Get("PREPARED_STATUS_SENT", (pInfo and pInfo.recipient) or recLabel)
    end
    return Addon.Locale:Get("PREPARED_STATUS_DRAFT", recLabel)
end

local function ApplyDetailStatusAndActivateLabel(tab, selectedQuest, isOffered, isPrepared, isCurrentActive)
    local activateLabel = isPrepared and Addon.Locale:Get("BTN_TEST_QUEST") or Addon.Locale:Get("BTN_ACTIVATE")
    local deactivateLabel = isPrepared and Addon.Locale:Get("BTN_STOP_TEST") or Addon.Locale:Get("BTN_DEACTIVATE")

    if isOffered then
        local senderSuffix = (type(selectedQuest.senderDisplayName) == "string" and selectedQuest.senderDisplayName ~= "")
            and (" (" .. Addon.Locale:Get("MAIL_FROM_LABEL", selectedQuest.senderDisplayName) .. ")")
            or ""
        tab.detailStatus:SetText(Addon.Locale:Get("STATUS_PENDING") .. senderSuffix)
    elseif isPrepared then
        tab.detailStatus:SetText(FormatPreparedStatusText(selectedQuest))
        tab.btnActivate:SetText(isCurrentActive and deactivateLabel or activateLabel)
    elseif selectedQuest.failed then
        tab.detailStatus:SetText(Addon.Locale:Get("STATUS_FAILED"))
        tab.btnActivate:SetText(activateLabel)
    elseif isCurrentActive then
        tab.detailStatus:SetText(Addon.Locale:Get("STATUS_ACTIVE"))
        tab.btnActivate:SetText(deactivateLabel)
    elseif selectedQuest.completed then
        tab.detailStatus:SetText(Addon.Locale:Get("STATUS_COMPLETED"))
        tab.btnActivate:SetText(activateLabel)
    else
        tab.detailStatus:SetText(Addon.Locale:Get("STATUS_AVAILABLE"))
        tab.btnActivate:SetText(activateLabel)
    end
end

local function BuildObjectiveLines(selectedQuest, isPrepared)
    local targets = selectedQuest.targets or {}
    local objLines = {}
    local maxVisibleObjLines = 4
    local totalTargets = #targets
    local limit = (totalTargets > maxVisibleObjLines) and (maxVisibleObjLines - 1) or totalTargets
    local bullet = "|t16:16:/esoui/art/miscellaneous/bullet.dds|t "

    for i = 1, limit do
        local t = targets[i]
        local line = Addon.Locale:Get(
            "OBJECTIVE_KILL_FORMAT",
            t.name or "",
            t.currentCount or 0,
            t.requiredCount or 1
        ):gsub("^•%s*", bullet)
        if (t.currentCount or 0) >= (t.requiredCount or 1) then
            line = line .. Addon.Locale:Get("OBJECTIVE_COMPLETED_SUFFIX")
        elseif isPrepared and Addon.QuestRepository:HasTargetLocation(t) then
            local locKey = t.locationRequired and "TARGET_DETAIL_LOC_REQUIRED" or "TARGET_DETAIL_LOC_OPTIONAL"
            line = line .. Addon.Locale:Get(locKey)
        end
        objLines[i] = line
    end
    if totalTargets > maxVisibleObjLines then
        objLines[maxVisibleObjLines] = string.format("... (+%d)", totalTargets - limit)
    end

    local discoveries = selectedQuest.discoveries or {}
    if #discoveries > 0 then
        if isPrepared then
            local sumLine = Addon.Locale:Get("DISCOVERY_PREPARED_SUMMARY", #discoveries):gsub("^•%s*", bullet)
            table.insert(objLines, sumLine)
        else
            for _, d in ipairs(discoveries) do
                if d.discovered then
                    local clueLine = Addon.Locale:Get("DISCOVERY_CLUE_FORMAT", d.message or ""):gsub("^•%s*", bullet)
                    table.insert(objLines, clueLine)
                end
            end
        end
    end

    if selectedQuest.requireUndetected then
        local stealthKey = selectedQuest.wasDetected and "STEALTH_STATUS_DETECTED" or "STEALTH_STATUS_UNDETECTED"
        table.insert(objLines, bullet .. Addon.Locale:Get(stealthKey))
    end

    if isPrepared then
        if selectedQuest.clue and selectedQuest.clue ~= "" then
            local clueLine = Addon.Locale:Get("DIALOGUE_DETAIL_CLUE_FORMAT", selectedQuest.clue):gsub("^•%s*", bullet)
            table.insert(objLines, clueLine)
        end
        local dialogues = selectedQuest.dialogues or {}
        if #dialogues > 0 then
            local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
            local dlgLine = Addon.Locale:Get("DIALOGUE_DETAIL_NPCS_FORMAT", #dialogues, maxNpcs):gsub("^•%s*", bullet)
            table.insert(objLines, dlgLine)
        end
        if selectedQuest.hideMapArea then
            local mapHiddenLine = Addon.Locale:Get("DIALOGUE_DETAIL_MAP_HIDDEN"):gsub("^•%s*", bullet)
            table.insert(objLines, mapHiddenLine)
        end
    end

    return objLines
end

local function UpdateDetailActionButtons(tab, selectedQuest, isOffered, isPrepared)
    tab:UpdateShowOnMapVisibility()
    tab.btnReset:ClearAnchors()
    if tab.btnAcceptOffered then tab.btnAcceptOffered:SetHidden(not isOffered) end
    if tab.btnRejectOffered then tab.btnRejectOffered:SetHidden(not isOffered) end
    if tab.btnSendDirect then tab.btnSendDirect:SetHidden(not isPrepared) end

    if isOffered then
        tab.btnActivate:SetHidden(true)
        tab.btnEdit:SetHidden(true)
        tab.btnReset:SetHidden(true)
    elseif isPrepared then
        tab.btnActivate:SetHidden(false)
        tab.btnEdit:SetHidden(false)
        tab.btnReset:SetAnchor(TOPLEFT, tab.btnActivate, BOTTOMLEFT, 0, 10)
        tab.btnReset:SetHidden(false)
    else
        local showCompletion = selectedQuest.completed and true or false
        local showFailed = selectedQuest.failed and true or false
        tab.btnActivate:SetHidden(showCompletion or showFailed)
        tab.btnEdit:SetHidden(true)
        tab.btnReset:SetHidden(not showFailed)
        if showFailed then
            tab.btnReset:SetAnchor(TOPLEFT, tab.detailObjText, BOTTOMLEFT, -25, 16)
        end
    end

    if tab.keybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(tab.keybindStripDescriptor)
    end
end

local function RenderEmptyDetailPane(tab)
    tab.detailTitle:SetText(Addon.Locale:Get("TAB_TITLE"))
    tab.detailStatus:SetText(Addon.Locale:Get("EMPTY_QUEST_LIST"))
    tab.detailLocation:SetText("")
    tab.detailDescBody:SetText("")
    tab.detailObjHeader:SetHidden(true)
    tab.detailObjText:SetText("")
    tab.btnActivate:SetHidden(true)
    if tab.btnAcceptOffered then tab.btnAcceptOffered:SetHidden(true) end
    if tab.btnRejectOffered then tab.btnRejectOffered:SetHidden(true) end
    tab.selectedQuestId = nil
    tab:UpdateShowOnMapVisibility()
    tab.btnEdit:SetHidden(true)
    tab.btnReset:SetHidden(true)
    if tab.btnSendDirect then tab.btnSendDirect:SetHidden(true) end
    if tab.keybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(tab.keybindStripDescriptor)
    end
end

function DetailPane.Refresh(tab, selectedQuest, activeQuest)
    selectedQuest = selectedQuest or (tab.selectedQuestId and Addon.QuestRepository:GetQuestById(tab.selectedQuestId))
    activeQuest = activeQuest or Addon.QuestRepository:GetActiveQuest()

    if not selectedQuest then
        RenderEmptyDetailPane(tab)
        return
    end

    tab.detailObjHeader:SetHidden(false)
    tab.detailTitle:SetText((selectedQuest.title or ""):upper())

    local isPrepared = Addon.QuestRepository:IsPreparedQuest(selectedQuest)
    local isOffered = Addon.QuestRepository:IsOfferedQuest(selectedQuest)
    local isCurrentActive = (activeQuest and activeQuest.id == selectedQuest.id)

    ApplyDetailStatusAndActivateLabel(tab, selectedQuest, isOffered, isPrepared, isCurrentActive)

    local locText = (selectedQuest.mapName and selectedQuest.mapName ~= "" and selectedQuest.mapName)
        or Addon.Locale:Get("LABEL_UNKNOWN_LOCATION")
    tab.detailLocation:SetText(Addon.Locale:Get("LABEL_LOCATION", locText))

    local descText = (selectedQuest.description and selectedQuest.description ~= "" and selectedQuest.description)
        or Addon.Locale:Get("LABEL_NO_DESCRIPTION")
    tab.detailDescBody:SetText(descText)

    local objLines = BuildObjectiveLines(selectedQuest, isPrepared)
    tab.detailObjText:SetDimensions(495, 0)
    tab.detailObjText:SetText(table.concat(objLines, "\n"))
    local textHeight = tab.detailObjText.GetTextHeight and tab.detailObjText:GetTextHeight()
    local objHeight = textHeight and (textHeight + 16) or (#objLines * 24)
    tab.detailObjText:SetDimensions(495, math.max(32, objHeight))
    if tab.detailScrollChild and tab.detailScrollChild.SetDimensions then
        tab.detailScrollChild:SetDimensions(526, math.max(650, 540 + objHeight))
    end

    UpdateDetailActionButtons(tab, selectedQuest, isOffered, isPrepared)
end

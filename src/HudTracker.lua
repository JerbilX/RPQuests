-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.HudTracker = {}
local HudTracker = Addon.HudTracker

local TRACKER_CONTROL_NAME = "RPQuest_HudTrackerPanel"

function HudTracker:Initialize()
    if self.isInitialized or not WINDOW_MANAGER or not GuiRoot then
        return
    end

    local panel = WINDOW_MANAGER:CreateControl(TRACKER_CONTROL_NAME, GuiRoot, CT_TOPLEVELCONTROL)
    panel:SetDimensions(290, 68)
    panel:SetMouseEnabled(true)

    local parentAnchor = ZO_FocusedQuestTrackerPanel or GuiRoot
    if ZO_FocusedQuestTrackerPanel then
        panel:SetAnchor(TOPRIGHT, parentAnchor, BOTTOMRIGHT, 0, 14)
    else
        panel:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -16, 260)
    end
    panel:SetHidden(true)

    local icon = WINDOW_MANAGER:CreateControl(TRACKER_CONTROL_NAME .. "_Icon", panel, CT_TEXTURE)
    icon:SetDimensions(22, 22)
    icon:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -4, 2)
    icon:SetTexture(Addon.Constants.UI.ICON_QUEST)
    self.icon = icon

    local titleLabel = WINDOW_MANAGER:CreateControl(TRACKER_CONTROL_NAME .. "_Title", panel, CT_LABEL)
    titleLabel:SetDimensions(254, 24)
    titleLabel:SetAnchor(TOPRIGHT, icon, TOPLEFT, -4, 0)
    titleLabel:SetFont("ZoFontWinH3")
    titleLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    titleLabel:SetColor(0.91, 0.83, 0.63, 1)
    self.titleLabel = titleLabel

    local objectiveLabel = WINDOW_MANAGER:CreateControl(TRACKER_CONTROL_NAME .. "_Objective", panel, CT_LABEL)
    objectiveLabel:SetDimensions(280, 22)
    objectiveLabel:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -4, 28)
    objectiveLabel:SetFont("ZoFontGameShadow")
    objectiveLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    objectiveLabel:SetColor(1, 1, 1, 0.95)
    self.objectiveLabel = objectiveLabel

    local locationLabel = WINDOW_MANAGER:CreateControl(TRACKER_CONTROL_NAME .. "_Location", panel, CT_LABEL)
    locationLabel:SetDimensions(280, 18)
    locationLabel:SetAnchor(TOPRIGHT, objectiveLabel, BOTTOMRIGHT, 0, 2)
    locationLabel:SetFont("ZoFontGameSmall")
    locationLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    locationLabel:SetColor(0.75, 0.75, 0.75, 0.85)
    self.locationLabel = locationLabel

    panel:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside then return end
        if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then
            PlaySound(SOUNDS.DEFAULT_CLICK)
        end
        local activeQuest = Addon.QuestRepository:GetActiveQuest()
        if button == (MOUSE_BUTTON_INDEX_RIGHT or 2) then
            if activeQuest then
                Addon.WorldMapArea:ShowQuestOnMap(activeQuest)
            end
        else
            if activeQuest then
                Addon.JournalTab:SelectQuest(activeQuest.id)
            end
            Addon.JournalTab:OpenTab()
        end
    end)

    self.panel = panel

    local FragmentClass = ZO_HUDFadeSceneFragment or ZO_FadeSceneFragment
    if FragmentClass then
        self.fragment = FragmentClass:New(panel)
        if HUD_SCENE and HUD_SCENE.AddFragment then
            HUD_SCENE:AddFragment(self.fragment)
        end
        if HUD_UI_SCENE and HUD_UI_SCENE.AddFragment then
            HUD_UI_SCENE:AddFragment(self.fragment)
        end
    end

    Addon.QuestRepository:RegisterListener(function(eventType)
        if eventType ~= "DRAFT_UPDATED" and eventType ~= "DRAFT_TARGET_CAPTURED" then
            self:Refresh()
        end
    end)

    self.isInitialized = true
    self:Refresh()
end

function HudTracker:Refresh()
    if not self.panel then return end

    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    if not activeQuest or activeQuest.completed then
        if self.fragment and self.fragment.SetHiddenForReason then
            self.fragment:SetHiddenForReason("NoActiveRPQuest", true)
        end
        return
    end

    self.titleLabel:SetText(activeQuest.title or "")

    local targets = activeQuest.targets or {}
    local objLines = {}
    for _, t in ipairs(targets) do
        table.insert(objLines, Addon.Locale:Get(
            "OBJECTIVE_KILL_FORMAT",
            t.name or "",
            t.currentCount or 0,
            t.requiredCount or 1
        ))
    end
    local objHeight = math.max(22, #objLines * 20)
    self.objectiveLabel:SetDimensions(280, objHeight)
    self.objectiveLabel:SetText(table.concat(objLines, "\n"))
    self.panel:SetDimensions(290, 46 + objHeight)

    local locName = (activeQuest.mapName and activeQuest.mapName ~= "" and activeQuest.mapName)
        or Addon.Locale:Get("LABEL_UNKNOWN_LOCATION")
    self.locationLabel:SetText(locName)

    if self.fragment and self.fragment.SetHiddenForReason then
        self.fragment:SetHiddenForReason("NoActiveRPQuest", false)
    end
end

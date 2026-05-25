-- Slash commands:
-- /tl

local ADDON_NAME = ...

local function GetAddonVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "unknown"
    end

    if GetAddOnMetadata then
        return GetAddOnMetadata(ADDON_NAME, "Version") or "unknown"
    end

    return "unknown"
end

local ADDON_VERSION = GetAddonVersion()

local entries = {
    -- Achievements
    { kind = "achievement", id = 6 },          -- Level 10
    { kind = "achievement", id = 42703 },
    { kind = "achievement", id = 8 },          -- Level 30
    { kind = "achievement", id = 40864 },

    -- Items
    { kind = "item", id = 6948 },              -- Hearthstone
    { kind = "item", id = 19019 },             -- Thunderfury
    { kind = "achievement", id = 5313 },
}

local rows = {}

local FRAME_WIDTH = 450
local FRAME_HEIGHT = 420

local ROW_HEIGHT = 30
local ROW_GAP = 1
local ROW_WIDTH = 370
local ROW_LEFT_INDENT = 8

local ICON_SIZE = 22
local TICK_SIZE = 20
local TICK_SLOT_WIDTH = 24

local selectedKind = "achievement"
local RefreshList

-- Main addon window
local frame = CreateFrame("Frame", "TheList", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

-- Make Escape close this window.
table.insert(UISpecialFrames, "TheList")

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)
frame.title:SetText(
    "TheList |cffffff00v" .. ADDON_VERSION .. "|r by |cff00ffffRaynesz|r"
)

-- Bottom controls container.
frame.controls = CreateFrame("Frame", nil, frame, "BackdropTemplate")
frame.controls:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 8)
frame.controls:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 8)
frame.controls:SetHeight(46)

frame.controls:SetBackdrop({
    bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 128,
    edgeSize = 13,
    insets = {
        left = 3,
        right = 3,
        top = 3,
        bottom = 3,
    },
})
frame.controls:SetBackdropColor(0.08, 0.07, 0.055, 0.95)
frame.controls:SetBackdropBorderColor(0.45, 0.36, 0.22, 0.95)

frame.controls.topLine = frame.controls:CreateTexture(nil, "ARTWORK")
frame.controls.topLine:SetTexture("Interface\\Buttons\\WHITE8x8")
frame.controls.topLine:SetPoint("TOPLEFT", frame.controls, "TOPLEFT", 6, -5)
frame.controls.topLine:SetPoint("TOPRIGHT", frame.controls, "TOPRIGHT", -6, -5)
frame.controls.topLine:SetHeight(1)
frame.controls.topLine:SetVertexColor(0.85, 0.68, 0.36, 0.45)

-- Scrollable list area
frame.scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
frame.scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -38)
frame.scrollFrame:SetPoint("BOTTOMRIGHT", frame.controls, "TOPRIGHT", -24, 8)

frame.scrollChild = CreateFrame("Frame", nil, frame.scrollFrame)
frame.scrollChild:SetSize(ROW_WIDTH + ROW_LEFT_INDENT, 1)
frame.scrollFrame:SetScrollChild(frame.scrollChild)

-- Opens Blizzard achievement UI and jumps to achievement
local function OpenAchievementByID(achievementID)
    if not AchievementFrame then
        AchievementFrame_LoadUI()
    end

    if not AchievementFrame:IsShown() then
        AchievementFrame_ToggleAchievementFrame()
    end

    C_Timer.After(0.1, function()
        AchievementFrame_SelectAchievement(achievementID)
    end)
end

-- Returns true if the achievement is currently tracked.
local function IsAchievementTrackedByID(achievementID)
    if not achievementID then
        return false
    end

    -- Retail/newer clients
    if C_ContentTracking and C_ContentTracking.GetTrackedIDs and Enum and Enum.ContentTrackingType then
        local trackedIDs = C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement) or {}

        for _, trackedID in ipairs(trackedIDs) do
            if trackedID == achievementID then
                return true
            end
        end

        return false
    end

    -- Older fallback
    if GetTrackedAchievements then
        for i = 1, select("#", GetTrackedAchievements()) do
            local trackedID = select(i, GetTrackedAchievements())

            if trackedID == achievementID then
                return true
            end
        end
    end

    return false
end

-- Tracks or untracks the achievement in the objective tracker.
local function ToggleAchievementTracking(achievementID)
    if not achievementID then
        return
    end

    -- Retail/newer clients
    if C_ContentTracking and C_ContentTracking.StartTracking and C_ContentTracking.StopTracking
        and Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement then

        local achievementType = Enum.ContentTrackingType.Achievement
        local stopType = Enum.ContentTrackingStopType and Enum.ContentTrackingStopType.Manual or 1

        if IsAchievementTrackedByID(achievementID) then
            C_ContentTracking.StopTracking(achievementType, achievementID, stopType)
            print("|cffff5555Untracked achievement:|r " .. tostring(achievementID))
        else
            local errorCode = C_ContentTracking.StartTracking(achievementType, achievementID)

            if errorCode == nil then
                print("|cff55ff55Tracked achievement:|r " .. tostring(achievementID))
            else
                print("|cffff5555Could not track achievement.|r Error code: " .. tostring(errorCode))
            end
        end

        return
    end

    -- Older fallback
    if IsAchievementTrackedByID(achievementID) then
        if RemoveTrackedAchievement then
            RemoveTrackedAchievement(achievementID)
            print("|cffff5555Untracked achievement:|r " .. tostring(achievementID))
        else
            print("|cffff5555RemoveTrackedAchievement API unavailable.|r")
        end
    else
        if AddTrackedAchievement then
            AddTrackedAchievement(achievementID)
            print("|cff55ff55Tracked achievement:|r " .. tostring(achievementID))
        else
            print("|cffff5555AddTrackedAchievement API unavailable.|r")
        end
    end
end

-- Gets item display data safely.
-- Item data can be uncached, so this may temporarily return "Loading..."
local function GetItemDisplayInfo(itemID)
    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType,
          itemSubType, itemStackCount, itemEquipLoc, itemTexture =
          C_Item.GetItemInfo(itemID)

    if itemName then
        local r, g, b = GetItemQualityColor(itemQuality or 1)
        return itemName, itemLink, itemTexture or 134400, r, g, b
    end

    return "Loading item " .. tostring(itemID) .. "...", nil, 134400, 1, 1, 1
end

local function GetBestItemLink(itemID)
    local itemName, itemLink = C_Item.GetItemInfo(itemID)

    if itemLink then
        return itemLink
    end

    return "item:" .. tostring(itemID)
end

local function ShowPermanentItemTooltip(itemID)
    local itemLink = GetBestItemLink(itemID)

    if not itemLink then
        return
    end

    ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
    ItemRefTooltip:ClearAllPoints()
    ItemRefTooltip:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    ItemRefTooltip:SetHyperlink(itemLink)
    ItemRefTooltip:Show()
end

local function RemoveEntryAtIndex(index)
    if not index or not entries[index] then
        return
    end

    table.remove(entries, index)

    if RefreshList then
        RefreshList()
    end
end

local function ShowRemoveButton(row)
    if not row then
        return
    end

    row.icon:Hide()
    row.removeButton:Show()
end

local function HideRemoveButton(row)
    if not row then
        return
    end

    row.removeButton:Hide()
    row.removeButtonGlow:Hide()
    row.icon:Show()

    row.removeButton:ClearAllPoints()
    row.removeButton:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
end

local function UpdateRowTextWidth(row)
    local maxTextWidth = ROW_WIDTH - ICON_SIZE - 8 - TICK_SLOT_WIDTH - 8
    row.text:SetWidth(maxTextWidth)
end

local function ConfigureAchievementRow(row, entry)
    local id, name, points, completed, month, day, year, description, flags, icon =
        GetAchievementInfo(entry.id)

    row.normalIcon = icon or 134400
    row.icon:SetTexture(row.normalIcon)
    row.icon:SetVertexColor(1, 1, 1, 1)
    row.icon:Show()

    if completed then
        row.completedCheck:Show()
    else
        row.completedCheck:Hide()
    end

    if name then
        row.text:SetText(name)
        row.text:SetTextColor(1, 0.82, 0)
    else
        row.text:SetText("|cffff0000Unknown achievement ID: " .. tostring(entry.id) .. "|r")
        row.text:SetTextColor(1, 0, 0)
        row.completedCheck:Hide()
    end

    UpdateRowTextWidth(row)

    row:SetScript("OnClick", function(self, button)
        if button ~= "LeftButton" then
            return
        end

        local achievementLink = GetAchievementLink(entry.id)

        -- Ctrl-click: track/untrack achievement
        if IsControlKeyDown() then
            ToggleAchievementTracking(entry.id)
            return
        end

        -- Shift-click: link achievement in chat
        if achievementLink and IsModifiedClick("CHATLINK") then
            ChatEdit_InsertLink(achievementLink)
            return
        end

        -- Normal click: open Blizzard achievement UI
        OpenAchievementByID(entry.id)
    end)

    row:SetScript("OnEnter", function(self)
        ShowRemoveButton(self)

        GameTooltip:SetOwner(self, "ANCHOR_LEFT")

        local achievementLink = GetAchievementLink(entry.id)

        if achievementLink then
            GameTooltip:SetHyperlink(achievementLink)
        else
            GameTooltip:SetText("Achievement unavailable")
            GameTooltip:AddLine("Achievement ID: " .. tostring(entry.id), 1, 0, 0)
        end

        GameTooltip:Show()
    end)
end

local function ConfigureItemRow(row, entry)
    local itemName, itemLink, itemIcon, r, g, b = GetItemDisplayInfo(entry.id)

    row.normalIcon = itemIcon or 134400
    row.icon:SetTexture(row.normalIcon)
    row.icon:SetVertexColor(1, 1, 1, 1)
    row.icon:Show()

    row.completedCheck:Hide()

    row.text:SetText("[" .. itemName .. "]")
    row.text:SetTextColor(r, g, b)

    UpdateRowTextWidth(row)

    row:SetScript("OnClick", function(self, button)
        if button ~= "LeftButton" then
            return
        end

        local _, freshItemLink = C_Item.GetItemInfo(entry.id)
        local bestItemLink = freshItemLink or GetBestItemLink(entry.id)

        -- Ctrl-click: preview item on character
        if IsControlKeyDown() or IsModifiedClick("DRESSUP") then
            DressUpItemLink(bestItemLink)
            return
        end

        -- Shift-click: link item in chat
        if freshItemLink and IsModifiedClick("CHATLINK") then
            ChatEdit_InsertLink(freshItemLink)
            return
        end

        -- Normal click: permanent item tooltip with close button
        ShowPermanentItemTooltip(entry.id)
    end)

    row:SetScript("OnEnter", function(self)
        ShowRemoveButton(self)

        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetItemByID(entry.id)
        GameTooltip:Show()
    end)
end

local function ConfigureInvalidRow(row, entry)
    row.normalIcon = 134400
    row.icon:SetTexture(row.normalIcon)
    row.icon:SetVertexColor(1, 1, 1, 1)
    row.icon:Show()

    row.completedCheck:Hide()

    row.text:SetText("|cffff0000Unknown entry kind: " .. tostring(entry.kind) .. "|r")
    row.text:SetTextColor(1, 0, 0)

    UpdateRowTextWidth(row)

    row:SetScript("OnClick", nil)

    row:SetScript("OnEnter", function(self)
        ShowRemoveButton(self)

        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Invalid entry")
        GameTooltip:AddLine("Unknown kind: " .. tostring(entry.kind), 1, 0, 0)
        GameTooltip:Show()
    end)
end

local function CreateMixedRow(index)
    local row = CreateFrame("Button", nil, frame.scrollChild)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)

    if index == 1 then
        row:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", ROW_LEFT_INDENT, 0)
    else
        row:SetPoint("TOPLEFT", rows[index - 1], "BOTTOMLEFT", 0, -ROW_GAP)
    end

    row:RegisterForClicks("LeftButtonUp")

    -- Normal achievement/item icon.
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

    -- Glow behind the remove button.
    row.removeButtonGlow = row:CreateTexture(nil, "BACKGROUND")
    row.removeButtonGlow:SetSize(34, 34)
    row.removeButtonGlow:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
    row.removeButtonGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    row.removeButtonGlow:SetBlendMode("ADD")
    row.removeButtonGlow:SetVertexColor(1, 0.15, 0.15, 0.85)
    row.removeButtonGlow:Hide()

    -- Real animated X button.
    row.removeButton = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.removeButton:SetSize(28, 28)
    row.removeButton:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
    row.removeButton:SetFrameLevel(row:GetFrameLevel() + 8)
    row.removeButton:Hide()

    row.removeButton:SetScript("OnEnter", function(self)
        row.removeButtonGlow:Show()
        ShowRemoveButton(row)
    end)

    row.removeButton:SetScript("OnLeave", function(self)
        row.removeButtonGlow:Hide()

        if not row:IsMouseOver() then
            HideRemoveButton(row)
            GameTooltip:Hide()
        end
    end)

    row.removeButton:SetScript("OnMouseDown", function(self)
        self:ClearAllPoints()
        self:SetPoint("CENTER", row.icon, "CENTER", 1, -1)
        row.removeButtonGlow:SetAlpha(1)
    end)

    row.removeButton:SetScript("OnMouseUp", function(self)
        self:ClearAllPoints()
        self:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
        row.removeButtonGlow:SetAlpha(0.85)
    end)

    row.removeButton:SetScript("OnClick", function(self)
        RemoveEntryAtIndex(row.index)
    end)

    -- Tick slot. This slot always exists so names line up.
    row.completedCheck = row:CreateTexture(nil, "OVERLAY")
    row.completedCheck:SetSize(TICK_SIZE, TICK_SIZE)
    row.completedCheck:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)
    row.completedCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    row.completedCheck:SetVertexColor(0.25, 1, 0.25, 1)
    row.completedCheck:Hide()

    -- Text starts after the reserved tick slot.
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 8 + TICK_SLOT_WIDTH, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("MIDDLE")
    row.text:SetWordWrap(true)

    if row.text.SetMaxLines then
        row.text:SetMaxLines(2)
    end

    row:SetScript("OnLeave", function(self)
        if not self.removeButton:IsMouseOver() then
            HideRemoveButton(self)
            GameTooltip:Hide()
        end
    end)

    rows[index] = row
    return row
end

local function ConfigureRow(row, entry, index)
    row.entry = entry
    row.index = index

    if entry.kind == "achievement" then
        ConfigureAchievementRow(row, entry)
    elseif entry.kind == "item" then
        ConfigureItemRow(row, entry)
    else
        ConfigureInvalidRow(row, entry)
    end

    if row:IsMouseOver() then
        ShowRemoveButton(row)
    else
        HideRemoveButton(row)
    end
end

RefreshList = function()
    for index, entry in ipairs(entries) do
        local row = rows[index] or CreateMixedRow(index)
        ConfigureRow(row, entry, index)
        row:Show()
    end

    for index = #entries + 1, #rows do
        rows[index]:Hide()
    end

    local contentHeight = math.max(1, (#entries * ROW_HEIGHT) + math.max(0, (#entries - 1) * ROW_GAP))
    frame.scrollChild:SetHeight(contentHeight)
    frame.scrollChild:SetWidth(ROW_WIDTH + ROW_LEFT_INDENT)
end

local function AddEntryFromControls()
    local rawID = frame.idEditBox:GetText()
    local id = tonumber(rawID)

    if not id then
        print("|cffff5555Invalid ID.|r")
        return
    end

    table.insert(entries, {
        kind = selectedKind,
        id = id,
    })

    frame.idEditBox:SetText("")
    frame.idEditBox:ClearFocus()

    RefreshList()
end

-- Bottom controls

frame.idLabel = frame.controls:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.idLabel:SetPoint("LEFT", frame.controls, "LEFT", 16, -1)
frame.idLabel:SetText("ID:")

frame.idEditBox = CreateFrame("EditBox", nil, frame.controls, "InputBoxTemplate")
frame.idEditBox:SetSize(95, 24)
frame.idEditBox:SetPoint("LEFT", frame.idLabel, "RIGHT", 8, 0)
frame.idEditBox:SetAutoFocus(false)
frame.idEditBox:SetNumeric(true)

frame.idEditBox:SetScript("OnEnterPressed", function()
    AddEntryFromControls()
end)

frame.idEditBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)

frame.kindDropdown = CreateFrame("Frame", "TheListKindDropdown", frame.controls, "UIDropDownMenuTemplate")
frame.kindDropdown:SetPoint("LEFT", frame.idEditBox, "RIGHT", 0, -2)

UIDropDownMenu_SetWidth(frame.kindDropdown, 115)
UIDropDownMenu_SetText(frame.kindDropdown, "Achievement")

UIDropDownMenu_Initialize(frame.kindDropdown, function(self, level)
    local achievementInfo = UIDropDownMenu_CreateInfo()
    achievementInfo.text = "Achievement"
    achievementInfo.checked = selectedKind == "achievement"
    achievementInfo.func = function()
        selectedKind = "achievement"
        UIDropDownMenu_SetText(frame.kindDropdown, "Achievement")
    end
    UIDropDownMenu_AddButton(achievementInfo, level)

    local itemInfo = UIDropDownMenu_CreateInfo()
    itemInfo.text = "Item"
    itemInfo.checked = selectedKind == "item"
    itemInfo.func = function()
        selectedKind = "item"
        UIDropDownMenu_SetText(frame.kindDropdown, "Item")
    end
    UIDropDownMenu_AddButton(itemInfo, level)
end)

frame.addButton = CreateFrame("Button", nil, frame.controls, "UIPanelButtonTemplate")
frame.addButton:SetSize(58, 24)
frame.addButton:SetPoint("RIGHT", frame.controls, "RIGHT", -16, 1)
frame.addButton:SetText("Add")
frame.addButton:SetScript("OnClick", function()
    AddEntryFromControls()
end)

RefreshList()

-- Refresh item rows when uncached item data becomes available
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

eventFrame:SetScript("OnEvent", function()
    RefreshList()
end)

-- Slash commands
SLASH_THELIST1 = "/tl"

SlashCmdList["THELIST"] = function()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end
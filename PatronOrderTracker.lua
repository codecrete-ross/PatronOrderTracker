local ADDON_NAME = "PatronOrderTracker"
local POT = {}

POT.shoppingListName = nil
POT.trackButton = nil
POT.clearButton = nil
POT.configButton = nil
POT.configFrame = nil
POT.initialized = false
POT.debug = false

-- ---------------------------------------------------------------------------
-- Event bootstrap
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == ADDON_NAME then
            eventFrame:UnregisterEvent("ADDON_LOADED")
            if not PatronOrderTrackerDB then PatronOrderTrackerDB = {} end
            eventFrame:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
            eventFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
        end
    elseif event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        if ProfessionsFrame and ProfessionsFrame.OrdersPage then
            POT:InjectButtons()
        end
    elseif event == "TRADE_SKILL_LIST_UPDATE" then
        POT:RefreshCostOverlays()
    end
end)

-- ---------------------------------------------------------------------------
-- Chat helper
-- ---------------------------------------------------------------------------

local function PrintMsg(msg)
    print("|cff00ccff[PatronOrderTracker]|r " .. msg)
end

local function DebugMsg(msg)
    if POT.debug then
        print("|cff888888[POT Debug]|r " .. msg)
    end
end

local function BuildCustomerProvidedMap(order)
    local map = {}
    if order.reagents then
        for _, r in ipairs(order.reagents) do
            local qty = r.reagentInfo and r.reagentInfo.quantity or 0
            map[r.slotIndex] = (map[r.slotIndex] or 0) + qty
        end
    end
    return map
end

local PROF_ABBR = {
    ["Alchemy"] = "Alch.", ["Blacksmithing"] = "BS", ["Enchanting"] = "Ench.",
    ["Engineering"] = "Eng.", ["Inscription"] = "Insc.", ["Jewelcrafting"] = "JC",
    ["Leatherworking"] = "LW", ["Tailoring"] = "Tail.",
}

-- ---------------------------------------------------------------------------
-- Copyable dump dialog (SimC-style)
-- ---------------------------------------------------------------------------

local REAGENT_TYPE_NAMES = {
    [Enum.CraftingReagentType.Basic] = "Basic",
    [Enum.CraftingReagentType.Modifying] = "Modifying",
    [Enum.CraftingReagentType.Finishing] = "Finishing",
    [Enum.CraftingReagentType.Automatic] = "Automatic",
}

local REAGENT_STATE_NAMES = { [0] = "All", [1] = "Some", [2] = "None" }

local function QualityStars(minQuality)
    if not minQuality or minQuality <= 0 then return "Any" end
    local stars = {}
    for i = 1, minQuality do stars[i] = "\226\152\133" end -- ★
    return table.concat(stars)
end

function POT:ShowDumpDialog(text)
    if not POT.dumpFrame then
        local f = CreateFrame("Frame", "PatronOrderTrackerDumpFrame", UIParent, "BackdropTemplate")
        f:SetSize(620, 450)
        f:SetPoint("CENTER")
        f:SetBackdrop({
            bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
            edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:EnableKeyboard(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                self:Hide()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText("Patron Order Tracker - Diagnostic Dump")

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)

        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 16, -40)
        sf:SetPoint("BOTTOMRIGHT", -34, 16)

        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject(GameFontHighlightSmall)
        eb:SetWidth(560)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)

        f.editBox = eb
        POT.dumpFrame = f
    end

    POT.dumpFrame.editBox:SetText(text)
    POT.dumpFrame:Show()
    POT.dumpFrame.editBox:HighlightText()
    POT.dumpFrame.editBox:SetFocus()
end

function POT:BuildDumpString()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    add("== Patron Order Tracker Dump ==")
    add("")

    local profInfo = C_TradeSkillUI.GetChildProfessionInfo()
    local profName = profInfo and (profInfo.parentProfessionName or profInfo.professionName) or "Unknown"
    add("Profession: " .. profName)

    local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
    local tabType = ordersPage and ordersPage.orderType
    local tabName = "Unknown"
    if tabType == Enum.CraftingOrderType.Npc then tabName = "Npc (Patron Orders)"
    elseif tabType == Enum.CraftingOrderType.Public then tabName = "Public"
    elseif tabType == Enum.CraftingOrderType.Guild then tabName = "Guild"
    elseif tabType == Enum.CraftingOrderType.Personal then tabName = "Personal"
    end
    add("Active Tab: " .. tabName)

    local flatOrders = C_CraftingOrders.GetCrafterOrders() or {}
    local buckets = C_CraftingOrders.GetCrafterBuckets() or {}
    add(string.format("Data: %d flat orders, %d buckets", #flatOrders, #buckets))
    add("")

    local npcOrders = {}
    for _, order in ipairs(flatOrders) do
        if order.orderType == Enum.CraftingOrderType.Npc then
            npcOrders[#npcOrders + 1] = order
        end
    end

    if #npcOrders == 0 and #buckets == 0 then
        add("No patron order data loaded. Browse the Patron Orders tab first.")
        return table.concat(lines, "\n")
    end

    local orderList = #npcOrders > 0 and npcOrders or nil
    if orderList then
        add(string.format("=== %d Patron Orders (Flat) ===", #orderList))
        add("")
        for i, order in ipairs(orderList) do
            local itemName = C_Item.GetItemNameByID(order.itemID) or ("itemID:" .. tostring(order.itemID))
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(order.spellID)
            local learned = recipeInfo and recipeInfo.learned

            add(string.format("--- Order %d ---", i))
            add("Item: " .. itemName)
            add(string.format("Recipe: spellID %d | Learned: %s", order.spellID, learned and "Yes" or "No"))
            add("Quality Requested: " .. QualityStars(order.minQuality))
            add("Reagent State: " .. (REAGENT_STATE_NAMES[order.reagentState] or tostring(order.reagentState)))
            add("isRecraft: " .. tostring(order.isRecraft))

            local schematic = C_TradeSkillUI.GetRecipeSchematic(order.spellID, order.isRecraft)
            if schematic and schematic.reagentSlotSchematics then
                local customerProvided = BuildCustomerProvidedMap(order)

                add("Reagents:")
                for _, slot in ipairs(schematic.reagentSlotSchematics) do
                    local typeName = REAGENT_TYPE_NAMES[slot.reagentType] or "?"
                    local reagentItemID = slot.reagents and slot.reagents[1] and slot.reagents[1].itemID
                    local reagentName = reagentItemID and C_Item.GetItemNameByID(reagentItemID) or ("itemID:" .. tostring(reagentItemID or "?"))
                    local needed = slot.quantityRequired or 0
                    local custQty = customerProvided[slot.slotIndex] or 0
                    local delta = needed - custQty

                    if slot.reagentType == Enum.CraftingReagentType.Basic then
                        if delta > 0 then
                            add(string.format("  [%s] %s: need %d, customer %d -> PLAYER SUPPLIES %d",
                                typeName, reagentName, needed, custQty, delta))
                        else
                            add(string.format("  [%s] %s: need %d, customer %d -> covered",
                                typeName, reagentName, needed, custQty))
                        end
                    else
                        add(string.format("  [%s] %s: need %d (optional, not included)",
                            typeName, reagentName, needed))
                    end
                end
            else
                add("Reagents: (schematic unavailable)")
            end
            add("")
        end
    else
        add(string.format("=== %d Recipe Buckets ===", #buckets))
        add("(Per-order reagent detail unavailable in bucketed mode)")
        add("")
        for i, bucket in ipairs(buckets) do
            local itemName = C_Item.GetItemNameByID(bucket.itemID) or ("itemID:" .. tostring(bucket.itemID))
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(bucket.spellID)
            local learned = recipeInfo and recipeInfo.learned
            add(string.format("--- Bucket %d ---", i))
            add("Item: " .. itemName)
            add(string.format("Recipe: spellID %d | Learned: %s | Available: %d",
                bucket.spellID, learned and "Yes" or "No", bucket.numAvailable or 0))
            add("")
        end
    end

    if POT.shoppingListName then
        add("Shopping list: " .. POT.shoppingListName)
    end

    add("")
    add("=== Visible Row UI State ===")
    local browseFrame = ProfessionsFrame and ProfessionsFrame.OrdersPage
                        and ProfessionsFrame.OrdersPage.BrowseFrame
    if browseFrame and browseFrame.OrderList and browseFrame.OrderList.ScrollBox then
        local rowIdx = 0
        browseFrame.OrderList.ScrollBox:ForEachFrame(function(row)
            rowIdx = rowIdx + 1
            -- Read what's actually rendered in the name cell
            local nameCell = nil
            local nameCellText = "(no name cell)"
            for i = 1, row:GetNumChildren() do
                local child = select(i, row:GetChildren())
                if child.Icon then
                    nameCell = child
                    -- Find the text widget inside the name cell
                    for j = 1, child:GetNumRegions() do
                        local region = select(j, child:GetRegions())
                        if region.GetText and region:GetText() then
                            nameCellText = region:GetText()
                            break
                        end
                    end
                    break
                end
            end

            -- Read elementData
            local ed = row:GetElementData()
            local order = ed and ed.option
            local edItemName = order and C_Item.GetItemNameByID(order.itemID) or "(no elementData)"

            add(string.format("Row %d:", rowIdx))
            add(string.format("  Name cell renders: %s", nameCellText))
            add(string.format("  elementData says:  %s", edItemName))
            if order then
                add(string.format("  order.spellID: %s", tostring(order.spellID)))
                local ri = C_TradeSkillUI.GetRecipeInfo(order.spellID)
                add(string.format("  GetRecipeInfo now: learned=%s", ri and tostring(ri.learned) or "nil"))
            end
            add(string.format("  overlay text: %s", row.potCostText and row.potCostText:GetText() or "(none)"))
            add(string.format("  overlay shown: %s", row.potCostText and tostring(row.potCostText:IsShown()) or "N/A"))
            add("")
        end)
    else
        add("ScrollBox not available")
    end

    return table.concat(lines, "\n")
end

-- ---------------------------------------------------------------------------
-- Settings popup
-- ---------------------------------------------------------------------------

function POT:SaveCeilingSetting(text)
    local gold = tonumber(text)
    local prev = PatronOrderTrackerDB.priceCeiling
    if not gold or gold <= 0 then
        PatronOrderTrackerDB.priceCeiling = nil
        if prev then PrintMsg("Order budget removed.") end
    else
        local newCeiling = math.floor(gold * 10000)
        PatronOrderTrackerDB.priceCeiling = newCeiling
        if newCeiling ~= prev then
            PrintMsg(string.format("Order budget set to %s.",
                GetCoinTextureString(newCeiling)))
        end
    end
    POT:RefreshCostOverlays()
end

function POT:CreateConfigPopup()
    if POT.configFrame then return end

    local f = CreateFrame("Frame", "PatronOrderTrackerConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(300, 225)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:EnableKeyboard(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Patron Order Tracker Settings")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 20, -50)
    label:SetText("Order budget:")

    local input = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    input:SetSize(100, 20)
    input:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 4, -8)
    input:SetAutoFocus(false)
    input:SetMaxLetters(10)
    input:SetNumeric(true)
    input:SetJustifyH("RIGHT")
    input:SetTextInsets(5, 8, 0, 0)

    local goldLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    goldLabel:SetPoint("LEFT", input, "RIGHT", 6, 0)
    goldLabel:SetText("|TInterface\\MoneyFrame\\UI-GoldIcon:0|t")

    local resetButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetButton:SetSize(60, 20)
    resetButton:SetPoint("LEFT", goldLabel, "RIGHT", 8, 0)
    resetButton:SetText("Clear")
    resetButton:SetScript("OnClick", function()
        input:SetText("")
        input:ClearFocus()
        POT:SaveCeilingSetting("")
    end)

    local help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", input, "BOTTOMLEFT", -4, -12)
    help:SetPoint("RIGHT", f, "RIGHT", -20, 0)
    help:SetJustifyH("LEFT")
    help:SetText("|cff888888Orders that cost more than this will be excluded.\nRequires a recent AH scan for accurate prices.|r")

    local showCostsCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    showCostsCheck:SetPoint("TOPLEFT", help, "BOTTOMLEFT", -2, -6)
    showCostsCheck.text = showCostsCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showCostsCheck.text:SetPoint("LEFT", showCostsCheck, "RIGHT", 2, 0)
    showCostsCheck.text:SetText("Show material costs in order list")
    showCostsCheck:SetScript("OnClick", function(self)
        PatronOrderTrackerDB.showCostOverlay = self:GetChecked()
        POT:RefreshCostOverlays()
    end)

    local doneButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    doneButton:SetSize(100, 22)
    doneButton:SetPoint("BOTTOM", f, "BOTTOM", 0, 16)
    doneButton:SetText("Done")
    doneButton:SetScript("OnClick", function()
        POT:SaveCeilingSetting(input:GetText())
        input:ClearFocus()
        f:Hide()
    end)
    input:SetScript("OnEnterPressed", function(self)
        POT:SaveCeilingSetting(self:GetText())
        self:ClearFocus()
        f:Hide()
    end)
    input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)

    f:SetScript("OnShow", function()
        local ceiling = PatronOrderTrackerDB and PatronOrderTrackerDB.priceCeiling
        if ceiling and ceiling > 0 then
            input:SetText(tostring(math.floor(ceiling / 10000)))
        else
            input:SetText("")
        end
        showCostsCheck:SetChecked(PatronOrderTrackerDB.showCostOverlay ~= false)
    end)

    f.input = input
    POT.configFrame = f
    f:Hide()
end

function POT:ToggleConfigPopup()
    POT:CreateConfigPopup()
    if POT.configFrame:IsShown() then
        POT.configFrame:Hide()
    else
        POT.configFrame:Show()
    end
end

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------

SLASH_PATRONORDERTRACKER1 = "/pot"
SlashCmdList["PATRONORDERTRACKER"] = function(input)
    local cmd = strtrim(input):lower()
    if cmd == "debug" then
        POT.debug = not POT.debug
        PrintMsg("Debug mode " .. (POT.debug and "ON" or "OFF"))
    elseif cmd == "dump" then
        POT:ShowDumpDialog(POT:BuildDumpString())
    else
        PrintMsg("Commands: /pot debug | /pot dump")
    end
end

-- ---------------------------------------------------------------------------
-- UI injection
-- ---------------------------------------------------------------------------

function POT:InjectButtons()
    if not Auctionator or not Auctionator.API or not Auctionator.API.v1 then return end

    if POT.initialized then
        POT:UpdateButtonState()
        return
    end

    local browseFrame = ProfessionsFrame.OrdersPage.BrowseFrame
    if not browseFrame then return end

    POT.trackButton = CreateFrame("Button", nil, browseFrame, "UIPanelButtonTemplate")
    POT.trackButton:SetSize(220, 22)
    POT.trackButton:SetText("Create Auctionator Shopping List")
    POT.trackButton:SetPoint("TOPRIGHT", browseFrame, "TOPRIGHT", -35, -32)
    POT.trackButton:SetScript("OnClick", function() POT:ScanAndCreateList() end)
    POT.trackButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Create an Auctionator shopping list with only the reagents you need to supply.", 1, 1, 1)
        GameTooltip:Show()
    end)
    POT.trackButton:SetScript("OnLeave", GameTooltip_Hide)

    POT.configButton = CreateFrame("Button", nil, browseFrame, "UIPanelButtonTemplate")
    POT.configButton:SetSize(26, 22)
    POT.configButton:SetPoint("TOPRIGHT", browseFrame, "TOPRIGHT", -8, -32)
    POT.configButton:SetText("")
    local configIcon = POT.configButton:CreateTexture(nil, "ARTWORK")
    configIcon:SetSize(14, 14)
    configIcon:SetPoint("CENTER")
    configIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    POT.configButton:SetScript("OnClick", function() POT:ToggleConfigPopup() end)
    POT.configButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Patron Order Tracker Settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    POT.configButton:SetScript("OnLeave", GameTooltip_Hide)

    POT.clearButton = CreateFrame("Button", nil, browseFrame, "UIPanelButtonTemplate")
    POT.clearButton:SetSize(210, 22)
    POT.clearButton:SetText("Clear Auctionator Shopping List")
    POT.clearButton:SetPoint("RIGHT", POT.trackButton, "LEFT", -5, 0)
    POT.clearButton:SetScript("OnClick", function() POT:ClearShoppingList() end)

    hooksecurefunc(ProfessionsFrame.OrdersPage, "SetCraftingOrderType", function()
        POT:UpdateButtonState()
        POT:RefreshCostOverlays()
    end)

    browseFrame:HookScript("OnHide", function()
        if POT.trackButton then POT.trackButton:Hide() end
        if POT.configButton then POT.configButton:Hide() end
        if POT.clearButton then POT.clearButton:Hide() end
    end)
    browseFrame:HookScript("OnShow", function()
        POT:UpdateButtonState()
    end)

    POT:HookOrderRows(browseFrame)

    pcall(function()
        Auctionator.API.v1.RegisterForDBUpdate(ADDON_NAME, function()
            POT:RefreshCostOverlays()
        end)
    end)

    POT.initialized = true
    POT:UpdateButtonState()
end

-- ---------------------------------------------------------------------------
-- Order row cost overlay
-- ---------------------------------------------------------------------------

local function FindNameCell(row)
    for i = 1, row:GetNumChildren() do
        local child = select(i, row:GetChildren())
        if child.Icon then return child end
    end
end

local function UpdateRowCostOverlay(row, elementData)
    local nameCell = FindNameCell(row)
    if not nameCell then
        if not row.potRetryFrame then
            row.potRetryFrame = CreateFrame("Frame")
        end
        row.potRetryFrame:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            UpdateRowCostOverlay(row, elementData)
        end)
        return
    end
    if not row.potCostText then
        row.potCostText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    end
    row.potCostText:ClearAllPoints()
    row.potCostText:SetPoint("RIGHT", nameCell, "RIGHT", -4, 0)

    if PatronOrderTrackerDB.showCostOverlay == false then
        row.potCostText:Hide()
        return
    end

    local order = elementData and elementData.option
    if not order or order.orderType ~= Enum.CraftingOrderType.Npc then
        row.potCostText:Hide()
        return
    end

    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(order.spellID)
    if not recipeInfo then
        row.potCostText:Hide()
        return
    end
    if not recipeInfo.learned then
        row.potCostText:SetText("|cff888888(not learned)|r")
        row.potCostText:Show()
        return
    end

    local customerProvided = BuildCustomerProvidedMap(order)
    local cost, hasMissing = POT:CalculateOrderCost(order.spellID, order.isRecraft, customerProvided)

    if not cost and hasMissing then
        row.potCostText:SetText("|cff888888No price data|r")
        row.potCostText:Show()
        return
    end

    local ceiling = PatronOrderTrackerDB.priceCeiling
    local costStr = GetCoinTextureString(cost)
    if ceiling then
        if cost > ceiling then
            row.potCostText:SetText("|cffff4444" .. costStr .. "|r")
        else
            row.potCostText:SetText("|cff00ff00" .. costStr .. "|r")
        end
    else
        row.potCostText:SetText(costStr)
    end
    row.potCostText:Show()
end

function POT:RefreshCostOverlays()
    local browseFrame = ProfessionsFrame and ProfessionsFrame.OrdersPage
                        and ProfessionsFrame.OrdersPage.BrowseFrame
    if not browseFrame or not browseFrame.OrderList or not browseFrame.OrderList.ScrollBox then return end
    browseFrame.OrderList.ScrollBox:ForEachFrame(function(row)
        if row.potCostText and row:GetElementData() then
            UpdateRowCostOverlay(row, row:GetElementData())
        end
    end)
end

function POT:HookOrderRows(browseFrame)
    local orderList = browseFrame.OrderList
    if not orderList or not orderList.ScrollBox then return end

    -- Hook via ScrollBox acquired-frame callback
    local scrollBox = orderList.ScrollBox
    if scrollBox.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event then
        pcall(function()
            scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, function(_, row, elementData)
                UpdateRowCostOverlay(row, elementData)
            end, POT)
        end)
        DebugMsg("Hooked order rows via ScrollBox callback")
    end

    -- Also hook Init for in-place row data updates (tab switches, recycling)
    if ProfessionsCrafterOrderListElementMixin and ProfessionsCrafterOrderListElementMixin.Init then
        hooksecurefunc(ProfessionsCrafterOrderListElementMixin, "Init", function(self, elementData)
            UpdateRowCostOverlay(self, elementData)
        end)
        DebugMsg("Hooked order rows via mixin Init")
    end
end

function POT:UpdateButtonState()
    local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
    if not ordersPage then return end

    local isNpcTab = (ordersPage.orderType == Enum.CraftingOrderType.Npc)
    local browseVisible = ordersPage.BrowseFrame and ordersPage.BrowseFrame:IsShown()

    if POT.trackButton then
        POT.trackButton:SetShown(isNpcTab and browseVisible)
    end
    if POT.configButton then
        POT.configButton:SetShown(isNpcTab and browseVisible)
    end
    if POT.clearButton then
        local listExists = false
        if isNpcTab and browseVisible and Auctionator and Auctionator.Shopping then
            local profInfo = C_TradeSkillUI.GetChildProfessionInfo()
            local profName = profInfo and (profInfo.parentProfessionName or profInfo.professionName)
            if profName then
                local playerName, playerRealm = UnitFullName("player")
                local charName = playerName .. "-" .. (playerRealm or GetRealmName())
                local profAbbr = PROF_ABBR[profName] or profName
                local name = "POT - " .. profAbbr .. " (" .. charName .. ")"
                local idx = Auctionator.Shopping.ListManager:GetIndexForName(name)
                listExists = (idx and idx ~= false) and true or false
            end
        end
        POT.clearButton:SetShown(listExists)
    end
end

-- ---------------------------------------------------------------------------
-- Core scan
-- ---------------------------------------------------------------------------

function POT:ScanAndCreateList()
    local flatOrders = C_CraftingOrders.GetCrafterOrders() or {}
    local buckets = C_CraftingOrders.GetCrafterBuckets() or {}

    DebugMsg(string.format("GetCrafterOrders returned %d, GetCrafterBuckets returned %d", #flatOrders, #buckets))

    local npcOrders = {}
    for _, order in ipairs(flatOrders) do
        DebugMsg(string.format("  Flat order: spellID=%s type=%s",
            tostring(order.spellID), tostring(order.orderType)))
        if order.orderType == Enum.CraftingOrderType.Npc then
            table.insert(npcOrders, order)
        end
    end

    local useBuckets = (#npcOrders == 0 and #buckets > 0)
    DebugMsg(string.format("Npc flat orders: %d, useBuckets: %s", #npcOrders, tostring(useBuckets)))

    if #npcOrders == 0 and #buckets == 0 then
        PrintMsg("No patron orders loaded. Browse the Patron Orders tab first.")
        return
    end

    local profInfo = C_TradeSkillUI.GetChildProfessionInfo()
    local profName = profInfo and (profInfo.parentProfessionName or profInfo.professionName) or "Unknown"
    local playerName, playerRealm = UnitFullName("player")
    local charName = playerName .. "-" .. (playerRealm or GetRealmName())
    local profAbbr = PROF_ABBR[profName] or profName
    POT.shoppingListName = "POT - " .. profAbbr .. " (" .. charName .. ")"

    local scannedCount = 0
    local skippedCount = 0
    local ceilingSkippedCount = 0
    local missingPriceCount = 0
    local reagentTotals = {}
    local ceiling = PatronOrderTrackerDB.priceCeiling

    if useBuckets then
        for i, bucket in ipairs(buckets) do
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(bucket.spellID)
            DebugMsg(string.format("  Bucket[%d]: spellID=%s learned=%s numAvailable=%s",
                i, tostring(bucket.spellID),
                tostring(recipeInfo and recipeInfo.learned),
                tostring(bucket.numAvailable)))
            if recipeInfo and recipeInfo.learned then
                if ceiling then
                    local cost, hasMissing = POT:CalculateOrderCost(bucket.spellID, false, nil)
                    if hasMissing then missingPriceCount = missingPriceCount + 1 end
                    if cost and cost > ceiling then
                        ceilingSkippedCount = ceilingSkippedCount + (bucket.numAvailable or 1)
                        DebugMsg(string.format("  Bucket[%d]: cost %s exceeds ceiling, skipping %d orders",
                            i, GetCoinTextureString(cost), bucket.numAvailable or 1))
                    else
                        POT:CalculateSchematicReagents(bucket.spellID, false, bucket.numAvailable, reagentTotals)
                        scannedCount = scannedCount + 1
                    end
                else
                    POT:CalculateSchematicReagents(bucket.spellID, false, bucket.numAvailable, reagentTotals)
                    scannedCount = scannedCount + 1
                end
            else
                skippedCount = skippedCount + 1
            end
        end
        PrintMsg("Estimated reagent counts. Individual order details not loaded.")
    else
        for i, order in ipairs(npcOrders) do
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(order.spellID)
            local learned = recipeInfo and recipeInfo.learned
            DebugMsg(string.format("  Order[%d]: spellID=%s learned=%s recraft=%s reagents=%d",
                i, tostring(order.spellID), tostring(learned),
                tostring(order.isRecraft), order.reagents and #order.reagents or 0))
            if learned then
                if ceiling then
                    local customerProvided = BuildCustomerProvidedMap(order)
                    local cost, hasMissing = POT:CalculateOrderCost(order.spellID, order.isRecraft, customerProvided)
                    if hasMissing then missingPriceCount = missingPriceCount + 1 end
                    if cost and cost > ceiling then
                        ceilingSkippedCount = ceilingSkippedCount + 1
                        DebugMsg(string.format("  Order[%d]: cost %s exceeds ceiling, skipping",
                            i, GetCoinTextureString(cost)))
                    else
                        POT:CalculatePlayerReagents(order, reagentTotals)
                        scannedCount = scannedCount + 1
                    end
                else
                    POT:CalculatePlayerReagents(order, reagentTotals)
                    scannedCount = scannedCount + 1
                end
            else
                skippedCount = skippedCount + 1
            end
        end
    end

    if scannedCount == 0 then
        if ceilingSkippedCount > 0 and skippedCount == 0 then
            PrintMsg(string.format("No shopping list created. All orders cost more than the %s order budget.",
                GetCoinTextureString(PatronOrderTrackerDB.priceCeiling)))
        elseif skippedCount > 0 and ceilingSkippedCount == 0 then
            PrintMsg("No shopping list created. All recipes are unlearned.")
        elseif skippedCount > 0 and ceilingSkippedCount > 0 then
            PrintMsg(string.format("No shopping list created. %d for unlearned recipes, %d over the %s order budget.",
                skippedCount, ceilingSkippedCount,
                GetCoinTextureString(PatronOrderTrackerDB.priceCeiling)))
        else
            PrintMsg("No shopping list created. No fulfillable patron orders found.")
        end
        return
    end

    POT:CreateShoppingList(reagentTotals, scannedCount, skippedCount, ceilingSkippedCount, missingPriceCount)
    POT:UpdateButtonState()
end

-- ---------------------------------------------------------------------------
-- Reagent delta: flat orders (full data)
-- ---------------------------------------------------------------------------

function POT:CalculatePlayerReagents(order, totals)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(order.spellID, order.isRecraft)
    if not schematic or not schematic.reagentSlotSchematics then return end

    local customerProvided = BuildCustomerProvidedMap(order)

    for _, slotSchematic in ipairs(schematic.reagentSlotSchematics) do
        if slotSchematic.reagentType == Enum.CraftingReagentType.Basic
           and slotSchematic.required
           and slotSchematic.quantityRequired > 0 then

            local playerNeeds = slotSchematic.quantityRequired - (customerProvided[slotSchematic.slotIndex] or 0)
            if playerNeeds > 0 then
                local itemID = slotSchematic.reagents and slotSchematic.reagents[1] and slotSchematic.reagents[1].itemID
                if itemID then
                    totals[itemID] = (totals[itemID] or 0) + playerNeeds
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Reagent estimate: bucketed mode (no per-order reagent data)
-- ---------------------------------------------------------------------------

function POT:CalculateSchematicReagents(spellID, isRecraft, orderCount, totals)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(spellID, isRecraft)
    if not schematic or not schematic.reagentSlotSchematics then return end

    for _, slotSchematic in ipairs(schematic.reagentSlotSchematics) do
        if slotSchematic.reagentType == Enum.CraftingReagentType.Basic
           and slotSchematic.required
           and slotSchematic.quantityRequired > 0 then

            local itemID = slotSchematic.reagents and slotSchematic.reagents[1] and slotSchematic.reagents[1].itemID
            if itemID then
                totals[itemID] = (totals[itemID] or 0) + (slotSchematic.quantityRequired * orderCount)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Per-order cost calculation (for ceiling filter)
-- ---------------------------------------------------------------------------

function POT:CalculateOrderCost(spellID, isRecraft, customerProvided)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(spellID, isRecraft)
    if not schematic or not schematic.reagentSlotSchematics then return nil, true end

    local totalCost = 0
    local hasMissingPrices = false

    for _, slotSchematic in ipairs(schematic.reagentSlotSchematics) do
        if slotSchematic.reagentType == Enum.CraftingReagentType.Basic
           and slotSchematic.required
           and slotSchematic.quantityRequired > 0 then

            local playerNeeds = slotSchematic.quantityRequired
            if customerProvided then
                playerNeeds = playerNeeds - (customerProvided[slotSchematic.slotIndex] or 0)
            end

            if playerNeeds > 0 then
                local itemID = slotSchematic.reagents and slotSchematic.reagents[1] and slotSchematic.reagents[1].itemID
                if itemID then
                    local price = Auctionator.API.v1.GetAuctionPriceByItemID(ADDON_NAME, itemID)
                    if price then
                        totalCost = totalCost + (price * playerNeeds)
                    else
                        hasMissingPrices = true
                    end
                end
            end
        end
    end

    return totalCost, hasMissingPrices
end

-- ---------------------------------------------------------------------------
-- Auctionator shopping list
-- ---------------------------------------------------------------------------

local function PrintSummary(scannedCount, skippedCount, reagentCount, hasShoppingList, ceilingSkippedCount, missingPriceCount)
    PrintMsg(string.format("Scanned %d patron order%s.", scannedCount, scannedCount == 1 and "" or "s"))
    if hasShoppingList and reagentCount > 0 then
        PrintMsg(string.format("Added %d reagent%s to shopping list.",
            reagentCount, reagentCount == 1 and "" or "s"))
    end
    if skippedCount > 0 then
        PrintMsg(string.format("Skipped %d order%s for recipes you haven't learned.", skippedCount, skippedCount == 1 and "" or "s"))
    end
    if ceilingSkippedCount and ceilingSkippedCount > 0 then
        PrintMsg(string.format("Skipped %d order%s over the order budget (%s).",
            ceilingSkippedCount, ceilingSkippedCount == 1 and "" or "s",
            GetCoinTextureString(PatronOrderTrackerDB.priceCeiling)))
    end
    if missingPriceCount and missingPriceCount > 0 then
        PrintMsg(string.format("|cffff8800Warning:|r %d order%s had no price data. Included anyway. Try scanning the AH.",
            missingPriceCount, missingPriceCount == 1 and "" or "s"))
    end
end

function POT:CreateShoppingList(reagentTotals, scannedCount, skippedCount, ceilingSkippedCount, missingPriceCount)
    local totalReagentCount = 0
    for _, count in pairs(reagentTotals) do
        totalReagentCount = totalReagentCount + count
    end

    local pendingItems = {}
    for itemID, count in pairs(reagentTotals) do
        table.insert(pendingItems, { itemID = itemID, count = count })
    end

    if #pendingItems == 0 then
        PrintSummary(scannedCount, skippedCount, 0, false, ceilingSkippedCount, missingPriceCount)
        return
    end

    local continuableContainer = ContinuableContainer:Create()
    for _, pending in ipairs(pendingItems) do
        continuableContainer:AddContinuable(Item:CreateFromItemID(pending.itemID))
    end

    continuableContainer:ContinueOnLoad(function()
        local searchStrings = {}
        for _, pending in ipairs(pendingItems) do
            local name = C_Item.GetItemNameByID(pending.itemID)
            if name then
                local searchString = Auctionator.API.v1.ConvertToSearchString(ADDON_NAME, {
                    searchString = name,
                    isExact = true,
                    quantity = pending.count,
                })
                table.insert(searchStrings, searchString)
            end
        end

        if #searchStrings > 0 then
            Auctionator.API.v1.CreateShoppingList(ADDON_NAME, POT.shoppingListName, searchStrings)
            PrintSummary(scannedCount, skippedCount, totalReagentCount, true, ceilingSkippedCount, missingPriceCount)
            PrintMsg("Created shopping list: " .. POT.shoppingListName)
        else
            PrintSummary(scannedCount, skippedCount, 0, false, ceilingSkippedCount, missingPriceCount)
            PrintMsg("No player-supplied reagents needed. Customers provided everything.")
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Clear shopping list
-- ---------------------------------------------------------------------------

function POT:ClearShoppingList()
    if Auctionator and Auctionator.Shopping then
        pcall(function()
            local listIndex = Auctionator.Shopping.ListManager:GetIndexForName(POT.shoppingListName)
            if listIndex then
                Auctionator.Shopping.ListManager:Delete(POT.shoppingListName)
            end
        end)
    end

    PrintMsg("Cleared the Auctionator shopping list.")
    POT.shoppingListName = nil
    POT:UpdateButtonState()
end

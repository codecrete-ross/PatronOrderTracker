local ADDON_NAME = "PatronOrderTracker"
local POT = {}

POT.trackedRecipes = {}
POT.shoppingListName = nil
POT.trackButton = nil
POT.clearButton = nil
POT.initialized = false
POT.trackErrorLogged = false
POT.debug = false

-- ---------------------------------------------------------------------------
-- Saved variables & event bootstrap
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == ADDON_NAME then
            POT:OnAddonLoaded()
            eventFrame:UnregisterEvent("ADDON_LOADED")
            eventFrame:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
        end
    elseif event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        if ProfessionsFrame and ProfessionsFrame.OrdersPage then
            POT:InjectButtons()
        end
    end
end)

function POT:OnAddonLoaded()
    if not PatronOrderTrackerDB then
        PatronOrderTrackerDB = { trackedRecipes = {} }
    end
    if not PatronOrderTrackerDB.trackedRecipes then
        PatronOrderTrackerDB.trackedRecipes = {}
    end
    -- Work directly on the saved table so changes persist without re-assignment
    POT.trackedRecipes = PatronOrderTrackerDB.trackedRecipes
end

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
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0, 0, 0, 0.9)
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        table.insert(UISpecialFrames, "PatronOrderTrackerDumpFrame")

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -10)
        title:SetText("Patron Order Tracker - Diagnostic Dump")

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)

        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 12, -34)
        sf:SetPoint("BOTTOMRIGHT", -30, 12)

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

    -- Header
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

    -- Filter to Npc orders only
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

    -- Orders
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
            add("isFulfillable: " .. tostring(order.isFulfillable))
            add("isRecraft: " .. tostring(order.isRecraft))

            -- Reagent breakdown
            local schematic = C_TradeSkillUI.GetRecipeSchematic(order.spellID, order.isRecraft)
            if schematic and schematic.reagentSlotSchematics then
                -- Build customer-provided lookup
                local customerProvided = {}
                if order.reagents then
                    for _, r in ipairs(order.reagents) do
                        local qty = r.reagentInfo and r.reagentInfo.quantity or 0
                        customerProvided[r.slotIndex] = (customerProvided[r.slotIndex] or 0) + qty
                    end
                end

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
                        add(string.format("  [%s] %s: need %d (optional, not tracked)",
                            typeName, reagentName, needed))
                    end
                end
            else
                add("Reagents: (schematic unavailable)")
            end
            add("")
        end
    else
        -- Bucketed fallback
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

    -- Tracked recipes
    local trackedCount = 0
    for _ in pairs(POT.trackedRecipes) do trackedCount = trackedCount + 1 end
    add(string.format("Addon-tracked recipes: %d", trackedCount))
    if POT.shoppingListName then
        add("Shopping list name: " .. POT.shoppingListName)
    end

    return table.concat(lines, "\n")
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

local function TrySetRecipeTracked(recipeID, tracked, isRecraft)
    local ok, err = pcall(C_TradeSkillUI.SetRecipeTracked, recipeID, tracked, isRecraft)
    if not ok and not POT.trackErrorLogged then
        PrintMsg("|cffff6666SetRecipeTracked failed:|r " .. tostring(err))
        POT.trackErrorLogged = true
    end
    return ok
end

-- ---------------------------------------------------------------------------
-- UI injection
-- ---------------------------------------------------------------------------

function POT:InjectButtons()
    if POT.initialized then
        POT:UpdateButtonState()
        return
    end

    local browseFrame = ProfessionsFrame.OrdersPage.BrowseFrame
    if not browseFrame then return end

    -- Track All button
    POT.trackButton = CreateFrame("Button", nil, browseFrame, "UIPanelButtonTemplate")
    POT.trackButton:SetSize(200, 22)
    POT.trackButton:SetText("Track All Fulfillable Orders")
    POT.trackButton:SetPoint("TOPRIGHT", browseFrame, "TOPRIGHT", -8, -32)
    POT.trackButton:SetScript("OnClick", function() POT:ScanAndTrackAll() end)
    POT.trackButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Tracks every Patron Order you can fulfill.")
        GameTooltip:AddLine("Only reagents you must supply are added to the Auctionator shopping list.", 1, 1, 1)
        GameTooltip:Show()
    end)
    POT.trackButton:SetScript("OnLeave", GameTooltip_Hide)

    -- Clear button
    POT.clearButton = CreateFrame("Button", nil, browseFrame, "UIPanelButtonTemplate")
    POT.clearButton:SetSize(160, 22)
    POT.clearButton:SetText("Clear Patron Tracking")
    POT.clearButton:SetPoint("RIGHT", POT.trackButton, "LEFT", -5, 0)
    POT.clearButton:SetScript("OnClick", function() POT:ClearAllTracking() end)

    -- Hook tab switching
    hooksecurefunc(ProfessionsFrame.OrdersPage, "SetCraftingOrderType", function()
        POT:UpdateButtonState()
    end)

    -- Hide when BrowseFrame hides (viewing an individual order)
    browseFrame:HookScript("OnHide", function()
        if POT.trackButton then POT.trackButton:Hide() end
        if POT.clearButton then POT.clearButton:Hide() end
    end)
    browseFrame:HookScript("OnShow", function()
        POT:UpdateButtonState()
    end)

    POT.initialized = true
    POT:UpdateButtonState()
end

function POT:UpdateButtonState()
    local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
    if not ordersPage then return end

    local isNpcTab = (ordersPage.orderType == Enum.CraftingOrderType.Npc)
    local browseVisible = ordersPage.BrowseFrame and ordersPage.BrowseFrame:IsShown()

    if POT.trackButton then
        POT.trackButton:SetShown(isNpcTab and browseVisible)
    end
    if POT.clearButton then
        POT.clearButton:SetShown(isNpcTab and browseVisible and next(POT.trackedRecipes) ~= nil)
    end
end

-- ---------------------------------------------------------------------------
-- Core scan & track
-- ---------------------------------------------------------------------------

function POT:ScanAndTrackAll()
    -- Determine data source: flat orders vs buckets
    local flatOrders = C_CraftingOrders.GetCrafterOrders() or {}
    local buckets = C_CraftingOrders.GetCrafterBuckets() or {}

    DebugMsg(string.format("GetCrafterOrders returned %d, GetCrafterBuckets returned %d", #flatOrders, #buckets))

    -- Filter flat orders to Npc type only
    local npcOrders = {}
    for _, order in ipairs(flatOrders) do
        DebugMsg(string.format("  Flat order: spellID=%s type=%s fulfillable=%s",
            tostring(order.spellID), tostring(order.orderType), tostring(order.isFulfillable)))
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

    -- Profession info for shopping list name
    local profInfo = C_TradeSkillUI.GetChildProfessionInfo()
    local profName = profInfo and (profInfo.parentProfessionName or profInfo.professionName) or "Unknown"
    POT.shoppingListName = "PatronOrderTracker - " .. profName

    local trackedCount = 0
    local skippedCount = 0
    local reagentTotals = {} -- { [itemID] = count }

    if useBuckets then
        -- Bucketed mode: no per-order reagent details, estimate from schematic
        for i, bucket in ipairs(buckets) do
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(bucket.spellID)
            DebugMsg(string.format("  Bucket[%d]: spellID=%s learned=%s numAvailable=%s",
                i, tostring(bucket.spellID),
                tostring(recipeInfo and recipeInfo.learned),
                tostring(bucket.numAvailable)))
            if recipeInfo and recipeInfo.learned then
                local wasAlreadyTracked = C_TradeSkillUI.IsRecipeTracked(bucket.spellID, false)
                if not wasAlreadyTracked then
                    if TrySetRecipeTracked(bucket.spellID, true, false) then
                        POT.trackedRecipes[bucket.spellID] = true
                    end
                end
                POT:CalculateSchematicReagents(bucket.spellID, false, bucket.numAvailable, reagentTotals)
                trackedCount = trackedCount + 1
            else
                skippedCount = skippedCount + 1
            end
        end
        PrintMsg("Note: Reagent counts are estimated (individual order details not loaded).")
    else
        -- Flat mode: full per-order reagent data
        for i, order in ipairs(npcOrders) do
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(order.spellID)
            local learned = recipeInfo and recipeInfo.learned
            DebugMsg(string.format("  Order[%d]: spellID=%s learned=%s recraft=%s reagents=%d",
                i, tostring(order.spellID), tostring(learned),
                tostring(order.isRecraft), order.reagents and #order.reagents or 0))
            if learned then
                local wasAlreadyTracked = C_TradeSkillUI.IsRecipeTracked(order.spellID, order.isRecraft)
                if not wasAlreadyTracked then
                    if TrySetRecipeTracked(order.spellID, true, order.isRecraft) then
                        POT.trackedRecipes[order.spellID] = true
                    end
                end
                POT:CalculatePlayerReagents(order, reagentTotals)
                trackedCount = trackedCount + 1
            else
                skippedCount = skippedCount + 1
            end
        end
    end

    if trackedCount == 0 then
        PrintMsg("No fulfillable patron orders found.")
        return
    end

    -- Create Auctionator shopping list, then print summary once it's done
    POT:CreateShoppingList(reagentTotals, trackedCount, skippedCount)

    POT:UpdateButtonState()
end

-- ---------------------------------------------------------------------------
-- Reagent delta: flat orders (full data)
-- ---------------------------------------------------------------------------

function POT:CalculatePlayerReagents(order, totals)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(order.spellID, order.isRecraft)
    if not schematic or not schematic.reagentSlotSchematics then return end

    -- Build lookup: how much the customer provides per slot
    local customerProvided = {} -- { [slotIndex] = quantity }
    if order.reagents then
        for _, orderReagent in ipairs(order.reagents) do
            local slot = orderReagent.slotIndex
            local qty = orderReagent.reagentInfo and orderReagent.reagentInfo.quantity or 0
            customerProvided[slot] = (customerProvided[slot] or 0) + qty
        end
    end

    -- Walk schematic slots, compute delta
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
-- Auctionator shopping list
-- ---------------------------------------------------------------------------

local function PrintSummary(trackedCount, skippedCount, reagentCount, hasShoppingList)
    local msg = string.format("Tracked %d patron order%s", trackedCount, trackedCount == 1 and "" or "s")
    if hasShoppingList and reagentCount > 0 then
        msg = msg .. string.format(" · %d reagent%s added to shopping list",
            reagentCount, reagentCount == 1 and "" or "s")
    end
    PrintMsg(msg)
    if skippedCount > 0 then
        PrintMsg(string.format("Skipped %d unfulfillable order%s.", skippedCount, skippedCount == 1 and "" or "s"))
    end
end

function POT:CreateShoppingList(reagentTotals, trackedCount, skippedCount)
    -- Count total reagents
    local totalReagentCount = 0
    for _, count in pairs(reagentTotals) do
        totalReagentCount = totalReagentCount + count
    end

    if not Auctionator or not Auctionator.API or not Auctionator.API.v1 then
        PrintSummary(trackedCount, skippedCount, totalReagentCount, false)
        PrintMsg("Auctionator not detected - recipes tracked in objective tracker only.")
        return
    end

    -- Collect itemIDs needing name resolution
    local pendingItems = {}
    for itemID, count in pairs(reagentTotals) do
        table.insert(pendingItems, { itemID = itemID, count = count })
    end

    if #pendingItems == 0 then
        PrintSummary(trackedCount, skippedCount, 0, false)
        return
    end

    -- Use ContinuableContainer for batch async item name resolution
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
            PrintSummary(trackedCount, skippedCount, totalReagentCount, true)
        else
            PrintSummary(trackedCount, skippedCount, 0, false)
            PrintMsg("No player-supplied reagents needed (customers provided everything).")
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Clear tracking
-- ---------------------------------------------------------------------------

function POT:ClearAllTracking()
    local count = 0
    for recipeID in pairs(POT.trackedRecipes) do
        TrySetRecipeTracked(recipeID, false, false)
        TrySetRecipeTracked(recipeID, false, true)
        count = count + 1
    end

    wipe(POT.trackedRecipes)

    -- Delete Auctionator shopping list (no public delete API; ListManager:Delete is what
    -- CreateShoppingList uses internally, so this is the standard pattern)
    if Auctionator and Auctionator.Shopping and POT.shoppingListName then
        pcall(function()
            local listIndex = Auctionator.Shopping.ListManager:GetIndexForName(POT.shoppingListName)
            if listIndex then
                Auctionator.Shopping.ListManager:Delete(POT.shoppingListName)
            end
        end)
    end

    if count > 0 then
        PrintMsg(string.format("Cleared tracking for %d recipe%s and removed shopping list.",
            count, count == 1 and "" or "s"))
    else
        PrintMsg("Nothing to clear.")
    end

    POT:UpdateButtonState()
end

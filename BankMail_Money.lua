-- Create the module
local addonName = "BankMail"
local BankMail_Money = {
    initialized = false
}
_G[addonName .. "_Money"] = BankMail_Money

-- Local variables
local isCollecting = false
local moneyCollected = {}

-- Helper function to group money by sender
local function GetMoneyBySender()
    local moneyGroups = {}
    local numItems = GetInboxNumItems()

    for i = 1, numItems do
        local _, sender, senderName, subject, money = GetInboxHeaderInfo(i)
        if money and money > 0 then
            -- Determine the category
            local category
            if subject then
                if subject:find("Auction successful:") then
                    -- Get the body text to check for buyout vs bid win
                    local _, _, _, bid, buyout = GetInboxInvoiceInfo(i)
                    if bid == buyout then
                        category = "Auction Sales (Buyout)"
                    elseif bid < buyout then
                        category = "Auction Sales (High bidder)"
                    else
                        category = "Auction Sales (Unknown)"
                    end
                elseif subject:find("Outbid on") then
                    category = "Auction Returns"
                elseif subject:find("Cancelled auction") then
                    category = "Auction Cancels"
                else
                    -- Group by sender for non-auction mail
                    category = senderName or sender or "Unknown Sender"
                    if tonumber(category) then
                        category = "Unknown Sender"
                    end
                end
            else
                category = "Unknown Sender"
            end
            -- Initialize or update the category
            moneyGroups[category] = (moneyGroups[category] or 0) + money
        end
    end

    return moneyGroups
end

-- Function to collect all money
function BankMail_Money:ProcessAllMoney()
    if isCollecting then return end

    isCollecting = true
    local numItems = GetInboxNumItems()
    local foundMoney = false
    moneyCollected = GetMoneyBySender() -- Use the existing grouping function

    for i = 1, numItems do
        local _, _, _, _, money = GetInboxHeaderInfo(i)
        if money and money > 0 then
            foundMoney = true
            TakeInboxMoney(i)

            -- Add a small delay before continuing to next mail
            C_Timer.After(0.5, function()
                isCollecting = false
                self:ProcessAllMoney()
            end)
            return -- Exit this iteration and wait for next timer
        end
    end

    -- Print final totals with enhanced categories
    if foundMoney then
        -- Sort categories for consistent display
        local sortedCategories = {}
        for category, amount in pairs(moneyCollected) do
            table.insert(sortedCategories, {category = category, amount = amount})
        end
        table.sort(sortedCategories, function(a, b) return a.category < b.category end)

        -- Print sorted categories
        for _, data in ipairs(sortedCategories) do
            if data.category:find("Auction") then
                print("BankMail - " .. data.category .. ": " .. 
                    C_CurrencyInfo.GetCoinTextureString(data.amount))
            else
                print("BankMail - Collected from " .. data.category .. ": " .. 
                    C_CurrencyInfo.GetCoinTextureString(data.amount))
            end
        end

        -- Print total if multiple categories exist
        if #sortedCategories > 1 then
            local total = 0
            for _, data in ipairs(sortedCategories) do
                total = total + data.amount
            end
            print("BankMail - Total Collected: " .. C_CurrencyInfo.GetCoinTextureString(total))
        end
    end

    moneyCollected = {}
    isCollecting = false
end

function BankMail_Money:CreateCollectionButton()
    local BUTTON_WIDTH = 80
    local BUTTON_HEIGHT = 25
    local BUTTON_SPACING = 10
    local BUTTON_OFFSET_Y = 102
    local HORIZONTAL_SHIFT = -25

    -- Create our collection button first
    local button = CreateFrame("Button", "BankMailCollectButton", InboxFrame, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetText("Open Coin")

    -- Only modify OpenAllMail if it exists
    if OpenAllMail then
        OpenAllMail:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
        OpenAllMail:SetText("Open All")
        OpenAllMail:ClearAllPoints()

        -- Total width of both buttons plus spacing
        local TOTAL_WIDTH = (BUTTON_WIDTH * 2) + BUTTON_SPACING
        local LEFT_OFFSET = -(TOTAL_WIDTH / 2) + (BUTTON_WIDTH / 2) + HORIZONTAL_SHIFT

        OpenAllMail:SetPoint("BOTTOM", InboxFrame, "BOTTOM", LEFT_OFFSET, BUTTON_OFFSET_Y)
        button:SetPoint("LEFT", OpenAllMail, "RIGHT", BUTTON_SPACING, 0)
    else
        -- If OpenAllMail doesn't exist, center our button
        button:SetPoint("BOTTOM", InboxFrame, "BOTTOM", HORIZONTAL_SHIFT, BUTTON_OFFSET_Y)
    end

    -- Add tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        local moneyGroups = GetMoneyBySender()
        local hasMultipleCategories = false
        local total = 0
        local categoryCount = 0

        -- Count categories and calculate total
        for _, amount in pairs(moneyGroups) do
            total = total + amount
            categoryCount = categoryCount + 1
        end

        hasMultipleCategories = categoryCount > 1

        -- Show total first if there are multiple categories
        if hasMultipleCategories then
            GameTooltip:AddLine("Pending total coin:", 1, 0.82, 0) -- Golden color
            GameTooltip:AddLine(C_CurrencyInfo.GetCoinTextureString(total), 1, 1, 1)
            GameTooltip:AddLine(" ")                               -- Empty line for spacing
        end

        -- Show auction money categories if they exist
        local auctionCategories = {
            ["Auction Sales (Buyout)"] = "Auction buyouts:",
            ["Auction Sales (High bidder)"] = "Auction bids:",
            ["Auction Returns"] = "Auction returns:",
            ["Auction Cancels"] = "Cancelled auctions:"
        }
        
        local hasAuctions = false
        for category, label in pairs(auctionCategories) do
            if moneyGroups[category] then
                if not hasAuctions then
                    GameTooltip:AddLine("Pending auction coin:")
                    hasAuctions = true
                end
                GameTooltip:AddLine(label, 0.7, 0.7, 0.7, true)
                GameTooltip:AddLine(C_CurrencyInfo.GetCoinTextureString(moneyGroups[category]), 1, 1, 1, true)
                moneyGroups[category] = nil -- Remove so we don't show it again
            end
        end
        
        if hasAuctions and next(moneyGroups) ~= nil then
            GameTooltip:AddLine(" ") -- Empty line for spacing
        end

        -- Show other categories
        for sender, amount in pairs(moneyGroups) do
            if amount > 0 then
                -- Try to get a proper name if it's a number (likely a GUID)
                local displayName = sender
                if tonumber(sender) then
                    displayName = "Unknown Sender"
                end
                GameTooltip:AddLine("Pending " .. displayName .. " coin:", nil, nil, nil, true)
                GameTooltip:AddLine(C_CurrencyInfo.GetCoinTextureString(amount), 1, 1, 1, true)
                if next(moneyGroups, sender) ~= nil then -- If there are more categories after this
                    GameTooltip:AddLine(" ")             -- Empty line for spacing
                end
            end
        end

        -- If no money at all, show that
        if total == 0 then
            GameTooltip:AddLine("No pending coin")
        end

        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function()
        BankMail_Money:ProcessAllMoney()
    end)

    -- Add debug print
    print("BankMail: Created collection button")
end

-- Initialize module
function BankMail_Money:Init()
    if self.initialized then
        print("BankMail Money: Already initialized")
        return
    end

    print("BankMail Money: Starting initialization")

    if not InboxFrame then
        print("BankMail Money: ERROR - InboxFrame not found")
        return
    end

    self:CreateCollectionButton()
    self.initialized = true
    print("BankMail Money: Initialization complete")
end

return BankMail_Money

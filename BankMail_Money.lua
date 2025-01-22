print("Loading Money, BankMailDB exists:", BankMailDB ~= nil)

-- Create the module
local addonName = "BankMail"
local BankMail_Money = {
    initialized = false
}
_G[addonName .. "_Money"] = BankMail_Money

-- Local variables
local isCollecting = false
local auctionTotal = 0

-- Function to collect auction money
function BankMail_Money:ProcessAuctionMail()
    if isCollecting then return end

    isCollecting = true
    local numItems = GetInboxNumItems()
    local foundAuctions = false

    for i = 1, numItems do
        local _, _, _, subject, money = GetInboxHeaderInfo(i)

        if subject and subject:find("Auction successful:") and money and money > 0 then
            foundAuctions = true
            auctionTotal = auctionTotal + money
            TakeInboxMoney(i)

            -- Add a small delay before continuing to next mail
            C_Timer.After(0.5, function()
                isCollecting = false
                self:ProcessAuctionMail()
            end)
            return -- Exit this iteration and wait for next timer
        end
    end

    -- Print final total only when we've finished processing all mails
    if foundAuctions then
        print("BankMail - Total Collected: " .. C_CurrencyInfo.GetCoinTextureString(auctionTotal))
        auctionTotal = 0
    end
    isCollecting = false
end

-- Function to scan for pending auction money
function BankMail_Money:GetPendingAuctionMoney()
    local total = 0
    local numItems = GetInboxNumItems()

    for i = 1, numItems do
        local _, _, _, subject, money = GetInboxHeaderInfo(i)
        if subject and subject:find("Auction successful:") and money and money > 0 then
            total = total + money
        end
    end

    return total
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

    -- Add debug print
    print("BankMail: Created collection button")

    -- Rest of the button setup...
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local pendingMoney = BankMail_Money:GetPendingAuctionMoney()
        if pendingMoney > 0 then
            GameTooltip:AddLine("Pending auction coin:")
            GameTooltip:AddLine(C_CurrencyInfo.GetCoinTextureString(pendingMoney), 1, 1, 1)
        else
            GameTooltip:AddLine("No auction coins to collect")
        end
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function()
        BankMail_Money:ProcessAuctionMail()
    end)
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

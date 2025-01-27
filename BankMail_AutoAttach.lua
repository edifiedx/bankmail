-- Create the module
local addonName = "BankMail"
local BankMail_AutoAttach = {
    initialized = false
}
_G[addonName .. "_AutoAttach"] = BankMail_AutoAttach

-- Constants
local MAX_ATTACHMENTS = ATTACHMENTS_MAX_SEND or 12
local ATTACH_DELAY = 0.3


-- Helper function to check if an item is BoE
local function IsBoEItem(bag, slot)
    local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
    if not itemInfo then return false end

    local itemLink = itemInfo.hyperlink
    if not itemLink then return false end

    -- Get binding type
    local bindType = select(14, C_Item.GetItemInfo(itemLink))

    -- Check if it's BoE (bind type 2) and not already bound
    return bindType == 2 and not itemInfo.isBound
end

-- Function to get all BoE items from bags
local function GetBoEItems()
    local boeItems = {}

    -- Scan all bags
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            if IsBoEItem(bag, slot) then
                table.insert(boeItems, {
                    bag = bag,
                    slot = slot,
                    info = C_Container.GetContainerItemInfo(bag, slot)
                })
            end
        end
    end

    return boeItems
end

-- Function to attach BoE items to mail
function BankMail_AutoAttach:AttachBoEItems()
    if not SendMailFrame:IsVisible() then return end

    -- Get current number of attachments
    local currentAttachments = 0
    for i = 1, MAX_ATTACHMENTS do
        if GetSendMailItem(i) then
            currentAttachments = currentAttachments + 1
        end
    end

    -- Get BoE items
    local boeItems = GetBoEItems()
    if #boeItems == 0 then
        print("BankMail: No unbound BoE items found in bags")
        return
    end

    -- Track how many items we can still attach
    local slotsLeft = MAX_ATTACHMENTS - currentAttachments
    if slotsLeft <= 0 then
        print("BankMail: No attachment slots available")
        return
    end

    -- Keep track of attached items for detailed printing
    local attachedItems = {}

    -- Attach items one at a time with delay
    local itemsToAttach = math.min(slotsLeft, #boeItems)
    local itemIndex = 1

    local function AttachNext()
        if itemIndex > itemsToAttach then
            if #attachedItems > 0 and BankMailDB.enableAutoAttachmentDetails then
                print(string.format("BankMail: Auto-attached %d BoE items:", #attachedItems))
                for _, item in ipairs(attachedItems) do
                    print(string.format("%dx %s", item.count, item.link))
                end
            else
                print(string.format("BankMail: Auto-attached %d BoE items", #attachedItems))
            end
            return
        end

        local item = boeItems[itemIndex]
        -- Find first empty attachment slot
        local emptySlot = nil
        for i = 1, MAX_ATTACHMENTS do
            if not GetSendMailItem(i) then
                emptySlot = i
                break
            end
        end

        if emptySlot then
            C_Container.PickupContainerItem(item.bag, item.slot)
            if CursorHasItem() then
                ClickSendMailItemButton(emptySlot)
                -- Store successful attachments for later printing
                table.insert(attachedItems, {
                    link = item.info.hyperlink,
                    count = item.info.stackCount or 1
                })
            end
        end

        itemIndex = itemIndex + 1
        C_Timer.After(ATTACH_DELAY, AttachNext)
    end

    AttachNext()
end

-- Create auto-attach button
function BankMail_AutoAttach:CreateAttachButton()
    local button = CreateFrame("Button", "BankMailAutoAttachButton", SendMailFrame, "UIPanelButtonTemplate")
    button:SetSize(100, 22)
    button:SetPoint("TOP", SendMailMailButton, "BOTTOM", 0, -5)
    button:SetText("Auto Attach")

    -- Add tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Auto Attach Items")
        GameTooltip:AddLine("Click to automatically attach unbound")
        GameTooltip:AddLine("Bind on Equip items from your bags")
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function()
        BankMail_AutoAttach:AttachBoEItems()
    end)
end

-- Function to handle auto-switch completion
local function OnAutoSwitchComplete()
    -- Small delay to ensure UI is ready
    C_Timer.After(0.2, function()
        if SendMailFrame:IsVisible() and SendMailNameEditBox:GetText() ~= "" and BankMailDB.enableAutoAttach then
            BankMail_AutoAttach:AttachBoEItems()
        end
    end)
end

-- Initialize module
function BankMail_AutoAttach:Init()
    if self.initialized then
        print("BankMail AutoAttach: Already initialized")
        return
    end

    if not SendMailFrame then
        print("BankMail AutoAttach: ERROR - SendMailFrame not found")
        return
    end

    -- Create button for manual triggering
    self:CreateAttachButton()

    -- Hook into MailFrameTab2's OnClick to catch auto-switch completion
    if MailFrameTab2 then
        MailFrameTab2:HookScript("OnClick", OnAutoSwitchComplete)
    end

    self.initialized = true
    print("BankMail AutoAttach: Initialization complete")
end

return BankMail_AutoAttach

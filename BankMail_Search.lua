-- Create the module
local addonName = "BankMail"
local BankMail_Search = {
    initialized = false,
    currentSearchText = "",
    isSearching = false
}
_G[addonName .. "_Search"] = BankMail_Search

-- Constants
local SEARCH_UPDATE_DELAY = 0.2
local MAX_RESULTS = 100

-- Create a frame for handling updates
local updateFrame = CreateFrame("Frame")
local searchTimer = nil

-- Debug message function
local function DebugMsg(msg)
    if BankMailDB and BankMailDB.debugMode then
        -- RGB for a light blue color
        local r, g, b = 0.4, 0.8, 1.0
        -- Send to all chat frames
        for i = 1, NUM_CHAT_WINDOWS do
            local chatFrame = _G["ChatFrame" .. i]
            if chatFrame and chatFrame:IsEventRegistered("SYSTEM") then
                chatFrame:AddMessage("BankMail Debug: " .. msg, r, g, b)
            end
        end
    end
end

-- Helper function to collect item data from a mail
local function GetMailItems(mailIndex)
    local items = {}

    DebugMsg("Starting GetMailItems for mail " .. mailIndex)

    -- Get mail header info
    local _, _, _, _, _, _, _, hasItem = GetInboxHeaderInfo(mailIndex)

    DebugMsg("Mail " .. mailIndex .. " hasItem: " .. tostring(hasItem))

    if not hasItem then
        DebugMsg("No items in mail " .. mailIndex)
        return items
    end

    -- Loop through attachment slots
    for attachIndex = 1, ATTACHMENTS_MAX_RECEIVE do
        DebugMsg("Checking attachment " .. attachIndex .. " in mail " .. mailIndex)

        local name, itemID, texture, count = GetInboxItem(mailIndex, attachIndex)

        if name then
            DebugMsg("Found item: " .. name .. " x" .. (count or 1))

            table.insert(items, {
                name = name,
                itemID = itemID,
                texture = texture,
                count = count or 1,
                mailIndex = mailIndex,
                attachIndex = attachIndex
            })
        else
            DebugMsg("No item in slot " .. attachIndex)
        end
    end

    DebugMsg("Found " .. #items .. " items in mail " .. mailIndex)

    return items
end

-- Function to search through inbox
local function SearchInbox(searchText)
    if not searchText or searchText == "" then return {} end
    if not GetInboxNumItems then
        print("BankMail Search: Mail API not available")
        return {}
    end

    searchText = searchText:lower()
    local results = {}
    local numItems = GetInboxNumItems()

    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: Starting search through", numItems, "mails for:", searchText)
    end

    for i = 1, numItems do
        if BankMailDB and BankMailDB.debugMode then
            print("BankMail Search: Checking mail", i)
        end

        local hasItem = select(8, GetInboxHeaderInfo(i))
        if hasItem then
            local items = GetMailItems(i)
            for _, item in ipairs(items) do
                if item.name and item.name:lower():find(searchText) then
                    print(string.format("BankMail Search: Found match: %s (x%d) in mail %d slot %d",
                        item.name, item.count, item.mailIndex, item.attachIndex))
                    table.insert(results, item)
                    if #results >= MAX_RESULTS then
                        print("BankMail Search: Reached maximum results limit of", MAX_RESULTS)
                        return results
                    end
                end
            end
        end
    end

    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: Found", #results, "matching items")
    end

    return results
end

-- Create the search interface
function BankMail_Search:CreateSearchUI()
    -- Create search box
    local searchBox = CreateFrame("EditBox", "BankMailSearchBox", InboxFrame, "SearchBoxTemplate")
    searchBox:SetPoint("TOP", InboxFrame, "TOP", 0, -30)
    searchBox:SetSize(200, 20)
    searchBox:SetAutoFocus(false)

    -- Update search box behavior
    searchBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local text = self:GetText()
            if text and text ~= "" then
                self.clearButton:Show()
            else
                self.clearButton:Hide()
            end
            BankMail_Search:OnSearchTextChanged(text)
        end
    end)

    -- Handle escape and enter
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    self.searchBox = searchBox
end

-- Handle search text changes
function BankMail_Search:OnSearchTextChanged(text)
    self.currentSearchText = text

    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: Text changed to:", text)
    end

    -- Cancel existing timer
    if searchTimer then
        if BankMailDB and BankMailDB.debugMode then
            print("BankMail Search: Cancelling existing search timer")
        end
        searchTimer:Cancel()
        searchTimer = nil
    end

    -- Clear isSearching flag
    self.isSearching = false

    -- Start new search
    if text and text ~= "" then
        if BankMailDB and BankMailDB.debugMode then
            print("BankMail Search: Starting new search")
        end
        SearchInbox(text)
    else
        if BankMailDB and BankMailDB.debugMode then
            print("BankMail Search: Empty search text, skipping search")
        end
    end
end

-- Initialize module
function BankMail_Search:Init()
    if self.initialized then
        print("BankMail Search: Already initialized")
        return
    end

    if not InboxFrame then
        print("BankMail Search: ERROR - InboxFrame not found")
        return
    end

    self:CreateSearchUI()
    self.initialized = true
    print("BankMail Search: Initialization complete")
end

return BankMail_Search

-- Create the module
local addonName = "BankMail"
local BankMail_Search = {
    initialized = false,
    currentSearchText = "",
    isSearching = false,
    resultsVisible = false,
    lastSearchState = {
        wasVisible = false,
        searchText = ""
    }
}
_G[addonName .. "_Search"] = BankMail_Search

-- Constants
local MAX_RESULTS = 200
local TAKE_ALL_DELAY = 0.3

-- Create a frame for handling updates
local updateFrame = CreateFrame("Frame")
updateFrame:RegisterEvent("MAIL_INBOX_UPDATE")
updateFrame:RegisterEvent("MAIL_CLOSED")
updateFrame:RegisterEvent("MAIL_SHOW")
local searchTimer = nil

-- Helper function to collect item data from a mail
local function GetMailItems(mailIndex)
    local items = {}

    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: Starting GetMailItems for mail", mailIndex)
    end

    -- Get mail header info
    local _, _, sender, subject, _, _, daysLeft, hasItem = GetInboxHeaderInfo(mailIndex)

    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: Mail", mailIndex, "hasItem:", tostring(hasItem))
    end

    if not hasItem then
        if BankMailDB and BankMailDB.debugMode then
            print("BankMail Search: No items in mail", mailIndex)
        end
        return items
    end

    -- Loop through attachment slots
    for attachIndex = 1, ATTACHMENTS_MAX_RECEIVE do
        if BankMailDB and BankMailDB.debugMode then
            print("BankMail Search: Checking attachment", attachIndex, "in mail", mailIndex)
        end

        local itemLink = GetInboxItemLink(mailIndex, attachIndex)
        if itemLink then
            local name, itemID, texture, count, quality = GetInboxItem(mailIndex, attachIndex)

            if name then
                if BankMailDB and BankMailDB.debugMode then
                    print("BankMail Search: Found item:", name, "x", count or 1)
                    print("BankMail Search: ItemLink:", itemLink)
                    print("BankMail Search: Texture:", texture)
                end

                table.insert(items, {
                    name = name,
                    itemLink = itemLink,
                    itemID = itemID,
                    texture = texture,
                    count = count or 1,
                    mailIndex = mailIndex,
                    attachIndex = attachIndex,
                    sender = sender,
                    subject = subject,
                    daysLeft = daysLeft,
                    quality = quality
                })
            end
        else
            if BankMailDB and BankMailDB.debugMode then
                print("BankMail Search: No item in slot", attachIndex)
            end
        end
    end

    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: Found", #items, "items in mail", mailIndex)
    end

    return items
end

-- Function to take all stacks of a specific item
local function TakeAllStacksOfItem(itemID, itemStacks)
    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: Taking all stacks of itemID:", itemID)
        print("BankMail Search: Found", #itemStacks, "stacks to collect")
    end

    table.sort(itemStacks, function(a, b) return a.mailIndex < b.mailIndex end)

    local currentIndex = 1

    local function TakeNextStack()
        if currentIndex > #itemStacks then
            if BankMailDB and BankMailDB.debugMode then
                print("BankMail Search: Finished taking all stacks")
            end
            return
        end

        local stack = itemStacks[currentIndex]
        if BankMailDB and BankMailDB.debugMode then
            print(string.format("BankMail Search: Taking stack %d/%d from mail %d, slot %d",
                currentIndex, #itemStacks, stack.mailIndex, stack.attachIndex))
        end

        -- Take the item
        TakeInboxItem(stack.mailIndex, stack.attachIndex)

        -- Set up next iteration
        currentIndex = currentIndex + 1

        -- Wait for the MAIL_INBOX_UPDATE event before proceeding
        C_Timer.After(TAKE_ALL_DELAY, function()
            -- Verify the item was taken
            local stillExists = GetInboxItemLink(stack.mailIndex, stack.attachIndex)
            if stillExists then
                -- Item still exists, try again
                C_Timer.After(TAKE_ALL_DELAY, TakeNextStack)
            else
                -- Item was taken, move to next
                TakeNextStack()
            end
        end)
    end

    -- Start the process
    TakeNextStack()
end

-- Function to search through inbox
local function SearchInbox(searchText)
    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: SearchInbox called with text:", searchText)
    end
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
                    if BankMailDB and BankMailDB.debugMode then
                        print(string.format("BankMail Search: Found match: %s (x%d) in mail %d slot %d",
                            item.name, item.count, item.mailIndex, item.attachIndex))
                    end
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

-- Function to create search result button
local function CreateSearchResultButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(37, 37)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Add button background (slot texture)
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture("Interface\\Buttons\\UI-Quickslot")

    -- Create border texture
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetPoint("CENTER")
    border:SetSize(55, 55)
    button.border = border

    -- Create icon texture
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("CENTER")
    button.icon = icon

    -- Create count text
    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -5, 2)
    button.count = count

    -- Add highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")

    -- Add hover effect
    button:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            if self.sender then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("From: " .. self.sender, 0.9, 0.9, 0.9)
            end
            if self.subject then
                GameTooltip:AddLine("Subject: " .. self.subject, 0.9, 0.9, 0.9)
            end
            local roundDaysLeft = string.format("%.1f", self.daysLeft)
            GameTooltip:AddLine("Days Left: " .. roundDaysLeft, 0.9, 0.9, 0.9)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Left-click to take this stack", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Right-click to take all stacks", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Add click handling
    button:SetScript("OnClick", function(self, buttonName)
        if not self.itemID then return end

        if buttonName == "LeftButton" then
            -- Take single stack
            if self.mailIndex and self.attachIndex then
                TakeInboxItem(self.mailIndex, self.attachIndex)
            end
        elseif buttonName == "RightButton" then
            -- Take all stacks of this item
            local allResults = SearchInbox(self.name:lower())
            local sameItemStacks = {}

            -- Find all stacks of the same item
            for _, result in ipairs(allResults) do
                if result.itemID == self.itemID then
                    table.insert(sameItemStacks, result)
                end
            end

            if #sameItemStacks > 0 then
                TakeAllStacksOfItem(self.itemID, sameItemStacks)
            end
        end
    end)

    return button
end

function BankMail_Search:SaveSearchState()
    self.lastSearchState = {
        wasVisible = self.resultsVisible,
        searchText = self.searchBox and self.searchBox:GetText() or ""
    }

    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: Saved state - ",
            "Visible:", self.lastSearchState.wasVisible,
            "Text:", self.lastSearchState.searchText
        )
    end
end

function BankMail_Search:ClearSearch(updateUI)
    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: Clearing search state")
    end

    self.currentSearchText = ""
    self.isSearching = false
    self.resultsVisible = false

    if updateUI and self.searchBox then
        self.searchBox:SetText("")
        self.searchBox:ClearFocus()
        self.searchBox.Instructions:SetText("search...")
    end

    self:HideResults()
end

-- Create the search interface
function BankMail_Search:CreateSearchUI()
    -- Create main container frame if it doesn't exist
    if not self.container then
        self.container = CreateFrame("Frame", "BankMailSearchContainer", InboxFrame, "BackdropTemplate")
        self.container:SetPoint("TOPLEFT", InboxFrame, "TOPLEFT", 0, -55)
        self.container:SetPoint("BOTTOMRIGHT", InboxFrame, "BOTTOMRIGHT", -50, 90)
        self.container:SetFrameStrata("HIGH")
        self.container:EnableMouse(true)

        -- Add background and border
        self.container:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        self.container:SetBackdropColor(0, 0, 0, 0.95)
        self.container:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end
    self.container:Hide()

    -- Create search box if it doesn't exist
    if not self.searchBox then
        self.searchBox = CreateFrame("EditBox", "BankMailSearchBox", InboxFrame, "SearchBoxTemplate")
        self.searchBox:SetPoint("TOP", InboxFrame, "TOP", -35, -30)
        self.searchBox:SetSize(175, 20)
        self.searchBox:SetAutoFocus(false)
        self.searchBox.Instructions:SetText("search...") -- omg, maybe?

        -- focus on show
        self.searchBox:SetScript("OnShow", function(self)
            if BankMailDB and BankMailDB.enableSearchAutoFocus then
                self:SetFocus()
            end
        end)

        self.searchBox.clearButton:SetScript("OnClick", function(self)
            local editBox = self:GetParent()
            editBox:SetText("")
            editBox:ClearFocus()
            BankMail_Search:OnSearchTextChanged("")
        end)

        -- drop focus on click away
        self.searchBox:EnableMouse(true)
        self.searchBox:SetScript("OnEditFocusLost", function(self)
            if self:GetText() == "" then
                self.Instructions:SetText("search...")
            end
        end)

        -- browse button
        if not self.browseButton then
            self.browseButton = CreateFrame("Button", "BankMailShowAllButton", InboxFrame, "UIPanelButtonTemplate")
            self.browseButton:SetSize(65, 22)
            self.browseButton:SetPoint("LEFT", self.searchBox, "RIGHT", 10, 0)
            self.browseButton:SetText("Browse")

            -- Add tooltip
            self.browseButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if BankMail_Search.resultsVisible then
                    GameTooltip:AddLine("Hide Items")
                    GameTooltip:AddLine("Hide the item browser", 1, 1, 1, true)
                else
                    GameTooltip:AddLine("Show All Items")
                    GameTooltip:AddLine("Display all items in your inbox")
                end
                GameTooltip:AddLine("")
                GameTooltip:AddLine("Left-click: take a single item stack", 1, 1, 1, true)
                GameTooltip:AddLine("Right-click: take all item stacks", 1, 1, 1, true)
                GameTooltip:Show()
            end)

            self.browseButton:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)


            -- Handle button click with toggle behavior
            self.browseButton:SetScript("OnClick", function()
                if self.resultsVisible then
                    self:ClearSearch(true)
                else
                    if BankMailDB and BankMailDB.debugMode then
                        print("BankMail Search: Show All button clicked")
                    end
                    self:ShowAllItems()
                end
            end)
        end

        -- Update search box behavior
        self.searchBox:SetScript("OnTextChanged", function(self, userInput)
            local text = self:GetText()
            if text and text ~= "" then
                self.Instructions:SetText("")
            else
                self.Instructions:SetText("search...")
            end
            if userInput then
                BankMail_Search:OnSearchTextChanged(text)
            end
        end)

        -- Handle escape and enter
        self.searchBox:SetScript("OnEscapePressed", function(self)
            if BankMailDB and BankMailDB.debugMode then
                print("BankMail Search: Escape pressed")
                print("- Has text:", self:GetText() ~= "")
                print("- Has focus:", self:HasFocus())
            end

            if self:GetText() ~= "" then
                if BankMailDB and BankMailDB.debugMode then
                    print("BankMail Search: Clearing text and focus")
                end
                BankMail_Search:ClearSearch(true)
                return
            end

            if self:HasFocus() then
                if BankMailDB and BankMailDB.debugMode then
                    print("BankMail Search: Dropping focus")
                end
                self:ClearFocus()
                return
            end

            if BankMailDB and BankMailDB.debugMode then
                print("BankMail Search: Closing mail window")
            end
            HideUIPanel(MailFrame)
        end)

        self.searchBox:SetScript("OnEnterPressed", function(self)
            if BankMailDB and BankMailDB.debugMode then
                print("BankMail Search: Enter pressed, clearing focus")
            end
            self:ClearFocus()
        end)
    end

    -- Create results container (scrolling)
    if not self.scrollFrame then
        self.scrollFrame = CreateFrame("ScrollFrame", "BankMailSearchScroll", self.container,
            "UIPanelScrollFrameTemplate")
        self.scrollFrame:SetPoint("TOPLEFT", self.container, "TOPLEFT", 8, -8)
        self.scrollFrame:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT", -28, 8)

        self.content = CreateFrame("Frame", nil, self.scrollFrame)
        self.content:SetWidth(self.scrollFrame:GetWidth() - 30)
        self.content:SetHeight(400)

        self.scrollFrame:SetScrollChild(self.content)
    end

    -- Initialize button pool
    self.buttonPool = {}
    self.activeButtons = {}
end

-- Function to collect and show all items in inbox
function BankMail_Search:ShowAllItems()
    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: Collecting all inbox items")
    end

    local allItems = {}
    local numItems = GetInboxNumItems()

    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: Found", numItems, "mails in inbox")
    end

    for i = 1, numItems do
        local items = GetMailItems(i)
        for _, item in ipairs(items) do
            table.insert(allItems, item)
            if BankMailDB and BankMailDB.debugMode then
                print("BankMail Search: Added item:", item.name, "from mail", i)
            end
        end
    end

    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: Total items found:", #allItems)
    end

    self:ShowResults(allItems)
end

-- Function to show search results
function BankMail_Search:ShowResults(results)
    if not self.container or not self.content then
        if BankMailDB and BankMailDB.debugMode then
            print("BankMail Search: UI not initialized, creating...")
        end
        self:CreateSearchUI()
    end

    self.resultsVisible = true
    if self.browseButton then
        self.browseButton:SetText("Hide")
    end

    -- Clear existing buttons
    for _, button in ipairs(self.activeButtons) do
        button:Hide()
        table.insert(self.buttonPool, button)
    end
    wipe(self.activeButtons)

    -- Show container and hide inbox pages
    self.container:Show()
    if InboxFrame.Pages then
        InboxFrame.Pages:Hide()
    end

    -- Layout results in a grid
    local buttonSize = 36
    local padding = 1
    local containerOffset = 30
    local contentWidth = self.container:GetWidth() - 25
    local columns = math.max(1, math.floor((contentWidth - padding) / (buttonSize + padding)))

    if BankMailDB and BankMailDB.debugMode then
        print("BankMail Search: Displaying", #results, "results")
        print("BankMail Search: Grid layout - Content width:", contentWidth, "Columns:", columns)
    end

    for i, result in ipairs(results) do
        local button = table.remove(self.buttonPool) or CreateSearchResultButton(self.content)
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.content, "TOPLEFT",
            col * (buttonSize + padding) + padding + containerOffset,
            -(row * (buttonSize + padding) + padding))

        if result.quality and result.quality > 1 then
            local r, g, b = C_Item.GetItemQualityColor(result.quality)
            button.border:SetVertexColor(r, g, b, 1)
            button.border:Show()
        else
            button.border:Hide()
        end
        button.icon:SetTexture(result.texture)
        button.count:SetText(result.count > 1 and result.count or "")
        button.itemLink = result.itemLink
        button.itemID = result.itemID
        button.name = result.name
        button.mailIndex = result.mailIndex
        button.attachIndex = result.attachIndex
        button.sender = result.sender
        button.subject = result.subject
        button.daysLeft = result.daysLeft
        button:Show()

        table.insert(self.activeButtons, button)
    end

    -- Update content height
    local rows = math.ceil(#results / columns)
    self.content:SetHeight(math.max(400, rows * (buttonSize + padding)))
    -- toggle button text
    if self.browseButton then
        self.browseButton:SetText("Hide")
    end
end

-- Function to hide search results
function BankMail_Search:HideResults()
    if self.container then
        self.container:Hide()
        if InboxFrame.Pages then
            InboxFrame.Pages:Show()
        end
    end

    self.resultsVisible = false
    if self.browseButton then
        self.browseButton:SetText("Browse")
    end
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
        local results = SearchInbox(text)
        self:ShowResults(results)
    else
        if BankMailDB and BankMailDB.debugMode then
            print("BankMail Search: Empty search text, hiding results")
        end
        self:HideResults()
    end
end

-- Handle mail inbox updates
updateFrame:SetScript("OnEvent", function(self, event)
    if event == "MAIL_INBOX_UPDATE" then
        -- Add a small delay to ensure mail data is fully updated
        C_Timer.After(0.2, function()
            if BankMail_Search.currentSearchText ~= "" then
                -- Refresh current search results
                local results = SearchInbox(BankMail_Search.currentSearchText)
                BankMail_Search:ShowResults(results)
            elseif BankMail_Search.resultsVisible then
                -- If we're showing all items, refresh that view
                BankMail_Search:ShowAllItems()
            end
        end)
    elseif event == "MAIL_CLOSED" then
        BankMail_Search:SaveSearchState()
        BankMail_Search:ClearSearch(true)
    elseif event == "MAIL_SHOW" then
        C_Timer.After(0.2, function()
            if BankMail_Search.lastSearchState.wasVisible then
                if BankMail_Search.lastSearchState.searchText ~= "" then
                    BankMail_Search.searchBox:SetText(BankMail_Search.lastSearchState.searchText)
                    BankMail_Search:OnSearchTextChanged(BankMail_Search.lastSearchState.searchText)
                else
                    BankMail_Search:ShowAllItems()
                end
            end
        end)
    end
end)

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

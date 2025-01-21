-- Create the addon frame and register for events
local frame = CreateFrame("Frame")
frame:RegisterEvent("MAIL_CLOSED")
frame:RegisterEvent("MAIL_SHOW")
frame:RegisterEvent("MAIL_INBOX_UPDATE")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

-- Addon name
local addonName = "BankMail"

local BankMail_Money = _G[addonName .. "_Money"]

-- Update default settings
local defaults = {
    enabled = true,
    accountDefaultRecipient = nil,
    characterRecipients = {},
    debugMode = false,
    disableAutoSwitchOnBank = true -- Default to true since it's likely desired behavior
}

local currentRealm
local currentChar
local mailLoadTimer = nil
local currentMailSession = false

-- Helper function to check if current character is the bank character
local function IsCurrentCharacterBank()
    local currentCharKey = GetCharacterKey()
    local bankChar = BankMailDB.accountDefaultRecipient

    -- If bank character doesn't include realm, append current realm
    if bankChar and not bankChar:find("-") then
        bankChar = bankChar .. "-" .. currentRealm
    end

    return bankChar and currentCharKey == bankChar
end

-- Function to get current character's full name
local function GetCharacterKey()
    return currentChar .. "-" .. currentRealm
end

-- Function to get default recipient for current character
local function GetDefaultRecipient()
    local charKey = GetCharacterKey()
    -- First check character-specific recipient
    if BankMailDB.characterRecipients[charKey] then
        return BankMailDB.characterRecipients[charKey]
    end
    -- Fall back to account-wide default
    return BankMailDB.accountDefaultRecipient
end

local function SetAccountDefaultRecipient(recipient)
    -- If recipient doesn't include a realm, append current realm
    if not recipient:find("-") then
        recipient = recipient .. "-" .. currentRealm
    end
    BankMailDB.accountDefaultRecipient = recipient
    print("BankMail: Account-wide default recipient set to: " .. recipient)
end

local function SetCharacterDefaultRecipient(recipient)
    local charKey = GetCharacterKey()
    BankMailDB.characterRecipients[charKey] = recipient
    print("BankMail: Character-specific default recipient for " .. charKey .. " set to: " .. recipient)
end

-- Function to check for unread mail
local function HasUnreadMail()
    local numItems = GetInboxNumItems()
    for i = 1, numItems do
        local _, _, _, _, _, _, _, _, wasRead = GetInboxHeaderInfo(i)
        if not wasRead then
            return true
        end
    end
    return false
end


-- Hook the Send Mail tab for right-click
local function HookSendMailTab()
    if BankMailDB.debugMode then
        print("BankMail: Attempting to hook Send Mail tab")
    end

    if not MailFrameTab2 then
        print("BankMail: ERROR - MailFrameTab2 not found!")
        return
    end

    if not MailFrameTab2.bmHooked then
        if BankMailDB.debugMode then
            print("BankMail: Setting up right-click menu")
        end

        -- Set up for right clicks
        MailFrameTab2:EnableMouse(true)
        MailFrameTab2:RegisterForClicks("AnyUp")

        -- Add the right-click handler
        MailFrameTab2:SetScript("OnMouseDown", function(self, button)
            if button == "RightButton" then
                if BankMailDB.debugMode then
                    print("BankMail: Right click detected!")
                end

                -- Create menu items
                local menuFrame = CreateFrame("Frame", "BankMailDropDownMenu", UIParent, "UIDropDownMenuTemplate")
                -- Rest of menu creation code...

                if BankMailDB.debugMode then
                    print("BankMail: Menu created")
                end
            end
        end)

        MailFrameTab2.bmHooked = true
        if BankMailDB.debugMode then
            print("BankMail: Hook completed")
        end
    else
        if BankMailDB.debugMode then
            print("BankMail: Tab was already hooked")
        end
    end
end

-- CheckAndSwitchTab function
local function CheckAndSwitchTab()
    if BankMailDB.debugMode then
        print("BankMail: CheckAndSwitchTab called")
        print("BankMail: Current Session:", currentMailSession)
        print("BankMail: Mail Frame Visible:", MailFrame:IsVisible())
        print("BankMail: Has Unread Mail:", HasUnreadMail())
    end

    if not BankMailDB.enabled then
        if BankMailDB.debugMode then
            print("BankMail: Addon is disabled")
        end
        return
    end

    if not currentMailSession then
        if BankMailDB.debugMode then
            print("BankMail: Already in current session, skipping switch")
        end
        return
    end

    -- Cancel any pending timer
    if mailLoadTimer then
        mailLoadTimer:Cancel()
        mailLoadTimer = nil
    end

    -- Check if we should disable auto-switch for bank character
    if BankMailDB.disableAutoSwitchOnBank and IsCurrentCharacterBank() then
        if BankMailDB.debugMode then
            print("BankMail: Auto-switch disabled for bank character")
        end
        return
    end

    mailLoadTimer = C_Timer.NewTimer(0.3, function()
        if MailFrame:IsVisible() then
            if not HasUnreadMail() then
                MailFrameTab2:Click()

                -- Auto-fill recipient if one is set
                local recipient = GetDefaultRecipient()
                if recipient and SendMailNameEditBox and SendMailNameEditBox:GetText() == "" then
                    SendMailNameEditBox:SetText(recipient)
                    SendMailSubjectEditBox:SetFocus()
                end

                -- Set session flag after first switch
                currentMailSession = true
            end
        end
        mailLoadTimer = nil
    end)
end

-- Update the StartMailLoad and FinishMailLoad functions
local function StartMailLoad()
    if BankMailDB.debugMode then
        print("BankMail: Starting mail load")
    end
    if mailLoadTimer then
        mailLoadTimer:Cancel()
        mailLoadTimer = nil
    end
end

local function FinishMailLoad()
    if BankMailDB.debugMode then
        print("BankMail: Finishing mail load")
        print("BankMail: Status:")
        print("BankMail: - Addon Enabled:", BankMailDB.enabled)
        print("BankMail: - Mail Frame Visible:", MailFrame:IsVisible())
        print("BankMail: - Has Unread Mail:", HasUnreadMail())
        print("BankMail: - Is Bank Character:", IsCurrentCharacterBank())
        print("BankMail: - Auto-switch Disabled for Bank:", BankMailDB.disableAutoSwitchOnBank)
    end
    CheckAndSwitchTab()
end

-- Slash command handler
local function HandleSlashCommand(msg)
    local command, arg = msg:match("^(%S*)%s*(.-)$")
    command = command:lower()

    if command == "toggle" then
        BankMailDB.enabled = not BankMailDB.enabled
        print("BankMail: " .. (BankMailDB.enabled and "Enabled" or "Disabled"))
    elseif command == "set" and arg ~= "" then
        SetAccountDefaultRecipient(arg)
    elseif command == "setcharacter" and arg ~= "" or command == "sc" and arg ~= "" then
        SetCharacterDefaultRecipient(arg)
    elseif command == "clear" then
        local charKey = GetCharacterKey()
        BankMailDB.characterRecipients[charKey] = nil
        print("BankMail: Cleared character-specific recipient for " .. charKey)
    elseif command == "clearaccount" then
        BankMailDB.accountDefaultRecipient = nil
        print("BankMail: Cleared account-wide default recipient")
    elseif command == "show" then
        local charKey = GetCharacterKey()
        local charRecipient = BankMailDB.characterRecipients[charKey]
        local accountRecipient = BankMailDB.accountDefaultRecipient

        if accountRecipient then
            print("BankMail: Account-wide default recipient: " .. accountRecipient)
        else
            print("BankMail: No account-wide default recipient set")
        end

        if charRecipient then
            print("BankMail: Character-specific recipient for " .. charKey .. ": " .. charRecipient)
        else
            print("BankMail: No character-specific recipient set for " .. charKey)
        end

        local effective = GetDefaultRecipient()
        if effective then
            print("BankMail: Currently using recipient: " .. effective)
        end
    else
        print("BankMail commands:")
        print("/bank toggle - Enable/disable automatic tab switching")
        print("/bank set CharacterName - Set account-wide default recipient")
        print("/bank setcharacter CharacterName - Set character-specific default recipient")
        print("/bank sc CharacterName - Short version of setcharacter")
        print("/bank clearaccount - Clear account-wide default recipient")
        print("/bank clear - Clear character-specific recipient")
        print("/bank show - Show current recipient settings")
    end
end

-- Register slash commands
SLASH_BANKMAIL1 = "/bankmail"
SLASH_BANKMAIL2 = "/bank"
SlashCmdList["BANKMAIL"] = HandleSlashCommand

-- Function to take all attachments from a mail
local function TakeAllAttachments(mailIndex)
    local hasItem = select(8, GetInboxHeaderInfo(mailIndex))
    if not hasItem then return end

    if BankMailDB.debugMode then
        print("BankMail: Starting mail", mailIndex)
    end

    -- First, scan the mail to know what we're dealing with
    local attachments = {}
    for i = 1, ATTACHMENTS_MAX_RECEIVE do
        local name, _, _, count = GetInboxItem(mailIndex, i)
        if name then
            table.insert(attachments, {
                slot = i,
                name = name,
                count = count or 0
            })
            if BankMailDB.debugMode then
                print(string.format("BankMail: Found slot %d: %s x%d", i, name, count or 0))
            end
        end
    end

    -- Take money if present
    local _, _, _, _, money = GetInboxHeaderInfo(mailIndex)
    if money and money > 0 then
        TakeInboxMoney(mailIndex)
    end

    -- Take items one at a time, waiting for confirmation
    local currentIndex = 1

    local function TakeNext()
        if currentIndex > #attachments then
            print("BankMail Debug: Finished taking all items")
            return
        end

        local item = attachments[currentIndex]
        print(string.format("Taking slot %d: %s x%d", item.slot, item.name, item.count))

        -- Take the item
        TakeInboxItem(mailIndex, item.slot)

        -- Wait for the MAIL_INBOX_UPDATE event before proceeding
        local function WaitForUpdate()
            -- Check if item was actually taken
            local newName = select(1, GetInboxItem(mailIndex, item.slot))
            if newName == item.name then
                -- Item still exists, wait a bit and try again
                C_Timer.After(0.3, WaitForUpdate)
            else
                -- Item was taken, move to next after a short delay
                currentIndex = currentIndex + 1
                C_Timer.After(0.3, TakeNext)
            end
        end

        -- Start waiting for update
        C_Timer.After(0.3, WaitForUpdate)
    end

    -- Start the process
    TakeNext()
end

-- Hook function for mail item buttons
local function HookInboxButtons()
    for i = 1, 7 do
        local button = _G["MailItem" .. i .. "Button"]
        if button then
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            button:HookScript("OnClick", function(self, buttonName)
                if buttonName == "RightButton" then
                    local mailIndex = self.index
                    if mailIndex then
                        TakeAllAttachments(mailIndex)
                    end
                end
                -- Left click retains default behavior
            end)
        end
    end
end

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if BankMailDB.debugMode then
        print("BankMail: Event fired:", event)
    end

    if event == "PLAYER_LOGIN" then
        BankMail_Money:Init()
    elseif event == "MAIL_SHOW" then
        if BankMailDB.debugMode then
            print("BankMail: Mail show - current session:", currentMailSession)
        end
        StartMailLoad()
        HookInboxButtons()
        HookSendMailTab()
    elseif event == "MAIL_INBOX_UPDATE" then
        FinishMailLoad()
    elseif event == "MAIL_CLOSED" then
        if BankMailDB.debugMode then
            print("BankMail: Mail closed - resetting session")
        end
        currentMailSession = false
    end
end)

-- Create the module
local addonName = "BankMail"
local AutoSwitch = {
    initialized = false,
    mailLoadTimer = nil,
    currentMailSession = false
}
_G[addonName .. "_AutoSwitch"] = AutoSwitch

-- Local variables
local currentRealm
local currentChar

-- Helper function to check if current character is the bank character
local function IsCurrentCharacterBank()
    local currentCharKey = AutoSwitch:GetCharacterKey()
    local bankChar = BankMailDB.accountDefaultRecipient

    -- If bank character doesn't include realm, append current realm
    if bankChar and not bankChar:find("-") then
        bankChar = bankChar .. "-" .. currentRealm
    end

    return bankChar and currentCharKey == bankChar
end

-- Function to get current character's full name
function AutoSwitch:GetCharacterKey()
    return currentChar .. "-" .. currentRealm
end

-- Function to get default recipient for current character
function AutoSwitch:GetDefaultRecipient()
    local charKey = self:GetCharacterKey()
    -- First check character-specific recipient
    if BankMailDB.characterRecipients[charKey] then
        return BankMailDB.characterRecipients[charKey]
    end
    -- Fall back to account-wide default
    return BankMailDB.accountDefaultRecipient
end

-- Helper function to ensure clean UI state
local function CleanupMailFrameState()
    -- Hide all potential overlapping elements
    if InboxFrame then
        InboxFrame:Hide()
    end
    if SendMailFrame then
        SendMailFrame:Hide()
    end

    -- Reset tab highlights
    if MailFrameTab1 then
        PanelTemplates_DeselectTab(MailFrameTab1)
    end
    if MailFrameTab2 then
        PanelTemplates_DeselectTab(MailFrameTab2)
    end
end

-- Function to check for unread mail
local function HasUnreadMail()
    local numItems = GetInboxNumItems()
    for i = 1, numItems do
        -- Get full header info
        local _, _, sender, subject, money, _, daysLeft, _, wasRead = GetInboxHeaderInfo(i)

        -- Debug logging if enabled
        if BankMailDB and BankMailDB.debugMode then
            print(string.format("BankMail Debug: Mail %d - From: %s, Subject: %s, Money: %s, Read: %s",
                i, sender or "nil", subject or "nil", tostring(money), tostring(wasRead)))
        end

        -- If header info isn't fully loaded yet, consider it as having unread mail
        if not wasRead or wasRead == nil then
            -- Additional check: if it's auction mail, wait for full details
            if subject and (subject:find("Auction") or subject:find("auction")) then
                if BankMailDB and BankMailDB.debugMode then
                    print("BankMail Debug: Found unread auction mail, waiting for details")
                end
                return true
            end

            -- For non-auction mail, proceed with normal unread check
            if wasRead == false then
                return true
            end
        end
    end
    return false
end

-- Function to auto-fill recipient
function AutoSwitch:AutoFillRecipient()
    if not BankMailDB.enabled then return end

    -- Check if we should disable auto-fill for bank character
    if not BankMailDB.enableAutoSwitchOnBank and IsCurrentCharacterBank() then
        if BankMailDB.debugMode then
            print("BankMail: Auto-fill disabled for bank character")
        end
        return
    end

    -- Only auto-fill if the recipient field is empty
    if SendMailNameEditBox and SendMailNameEditBox:GetText() == "" then
        local recipient = self:GetDefaultRecipient()
        if recipient then
            SendMailNameEditBox:SetText(recipient)
            -- Add delay before focusing subject box
            C_Timer.After(0.1, function()
                if SendMailSubjectEditBox then
                    SendMailSubjectEditBox:SetFocus()
                end
            end)
        end
    end
end

-- Function to format money amount as text
local function FormatMoneyText(copper)
    if not copper or copper == 0 then return "0c" end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local remainingCopper = copper % 100

    local parts = {}
    if gold > 0 then table.insert(parts, gold .. "g") end
    if silver > 0 then table.insert(parts, silver .. "s") end
    if remainingCopper > 0 then table.insert(parts, remainingCopper .. "c") end

    return table.concat(parts, " ")
end

-- Function to auto-fill subject when money is attached
local function AutoFillMoneySubject()
    if not BankMailDB or not BankMailDB.enabled or BankMailDB.enableCoinSubject == false then return end

    local currentSubject = SendMailSubjectEditBox:GetText()
    -- Proceed if subject is empty or matches our coin format
    if currentSubject ~= "" and not currentSubject:match("^coin: .*[gsc]$") then return end

    local moneyAmount = MoneyInputFrame_GetCopper(SendMailMoney)
    if moneyAmount and moneyAmount > 0 then
        SendMailSubjectEditBox:SetText("coin: " .. FormatMoneyText(moneyAmount))
    end
end

-- CheckAndSwitchTab function
function AutoSwitch:CheckAndSwitchTab()
    -- Validate requirements before proceeding
    if not BankMailDB or not BankMailDB.enabled then
        return
    end

    if not currentRealm or not currentChar then
        if BankMailDB.debugMode then
            print("BankMail: Missing character data, aborting tab switch")
        end
        return
    end

    if not MailFrame:IsVisible() then
        return
    end

    -- Don't switch if we're already in a mail session
    if self.currentMailSession then
        if BankMailDB.debugMode then
            local now = time()
            local sessionAge = now - self.currentMailSession
            local startTime = date("[%I:%M:%S %p]", self.currentMailSession)
            local currentTime = date("[%I:%M:%S %p]", now)
            print(string.format(
                "BankMail: Mail session active since %s (current time %s, %d seconds ago), skipping auto-switch",
                startTime, currentTime, sessionAge))
        end
        return
    end

    if BankMailDB.debugMode then
        print("BankMail: Starting fresh mail session check at " .. date("[%I:%M:%S %p]"))
    end

    -- Cancel any pending timer
    if self.mailLoadTimer then
        self.mailLoadTimer:Cancel()
        self.mailLoadTimer = nil
    end

    -- Check if we should disable auto-switch for bank character
    if BankMailDB.disableAutoSwitchOnBank and IsCurrentCharacterBank() then
        if BankMailDB.debugMode then
            print("BankMail: Auto-switch disabled for bank character")
        end
        return
    end

    -- Set up new timer with error handling
    self.mailLoadTimer = C_Timer.NewTimer(0.3, function()
        if not MailFrame:IsVisible() then return end

        -- First check if mail data is still loading
        local numItems = GetInboxNumItems()
        if numItems > 0 then
            local _, _, _, subject = GetInboxHeaderInfo(1)
            if not subject then
                -- Mail data still loading, try again shortly
                if BankMailDB and BankMailDB.debugMode then
                    print("BankMail Debug: Mail data still loading, retrying...")
                end
                C_Timer.After(0.2, function()
                    self:CheckAndSwitchTab()
                end)
                return
            end
        end

        if not HasUnreadMail() then
            -- Clean up UI state before switching
            CleanupMailFrameState()

            C_Timer.After(0.05, function()
                if MailFrameTab2 then
                    MailFrameTab2:Click()
                    C_Timer.After(0.1, function()
                        self:AutoFillRecipient()
                    end)
                end
            end)
        else
            if BankMailDB and BankMailDB.debugMode then
                print("BankMail Debug: Unread mail detected, staying on inbox tab")
            end
        end

        self.currentMailSession = time()
        self.mailLoadTimer = nil
    end)
end

function AutoSwitch:StartMailLoad()
    if BankMailDB.debugMode then
        print("BankMail: Starting mail load - resetting session from " ..
            (self.currentMailSession and date("[%I:%M:%S %p]", self.currentMailSession) or "nil"))
    end

    -- Reset session state when starting a new mail load
    self.currentMailSession = nil

    if self.mailLoadTimer then
        self.mailLoadTimer:Cancel()
        self.mailLoadTimer = nil
    end
end

function AutoSwitch:FinishMailLoad()
    if BankMailDB.debugMode then
        print("BankMail: Finishing mail load")
        print("BankMail: Status:")
        print("BankMail: - Addon Enabled:", BankMailDB.enabled)
        print("BankMail: - Mail Frame Visible:", MailFrame:IsVisible())
        print("BankMail: - Has Unread Mail:", HasUnreadMail())
        print("BankMail: - Is Bank Character:", IsCurrentCharacterBank())
        print("BankMail: - Auto-switch Disabled for Bank:", BankMailDB.disableAutoSwitchOnBank)
    end
    self:CheckAndSwitchTab()
end

-- Initialize module
function AutoSwitch:Init()
    if self.initialized then
        print("BankMail AutoSwitch: Already initialized")
        return
    end

    -- Initialize character and realm data
    currentRealm = GetRealmName()
    currentChar = UnitName("player")

    -- Hook the mail tab buttons to ensure auto-fill happens when manually switching tabs
    if MailFrameTab2 then
        MailFrameTab2:HookScript("OnClick", function()
            C_Timer.After(0.1, function()
                AutoSwitch:AutoFillRecipient()
            end)
        end)
    end

    -- Hook money input fields for subject autofill
    if SendMailMoneyGold then
        SendMailMoneyGold:HookScript("OnTextChanged", AutoFillMoneySubject)
    end
    if SendMailMoneySilver then
        SendMailMoneySilver:HookScript("OnTextChanged", AutoFillMoneySubject)
    end
    if SendMailMoneyCopper then
        SendMailMoneyCopper:HookScript("OnTextChanged", AutoFillMoneySubject)
    end

    if BankMailDB.debugMode then
        print("BankMail AutoSwitch: Initialized for", currentChar, "on", currentRealm)
    end

    self.initialized = true
end

return AutoSwitch

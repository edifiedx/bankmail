-- Create the module
local addonName = "BankMail"
local Debug = _G[addonName .. "_Debug"]
local AutoSwitch = {
    initialized = false,
    mailLoadTimer = nil,
    currentMailSession = nil
}
_G[addonName .. "_AutoSwitch"] = AutoSwitch

-- Local variables
local debug = Debug:CreateDebugger("AutoSwitch")
local currentRealm = GetRealmName()
local currentChar = UnitName("player")
local isInitialLoad = false

-- Helper function to check if current character is the bank character
local function IsCurrentCharacterBank()
    local currentCharKey = currentChar .. "-" .. currentRealm
    local bankChar = BankMailDB.accountDefaultRecipient

    -- If bank character doesn't include realm, append current realm
    if bankChar and not bankChar:find("-") then
        bankChar = bankChar .. "-" .. currentRealm
    end

    return bankChar and currentCharKey == bankChar
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

        debug("Mail " .. i .. " - From: " .. (sender or "nil") .. ", Subject: " .. (subject or "nil") .. ", Money: " .. tostring(money) .. ", Read: " .. tostring(wasRead))

        -- If header info isn't fully loaded yet, consider it as having unread mail
        if not wasRead or wasRead == nil then
            -- Additional check: if it's auction mail, wait for full details
            if subject and (subject:find("Auction") or subject:find("auction")) then
                debug("Found unread auction mail, waiting for details")
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

-- CheckAndSwitchTab function
function AutoSwitch:CheckAndSwitchTab()
    -- Validate requirements before proceeding
    if not BankMailDB or not BankMailDB.enabled then
        return
    end

    if not MailFrame:IsVisible() then
        return
    end

    -- Check if we should disable auto-switch for bank character
    if not BankMailDB.enableAutoSwitchOnBank and IsCurrentCharacterBank() then
        debug("Auto-switch disabled for bank character")
        return
    end

    -- Cancel any pending timer
    if self.mailLoadTimer then
        self.mailLoadTimer:Cancel()
        self.mailLoadTimer = nil
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
                debug("Mail data still loading, retrying...")
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
                end
            end)
        else
            debug("Unread mail detected, staying on inbox tab")
        end

        self.mailLoadTimer = nil
    end)
end

function AutoSwitch:StartMailLoad()
    debug("Starting mail load")

    if self.mailLoadTimer then
        self.mailLoadTimer:Cancel()
        self.mailLoadTimer = nil
    end

    -- Set initial load flag
    isInitialLoad = true

    -- Set up a timeout to clear initial load state
    C_Timer.After(2.0, function()
        if isInitialLoad then
            debug("Initial load timeout reached, clearing state")
            isInitialLoad = false
        end
    end)
end

function AutoSwitch:FinishMailLoad()
    -- Only proceed if we're in initial load
    if not isInitialLoad then
        debug("Ignoring mail update - not in initial load")
        return
    end

    debug("Finishing initial mail load. Status:")
    debug("Mail Load Timer:" .. tostring(self.mailLoadTimer))
    debug("Mail Frame Visible:" .. tostring(MailFrame:IsVisible()))
    -- debug("Addon Enabled:" .. BankMailDB.enabled)
    -- debug("Has Unread Mail:" .. HasUnreadMail())
    -- debug("Is Bank Character:" .. IsCurrentCharacterBank())
    -- debug("Auto-switch Disabled for Bank:" .. not BankMailDB.enableAutoSwitchOnBank)

    -- Clear initial load state
    isInitialLoad = false

    -- Perform the tab switch check
    self:CheckAndSwitchTab()
end

-- Initialize module
function AutoSwitch:Init()
    if self.initialized then
        print("BankMail AutoSwitch: Already initialized")
        return
    end

    debug("Initialized for" .. currentChar .. "on" .. currentRealm)

    self.initialized = true
end

return AutoSwitch -- Check if we're in an active mail session

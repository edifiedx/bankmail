print("Loading Options, BankMailDB exists:", BankMailDB ~= nil)

local addonName = "BankMail"
local Options = {
    Panel = CreateFrame("Frame")
}
_G[addonName .. "_Options"] = Options

local panel = Options.Panel
panel.name = "BankMail"
panel:Hide()

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Options.Category = category

-- Counter for unique checkbox names (like KillTrack does)
local checkCounter = 0

local function checkbox(label, description, onclick)
    local check = CreateFrame(
        "CheckButton",
        "BankMailOptCheck" .. checkCounter,
        panel,
        "InterfaceOptionsCheckButtonTemplate"
    )
    check:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        onclick(self, checked and true or false)
    end)
    check.label = _G[check:GetName() .. "Text"]
    check.label:SetText(label)
    check.tooltipText = label
    check.tooltipRequirement = description
    checkCounter = checkCounter + 1
    return check
end

function Options.Show(self)
    local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BankMail Options")

    -- Enable/Disable checkbox
    local enableAddon = checkbox("Enable BankMail",
        "Enable or disable automatic mail tab switching",
        function(_, checked)
            BankMailDB.enabled = checked
            print("BankMail: " .. (checked and "Enabled" or "Disabled"))
        end)
    enableAddon:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -16)

    -- Bank Character label and input
    local bankCharLabel = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    bankCharLabel:SetPoint("TOPLEFT", enableAddon, "BOTTOMLEFT", 2, -8)
    bankCharLabel:SetTextColor(1, 1, 1)
    bankCharLabel:SetText("Default Bank Character (press enter to apply)")

    local bankCharInput = CreateFrame("EditBox", "BankMailOptBankChar", panel, "InputBoxTemplate")
    bankCharInput:SetHeight(22)
    bankCharInput:SetWidth(150)
    bankCharInput:SetPoint("TOPLEFT", bankCharLabel, "BOTTOMLEFT", 2, -8)
    bankCharInput:SetAutoFocus(false)
    bankCharInput:EnableMouse(true)

    -- Setup autocomplete
    bankCharInput.autoCompleteFunction = GetAutoCompleteResults
    bankCharInput.autoCompleteParams = { include = AUTOCOMPLETE_LIST.MAIL }
    AutoCompleteEditBox_SetAutoCompleteSource(bankCharInput, GetAutoCompleteResults)
    bankCharInput:SetScript("OnTabPressed", AutoCompleteEditBox_OnTabPressed)
    bankCharInput:SetScript("OnTextChanged", AutoCompleteEditBox_OnTextChanged)
    bankCharInput:SetScript("OnEditFocusLost", AutoCompleteEditBox_OnEditFocusLost)

    bankCharInput:SetScript("OnEscapePressed", function(self)
        self:SetText(BankMailDB.accountDefaultRecipient or "")
        self:ClearFocus()
    end)
    bankCharInput:SetScript("OnEnterPressed", function(self)
        local value = self:GetText()
        if value and value ~= "" then
            SetAccountDefaultRecipient(value)
        end
        self:ClearFocus()
    end)

    -- Auto-switch toggle
    local disableAutoSwitch = checkbox("Disable Auto-Switch for Bank Character",
        "Disable automatic tab switching when on the bank character",
        function(_, checked)
            if not BankMailDB then BankMailDB = {} end
            BankMailDB.disableAutoSwitchOnBank = checked
            print("BankMail: Auto-switch for bank character " .. (checked and "disabled" or "enabled"))
        end)
    disableAutoSwitch:SetPoint("TOPLEFT", bankCharInput, "BOTTOMLEFT", -2, -8)

    -- Debug mode toggle
    local debugMode = checkbox("Debug Mode",
        "Enable debug logging",
        function(_, checked)
            if not BankMailDB then BankMailDB = {} end
            BankMailDB.debugMode = checked
            print("BankMail: Debug mode " .. (checked and "enabled" or "disabled"))
        end)
    debugMode:SetPoint("TOPLEFT", disableAutoSwitch, "BOTTOMLEFT", 0, -8)

    local function init()
        if not BankMailDB then BankMailDB = {} end
        BankMailDB.enabled = BankMailDB.enabled ~= nil and BankMailDB.enabled or true
        BankMailDB.disableAutoSwitchOnBank = BankMailDB.disableAutoSwitchOnBank ~= nil and
            BankMailDB.disableAutoSwitchOnBank or true
        BankMailDB.debugMode = BankMailDB.debugMode ~= nil and BankMailDB.debugMode or false

        enableAddon:SetChecked(BankMailDB.enabled)
        bankCharInput:SetText(BankMailDB.accountDefaultRecipient or "")
        disableAutoSwitch:SetChecked(BankMailDB.disableAutoSwitchOnBank)
        debugMode:SetChecked(BankMailDB.debugMode)
    end

    init()
    self:SetScript("OnShow", init)
end

panel:SetScript("OnShow", function(self)
    Options.Show(self)
end)

Settings.RegisterAddOnCategory(category)

return Options

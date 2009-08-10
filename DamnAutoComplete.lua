--[[
	Damn Auto Complete by Shadowed
]]

local DAC = {}
local enteredText, lastChar

local L = DamnAutoCompleteLocals

-- Frame names -> type
local frameTypes = {
	["ChatFrameEditBox"] = "chat",
	["CalendarCreateEventInviteEdit"] = "calendar",
	["SendMailNameEditBox"] = "mail",
	["StaticPopup1EditBox"] = "popup",
	["StaticPopup2EditBox"] = "popup",
	["StaticPopup3EditBox"] = "popup",
	["StaticPopup4EditBox"] = "popup",
}

-- Keeps auto complete happy and working
local function OnChar(self, char, ...)
	self.DACTextChanged = true
	lastChar = char
	
	if( self.DACOnChar ) then
		return self.DACOnChar(self, char, ...)
	end
end

function DAC:ADDON_LOADED(event, addon)
	-- Addon loaded, setup hooks, DB and all that good stuff
	if( addon == "DamnAutoComplete" ) then
		DamnAutoCompleteDB = DamnAutoCompleteDB or {
			original = {["mail"] = true, ["calendar"] = true, ["popup"] = true},
			window = {["calendar"] = true, ["mail"] = true, ["popup"] = true, ["chat"] = true}
		}
		
		local _G = getfenv(0)
		for name, type in pairs(frameTypes) do
			local frame = _G[name]
			if( frame and type ~= "chat" ) then
				frame.DACOnChar = frame:GetScript("OnChar")
				frame:SetScript("OnChar", OnChar)
			end
		end

	-- As Calendar is LoD, have to wait for it to load before it's hooked
	elseif( addon == "Blizzard_Calendar" ) then
		CalendarCreateEventInviteEdit.DACOnChar = CalendarCreateEventInviteEdit:GetScript("OnChar")
		CalendarCreateEventInviteEdit:SetScript("OnChar", OnChar)
	end
end

-- This is where we will disable auto complete frame
local Orig_AutoComplete_Update = AutoComplete_Update
function AutoComplete_Update(parent, text, ...)
	if( parent.autoCompleteParams ) then
		-- It's disabled no matter what, so stop quickly
		local type = frameTypes[parent:GetName() or ""]
		if( type and DamnAutoCompleteDB.window[type] and not DamnAutoCompleteDB.original[type] ) then
			AutoComplete_HideIfAttachedTo(parent)
			return
		end
		
		-- Will hook OnChar so we know the text actually changed, and we can use the original method of auto completing
		enteredText = parent.DACTextChanged and text
		parent.DACTextChanged = nil
	end
	
	return Orig_AutoComplete_Update(parent, text, ...)
end

local Orig_AutoComplete_UpdateResults = AutoComplete_UpdateResults
AutoComplete_UpdateResults = function(self, ...)
	local parent = self.parent
	if( parent ) then
		-- Supposed to use the original auto complete
		local type = frameTypes[parent:GetName() or ""]
		if( type and DamnAutoCompleteDB.original[type] ) then
			-- Is the first result a match?
			local name = select(1, ...)
			if( name and enteredText and string.find(string.lower(name), string.lower(enteredText), 1, 1) == 1 ) then
				parent:SetText(name)

				-- IME = Using a different localization so need to slightly alter our method of highlighting
				if( parent:IsInIMECompositionMode() ) then
					parent:HighlightText(string.len(enteredText) - strlen(lastChar), -1)
				else
					parent:HighlightText(string.len(enteredText), -1)
				end
			end
		end
		
		-- We're supposed to hide the auto complete window too
		if( DamnAutoCompleteDB.window[type] ) then
			AutoComplete_HideIfAttachedTo(parent)
			return
		end
	end
	
	return Orig_AutoComplete_UpdateResults(self, ...)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
	DAC[event](DAC, event, ...)
end)

DAC.frame = frame

function DAC:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99Damn Auto Complete|r: " .. msg)
end

-- Slash commands
SLASH_DAMNAUTOCOMPETE1 = "/damnautocomplete"
SLASH_DAMNAUTOCOMPETE2 = "/autocomplete"
SlashCmdList["DAMNAUTOCOMPETE"] = function(msg)
	local cmd, arg = string.split(" ", msg or "", 2)
	cmd = string.lower(cmd or "")
	
	if( cmd == "original" and arg ) then
		arg = string.lower(arg)
		
		if( arg == "chat" ) then
			DAC:Print(L["You cannot enable original style auto completing for chat."])
		elseif( not L.types[arg] ) then
			DAC:Print(string.format(L["Invalid input type \"%s\" entered."], arg))
			return
		end
		
		DamnAutoCompleteDB.original[arg] = not DamnAutoCompleteDB.original[arg]
		
		if( DamnAutoCompleteDB.original[arg] ) then
			DAC:Print(string.format(L["Enabled original auto completion for %s!"], L.types[arg]))
		else
			DAC:Print(string.format(L["Disabled original auto completion for %s."], L.types[arg]))
		end
	
	elseif( cmd == "window" and arg ) then
		arg = string.lower(arg)
		if( not L.types[arg] ) then
			DAC:Print(string.format(L["Invalid input type \"%s\" entered."], arg))
			return
		end
		
		DamnAutoCompleteDB.window[arg] = not DamnAutoCompleteDB.window[arg]
		
		if( DamnAutoCompleteDB.window[arg] ) then
			DAC:Print(string.format(L["Disabled auto complete window for %s."], L.types[arg]))
		else
			DAC:Print(string.format(L["Enabled auto complete window for %s!"], L.types[arg]))
		end
	elseif( cmd == "list" ) then
		DAC:Print(L["Listing current settings"])
		
		for type in pairs(L.types) do
			local original = DamnAutoCompleteDB.original[type] and GREEN_FONT_COLOR_CODE .. L["enabled"] .. "|r" or RED_FONT_COLOR_CODE .. L["disabled"] .. "|r"
			local window = DamnAutoCompleteDB.window[type] and RED_FONT_COLOR_CODE .. L["disabled"] .. "|r" or GREEN_FONT_COLOR_CODE .. L["enabled"] .. "|r"
			DEFAULT_CHAT_FRAME:AddMessage(string.format(L["%s: Original auto complete %s / Auto complete window %s"], type, original, window))
		end
	else
		DAC:Print(L["Slash commands"])
		DEFAULT_CHAT_FRAME:AddMessage(L["/autocomplete window <chat/popoup/mail/calendar> - Toggles the auto complete window for the passed input type."])
		DEFAULT_CHAT_FRAME:AddMessage(L["/autocomplete original <popoup/mail/calendar> - Toggles the original style of auto completing for the passed input type."])
		DEFAULT_CHAT_FRAME:AddMessage(L["/autocomplete list - Lists your current settings"])
	end
end


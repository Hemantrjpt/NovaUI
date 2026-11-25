--[[
    MacUI + Junkie key system
    UI:  https://github.com/Ngducok/MacUI-luau
    SDK: https://jnkie.com/sdk/library.lua  (check_key / get_key_link / load_script)

    Fill in CONFIG.Junkie with your dashboard values.
]]

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------
local CONFIG = {
	Name     = "TITANIC HUB",
	Subtitle = "Key System",
	FileName = "TitanicHub_key.txt",   -- local saved key

	Junkie = {
		Service    = "Premium",
		Identifier = "1165534",
		Provider   = "Premium",   -- used by Get Key
		ScriptId   = "3457fe2a430a1bd28a2d87f199af3a4df912314a8f8c6c42923d2e2942aae29a", -- public token of the protected script
	},

	-- true  = this file is a standalone loader: after a valid key it calls Junkie.load_script().
	-- false = this UI is the "UI Source" INSIDE the protected script: it must NOT call
	--         load_script() (it would load itself again); it just lets execution continue.
	LoadProtectedScript = true,

	Links = {
		Buy     = "https://discord.gg/titanichub",             -- shop link
		Discord = "https://discord.gg/titanichub",
	},

	MaxAttempts = 5,   -- failed tries before lockout
	LockSeconds = 30,
}

----------------------------------------------------------------------
-- SDK
----------------------------------------------------------------------
local Junkie = loadstring(game:HttpGet("https://jnkie.com/sdk/library.lua"))()
Junkie.service    = CONFIG.Junkie.Service
Junkie.identifier = CONFIG.Junkie.Identifier
Junkie.provider   = CONFIG.Junkie.Provider
Junkie.script_id  = CONFIG.Junkie.ScriptId

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function copy(text)
	local fn = setclipboard or toclipboard or (Clipboard and Clipboard.set)
	if fn then
		return (pcall(fn, text))
	end
	return false
end

local function saveKey(key)
	if writefile then pcall(writefile, CONFIG.FileName, key) end
end

local function loadSavedKey()
	if isfile and readfile then
		local ok, has = pcall(isfile, CONFIG.FileName)
		if ok and has then
			local ok2, v = pcall(readfile, CONFIG.FileName)
			if ok2 and v then return (tostring(v):gsub("%s+", "")) end
		end
	end
	return ""
end

local function clearSavedKey()
	if delfile then pcall(delfile, CONFIG.FileName) end
end

-- Runs after the key is accepted (and after load_script if enabled).
local function OnSuccess(key, result)
	-- put extra logic here, e.g. check result.JD_TIER == "elite"
end

----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Ngducok/MacUI-luau/main/dist/MacUI.luau"))()

local Window = UI:CreateWindow({
	Subtitle = CONFIG.Subtitle,
	Size = UDim2.fromOffset(500, 400),
	MinSize = Vector2.new(380, 320),
	ToggleKey = Enum.KeyCode.RightShift,
	Resizable = false,
	Draggable = true,
	Account = { Enabled = false },
})
pcall(function() Window:SetTitle(CONFIG.Name, CONFIG.Subtitle) end)

local Page = Window:AddPage({
	Id = "key",
	Title = "Key",
	Description = "Enter your key to continue",
	Icon = "person",
})

local Entry = Page:AddSection({ Title = "Authentication" })
local Card = Entry:AddCard({
	Id = "key-card",
	Title = "License key",
	Description = "Paste your key below, then press Verify.",
	Icon = "person",
	Searchable = false,
})

local keyInput = Card:AddInput({
	Id = "key-input",
	Title = "Key",
	Placeholder = "Paste your key",
	Width = 250,
	Clearable = true,
})

local status = Card:AddStatus({ Title = "Status", Value = "Waiting for key", Kind = "Neutral" })

local busy, fails, lockedUntil, finished = false, 0, 0, false

local function readKey()
	local raw = (keyInput.field and keyInput.field.Text) or keyInput:GetValue() or ""
	return (tostring(raw):gsub("%s+", ""))
end

local function attempt(key, silent)
	if busy or finished then return end
	if key == "" then
		status:SetValue("Enter a key first", "Warning")
		return
	end
	if os.clock() < lockedUntil then
		status:SetValue(("Locked, wait %ds"):format(math.ceil(lockedUntil - os.clock())), "Danger")
		return
	end

	busy = true
	Card:SetLoading(true)
	status:SetValue("Checking key...", "Accent")

	-- check_key can yield and can raise, so always pcall it
	local ok, result = pcall(Junkie.check_key, key)

	Card:SetLoading(false)
	busy = false

	if not ok or type(result) ~= "table" then
		status:SetValue("Request failed, try again", "Warning")
		if not silent then
			Window:Notify({ Title = "Request failed", Content = "Could not reach the key server.", Kind = "warning", Duration = 3 })
		end
		return
	end

	if result.valid then
		finished = true
		saveKey(key)
		local tier = result.JD_TIER_NAME or (result.is_premium and "Premium" or "Standard")
		status:SetValue("Key valid (" .. tier .. ")", "Success")
		Window:Notify({ Title = "Key accepted", Content = "Tier: " .. tier, Kind = "success", Duration = 3 })
		task.wait(1)
		Window:Destroy()

		getgenv().SCRIPT_KEY = key
		task.spawn(function()
			if CONFIG.LoadProtectedScript then
				local lok, lerr = pcall(Junkie.load_script)
				if not lok then warn("[" .. CONFIG.Name .. "] load_script failed: " .. tostring(lerr)) end
			end
			OnSuccess(key, result)
		end)
		return
	end

	local err = tostring(result.error or "Invalid key")
	local transient = err == "ERROR" or err:find("^http") ~= nil
	local msg = if err == "http 429" then "Too many requests, wait a bit" else err
	status:SetValue(msg, if transient then "Warning" else "Danger")
	if not silent then
		Window:Notify({ Title = "Key rejected", Content = msg, Kind = "error", Duration = 3 })
	end
	if transient then return end

	clearSavedKey()
	fails += 1
	if fails >= CONFIG.MaxAttempts then
		fails = 0
		lockedUntil = os.clock() + CONFIG.LockSeconds
		status:SetValue(("Too many attempts, locked %ds"):format(CONFIG.LockSeconds), "Danger")
	end
end

Card:AddButton({
	Title = "Verify key",
	Variant = "Primary",
	Icon = "circle-check",
	Callback = function() task.spawn(attempt, readKey()) end,
})

-- Links ----------------------------------------------------------------
local Links = Page:AddSection({ Title = "Get access", Layout = "Grid" })

local function shareLink(title, url)
	if copy(url) then
		Window:Notify({ Title = title, Content = "Link copied to clipboard", Kind = "success", Duration = 2 })
	else
		Window:Notify({ Title = title, Content = url, Kind = "info", Duration = 10 })
	end
end

-- Get Key (Junkie access flow)
local keyCard = Links:AddCard({ Title = "Get Key", Description = "Free key via the access flow", Searchable = false })
local gettingLink = false
keyCard:AddButton({
	Title = "Get link",
	Callback = function()
		if gettingLink then return end
		gettingLink = true
		keyCard:SetLoading(true)
		task.spawn(function()
			local ok, link, err = pcall(Junkie.get_key_link)
			keyCard:SetLoading(false)
			gettingLink = false
			if not ok then
				Window:Notify({ Title = "Get Key", Content = "Request failed, try again.", Kind = "warning", Duration = 3 })
			elseif link then
				shareLink("Get Key", link)
			elseif err == "RATE_LIMITTED" then -- exact SDK spelling
				Window:Notify({ Title = "Get Key", Content = "Too many requests, wait before trying again.", Kind = "warning", Duration = 3 })
			else
				Window:Notify({ Title = "Get Key", Content = "Could not create a link: " .. tostring(err), Kind = "error", Duration = 4 })
			end
		end)
	end,
})

local buyCard = Links:AddCard({ Title = "Buy Premium", Description = "Instant delivery", Searchable = false })
buyCard:AddButton({ Title = "Copy link", Callback = function() shareLink("Buy Premium", CONFIG.Links.Buy) end })

local dcCard = Links:AddCard({ Title = "Discord", Description = "Support and announcements", Searchable = false })
dcCard:AddButton({ Title = "Copy link", Callback = function() shareLink("Discord", CONFIG.Links.Discord) end })

-- Auto-check the saved key (one check per launch) ----------------------
task.spawn(function()
	local saved = loadSavedKey()
	if saved ~= "" then
		keyInput:SetValue(saved)
		attempt(saved, true)
	end
end)

return Window

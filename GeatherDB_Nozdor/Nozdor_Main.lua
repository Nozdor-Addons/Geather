if not GathererDB then GathererDB = {} end

local lib = {}
GathererDB.Nozdor = lib

lib.isLoading = true
if not Gatherer then lib.isLoading = false
elseif not Gatherer.Api then lib.isLoading = false
elseif not Gatherer.Api.AddGather then lib.isLoading = false
elseif not Gatherer.ZoneTokens then lib.isLoading = false
elseif not Gatherer.Config.AddCallback then
	DEFAULT_CHAT_FRAME:AddMessage("GeatherDB_Nozdor: Please upgrade to the latest version of Gatherer.")
	lib.isLoading = false
end

if not lib.isLoading then
	DEFAULT_CHAT_FRAME:AddMessage("GeatherDB_Nozdor: Not loading due to missing or old Gatherer.")
	return
end

local NODE_ID = 255723
local NODE_TYPE = "OPEN"

if not Gatherer.Nodes.Objects[NODE_ID] then
	Gatherer.Nodes.Objects[NODE_ID] = NODE_TYPE
end

if not Gatherer.Categories.CategoryNames[NODE_ID] then
	Gatherer.Categories.CategoryNames[NODE_ID] = "Хранилище рун"
end
if not Gatherer.Nodes.Names then Gatherer.Nodes.Names = {} end
if not Gatherer.Nodes.Names["Хранилище рун"] then
	Gatherer.Nodes.Names["Хранилище рун"] = NODE_ID
end
if not Gatherer.Nodes.Names["Nozdor Cache"] then
	Gatherer.Nodes.Names["Nozdor Cache"] = NODE_ID
end

local zonelut
local updateFrame
local co

local YIELD_AT = 30

local function beginImport()
	local curMini = Gatherer.Config.GetSetting("minimap.enable")
	local curHud = Gatherer.Config.GetSetting("hud.enable")
	Gatherer.Config.SetSetting("minimap.enable", false)
	Gatherer.Config.SetSetting("hud.enable", false)

	local position, total, counter = 0,0,0
	for zone, zdata in pairs(lib.data) do
		for node, ndata in pairs(zdata) do
			total = total + #ndata
		end
	end

	for zone, zonedef in pairs(zonelut) do
		local c,z = unpack(zonedef)
		Gatherer.Storage.RemoveGather(c, z, NODE_ID, "DB:Nozdor")
		counter = counter + 1
		if counter > YIELD_AT then
			coroutine.yield()
			counter = 0
		end
	end

	for zone, zdata in pairs(lib.data) do
		local zonedef = zonelut[zone]
		if zonedef then
			local c,z = unpack(zonedef)
			local ndata = zdata[NODE_ID]
			if ndata then
				for _, coord in ipairs(ndata) do
					local x = math.floor(coord/1000)/1000
					local y = (coord%1000)/1000
					Gatherer.Api.AddGather(NODE_ID, nil, nil, "DB:Nozdor", nil, nil, false, c, z, x, y)
					position = position + 1
					counter = counter + 1
					if counter > YIELD_AT then
						updateFrame:SetPct(position/total)
						coroutine.yield()
						counter = 0
					end
				end
			end
		end
	end

	Gatherer.Config.SetSetting("minimap.enable", curMini)
	Gatherer.Config.SetSetting("hud.enable", curHud)
end

function lib:PerformImport()
	if not updateFrame then
		zonelut = {}
		for c, zones in pairs(Gatherer.ZoneTokens.Tokens) do
			for zone, z in pairs(zones) do
				if type(zone)=='string' and type(z)=='number' then
					zonelut[zone] = {c, z}
				end
			end
		end

		updateFrame = CreateFrame("Frame", nil, UIParent)
		updateFrame:SetPoint("CENTER", UIParent, "CENTER")
		updateFrame:SetFrameStrata("TOOLTIP")
		updateFrame:SetWidth("320")
		updateFrame:SetHeight("50")
		updateFrame:SetScript("OnUpdate", function()
			if not coroutine.resume(co) then
				this:Hide()
			end
		end)

		updateFrame.text = updateFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		updateFrame.text:SetPoint("TOPLEFT", updateFrame, "TOPLEFT", 10,-5)
		updateFrame.text:SetHeight(16)
		updateFrame.text:SetJustifyH("LEFT")
		updateFrame.text:SetJustifyV("TOP")
		updateFrame.text:SetText("Importing Nozdor database:")

		updateFrame.back = updateFrame:CreateTexture(nil, "BACKGROUND")
		updateFrame.back:SetPoint("TOPLEFT")
		updateFrame.back:SetPoint("BOTTOMRIGHT")
		updateFrame.back:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

		updateFrame.bar = updateFrame:CreateTexture(nil, "BORDER")
		updateFrame.bar:SetTexture(1,1,1)
		updateFrame.bar:SetPoint("BOTTOMLEFT", updateFrame, "BOTTOMLEFT", 10, 5)
		updateFrame.bar:SetPoint("BOTTOMRIGHT", updateFrame, "BOTTOMRIGHT", -10, 5)
		updateFrame.bar:SetHeight(18)
		updateFrame.bar:SetAlpha(0.2)

		updateFrame.bar.pct = updateFrame:CreateTexture(nil, "ARTWORK")
		updateFrame.bar.pct:SetTexture(1,1,1)
		updateFrame.bar.pct:SetGradientAlpha("Vertical", 0,0,0.4, 1, 0,0,0.7, 1)
		updateFrame.bar.pct:SetPoint("BOTTOMLEFT", updateFrame.bar, "BOTTOMLEFT")
		updateFrame.bar.pct:SetPoint("TOPLEFT", updateFrame.bar, "TOPLEFT")

		updateFrame.bar.text = updateFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		updateFrame.bar.text:SetPoint("TOPLEFT", updateFrame.bar, "TOPLEFT", 0,0)
		updateFrame.bar.text:SetPoint("BOTTOMRIGHT", updateFrame.bar, "BOTTOMRIGHT", 0,0)
		updateFrame.bar.text:SetJustifyH("CENTER")
		updateFrame.bar.text:SetJustifyV("CENTER")
		updateFrame.bar.text:SetText("0%")

		function updateFrame:SetPct(pct)
			pct = math.max(0, math.min((tonumber(pct) or 0), 1))
			local width = updateFrame:GetWidth() - 20
			updateFrame.bar.pct:SetWidth(width * pct)
			updateFrame.bar.text:SetText(("%0.1f%%"):format(pct*100))
		end
	end
	updateFrame:Show()
	co = coroutine.create(beginImport)
end

local function setupGui(gui)
	local id
	if (GathererDB.guiId) then
		id = GathererDB.guiId
	else
		id = gui:AddTab("Database")
		gui:AddControl(id, "Header", 0, "GathererDB Imports")
		gui:MakeScrollable(id)
		GathererDB.guiId = id
	end

	local version = GetAddOnMetadata("GeatherDB_Nozdor", "Version")
	gui:AddControl(id, "Subhead", 0, "Perform import of Nozdor "..version.." DB:")

	local buttonFrame = CreateFrame("Frame", nil, gui.tabs[id][3])
	buttonFrame:SetHeight(24)
	gui:AddControl(id, "Custom", 0, 1, buttonFrame)

	local button = CreateFrame("Button", nil, buttonFrame, "OptionsButtonTemplate")
	button:SetPoint("TOPLEFT", buttonFrame, "TOPLEFT", 0,0)
	button:SetScript("OnClick", lib.PerformImport)
	button:SetText("Import")

	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	button.text:SetPoint("LEFT", button, "RIGHT", 5, 0)
	button.text:SetPoint("RIGHT", buttonFrame, "RIGHT", 0, 0)
	button.text:SetJustifyH("LEFT")
	button.text:SetText("Custom DB")
end
Gatherer.Config.AddCallback("GeatherDB_Nozdor", setupGui)

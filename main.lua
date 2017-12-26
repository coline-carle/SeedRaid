-- Notes
--
-- UI Frames once created are never released by WoW until a /reload.
-- Therefore, frames are spawned and returned to a pool.

local SeedRaid = {}
SeedRaid.SAVE_FILE_VERSION = "1.0.3"

-- Configuration, UI constants are from UI.xml
SeedRaid.frame = SR
SeedRaid.close = SR_Close

SeedRaid.raidClip  = SR_ScrollFrame
SeedRaid.content   = SR_ScrollFrame_Content
SeedRaid.scrollbar = SR_ScrollFrame_ScrollBar

SeedRaid.seedClip         = SR_ScrollFrame_Planted
SeedRaid.contentPlanted   = SR_ScrollFrame_Planted_Content
SeedRaid.scrollbarPlanted = SR_ScrollFrame_Planted_ScrollBar

SeedRaid.lootClip      = SR_ScrollFrame_Loot
SeedRaid.contentLoot   = SR_ScrollFrame_Loot_Content
SeedRaid.scrollbarLoot = SR_ScrollFrame_Loot_ScrollBar

SeedRaid.debug = false
SeedRaid.actAsLeader = false
SeedRaid.errors = false


-- WoW scans the global table (_G) for "SLASH_" and uses string matching
-- to connect the slash command with its matching function.

--
-- Clears current data.
--
SLASH_CLEAR1 = "/sr_clear"
function SlashCmdList.CLEAR(msg, editbox)
  if not SeedRaid then
    return
  end
  SeedRaid:Reset()
  print("SeedRaid results cleared.")
end

--
-- Shows the SeedRaid window.
--
SLASH_SHOW1 = "/sr_show"
function SlashCmdList.SHOW(msg, editbox)
  if not SeedRaid or SeedRaid.frame then
    return
  end
  SeedRaid.frame:Show()
end

--
-- Shows the SeedRaid window.
--
SLASH_EXPORT1 = "/sr_export"
function SlashCmdList.EXPORT(msg, editbox)
  header = "Instructions: Copy the whole text and paste it at http://url\n"
  header = header .. "Tips: don't worry about the instructions you can copy everything\n"
  header = header .. "------------------------\n"
  export_text = header .. SeedRaid.Serialize()
  SeedRaid.frame:Show()
  -- show the appropriate frames
  SeedRaidCopyFrame:Show()
  SeedRaidCopyFrameScroll:Show()
  SeedRaidCopyFrameScrollText:Show()
  SeedRaidCopyFrameScrollText:SetText(export_text)
  SeedRaidCopyFrameScrollText:HighlightText()
end

--
-- Toggles printing of errors.
--
SLASH_ERRORS1 = "/sr_errors"
function SlashCmdList.ERRORS(msg, editbox)
  if not SeedRaid then
    return
  end
  SeedRaid.errors = not SeedRaid.errors
  print("Seed raid print errors is", SeedRaid.errors)
end

--
-- Toggles acting as raid leader.
--
SLASH_LEADER1 = "/sr_leader"
function SlashCmdList.LEADER(msg, editbox)
  if not SeedRaid then
    return
  end
  SeedRaid.actAsLeader = not SeedRaid.actAsLeader
  print("Seed raid act as leader is", SeedRaid.actAsLeader)
end

--
-- Adds a raid member (name-realm) to the member table.
-- @param name Raid member name to enter into member table.
-- @param unitId UnitId of the member, used by many WoW API functions.
-- @param rank Raid rank of the member.
-- @return Raid member table.
--
function SeedRaid:AddMember(guid, playerInfo, name, rank, marked)
  if (not SeedRaid               or not SeedRaid.seeds)         or
     (not SeedRaidSaves.membersByGUID) or
     (not guid       or type(guid)       ~= "string")           or
     (not playerInfo or type(playerInfo) ~= "table")            or
     (not name       or type(name)       ~= "string")           or
     (not rank       or type(rank)       ~= "number")           or
     (not marked     or type(marked)     ~= "number")           then
    return nil
  end

  local member = SeedRaidSaves.membersByGUID[guid]

  if not member then
    local seedsCount = {}
    for i in pairs(SeedRaid.seeds) do
      seedsCount[i] = 0
    end

    member = {
      guid        = guid,
      loots       = {},
      plantedAll  = false,
      seeds       = seedsCount,
      seedsSum    = 0
    }

    SeedRaidSaves.membersByGUID[guid] = member
    SeedRaidSaves.memberCount = SeedRaidSaves.memberCount + 1
  end

  member.name = name
  member.inPartyOrRaid = true
  member.marked = marked
  member.rank = rank
  return member
end

--
-- Enables frame and game events.
--
function SeedRaid:EnableEvents()
  SeedRaid.frame:SetScript("OnDragStart",
    function(self, button)
      SeedRaid.frame:StartMoving()
    end
  )

  SeedRaid.frame:SetScript("OnDragStop",
    function(self, button)
      SeedRaid.frame:StopMovingOrSizing()
    end
  )

  SR_Close:SetScript("OnClick", SeedRaid.ToggleVisible)

  SeedRaid.raidClip:SetScript("OnMouseWheel", SeedRaid.OnMouseWheel)
  SeedRaid.scrollbar:SetScript("OnMouseWheel", SeedRaid.OnMouseWheel)
  SeedRaid.seedClip:SetScript("OnMouseWheel", SeedRaid.OnMouseWheel)
  SeedRaid.scrollbarPlanted:SetScript("OnMouseWheel", SeedRaid.OnMouseWheel)
  SeedRaid.lootClip:SetScript("OnMouseWheel", SeedRaid.OnMouseWheel)
  SeedRaid.scrollbarLoot:SetScript("OnMouseWheel", SeedRaid.OnMouseWheel)

  SeedRaid.scrollbar:SetScript("OnValueChanged",
    function (self, value)
      self:GetParent():SetVerticalScroll(value)
      SeedRaid:UpdateRaidDisplay()
    end
  )

  SeedRaid.scrollbarLoot:SetScript("OnValueChanged",
    function (self, value)
      self:GetParent():SetVerticalScroll(value)
      SeedRaid:UpdateRaidDisplay()
    end
  )

  -- Seed Count
  SR_SeedCount:SetScript("OnEditFocusGained",
    function (self)
      SR_SeedCount:HighlightText()
    end
  )
  SR_SeedCount:SetScript("OnEnterPressed", SeedRaid.SetSeedCount)
  SR_SeedCount:SetScript("OnEscapePressed",
    function (self)
      self:SetText(SeedRaidSaves.seedCount)
      SeedRaid.SetSeedCount(self)
    end
  )
  SR_SeedCount:SetScript("OnTabPressed",
    function (self)
      SeedRaid.SetSeedCount(self)
      if IsShiftKeyDown() then
        SR_AlertInterval:SetFocus()
      else
        SR_RoundSize:SetFocus()
      end
    end
  )

  -- Round Size
  SR_RoundSize:SetScript("OnEditFocusGained",
    function (self)
      SR_RoundSize:HighlightText()
    end
  )
  SR_RoundSize:SetScript("OnEnterPressed", SeedRaid.SetRoundSize)
  SR_RoundSize:SetScript("OnEscapePressed",
    function (self)
      self:SetText(SeedRaidSaves.roundSize)
      SeedRaid.SetRoundSize(self)
    end
  )
  SR_RoundSize:SetScript("OnTabPressed",
    function (self)
      SeedRaid.SetRoundSize(self)
      if IsShiftKeyDown() then
        SR_SeedCount:SetFocus()
      else
        SR_AlertInterval:SetFocus()
      end
    end
  )

  -- Alert Interval
  SR_AlertInterval:SetScript("OnEditFocusGained",
    function (self)
      SR_AlertInterval:HighlightText()
    end
  )
  SR_AlertInterval:SetScript("OnEnterPressed", SeedRaid.SetAlertInterval)
  SR_AlertInterval:SetScript("OnEscapePressed",
    function (self)
      self:SetText(SeedRaidSaves.alertInterval)
      SeedRaid.SetAlertInterval(self)
    end
  )
  SR_AlertInterval:SetScript("OnTabPressed",
    function (self)
      SeedRaid.SetAlertInterval(self)
      if IsShiftKeyDown() then
        SR_RoundSize:SetFocus()
      else
        SR_SeedCount:SetFocus()
      end
    end
  )

  -- Enable game events last, as that is where most race conditions would be
  SeedRaid.frame:SetScript("OnEvent", SeedRaid.OnEvent)
end

--
-- Get a CheckButton widget from the frame pool.
--
function SeedRaid:GetCheckButton(pool)
  if pool ~= "raid" and pool ~= "seed" and pool ~= "loot" then
    error("SeedRaid: Invalid frame pool " .. tostring(pool))
    return nil
  end

  local framepool = SeedRaid.framepool[pool]
  local parent = SeedRaid.framepoolParents[pool]

  local count = table.getn(framepool)
  local frame = table.remove(framepool)
  if not frame then
    frame =
    CreateFrame(
      "CheckButton",
      "$parent_CheckButton_" .. count,
      parent,
      "SR_EntryTemplate"
    )

    frame:SetScript("OnClick",
      function()
        SeedRaid:SetRaidRosterSelection(frame)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        SeedRaid:UpdateRaidDisplay()
      end
    )

    frame.text = frame:CreateFontString(
      "$parent_FontString",
      "OVERLAY",
      "CombatLogFont"
    )
    frame.text:SetPoint("LEFT")
    frame.text:SetTextColor(1, 1, 1, 1)

    frame.raidMarker = CreateFrame("Frame", nil, SeedRaid.frame)
    frame.raidMarker.texture = frame.raidMarker:CreateTexture()
  else
    frame:ClearAllPoints()
  end
  frame:Show()
  return frame
end

--
-- Records what loot has been receieved.
--
function SeedRaid.LootReceieved(...)
  local message = select(1, ...)
  local name = select(5, ...)

  if (not message or type(message) ~= "string") or
     (not name    or type(name)    ~= "string") then
    return false
  end

  if not string.find(name, '-') then
    name = name .. "-" .. GetRealmName()
  end

  local loot = string.match(message, "%[(.+)%]")
  local count = string.match(message, "x(%d+)%.") or 1

  if not loot then
    return false
  end

  count = tonumber(count)

  local found = false
  local guid = ""
  for i, v in pairs(SeedRaidSaves.membersByGUID) do
    if v.name == name then
      found = true
      guid = i
      break
    end
  end

  if not found then
    error("Loot not recorded. " .. name .. " " .. loot .. " " .. count)
    return false
  end

  local member = SeedRaidSaves.membersByGUID[guid]

  if member.loots[loot] == nil then
    member.loots[loot] = count
  else
    member.loots[loot] = member.loots[loot] + count
  end

  if SeedRaid.lootFrames[loot] == nil then
    SeedRaid.lootFrames[loot] = SeedRaid:GetCheckButton("loot")
    SeedRaid.lootFrames[loot]:Disable()
  end

  if SeedRaid.frameSelected == SeedRaid.memberFrames[member.guid] then
    return true
  end

  return false
end

--
-- Executes event code in a protected call.
-- @param ... Event and event arguements.
--
function SeedRaid:OnEvent(...)
  SeedRaid.xpcall(SeedRaid.OnEventP, ...)
end

--
-- Reacts to registered game events.
-- @param event The event that has been registered to be receieved.
-- @param ... Event specific arguements.
--
function SeedRaid.OnEventP(event, ...)
  local updateDisplay = false
  if event == "GROUP_ROSTER_UPDATE"  or
    event == "PARTY_LEADER_CHANGED"  or
    event == "PLAYER_ENTERING_WORLD" or
    event == "RAID_TARGET_UPDATE"    or
    event == "UNIT_NAME_UPDATE"      then
    SeedRaid.UpdateMembers()
    updateDisplay = true

  elseif event == "UNIT_SPELLCAST_FAILED" then
    if SeedRaid.debug then
      updateDisplay = SeedRaid.SeedPlanted(...)
    end

  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    updateDisplay = SeedRaid.SeedPlanted(...)

  elseif event == "CHAT_MSG_LOOT" then
    updateDisplay = SeedRaid.LootReceieved(...)

  elseif event == "ADDON_LOADED" then
    if select(1, ...) ~= "SeedRaid" then
      return
    end

    if not SeedRaidSaves then
      SeedRaidSaves = {}
      SeedRaidSaves.membersByGUID = {}
      SeedRaidSaves.seedCount = 100
      SeedRaidSaves.roundSize = 50
      SeedRaidSaves.alertInterval = 10
      SeedRaidSaves.memberCount = 0
      SeedRaidSaves.plantChannel = "WHISPER"
      SeedRaidSaves.SAVE_FILE_VERSION = SeedRaid.SAVE_FILE_VERSION
      SeedRaidSaves.icon = {hide = false}
      SeedRaidSaves.visible = true
    end

    SeedRaid.inGroupOrRaid = IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInRaid()

  elseif event == "PLAYER_LOGIN" then
    SeedRaid.Initialize()

    -- Create minimap icon
    ldbObject = {
      type = "launcher",
      text = "Seed Raid",
      icon = "656679",
      OnClick = function(self, button)
        if button == "LeftButton" then
          SeedRaid.ToggleVisible()
        elseif button == "MiddleButton" then
          if SeedRaidSaves.plantChannel == "WHISPER" then
            SeedRaidSaves.plantChannel = nil
            print("SeedRaid whispering disabled.")
          else
            SeedRaidSaves.plantChannel = "WHISPER"
            print("SeedRaid whispering enabled.")
          end
        elseif button == "RightButton" then
          StaticPopup_Show("SeedRaid_Clear")
        end
      end,
      OnTooltipShow = function(tooltip)
        tooltip:AddLine("Seed Raid")
        tooltip:AddLine("Left Click - Show/Hide")
        tooltip:AddLine("Middle Click - Mute/Whisper")
        tooltip:AddLine("Right Click - Clear Results")
      end
    }
    LibStub("LibDataBroker-1.1"):NewDataObject("Seed Raid", ldbObject)
    LibStub("LibDBIcon-1.0"):Register("Seed Raid", ldbObject, SeedRaidSaves.icon)

    SeedRaid.SetSeedCount(SR_SeedCount)

    updateDisplay = true
  end

  if updateDisplay then
    SeedRaid:UpdateRaidDisplay()
  end
end

function SeedRaid.Serialize()
  local libS = LibStub:GetLibrary("AceSerializer-3.0")
  local data = libS:Serialize(SeedRaidSaves)
  return data
end
--
-- Scrolls a list when mousewheel is scrolled.
--
function SeedRaid.OnMouseWheel(self, delta)
  local scrollbar = SeedRaid.scrollbar
      if self == SeedRaid.seedClip or self == SeedRaid.scrollbarPlanted then
      scrollbar = SeedRaid.scrollbarPlanted
  elseif self == SeedRaid.lootClip or self == SeedRaid.scrollbarLoot    then
      scrollbar = SeedRaid.scrollbarLoot
  end

  local value = scrollbar:GetValue()
  local newvalue = value + delta * scrollbar.scrollStep * -1
  scrollbar:SetValue(newvalue)
  SeedRaid:UpdateRaidDisplay()
end

--
-- Moves CheckButton widget back to the frame pool.
--
function SeedRaid:RemoveCheckButton(frame, pool)
  if not pool         or
     (pool ~= "raid" and
      pool ~= "seed" and
      pool ~= "loot") then
    error("SeedRaid: not a valid frame pool " .. tostring(pool))
    return
  end

  if not frame or type(frame) ~= "table" then
    error("SeedRaid: not a valid frame " .. tostring(frame))
  end

  local pool = SeedRaid.framepool[pool]
  frame:Hide()
  frame:SetChecked(false)
  frame.text:SetTextColor(1, 1, 1, 1)
  frame.member = nil
  table.insert(pool, frame)
end

--
-- Removes a raid member from the member table.
-- @param name Raid member name to remove.
--
function SeedRaid:RemoveMember(guid)
  if not guid or type(guid) ~= "string" then
    return
  end

  local member = SeedRaidSaves.membersByGUID[guid]
  if member ~= nil then
    SeedRaid:RemoveCheckButton(SeedRaid.memberFrames[member.guid], "raid")
    SeedRaid.memberFrames[member.guid] = nil
    SeedRaidSaves.membersByGUID[member.guid] = nil
    SeedRaidSaves.memberCount = SeedRaidSaves.memberCount - 1
  else
    error(tostring(name) .. " not in table.")
  end
end

--
-- Detects when seeds are planted.
-- @param ... The data received with the UNIT_SPELLCAST_SUCCEEDED event.
-- @return boolean Whether or not a seed was planted & recorded.
--
function SeedRaid.SeedPlanted(...)
  local unitId = select(1, ...)
  local lineId = select(4, ...)
  local spellId = select(5, ...)

  if (not unitId  or type(unitId)  ~= "string") or
     (not spellId or type(spellId) ~= "number") or
     (not lineId  or type(lineId)  ~= "string") then
    return false
  end

  local found = false
  for seedId, data in pairs(SeedRaid.seeds) do
    if spellId == seedId then
      found = true
      break
    end
  end
  if found == false then
    -- Spell is not a seed spell
    return false
  end

  -- Restrict unit types
  if not string.find(unitId, "party")  and
     not string.find(unitId, "player") and
     not string.find(unitId, "raid")   or
         string.find(unitId, "pet")    then
    return false
  end

  -- Ignore party in raid
  if string.find(unitId, "party") and IsInRaid() then
    return false
  end

  local guid = UnitGUID(unitId)

  -- Ignore duplicate player events
  if not SeedRaid.player or
         SeedRaid.player.guid == guid and unitId ~= "player" then
    return false
  end

  local member = SeedRaidSaves.membersByGUID[guid]
  if not member then
    error("No such member. " .. guid)
    return false
  end

  if SeedRaid.lineIdLast and SeedRaid.lineIdLast == lineId then
    -- error("Duplicate of seed plant spell event.")
    if SeedRaid.errors then
      print(member.name, unitId, SeedRaid.unitIdLast, spellId, SeedRaid.spellIdLast)
      print(guid, SeedRaid.guidLast)
      print(lineId, SeedRaid.lineIdLast)
    end
    return false
  end
  SeedRaid.guidLast = guid
  SeedRaid.unitIdLast = unitId
  SeedRaid.lineIdLast = lineId
  SeedRaid.spellIdLast  = spellId

  member.seeds[spellId] = member.seeds[spellId] + 1
  if spellId ~= 193801 then
    -- Excepting Felwort, count this seed planted towards total
    member.seedsSum = member.seedsSum + 1
  else
    return true
  end

  if not SeedRaidSaves.plantChannel then
    return true
  end

  local rank = SeedRaid.player.rank
  local act = SeedRaid.actAsLeader
  local isPlayer = member == SeedRaid.player

  if SeedRaid.debug then
    if rank ~= SeedRaid.RAID_LEADER and not act then
      return true
    end
  elseif rank ~= SeedRaid.RAID_LEADER and not act or isPlayer then
    return true
  end

  if member.seedsSum == SeedRaidSaves.seedCount then
    member.plantedAll = true
    SendChatMessage(
      member.name .. ": " .. member.seedsSum .. " planted, DONE PLANTING.",
      SeedRaidSaves.plantChannel,
      nil,
      member.name
    )
  elseif (member.seedsSum % SeedRaidSaves.roundSize) == 0 and member.seedsSum > 0 then
    SendChatMessage(
      member.name .. ": " .. member.seedsSum .. " planted, done with round.",
      SeedRaidSaves.plantChannel,
      nil,
      member.name
    )
  elseif (member.seedsSum % SeedRaidSaves.alertInterval) == 0 and member.seedsSum > 0 then
    SendChatMessage(
      member.name .. ": " .. member.seedsSum .. " planted.",
      SeedRaidSaves.plantChannel,
      nil,
      member.name
    )
  end

  return true
end

--
-- Ensures only one raid member is selected at a time.
--
function SeedRaid:SetRaidRosterSelection(frame)
  if not SeedRaidSaves.membersByGUID or
     not SeedRaid.lootFrames or
     not SeedRaid.memberFrames or
     not frame then
    return
  end

  for guid, data in pairs(SeedRaidSaves.membersByGUID) do
    if SeedRaid.memberFrames[data.guid] then
      SeedRaid.memberFrames[data.guid]:SetChecked(false)
    end
  end

  SeedRaid.frameSelected = frame
  SeedRaid.frameSelected:SetChecked(true)

  for _, frame in pairs(SeedRaid.lootFrames) do
    frame:Hide()
  end
end

--
-- Sets raid seed count when enter/escape pressed on seed count editbox.
--
function SeedRaid.SetSeedCount(self)
  self:ClearFocus()
  local num = self:GetNumber()
  if num > 0 then
    SeedRaidSaves.seedCount = num
  end
  SeedRaidSaves.roundSize = math.min(SeedRaidSaves.roundSize, SeedRaidSaves.seedCount)
  SeedRaidSaves.alertInterval = math.min(SeedRaidSaves.alertInterval, SeedRaidSaves.roundSize)
  SeedRaid:UpdateRaidDisplay()
end

--
-- Sets round seed count when enter/escape pressed on round size editbox.
--
function SeedRaid.SetRoundSize(self)
  self:ClearFocus()
  local num = self:GetNumber()
  if num > 0 then
    SeedRaidSaves.roundSize = num
  end
  SeedRaidSaves.seedCount = math.max(SeedRaidSaves.seedCount, SeedRaidSaves.roundSize)
  SeedRaidSaves.alertInterval = math.min(SeedRaidSaves.alertInterval, SeedRaidSaves.roundSize)
  SeedRaid:UpdateRaidDisplay()
end

--
-- Sets alert seed count when enter/escape pressed on alert interval editbox.
--
function SeedRaid.SetAlertInterval(self)
  self:ClearFocus()
  local num = self:GetNumber()
  if num > 0 then
    SeedRaidSaves.alertInterval = num
  end
  SeedRaidSaves.seedCount = math.max(SeedRaidSaves.seedCount, SeedRaidSaves.alertInterval)
  SeedRaidSaves.roundSize = math.max(SeedRaidSaves.roundSize, SeedRaidSaves.alertInterval)
  SeedRaid:UpdateRaidDisplay()
end

--
-- Toggles whether or not the addon is visible
--
function SeedRaid.ToggleVisible()
  SeedRaidSaves.visible = not SeedRaidSaves.visible
  if SeedRaidSaves.visible then
    SeedRaid.frame:Show()
  else
    SeedRaid.frame:Hide()
  end
end

--
-- Gets the name of every raid member and initializes their data structure.
--
function SeedRaid:UpdateMembers()
  if not SeedRaidSaves.membersByGUID then
    return
  end

  -- Reset player flags
  for _, data in pairs(SeedRaidSaves.membersByGUID) do
    data.inPartyOrRaid = false
    data.marked = 0
    data.rank = SeedRaid.RAID_MEMBER
  end

  local limit = MAX_PARTY_MEMBERS
  local unit = "party"
  if IsInRaid() then
    limit = MAX_RAID_MEMBERS
    unit = "raid"
  end

  local UpdateMember =
  function(unitId, index)
    local guid = UnitGUID(unitId)
    local name, rank = GetRaidRosterInfo(index)

    if not IsInRaid() or unitId == "player" then
      name = GetUnitName(unitId, true)
      if UnitIsGroupLeader(unitId) then
        rank = SeedRaid.RAID_LEADER
      else
        rank = SeedRaid.RAID_MEMBER
      end
    end

    local exists = UnitExists(unitId) and UnitExists(name)

    if not guid or not name or not exists then
      return nil
    end

    if not string.find(name, '-') then
      name = name .. "-" .. GetRealmName()
    end

    local marked = GetRaidTargetIndex(unitId) or 0
    local playerInfo = {GetPlayerInfoByGUID(guid)}

    return SeedRaid:AddMember(guid, playerInfo, name, rank, marked)
  end

  for i=1, limit do
    local unitId = unit..i
    UpdateMember(unitId, i)
  end

  if not IsInRaid() or not SeedRaid.player then
    SeedRaid.player = UpdateMember("player", 1)
  end

  -- Create new (joined raid) or missing frames (loaded from save)
  for guid, member in pairs(SeedRaidSaves.membersByGUID) do
    if SeedRaid.memberFrames[member.guid] == nil then
      SeedRaid.memberFrames[member.guid] = SeedRaid:GetCheckButton("raid")
      SeedRaid.memberFrames[member.guid].member = member
    end
    for loot in pairs(member.loots) do
      if SeedRaid.lootFrames[loot] == nil then
        SeedRaid.lootFrames[loot] = SeedRaid:GetCheckButton("loot")
        SeedRaid.lootFrames[loot]:Disable()
      end
    end
  end

  local inGroupOrRaid = IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInRaid()
  if not SeedRaid.inGroupOrRaid and inGroupOrRaid then
    StaticPopup_Show("SeedRaid_Clear")
  end
  SeedRaid.inGroupOrRaid = inGroupOrRaid
end

--
-- Match the UI to Lua data
--
function SeedRaid:UpdateRaidDisplay()
  -- Titlebar

  local memberCount = 0
  for guid, data in pairs(SeedRaidSaves.membersByGUID) do
    if data.inPartyOrRaid then
      memberCount = memberCount + 1
    end
  end

  if memberCount < 1 then
    return
  end

  SR_Title:SetText("Seed Raid " .. memberCount .. "/10")
  SR_Title:SetPoint("LEFT", 5, 0)
  SR_SeedCountText:SetPoint("LEFT", SR_Title, "RIGHT", 20, 0)
  SR_SeedCount:SetPoint("LEFT", SR_SeedCountText, "RIGHT", 5, 0)
  SR_RoundSizeText:SetPoint("LEFT", SR_SeedCount, "RIGHT", 20, 0)
  SR_RoundSize:SetPoint("LEFT", SR_RoundSizeText, "RIGHT", 5, 0)
  SR_AlertIntervalText:SetPoint("LEFT", SR_RoundSize, "RIGHT", 20, 0)
  SR_AlertInterval:SetPoint("LEFT", SR_AlertIntervalText, "RIGHT", 5, 0)

  -- Reset SR frame width
  local left, bottom, width, height = SR_AlertInterval:GetRect()
  local right = left + width + 30
  local left, bottom, width, height = SR:GetRect()
  local width = right - left
  SR:SetWidth(width)

  SR_SeedCount:SetText(SeedRaidSaves.seedCount)
  SR_RoundSize:SetText(SeedRaidSaves.roundSize)
  SR_AlertInterval:SetText(SeedRaidSaves.alertInterval)

  SeedRaid.scrollbar:Hide()
  SeedRaid.scrollbarLoot:Hide()

  -- Player List

  local colorFinished = {0.0, 0.5, 0.505, 1.0}
  local colorNormal = {1, 1, 1, 1}
  local colorNotInPartyOrRaid = {0.45, 0.45, 0.45, 1.0}

  -- Re-flow the layout based on current raid status (SeedRaid.comparePairs)
  local count = 1
  local previous = nil
  for name, data in SeedRaid:orderedPairs(SeedRaidSaves.membersByGUID) do
    local frame = SeedRaid.memberFrames[data.guid]
    if count == 1 then
      frame:SetPoint("TOPLEFT")
    else
      frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT")
    end

    local text = string.format("%3.0f", data.seedsSum) .. " " .. name
    frame.text:SetText(text)
    if not data.inPartyOrRaid then
      frame.text:SetTextColor(unpack(colorNotInPartyOrRaid))
    elseif data.seedsSum >= SeedRaidSaves.seedCount then
      frame.text:SetTextColor(unpack(colorFinished))
    else
      frame.text:SetTextColor(unpack(colorNormal))
    end

    if data.marked > 0 then
      local mark = tostring(data.marked)
      local file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. mark
      frame.raidMarker.texture:SetTexture(file);
      frame.raidMarker.texture:SetAllPoints()
      frame.raidMarker:SetHeight(16)
      frame.raidMarker:SetWidth(16)
      frame.raidMarker:SetPoint("RIGHT", frame, "LEFT")
      frame.raidMarker:Show()
    else
      frame.raidMarker:Hide()
    end

    count = count + 1
    previous = frame
  end

  -- Adjust scrollbar
  if previous then
    local entryHeight = previous:GetHeight()
    local contentSize = entryHeight * (count - 1)
    local scrollSize = SeedRaid.raidClip:GetHeight()
    local scroll = contentSize - scrollSize
    if scroll > 0 then
      SeedRaid.scrollbar:Show()
    end
    scroll = math.max(1, scroll)
    SeedRaid.scrollbar:SetMinMaxValues(1, scroll)
    SeedRaid.scrollbar:SetValueStep(entryHeight)
    SeedRaid.scrollbar.scrollStep = entryHeight

    local scrollBottom = SeedRaid.raidClip:GetBottom()
    local scrollTop = scrollBottom + scrollSize
    -- Hide players outside of scroll area
    for guid, data in pairs(SeedRaidSaves.membersByGUID) do
      local frame = SeedRaid.memberFrames[guid]
      local left, bottom, width, height = frame:GetBoundsRect()
      if (bottom > scrollTop)             or
        (bottom + height < scrollBottom) then
        frame:Hide()
        frame.raidMarker:Hide()
      else
        frame:Show()
        if data.marked > 0 then
          frame.raidMarker:Show()
        else
          frame.raidMarker:Hide()
        end
      end
    end
  end

  -- Seed List

  if not SeedRaid.frameSelected or not SeedRaid.frameSelected.member then
    if SeedRaid.player then
      SeedRaid:SetRaidRosterSelection(SeedRaid.memberFrames[SeedRaid.player.guid])
    else
      return
    end
  end
  local selected = SeedRaid.frameSelected.member

  for seedId, count in pairs(selected.seeds) do
    local text = "" .. count .. " " .. SeedRaid.seeds[seedId].name
    local frame = SeedRaid.seeds[seedId].frame
    frame.text:SetText(text)
    frame:Show()
  end

  -- Loot List

  local count = 1
  local previous = nil
  for loot, lootCount in SeedRaid:orderedPairs(selected.loots) do
    local frame = SeedRaid.lootFrames[loot]

    if count > 1 then
      frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT")
    else
      frame:SetPoint("TOPLEFT")
    end

    local text = "" .. lootCount .. " " .. loot
    frame.text:SetText(text)

    previous = frame
    count = count + 1
  end

  -- Adjust scrollbar
  if previous then
    local entryHeight = previous:GetHeight()
    local contentSize = entryHeight * (count - 1)
    local scrollSize = SeedRaid.lootClip:GetHeight()
    local scroll = contentSize - scrollSize
    if scroll > 0 then
      SeedRaid.scrollbarLoot:Show()
    end
    scroll = math.max(1, scroll)
    SeedRaid.scrollbarLoot:SetMinMaxValues(1, scroll)
    SeedRaid.scrollbarLoot:SetValueStep(entryHeight)
    SeedRaid.scrollbarLoot.scrollStep = entryHeight

    local scrollBottom = SeedRaid.lootClip:GetBottom()
    local scrollTop = scrollBottom + scrollSize
    -- Hide loot outside of scroll area
    for loot, lootCount in pairs(selected.loots) do
      local frame = SeedRaid.lootFrames[loot]
      local left, bottom, width, height = frame:GetBoundsRect()
      if (bottom > scrollTop)             or
         (bottom + height < scrollBottom) then
        frame:Hide()
      else
        frame:Show()
      end
    end
  end
end

-- -----------------------------------------------------------------------------
-- -----------------------------------------------------------------------------

--
-- Returns a table iterator, which is sorted by the table key.
-- @param t The table to iterate.
--
function SeedRaid:orderedPairs(t)
  local ordered = {}
  for key, value in pairs(t) do
    if type(value) == "table" and value.guid then
      key = value.name
    end
    table.insert(ordered, {key, value})
  end
  table.sort(ordered, SeedRaid.comparePairs)
  local i = 0
  local n = table.getn(ordered)

  return function()
    i = i + 1
    if i <= n then
      local pair = ordered[i]
      return pair[1], pair[2]
    end
    return nil
  end
end

--
-- Compares two tables crafted by SeedRaid:orderedPairs.
-- @param a The first table.
-- @param b The second table.
--
function SeedRaid.comparePairs(a, b)
  if SeedRaid.player then
    if a[1] == SeedRaid.player.name then
      return true
    elseif b[1] == SeedRaid.player.name then
      return false
    end
  end

  if type(a[2]) == "table" and type(b[2]) == "table" then
    if a[2].marked > 0 and b[2].marked == 0 then
      return true
    elseif b[2].marked > 0 and a[2].marked == 0 then
      return false
    elseif a[2].inPartyOrRaid and not b[2].inPartyOrRaid then
      return true
    elseif b[2].inPartyOrRaid and not a[2].inPartyOrRaid then
      return false
    end
  end

  return a[1] < b[1]
end

--
-- Performs a protected call that will, for errors, have a stacktrace.
-- @param f   The function to call.
-- @param ... The function parameters.
--
function SeedRaid.xpcall(f, ...)
  local args = {...}
  local success, values = xpcall(
    function()
      return {f(unpack(args))}
    end,
    function(msg)
      return {[1]=msg, [2]=debugstack()}
    end
  )
  if not values or type(values) ~= "table" then
    return
  end
  if not success and SeedRaid.errors then
    print(values[1], values[2])
  end
  return unpack(values)
end

-- -----------------------------------------------------------------------------
-- -----------------------------------------------------------------------------

function SeedRaid.Initialize()
  SeedRaid.scrollbar:SetValue(1)
  SeedRaid.scrollbar:SetMinMaxValues(1, 1)
  SeedRaid.scrollbar:SetWidth(16)

  SeedRaid.scrollbarPlanted:SetValue(1)
  SeedRaid.scrollbarPlanted:SetMinMaxValues(1, 1)
  SeedRaid.scrollbarPlanted:SetWidth(16)
  SeedRaid.scrollbarPlanted:Hide()

  SeedRaid.scrollbarLoot:SetValue(1)
  SeedRaid.scrollbarLoot:SetMinMaxValues(1, 1)
  SeedRaid.scrollbarLoot:SetWidth(16)

  if SeedRaidSaves.visible then
    SeedRaid.frame:Show()
  else
    SeedRaid.frame:Hide()
  end

  StaticPopupDialogs["SeedRaid_Clear"] = {
    text = "Clear Seed Raid results?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
      SeedRaid.xpcall(SeedRaid.Reset)
      print("Seed Raid results cleared.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }

  -- Hide all loot frames
  for loot, frame in pairs(SeedRaid.lootFrames) do
    frame:Hide()
  end

  -- Add current raid members
  SeedRaid:UpdateMembers()

  SeedRaid:UpdateRaidDisplay()
end

--
-- Resets all data, just like a /reload would.
--
function SeedRaid.Reset()
  for guid, data in pairs(SeedRaidSaves.membersByGUID) do
    SeedRaid:RemoveMember(guid)
  end

  SeedRaid.player = nil
  if SeedRaid.frameSelected then
    SeedRaid.frameSelected.member = nil
    SeedRaid.frameSelected = nil
  end

  SeedRaid.Initialize()
end

function SeedRaid.Setup()
  SeedRaid.RAID_MEMBER = 0
  SeedRaid.RAID_ASSISTANT = 1
  SeedRaid.RAID_LEADER = 2

  -- Register mouse events with SeedRaid frame
  SeedRaid.frame:RegisterForDrag("LeftButton")

  -- Register mousewheel with clip frames
  SeedRaid.raidClip:EnableMouseWheel(true)
  SeedRaid.scrollbar:EnableMouseWheel(true)
  SeedRaid.seedClip:EnableMouseWheel(true)
  SeedRaid.scrollbarPlanted:EnableMouseWheel(true)
  SeedRaid.lootClip:EnableMouseWheel(true)
  SeedRaid.scrollbarLoot:EnableMouseWheel(true)

  -- Register game events with SeedRaid frame
  SeedRaid.frame:RegisterEvent("ADDON_LOADED")
  SeedRaid.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
  SeedRaid.frame:RegisterEvent("RAID_TARGET_UPDATE")
  SeedRaid.frame:RegisterEvent("CHAT_MSG_LOOT")
  SeedRaid.frame:RegisterEvent("PARTY_LEADER_CHANGED")
  SeedRaid.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  SeedRaid.frame:RegisterEvent("PLAYER_LOGIN")
  SeedRaid.frame:RegisterEvent("UNIT_NAME_UPDATE")
  SeedRaid.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  SeedRaid.frame:RegisterEvent("UNIT_SPELLCAST_FAILED")

  -- One time setup
  SeedRaid.framepool = {raid={}, seed={}, loot={}}
  SeedRaid.framepoolParents = {
    raid=SeedRaid.content,
    seed=SeedRaid.contentPlanted,
    loot=SeedRaid.contentLoot
  }

  SeedRaid.seeds = {
    [193795] = {name="Aethril",        frame=SeedRaid:GetCheckButton("seed")},
    [193797] = {name="Dreamleaf",      frame=SeedRaid:GetCheckButton("seed")},
    [193801] = {name="Felwort",        frame=SeedRaid:GetCheckButton("seed")},
    [193799] = {name="Fjarnskaggl",    frame=SeedRaid:GetCheckButton("seed")},
    [193798] = {name="Foxflower",      frame=SeedRaid:GetCheckButton("seed")},
    [193800] = {name="Starlight Rose", frame=SeedRaid:GetCheckButton("seed")}
  }
  SeedRaid.seeds[193795].frame:SetPoint("TOPLEFT")
  SeedRaid.seeds[193797].frame:SetPoint("TOPLEFT", SeedRaid.seeds[193795].frame, "BOTTOMLEFT")
  SeedRaid.seeds[193801].frame:SetPoint("TOPLEFT", SeedRaid.seeds[193797].frame, "BOTTOMLEFT")
  SeedRaid.seeds[193799].frame:SetPoint("TOPLEFT", SeedRaid.seeds[193801].frame, "BOTTOMLEFT")
  SeedRaid.seeds[193798].frame:SetPoint("TOPLEFT", SeedRaid.seeds[193799].frame, "BOTTOMLEFT")
  SeedRaid.seeds[193800].frame:SetPoint("TOPLEFT", SeedRaid.seeds[193798].frame, "BOTTOMLEFT")
  for i, seed in pairs(SeedRaid.seeds) do
    seed.frame:Disable()
  end

  SeedRaid.lootFrames = {}
  SeedRaid.memberFrames = {}

  -- Set CheckButton sizes
  local height = 15
  -- SR_EntryTemplate:SetHeight(height)
  SeedRaid.raidClip:SetHeight(height*11)
  SeedRaid.content:SetHeight(height*40)

  SeedRaid:EnableEvents()
end

SeedRaid.xpcall(SeedRaid.Setup)

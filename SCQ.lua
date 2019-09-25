SCQ = {
	TITLE = "Share contributable quests",	-- Enduser friendly version of the add-on's name
	AUTHOR = "Ek1",
	DESCRIPTION = "Shares quests to party members that can contribute to the quest.",
	VERSION = "1.1.190925.0134",
	LIECENSE = "BY-SA = Creative Commons Attribution-ShareAlike 4.0 International License",
	URL = "https://github.com/Ek1/SCQ"
}
local ADDON = "SCQ"	-- Codereview friendly referce to this add-on.

-- Starting to do magic
function SCQ.Start()

	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_MEMBER_JOINED,	SCQ.EVENT_GROUP_MEMBER_JOINED)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED,	SCQ.EVENT_PLAYER_ACTIVATED)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_SUPPORT_RANGE_UPDATE,	SCQ.EVENT_GROUP_SUPPORT_RANGE_UPDATE)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_MEMBER_LEFT,	SCQ.EVENT_GROUP_MEMBER_LEFT)

	d( ADDON .. ": started. Listening to group size changes and when party member is close enough to support.")
end

local SharedQuests = {}
-- API 100026	EVENT_QUEST_ADDED (number eventCode, number journalIndex, string questName, string objectiveName)
function SCQ.EVENT_QUEST_ADDED (_, journalIndex, questName, objectiveName)
	if GetIsQuestSharable(journalIndex) then
		SharedQuests = {}
	else
		SharedQuests[questName] = os.time()	-- If it can't be shared, don't bother trying to share it anyway
	end
end

local playerUnitTag
local groupMembersInSupportRange
-- local myDisplayName = GetDisplayName()
-- 100028 EVENT_GROUP_MEMBER_JOINED (number eventCode, string memberCharacterName, string memberDisplayName, boolean isLocalPlayer)
function SCQ.EVENT_GROUP_MEMBER_JOINED(_ , _, memberDisplayName, isLocalPlayer)

	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_SUPPORT_RANGE_UPDATE,	SCQ.EVENT_GROUP_SUPPORT_RANGE_UPDATE)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_MEMBER_CONNECTED_STATUS,	SCQ.EVENT_GROUP_MEMBER_CONNECTED_STATUS)

	if isLocalPlayer then
		d( ADDON .. ": joined a group.")
	else
		SharedQuests = {}
		d( ADDON .. ": " .. ZO_LinkHandler_CreateDisplayNameLink(memberDisplayName)  .. " joined the group.")
	end
end

--	EVENT_GROUP_MEMBER_CONNECTED_STATUS (number eventCode, string unitTag, boolean isOnline)
function SCQ.EVENT_GROUP_MEMBER_CONNECTED_STATUS (_, string_unitTag, boolean_isOnline)
	SCQ.fixMembersInSupportRange()
end

--	EVENT_PLAYER_ACTIVATED (number eventCode, boolean initial)
function SCQ.EVENT_PLAYER_ACTIVATED(_, _)
	SCQ.fixMembersInSupportRange()
end

--	Inefficient support range checker that nees to be done when exiting loading screen as EVENT_GROUP_SUPPORT_RANGE_UPDATE is not updated then
function SCQ.fixMembersInSupportRange()
	local GroupSize = GetGroupSize() or 0
	groupMembersInSupportRange = 0
	if 0 < GroupSize then
		for i = 1, GroupSize do
			local scopum = GetGroupUnitTagByIndex(i)
			if IsUnitInGroupSupportRange( scopum ) then
				groupMembersInSupportRange = groupMembersInSupportRange + 1
			end
		end
	end
end

-- Following keeps track of the members that are in support range
-- 100028 EVENT_GROUP_SUPPORT_RANGE_UPDATE (number eventCode, string unitTag, boolean status)
function SCQ.EVENT_GROUP_SUPPORT_RANGE_UPDATE(_, unitTag, isSupporting)

	if not groupMembersInSupportRange then
		groupMembersInSupportRange = 0
	end
	
	local GroupSize = GetGroupSize() or 2	-- 
	d( SCQ.TITLE .. ": EVENT_GROUP_SUPPORT_RANGE_UPDATE " .. groupMembersInSupportRange .. " party members in support range before check")

	if isSupporting then
		groupMembersInSupportRange = groupMembersInSupportRange + 1
		d( SCQ.TITLE .. ": EVENT_GROUP_SUPPORT_RANGE_UPDATE updated to " .. groupMembersInSupportRange .. " party members in support range")
		if GroupSize and GroupSize < groupMembersInSupportRange then	-- There can't be more people supporting than there are members in group
			groupMembersInSupportRange = GroupSize or 2
			d( SCQ.TITLE .. ": EVENT_GROUP_SUPPORT_RANGE_UPDATE fixed to " .. groupMembersInSupportRange .. " party members in support range")
		end
	else
		groupMembersInSupportRange = groupMembersInSupportRange - 1
		d( SCQ.TITLE .. ": EVENT_GROUP_SUPPORT_RANGE_UPDATE updated to " .. groupMembersInSupportRange .. " party members in support range")
		if groupMembersInSupportRange < 1 then	-- Player is always in support range of himself
			groupMembersInSupportRange = 1
			d( SCQ.TITLE .. ": EVENT_GROUP_SUPPORT_RANGE_UPDATE fixed to " .. groupMembersInSupportRange .. " party members in support range")
		end
	end


	if 2 <= groupMembersInSupportRange then
	-- ZO_PreHook(WORLD_MAP_QUEST_BREADCRUMBS, "OnQuestPositionRequestComplete", SCQ.EVENT_QUEST_POSITION_REQUEST_COMPLETE)
		EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_QUEST_POSITION_REQUEST_COMPLETE, SCQ.EVENT_QUEST_POSITION_REQUEST_COMPLETE)
		d( ADDON .. ": listening to EVENT_QUEST_POSITION_REQUEST_COMPLETE")
	else
		EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_QUEST_POSITION_REQUEST_COMPLETE)
		d( ADDON .. ": muting EVENT_QUEST_POSITION_REQUEST_COMPLETE")
	end
end

local playersCurrentZoneIndex = GetUnitZoneIndex("player") or -1
-- 100028 EVENT_QUEST_POSITION_REQUEST_COMPLETE (number eventCode, number taskId, MapDisplayPinType pinType, number xLoc, number yLoc, number areaRadius, boolean insideCurrentMapWorld, boolean isBreadcrumb)
function SCQ.EVENT_QUEST_POSITION_REQUEST_COMPLETE(self, taskId, pinType, xLoc, yLoc, areaRadius, insideCurrentMapWorld, isBreadcrumb)

	if insideCurrentMapWorld and DoesCurrentMapMatchMapForPlayerLocation() and GetUnitZoneIndex("player") ~= playersCurrentZoneIndex then
		d(taskId)
		playersCurrentZoneIndex = GetUnitZoneIndex("player")
		SCQ.InnefficientSharing()
	end

	--[[ Attempt for precise quest sharing

	local conditionData = WORLD_MAP_QUEST_BREADCRUMBS.taskIdToConditionData[taskId] or {}
	local journalQuestIndex, stepIndex, conditionIndex = conditionData.questIndex, conditionData.stepIndex, conditionData.conditionIndex

	if journalQuestIndex then
		d( SCQ.TITLE .. ": EVENT_QUEST_POSITION_REQUEST_COMPLETE " .. journalQuestIndex)
	end

	if GetIsQuestSharable(journalQuestIndex) then
		ShareQuest(journalQuestIndex)
		d( SCQ.TITLE .. ": shared #" .. journalQuestIndex .. " " .. GetJournalQuestName(journalQuestIndex) )
	end
]]
end

	-- Dirty quest sharing
function SCQ.InnefficientSharing()

	local journalQuestName
--	local playersCurrentZoneIndex = GetUnitZoneIndex("player")	-- Where we are now
	d( ADDON .. ": playersCurrentZoneIndex = " .. playersCurrentZoneIndex)

	for i = 1, GetNumJournalQuests() do
		local journalQuestName = GetJournalQuestName(i)
		if SharedQuests[journalQuestName] then
--			d( ADDON .. ": already shared before  #" .. i .. " " .. journalQuestName)
		else
			if GetIsQuestSharable(i) then

				local journalQuestLocationZoneName, objectiveName, journalQuestLocationZoneIndex, poiIndex =	GetJournalQuestLocationInfo(i)
				local JournalQuestStartingZoneIndex = GetJournalQuestStartingZone(i)

				if playersCurrentZoneIndex == journalQuestLocationZoneName or playersCurrentZoneIndex == JournalQuestStartingZoneIndex then
					ShareQuest(i)
					SharedQuests[journalQuestName] = os.time()
					d( ADDON .. ": shared #" .. i .. " " .. journalQuestName .. " that locates in " .. journalQuestLocationZoneName)
				end
			else
				SharedQuests[journalQuestName] = os.time()
			end
		end
	end
end	-- Dirty quest sharing done

-- 100028 EVENT_GROUP_MEMBER_LEFT (number eventCode, string memberCharacterName, GroupLeaveReason reason, boolean isLocalPlayer, boolean isLeader, string memberDisplayName, boolean actionRequiredVote)
function SCQ.EVENT_GROUP_MEMBER_LEFT(_ , memberCharacterName, GroupLeaveReason, isLocalPlayer, isLeader, memberDisplayName, actionRequiredVote)

	if isLocalPlayer then
		d( ADDON .. ": soloing.")
		EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_QUEST_POSITION_REQUEST_COMPLETE)
		EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_MEMBER_LEFT)
		EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_SUPPORT_RANGE_UPDATE)
		EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_MEMBER_JOINED,	SCQ.EVENT_GROUP_MEMBER_JOINED)
	else
		d( ADDON .. ": " .. ZO_LinkHandler_CreateDisplayNameLink(memberDisplayName)  .. " left the group.")
	end
end

function SCQ.Stop()

	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_MEMBER_JOINED)
	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_SUPPORT_RANGE_UPDATE)
	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_QUEST_POSITION_REQUEST_COMPLETE)
	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_MEMBER_CONNECTED_STATUS)
	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_MEMBER_LEFT)

	d( ADDON .. ": stopped. Deff to EVENT_GROUP_MEMBER_JOINED, EVENT_GROUP_SUPPORT_RANGE_UPDATE, EVENT_QUEST_POSITION_REQUEST_COMPLETE & EVENT_GROUP_MEMBER_LEFT")
end

-- Variable to keep count how many loads have been done before it was this ones turn.
local loadOrder = 1
function SCQ.GotLoaded(_, loadedAddOnName)
	if loadedAddOnName == ADDON then
	--	Seems it is our time so lets stop listening load trigger and initialize the add-on
		d( SCQ.TITLE .. " (" .. ADDON .. ")".. ": load order " ..  loadOrder .. ", starting")
		EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

		SCQ.Start()
	end
	loadOrder = loadOrder + 1
end

-- Registering the SCQ's initializing event when add-on's are loaded 
EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, SCQ.GotLoaded)

--[[	Possible implementantion methods
	
SafeAddString(SI_JOURNAL_MENU_QUESTS, "Quests", 0)

GetGroupLeaderUnitTag()
Returns: string leaderUnitTag

IsGroupMemberInSameWorldAsPlayer(string unitTag)
Returns: boolean isInSameWorld

IsUnitGroupLeader(string unitTag)
Returns: boolean isGroupLeader

GetGroupUnitTagByIndex(number sortIndex)
Returns: string:nilable unitTag

GetUnitDisplayName(string unitTag)
Returns: string displayName

GetPlayerActiveSubzoneName()
Returns: string subzoneName

GetPlayerActiveZoneName()
Returns: string zoneName

IsAnyGroupMemberInDungeon()
Returns: boolean isAnyGroupMemberInDungeon

IsPlayerInGroup(string characterOrDisplayName)
Returns: boolean inGroup
IsUnitGrouped(string unitTag)
Returns: boolean isGrouped

GetCurrentCharacterId()
Returns: string id

IsJournalQuestIndexInTrackedZoneStory(number journalQuestIndex)
Returns: boolean isInTrackedZoneStory

IsJournalQuestStepEnding(number journalQuestIndex, number stepIndex)
Returns: boolean isEnding

EVENT_LEADER_UPDATE (number eventCode, string leaderTag)
]]
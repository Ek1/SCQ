local SCQ = {
	TITLE = "Share contributable quests",	-- Enduser friendly version of the add-on's name
	AUTHOR = "Ek1",
	DESCRIPTION = "Shares quests to party members that can contribute to the quest.",
	VERSION = "1.0.190902.1400",
	LIECENSE = "BY-SA = Creative Commons Attribution-ShareAlike 4.0 International License",
	URL = "https://github.com/Ek1/SCQ"
}
local ADDON = "SCQ"	-- Codereview friendly referce to this add-on.

-- Starting to do magic
function SCQ.start()

	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_MEMBER_JOINED,	SCQ.inGroup)

	d( SCQ.TITLE .. ": started. Listening EVENT_GROUP_MEMBER_JOINED")
end

local groupMembersInSupportRange = {}
groupMembersInSupportRange[0] = 0
-- 100028 EVENT_GROUP_MEMBER_JOINED (number eventCode, string memberCharacterName, string memberDisplayName, boolean isLocalPlayer)
function SCQ.inGroup(_ , _, _, isLocalPlayer)
	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_MEMBER_JOINED)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_SUPPORT_RANGE_UPDATE,	SCQ.EVENT_GROUP_SUPPORT_RANGE_UPDATE)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_MEMBER_LEFT,	SCQ.soloing)
	d( SCQ.TITLE .. ": inGroup, muting EVENT_GROUP_MEMBER_JOINED and listening EVENT_GROUP_SUPPORT_RANGE_UPDATE & EVENT_GROUP_MEMBER_LEFT.")

	local UnitTag = 0
	for i = 1, GetGroupSize() do
		UnitTag = GetGroupUnitTagByIndex(i)
		if IsUnitInGroupSupportRange( UnitTag ) then
			groupMembersInSupportRange[0] = groupMembersInSupportRange[0] + 1
		end
	end
end

-- Following keeps track of the members that are in support range
-- 100028 EVENT_GROUP_SUPPORT_RANGE_UPDATE (number eventCode, string unitTag, boolean status)
function SCQ.EVENT_GROUP_SUPPORT_RANGE_UPDATE(_, unitTag, isSupporting)

	if isSupporting then
		if groupMembersInSupportRange[0] < 0 then
			groupMembersInSupportRange[0] = 1
		else
		groupMembersInSupportRange[0] = groupMembersInSupportRange[0] + 1
		end
	else
		groupMembersInSupportRange[0] = groupMembersInSupportRange[0] - 1
	end

	d( SCQ.TITLE .. ": EVENT_GROUP_SUPPORT_RANGE_UPDATE now " .. groupMembersInSupportRange[0] .. "party members in support range")

	if 0 < groupMembersInSupportRange[0] then
--		ZO_PreHook(WORLD_MAP_QUEST_BREADCRUMBS, "OnQuestPositionRequestComplete", SCQ.EVENT_QUEST_POSITION_REQUEST_COMPLETE)
		EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_QUEST_POSITION_REQUEST_COMPLETE, SCQ.EVENT_QUEST_POSITION_REQUEST_COMPLETE)
		d( SCQ.TITLE .. ": listening to EVENT_QUEST_POSITION_REQUEST_COMPLETE")
	else
		EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_QUEST_POSITION_REQUEST_COMPLETE)
		d( SCQ.TITLE .. ": muting EVENT_QUEST_POSITION_REQUEST_COMPLETE")
	end
end

-- 100028 EVENT_QUEST_POSITION_REQUEST_COMPLETE (number eventCode, number taskId, MapDisplayPinType pinType, number xLoc, number yLoc, number areaRadius, boolean insideCurrentMapWorld, boolean isBreadcrumb)
function SCQ.EVENT_QUEST_POSITION_REQUEST_COMPLETE(self, taskId, pinType, xLoc, yLoc, areaRadius, insideCurrentMapWorld, isBreadcrumb)

	SCQ.InnefficientSharing()

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

function SCQ.InnefficientSharing()
	-- Dirty quest sharing
	for i=1, MAX_JOURNAL_QUESTS do
		if GetIsQuestSharable(i) and IsJournalQuestInCurrentMapZone(i) then
			ShareQuest(i)
		end
	end
end	-- Dirty quest sharing done

function SCQ.soloing(_ , _, _, isLocalPlayer)

	if isLocalPlayer then
		groupMembersInSupportRange[0] = 0	-- Just making sure the counter resets
		EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_MEMBER_LEFT)
		EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_SUPPORT_RANGE_UPDATE)
		EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_MEMBER_JOINED,	SCQ.inGroup)
		d( SCQ.TITLE .. ": soloing, muting EVENT_GROUP_MEMBER_LEFT, EVENT_GROUP_SUPPORT_RANGE_UPDATE and listening EVENT_GROUP_MEMBER_JOINED.")
	end
end

function SCQ.stop()

	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_MEMBER_JOINED)
	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_SUPPORT_RANGE_UPDATE)
	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_QUEST_POSITION_REQUEST_COMPLETE)
	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_MEMBER_LEFT)

	d( SCQ.TITLE .. ": stopped. Muting EVENT_GROUP_MEMBER_JOINED, EVENT_GROUP_SUPPORT_RANGE_UPDATE, EVENT_QUEST_POSITION_REQUEST_COMPLETE & EVENT_GROUP_MEMBER_LEFT")
end

-- Variable to keep count how many loads have been done before it was this ones turn.
local loadOrder = 1
function SCQ.onSCQLoaded(_, loadedAddOnName)
	if loadedAddOnName == ADDON then
	--	Seems it is our time so lets stop listening load trigger and initialize the add-on
		d( SCQ.TITLE .. ": load order " ..  loadOrder .. ", starting")
		EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
		SCQ.start()
	end
	loadOrder = loadOrder+1
end

-- Registering the SCQ's initializing event when add-on's are loaded 
EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, SCQ.onSCQLoaded)

--[[	Possible implementantion choices
	

GetGroupLeaderUnitTag()
Returns: string leaderUnitTag

IsGroupMemberInSameWorldAsPlayer(string unitTag)
Returns: boolean isInSameWorld

IsUnitGroupLeader(string unitTag)
Returns: boolean isGroupLeader

GetGroupSize()
Returns: number groupSize
GetGroupUnitTagByIndex(number sortIndex)
Returns: string:nilable unitTag

GetGroupUnitTagByIndex(number sortIndex)
Returns: string:nilable unitTag

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

IsUnitSoloOrGroupLeader(string unitTag)
Returns: boolean isSoloOrGroupLeader

JumpToGroupLeader()
JumpToGroupMember(string characterOrDisplayName)

IsJournalQuestInCurrentMapZone(number questIndex)
Returns: boolean isInCurrentZone
IsJournalQuestIndexInTrackedZoneStory(number journalQuestIndex)
Returns: boolean isInTrackedZoneStory
IsJournalQuestStepEnding(number journalQuestIndex, number stepIndex)
Returns: boolean isEnding



EVENT_GROUP_MEMBER_JOINED (number eventCode, string memberCharacterName, string memberDisplayName, boolean isLocalPlayer)	-- reset the list 
EVENT_GROUP_UPDATE (number eventCode)	-- Fired when group size changes
EVENT_GROUP_SUPPORT_RANGE_UPDATE (number eventCode, string unitTag, boolean status)	-- Fired when party member comes close enough(?) answer when to share quests?
EVENT_LEADER_UPDATE (number eventCode, string leaderTag)
]]
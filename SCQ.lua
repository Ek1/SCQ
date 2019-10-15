SCQ = {
	TITLE = "Share contributable quests",	-- Enduser friendly version of the add-on's name
	AUTHOR = "Ek1",
	DESCRIPTION = "Shares quests to party members that can contribute to the quest.",
	VERSION = "1.2.191016",
	LIECENSE = "BY-SA = Creative Commons Attribution-ShareAlike 4.0 International License",
	URL = "https://github.com/Ek1/SCQ"
}
local ADDON = "SCQ"	-- Codereview friendly reference to this add-on.

-- Starting to do magic
function SCQ.Start()

	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_MEMBER_JOINED,	SCQ.EVENT_GROUP_MEMBER_JOINED)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED,	SCQ.EVENT_PLAYER_ACTIVATED)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_MEMBER_LEFT,	SCQ.EVENT_GROUP_MEMBER_LEFT)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_MEMBER_CONNECTED_STATUS,	SCQ.EVENT_GROUP_MEMBER_CONNECTED_STATUS)

	d( ADDON .. ": started. Listening to group size changes and when party member is close enough to support.")
end

local supportingThereshold = 2/7
local sharedQuests = {}
local membersSupporting = 0

-- 100028 EVENT_GROUP_MEMBER_JOINED (number eventCode, string memberCharacterName, string memberDisplayName, boolean isLocalPlayer)
function SCQ.EVENT_GROUP_MEMBER_JOINED(_ , memberCharacterName, memberDisplayName, isLocalPlayer)

	sharedQuests = {}

	if isLocalPlayer then
		EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_GROUP_SUPPORT_RANGE_UPDATE,	SCQ.EVENT_GROUP_SUPPORT_RANGE_UPDATE)
		EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_QUEST_ADDED,	SCQ.EVENT_QUEST_ADDED)
		EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED,	SCQ.EVENT_PLAYER_ACTIVATED)
		d( ADDON .. ": You joined a group with Your " .. zo_strformat("<<1>>", memberCharacterName) .. " consisting of " .. zo_strformat("<<n:1>>", GetGroupSize() ) .. " brave adventurers  ")
	else
		d( ADDON .. ": " .. ZO_LinkHandler_CreateLinkWithoutBrackets(memberDisplayName, nil, CHARACTER_LINK_TYPE, memberDisplayName)  .. " joined the group with " .. zo_strformat("<<1>>", memberCharacterName) .. " making us " .. zo_strformat("<<n:1>>", GetGroupSize() ) .. " undaunted adventurers" )
	end

	SCQ.fixMembersInSupportRange()
	if supportingThereshold <= ( membersSupporting / GetGroupSize() ) then
		SCQ.targetedQuestSharing(	GetUnitZoneIndex("player")	)
	end
end

-- API 100026	EVENT_QUEST_ADDED (number eventCode, number journalIndex, string questName, string objectiveName)
function SCQ.EVENT_QUEST_ADDED (_, journalIndex, questName, objectiveName)
	if GetIsQuestSharable(journalIndex) then
		sharedQuests = {}
	else
		sharedQuests[questName] = os.time()	-- If it can't be shared, don't bother trying to share it anyway
	end

	if supportingThereshold <= ( membersSupporting / GetGroupSize() ) then
		SCQ.targetedQuestSharing(	GetUnitZoneIndex("player")	)
	end
end

--	EVENT_GROUP_MEMBER_CONNECTED_STATUS (number eventCode, string unitTag, boolean isOnline)
function SCQ.EVENT_GROUP_MEMBER_CONNECTED_STATUS (_, string_unitTag, boolean_isOnline)
	SCQ.fixMembersInSupportRange()
end

--	EVENT_PLAYER_ACTIVATED (number eventCode, boolean initial)
function SCQ.EVENT_PLAYER_ACTIVATED(_, _)
	SCQ.fixMembersInSupportRange()
	if supportingThereshold <= ( membersSupporting / GetGroupSize() ) then
		SCQ.targetedQuestSharing(	GetUnitZoneIndex("player")	)
	end
end


--	Inefficient support range checker that needs to be done when exiting loading screen as EVENT_GROUP_SUPPORT_RANGE_UPDATE is not updated then
function SCQ.fixMembersInSupportRange()
	membersSupporting = 0
	if 0 < GetGroupSize() then
		for i = 1, GetGroupSize() do
			if IsUnitInGroupSupportRange(	GetGroupUnitTagByIndex(i)	) then
				membersSupporting = membersSupporting + 1
			end
		end
	end
end

-- Following keeps track of the members that are in support range
-- 100028 EVENT_GROUP_SUPPORT_RANGE_UPDATE (number eventCode, string unitTag, boolean status)
function SCQ.EVENT_GROUP_SUPPORT_RANGE_UPDATE(_, unitTag, isSupporting)

	if not membersSupporting then
		membersSupporting = 0
	end
	--d( SCQ.TITLE .. ": EVENT_GROUP_SUPPORT_RANGE_UPDATE " .. membersSupporting .. "/" .. GetGroupSize() .. " party members in support range before check")

	if isSupporting then
		membersSupporting = 1 + membersSupporting or 2
		--d( SCQ.TITLE .. ": EVENT_GROUP_SUPPORT_RANGE_UPDATE updated to " .. membersSupporting .. "/" .. GetGroupSize() .. " party members in support range")
		if GetGroupSize() < membersSupporting then	-- There can't be more people supporting than there are members in group
			membersSupporting = GetGroupSize() or 2
			--d( SCQ.TITLE .. ": EVENT_GROUP_SUPPORT_RANGE_UPDATE fixed to " .. membersSupporting .. "/" .. GetGroupSize() .. " party members in support range")
		end
	else
		membersSupporting = membersSupporting - 1 or 1
		--d( SCQ.TITLE .. ": EVENT_GROUP_SUPPORT_RANGE_UPDATE updated to " .. membersSupporting .. "/" .. group[0] .. " party members in support range")
		if membersSupporting < 1 then	-- Player is always in support range of himself
			membersSupporting = 1
			--d( SCQ.TITLE .. ": EVENT_GROUP_SUPPORT_RANGE_UPDATE fixed to " .. membersSupporting .. "/" .. group[0] .. " party members in support range")
		end
	end
end

-- Quests in target zone sharing
-- Optionally takes int_ZoneIndex and int_questRepeatType as arguments for more specific sahres
function SCQ.targetedQuestSharing( targetZoneIndex, questRepeatTypeFromZeroToTwo)

	if targetZoneIndex == nil then
		targetZoneIndex = GetUnitZoneIndex("player")	-- If not target was given, presume target is players zone
	end
	local questRepeatTypeMinimumToShare = questRepeatTypeFromZeroToTwo or 0	-- if no limit was given, presume everything is wanted

	local sharedQuests = {}

	for i = 1, GetNumJournalQuests() do

		if GetIsQuestSharable(i) then	-- If it can't be shared, don't even bother

			if questRepeatTypeMinimumToShare <= GetJournalQuestRepeatType(i) then

				local journalQuestLocationZoneName, objectiveName, journalQuestLocationZoneIndex, poiIndex =	GetJournalQuestLocationInfo(i)
				local JournalQuestStartingZoneIndex = GetJournalQuestStartingZone(i)

				if targetZoneIndex == journalQuestLocationZoneName or targetZoneIndex == JournalQuestStartingZoneIndex then
					ShareQuest(i)
					d( ADDON .. ": shared #" .. i .. " " .. GetJournalQuestName(i) .. " that locates in " .. journalQuestLocationZoneName)
					local indexTarget = GetJournalQuestName(1)
					sharedQuests[indexTarget] = os.time()
				end
			end
		end
	end
end	-- Quests in target zone sharing


-- 100028 EVENT_GROUP_MEMBER_LEFT (number eventCode, string memberCharacterName, GroupLeaveReason reason, boolean isLocalPlayer, boolean isLeader, string memberDisplayName, boolean actionRequiredVote)
function SCQ.EVENT_GROUP_MEMBER_LEFT(_ , memberCharacterName, GroupLeaveReason, isLocalPlayer, isLeader, memberDisplayName, actionRequiredVote)

	if isLocalPlayer then
		EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_QUEST_ADDED)
		EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_MEMBER_LEFT)
		EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED)
		d( ADDON .. ": Now soloing.")
	else
		d( ADDON .. ": " .. ZO_LinkHandler_CreateLinkWithoutBrackets(memberDisplayName, nil, CHARACTER_LINK_TYPE, memberDisplayName) .. " left the group with " .. zo_strformat("<<1>>", memberCharacterName)	)
	end
end

-- Kill the add-on if needed for some reason. Also a list of stuff that needs to be remembered.
function SCQ.Stop()

	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_QUEST_ADDED)

	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_MEMBER_JOINED)
	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_SUPPORT_RANGE_UPDATE)
	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_MEMBER_CONNECTED_STATUS)
	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_GROUP_MEMBER_LEFT)

	EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED)

	d( ADDON .. ": stopped")
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
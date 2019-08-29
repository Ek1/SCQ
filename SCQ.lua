local SCQ = {
	TITLE = "Shares quests to party members that can contribute to the quest",	-- Not codereview friendly but enduser friendly version of the add-on's name
	AUTHOR = "Ek1",
	DESCRIPTION = "Libary for other add-on's to get quest data.",
	VERSION = "1.0",
	LIECENSE = "BY-SA = Creative Commons Attribution-ShareAlike 4.0 International License",
	URL = "https://github.com/Ek1/SCQ"
}
local ADDON_NAME = "SCQ"	-- Variable used to refer to this add-on. Codereview friendly.

--[[ Loop through repeatable quests in the zone character is located and share those quests
  ]]--
function ShareZoneQuest (ZoneID) 

	IsJournalQuestInCurrentMapZone(number questIndex)
	Returns: boolean isInCurrentZone

end
--[[
|H1:achievement:2491:12:0|h|h  |H1:achievement:2493:12:0|h|h
/z =|H0:achievement:2492:51:0|h|h: Abode. Join the zoneGroup with /w + for |H0:item:151620:122:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h.
/z =|H0:achievement:2495:51:0|h|h: Duo. Join the zoneGroup with /w + for |H0:item:151620:122:1:0:0:0:0:0:0:0:1:0:0:0:1:0:0:1:0:0:0|h|h.
/z +|H0:achievement:2498:-6571:0|h|h. Join zoneGroup with /w + for |H0:item:151623:122:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h.
6357 ja 6384 /z =|H0:achievement:2496:1:0|h|h/6384. Join the zoneGroup with /w + for |H0:item:151623:122:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h.

/z =|H0:achievement:2498:6357:0|h|h, =|H0:achievement:2495:51:0|h|h: Vhysradue & =|H0:achievement:2492:51:0|h|h: Tangle. Join the zoneGroup with /w @Ek1 + for shared progression, more quests and faster travel.
]]

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

EVENT_GROUP_MEMBER_JOINED (number eventCode, string memberCharacterName, string memberDisplayName, boolean isLocalPlayer)	-- reset the list 
EVENT_GROUP_UPDATE (number eventCode)	-- Fired when group size changes
EVENT_GROUP_SUPPORT_RANGE_UPDATE (number eventCode, string unitTag, boolean status)	-- Fired when party member comes close enough(?) answer when to share quests?
EVENT_LEADER_UPDATE (number eventCode, string leaderTag)

-- Lets fire up the add-on by registering for events and loading variables
function SCQ.Initialize()

	-- Loading account variables i.o. all quest with complete data or if none saved, create one
	allQuestIds	= SCQ_allQuestIds or {}
	allQuestNames	= SCQ_allQuestNames or {}

	-- Loading character variables i.o. all incomplete quests
	charactersQuestHistory	= ZO_SavedVars:NewCharacterIdSettings("SCQ_charactersQuestHistory", SCQ.VARIABLEVERSION, GetWorldName(), charactersQuestHistory) or {}
	charactersOngoingQuests	= ZO_SavedVars:NewCharacterIdSettings("SCQ_ongoingCharacterQuests", SCQ.VARIABLEVERSION, GetWorldName(), charactersOngoingQuests) or {}

	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_QUEST_SHARED,	SCQ.EVENT_QUEST_SHARED)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_QUEST_OFFERED,	SCQ.EVENT_QUEST_OFFERED)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_QUEST_ADDED,	SCQ.EVENT_QUEST_ADDED)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_QUEST_ADVANCED,	SCQ.EVENT_QUEST_ADVANCED)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_QUEST_COMPLETE,	SCQ.EVENT_QUEST_COMPLETE)
	EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_QUEST_REMOVED,	SCQ.EVENT_QUEST_REMOVED)


	d( SCQ.TITLE .. ": initalization done. ")
end

-- Variable to keep count how many loads have been done before it was this ones turn.
local loadOrder = 1
function SCQ.OnSCQLoaded(_, SCQName)
	if SCQName == ADDON then
	--	Seems it is our time so lets stop listening load trigger and initialize the add-on
		d( SCQ.TITLE .. ": load order " ..  loadOrder .. ", starting initalization")
		EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
		SCQ.Initialize()
	end
	loadOrder = loadOrder+1
end

-- Registering the SCQ's initializing event when add-on's are loaded 
EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, SCQ.OnSCQLoaded)
# Widget API and Blizzard UI patterns: reference for SquadRank

Sources (accessed 2026-11-10):
- https://warcraft.wiki.gg/wiki/Widget_API
- Blizzard source, Gethe/wow-ui-source branch `forever` @ 4cd0ab7 (1.60.1.70888); file paths below are under
  `Interface/AddOns/`. The `live` branch @ 297d7aa (12.1.5) has the same files unless noted.

## Widget API facts
- Widgets are created with `CreateFrame(frameType, name, parent, template, id)` or from XML.
- Inheritance runs FrameScriptObject → Object → ScriptRegion → Region → Frame → Button / EditBox / ScrollFrame ...
- 12.x secret-related methods on every FrameScriptObject: `HasSecretValues`, `IsPreventingSecretValues`,
  `HasAnySecretAspect`, `HasSecretAspect`, `AddSecretAspect` (the wiki also lists `SetPreventSecretValues`
  under the 12.0 changes).
- EditBox has `SetMaxLetters`, `SetMaxBytes` and `SetCountInvisibleLetters` (SimpleEditBoxAPIDocumentation.lua).
  FontString has `SetTextToFit`.
- Since 9.0, backdrops require the `BackdropTemplate` (defined in `Blizzard_SharedXML/Backdrop.xml`) or
  `BackdropTemplateMixin`. This is general knowledge, and the template is confirmed present in Forever.

## Text sanitizing (player-entered text is untrusted)
`C_StringUtil.StripHyperlinks(text, maintainColor, maintainBrackets, stripNewlines, maintainAtlases, maintainTextures)`
(StringUtilDocumentation.lua, Forever and live). With all flags at their default `false`, it strips `|H` links,
colors `|c..|r`, atlases `|A` and textures `|T`. **Verify the exact behavior in game**, and still apply our own
Lua 5.1 gsub fallback plus a length cap:
```
/dump C_StringUtil.StripHyperlinks("|cffff0000red|r |T134400:16|t |Hitem:1|h[x]|h |A:foo:16:16|a end")
```

## Blizzard building blocks that replace the legacy custom code
| Need | Blizzard API / template (confirmed file in Forever) | Replaces in the legacy code |
|---|---|---|
| Scrolling list with row recycling | `CreateScrollBoxListLinearView`, `ScrollUtil.InitScrollBoxListWithScrollBar`, template `WowScrollBoxList` + `MinimalScrollBar` (`Blizzard_SharedXML/Shared/Scroll/`) | `UIPanelScrollFrameTemplate` plus creating one frame per row on every refresh (leaks frames, `SetParent(nil)` does not free them) |
| Data source | `CreateDataProvider(tbl)` | hand-built y-offset layout |
| Dropdowns / context menus | `Blizzard_Menu`: `MenuUtil.CreateContextMenu`, `WowStyle1DropdownTemplate`, `Menu.ModifyMenu` | Class and Rank "dropdowns" that are plain buttons with no menu (non-functional) |
| Add "Rate player" to right-click unit menus | `Menu.ModifyMenu("MENU_UNIT_PARTY", fn)` (the tag name needs verifying) | nothing (new feature) |
| Window chrome | `ButtonFrameTemplate`, `PortraitFrameTemplate` (`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`) | 1100×700 custom backdrop window with hardcoded sizes |
| Search box | `SearchBoxTemplate` (`Shared/InputBox/InputBoxTemplates.xml`) | `InputBoxTemplate` + label |
| Settings | `Settings.RegisterVerticalLayoutCategory` / `RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory` (`Blizzard_Settings_Shared/Blizzard_Settings.lua`) | "Settings panel - Coming soon!" |
| Class colors | `C_ClassColor.GetClassColor(classFile)`, `RAID_CLASS_COLORS`, `GetClassColorObj`, `ColorMixin:WrapTextInColorCode` | hardcoded class-color table |
| Role icons | `CreateAtlasMarkup` + role atlases (atlas names need verifying) | `UI-LFG-ICON-PORTRAITROLES` texcoords |
| Callbacks / events between modules | `CallbackRegistryMixin` (`Blizzard_SharedXMLBase/CallbackRegistry.lua`), `EventRegistry` | direct calls into the `SquadRank` global |
| Popups | `StaticPopupDialogs` + `StaticPopup_Show` (`Blizzard_StaticPopup/StaticPopup.lua`) | (same, but see the bug below) |
| Minimap entry | **Addon Compartment** (`Blizzard_Minimap/Camelot/AddonCompartment.xml` is a Forever-specific file) via TOC `AddonCompartmentFunc`, or LibDBIcon | 70-line custom minimap button with its own drag math and a bogus `GetMinimapShape` |

### StaticPopup edit box: legacy bug
Forever `Blizzard_StaticPopup_Game/GameDialog.xml:210` declares the edit box as `parentKey="EditBox"` (capital E).
There is no `.editBox` alias anywhere in `Blizzard_StaticPopup*`. Legacy `self.editBox:GetText()` will error.
Use `self.EditBox` or `self:GetEditBox()` if it exists. Test:
```
/run StaticPopupDialogs.SR_T={text="t",hasEditBox=1,button1="OK",OnShow=function(s) print(s.editBox, s.EditBox, s.GetEditBox) end} StaticPopup_Show("SR_T")
```

## Blizzard's own code: patterns worth copying
- **Group iteration** (`Blizzard_CompactRaidFrames/Blizzard_CompactRaidFrameContainer.lua`): `IsInRaid()` → `"raid"..i`
  for `1..MAX_RAID_MEMBERS`; otherwise `"player"` + `"party"..i` for `1..GetNumSubgroupMembers()`. Checks `UnitExists`
  each time. In a raid the `raidN` tokens include the player, so skip the player with `UnitIsUnit(u,"player")`.
- **Dungeon complete** (`Blizzard_FrameXML/Mainline/AlertFrames.lua:565`): toast on `LFG_COMPLETION_REWARD`,
  using `C_Scenario.IsInScenario()` to distinguish scenarios. This fires only for LFG-queued content.
- **Forever difficulty** (`Blizzard_FrameXML/Camelot/InstanceDifficultyOverrides.lua`): Forever labels instances by
  `maxPlayers` (5 = dungeon; 10/20/40 = raid) and uses only `DifficultyUtil.ID.DungeonNormal`, with **no heroic or mythic tiers**.
- **Recent Allies** (`Blizzard_RecentAllies/`, TOC `AllowLoadGameType: mainline`, which includes Forever):
  Blizzard's own "people you recently played with" system. See below.

## C_RecentAllies (in both Forever and live generated docs)
Functions: `IsSystemSupported`, `IsSystemEnabled`, `TryRequestRecentAlliesData`, `IsRecentAllyDataReady`,
`GetRecentAllies`, `SearchRecentAllies(searchInfo)`, `GetRecentAllyByGUID`, `GetRecentAllyByFullName`,
`IsRecentAllyByGUID`, `IsRecentAllyPinned`, `SetRecentAllyPinned(guid,bool)`, `CanSetRecentAllyNote(guid)`,
`SetRecentAllyNote(guid, note)`.
Events: `RECENT_ALLIES_DATA_READY`, `RECENT_ALLIES_CACHE_UPDATE`, `RECENT_ALLY_DATA_UPDATED(guid)`,
`RECENT_ALLIES_SYSTEM_STATUS_UPDATED`.
`characterData`: guid, name, fullName, realmName, level, classID, raceID, sex.
Interaction filters: Professions, PvP, Raiding, **Dungeons**, Delves, Questing. Pins expire (warning at 5 days).

**Why it matters:** it already gives GUID-keyed "who did I group with", plus a server-stored note and pin.
SquadRank's unique value is then the **rating, per-run history and our own notes**, which we must not write into
Blizzard's note field without the user agreeing to it.
Test:
```
/run print(C_RecentAllies.IsSystemSupported(), C_RecentAllies.IsSystemEnabled(), C_RecentAllies.IsRecentAllyDataReady())
/run C_RecentAllies.TryRequestRecentAlliesData() C_Timer.After(2,function() local t=C_RecentAllies.GetRecentAllies() print(#t) if t[1] then print(t[1].characterData.fullName, t[1].characterData.guid) end end)
```

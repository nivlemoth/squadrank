# API verification log (per SKILL.md `wow-api-check`)

Checked 2026-11-10 against Blizzard_APIDocumentationGenerated in Gethe/wow-ui-source:
- **F** = `forever` branch @ 4cd0ab7, build 1.60.1 (70888)
- **L** = `live` branch @ 297d7aa, build 12.1.5 (70783)

Status: **verified-src** = present in the generated docs on both clients, signature as shown.
**undocumented** = a global absent from the generated docs (normal for old globals), so it **needs the in-game test**
before use. **in-game ✔** = Nivlemoth has confirmed it in game (no entries yet).

## Unit / group
| API | Status | Secret flag (F) | In-game test |
|---|---|---|---|
| `UnitName(unit)` → name, server | verified-src F+L | SecretWhenUnitNameIdentityRestricted | `/run print(UnitName("party1"))` |
| `UnitFullName(unit)` → name, server | verified-src F+L | SecretWhenUnitIdentityRestricted | `/run print(UnitFullName("party1"))` |
| `UnitGUID(unit)` → guid? | verified-src F+L | SecretWhenUnitIdentityRestricted | `/run print(UnitGUID("party1"))` |
| `UnitClass(unit)` → locName, classFile, classID | verified-src F+L | ret1 ConditionalSecret only | |
| `UnitFactionGroup(unit)` → tag, localized | verified-src F+L | none | |
| `UnitExists`, `UnitIsPlayer`, `UnitIsUnit` | verified-src F+L | | |
| `UnitGroupRolesAssigned(unit)` | verified-src F+L | SecretWhenUnitIdentityRestricted | `/run print(UnitGroupRolesAssigned("party1"))` — returns `NONE` in Forever manual groups (confirmed by the unknown-role bug, not a new probe) |
| `UnitTokenFromGUID(guid)` | verified-src F+L | SecretWhenUnitIdentityRestricted | |
| `GetPlayerInfoByGUID(guid)` → locClass, class, locRace, race, sex, name, realm, level? | verified-src F+L | none flagged | `/run print(GetPlayerInfoByGUID(UnitGUID("party1")))` |
| `IsInGroup()` | **undocumented** | | `/run print(type(IsInGroup), IsInGroup())` |
| `IsInRaid()` | **undocumented** | | `/run print(type(IsInRaid), IsInRaid())` |
| `GetNumGroupMembers()` | **undocumented** | | `/run print(type(GetNumGroupMembers), GetNumGroupMembers())` |
| `GetNumSubgroupMembers()` | **undocumented** (used by Blizzard CompactRaidFrames) | | `/run print(type(GetNumSubgroupMembers), GetNumSubgroupMembers())` |
| `GetRaidRosterInfo(i)` | **undocumented** (used by Blizzard) | | `/run print(GetRaidRosterInfo(1))` |
| `GetRealmName()` / `GetNormalizedRealmName()` | verified-src F+L | | `/run print(GetRealmName(), GetNormalizedRealmName())` |

## Instance / encounter
| API / event | Status | Notes |
|---|---|---|
| `IsInInstance()` | verified-src F+L | |
| `GetInstanceInfo()` → name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, lfgDungeonID, hasWorldTier | verified-src F+L | use **instanceID** for keys, not the name |
| `GetDifficultyInfo(id)` | verified-src F+L | |
| `GetZoneText()` | verified-src F+L | localized, so display only |
| `ENCOUNTER_START` (id, name, difficultyID, groupSize) | verified-src F+L | need to test that it fires in Forever dungeons |
| `ENCOUNTER_END` (+ success; L adds encounterUnitStatus) | verified-src F+L | **payload differs** |
| `BOSS_KILL`, `GROUP_ROSTER_UPDATE`, `GROUP_JOINED`, `GROUP_LEFT`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_REGEN_*`, `ADDON_RESTRICTION_STATE_CHANGED`, `LFG_COMPLETION_REWARD` | verified-src F+L | |

## Restrictions / secrets
| API | Status |
|---|---|
| `issecretvalue`, `canaccessvalue`, `issecrettable`, `canaccesstable` | verified-src F+L |
| `C_RestrictedActions.IsAddOnRestrictionActive(type)`, `.GetAddOnRestrictionState(type)`, `InCombatLockdown()` | verified-src F+L |
| `C_Secrets.ShouldUnitIdentityBeSecret` | verified-src F+L |

## UI / util
| API | Status | Notes |
|---|---|---|
| `C_Timer.After`, `C_Timer.NewTicker` | verified-src F+L | |
| `C_ClassColor.GetClassColor(classFile)` | verified-src F+L | |
| `C_AddOns.GetAddOnMetadata` | verified-src F+L | |
| `C_StringUtil.StripHyperlinks(text, ...)` | verified-src F+L | test: see widget-api-and-blizzard-ui.md |
| `GetCursorPosition`, `Region:GetEffectiveScale` | verified-src F+L | |
| `GetServerTime()`, `date()` | verified-src F+L | store `GetServerTime()` epoch, not formatted strings |
| `GetCVar`, `GetCVarBool` | verified-src F+L | |
| `Minimap:SetArchBlobRingScalar` | verified-src F (method **exists**) | so legacy `GetMinimapShape()` always returns "square" (bug) |
| CVar `minimapShapeshiftTracking` | **not found** anywhere in F source | legacy uses it, and it is meaningless |
| `strsplit` | **undocumented** (WoW Lua global) | `/run print(strsplit(":", "a:b"))` |
| `StaticPopup` dialog `.editBox` | **absent in F**; the field is `.EditBox` | test in widget-api-and-blizzard-ui.md |
| `table.getn` | Lua 5.0 compatibility, present in WoW's 5.1 | legacy calls it on a hash table, so it always returns 0 (bug) |

## C_RecentAllies (candidate dependency)
All functions listed in widget-api-and-blizzard-ui.md are verified-src F+L. **Runtime enablement on Forever is unknown:**
`/run print(C_RecentAllies.IsSystemSupported(), C_RecentAllies.IsSystemEnabled())`

## Added during the v0.1 build (2026-11-10)

All of these were checked in the Forever source (`forever` @ 4cd0ab7) but **none has run in the client yet**.
Each is called through a guard (pcall or a nil check), and `/sr selftest` reports on it.

| API | Source file in Forever | Status | Guard / fallback |
|---|---|---|---|
| `GROUP_JOINED(category, partyGUID)`, `GROUP_LEFT` | PartyInfoDocumentation.lua | verified-src, **unverified in game** | party GUID is only a session key; nil is fine |
| `SAVED_VARIABLES_TOO_LARGE(addOnName)` | AddOnsDocumentation.lua | verified-src | warning only |
| `C_GameRules.IsHardcoreActive()` | GameRulesDocumentation.lua | verified-src, **unverified in game** | pcall; ruleset tag falls back to the realm name |
| Second return of `UnitName` on Forever (realm or surname) | UnitPopupShared.lua:34-50 | **unverified** | stored as returned; self-test reports type and length only |
| `Menu.ModifyMenu(tag, fn)` with tags `MENU_UNIT_PARTY`, `_RAID_PLAYER`, `_PLAYER`, `_TARGET`, `_FOCUS` | Blizzard_Menu/Menu.lua:2767, UnitPopupShared.lua:110 | verified-src, **unverified in game** | pcall per tag; `/sr rate <name>` always works |
| `MenuUtil.CreateContextMenu`, `root:CreateButton/CreateRadio/CreateTitle/CreateDivider` | Blizzard_Menu/MenuUtil.lua, 11_0_0_MenuImplementationGuide.lua | verified-src | nil check + pcall |
| `Settings.RegisterVerticalLayoutCategory`, `RegisterAddOnSetting(category, variable, key, tbl, type, name, default)`, `CreateCheckbox`, `CreateSlider`, `CreateSliderOptions`, `RegisterAddOnCategory` | Blizzard_Settings_Shared/Blizzard_Settings.lua | verified-src | each control in its own pcall |
| `CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, addSearchTags)` | Blizzard_SettingControls.lua:1040 | verified-src | pcall |
| `ButtonFrameTemplate` + `ButtonFrameTemplate_HidePortrait/_HideButtonBar`, `frame:SetTitle` | SharedUIPanelTemplates.xml/.lua, PortraitFrame.lua | verified-src | pcall; plain backdrop window otherwise |
| `WowScrollBoxList`, `MinimalScrollBar`, `CreateScrollBoxListLinearView`, `view:SetElementExtent`, `view:SetElementInitializer("Button", fn)`, `ScrollUtil.InitScrollBoxListWithScrollBar`, `CreateDataProvider`, `ScrollBoxConstants.RetainScrollPosition` | Shared/Scroll/*, FrameFactory.lua:12-26 (frame types allowed) | verified-src | pcall; recycled-row list otherwise; `/sr debug lists` forces the fallback |
| `TooltipBackdropTemplate` (toast) | SharedTooltipTemplates.xml | verified-src | pcall; `BackdropTemplate` otherwise |
| `SearchBoxTemplate`, `InputBoxTemplate`, `UIPanelButtonTemplate`, `UIPanelCloseButton`, `UIPanelScrollFrameTemplate` | InputBoxTemplates.xml, SharedUIPanelTemplates.xml, SecureScrollTemplates.xml | verified-src | search box falls back to InputBoxTemplate |
| `StaticPopupDialogs` / `StaticPopup_Show(which, text, nil, data)`, `OnAccept(dialog, data)` | Blizzard_StaticPopup/StaticPopup.lua | verified-src | no edit box is used |
| `C_AddOns.GetAddOnMetadata(..., "AddonCompartmentFunc")` calling `_G[name](addonName, buttonName)` | Blizzard_Minimap/Mainline/AddonCompartment.lua:106-125 | verified-src | `/sr` always works |
| `C_RecentAllies.GetRecentAllyByFullName`, `IsSystemEnabled` | RecentAlliesDocumentation.lua | verified-src; **enabled state unknown** | off by default; nil check + pcall |
| `LOCALIZED_CLASS_NAMES_MALE` | not checked | **unverified** | read through `_G`; falls back to the class token |
| TOC `IconTexture: Interface\Icons\INV_Misc_GroupLooking` | not checked | **unverified** | cosmetic only |

## Added for 0.2.0 (2026-11-11)

Checked in the Forever source (`forever` @ 4cd0ab7). None has run in the client yet. All are cosmetic: if one
fails, the window still works without that motion or art.

| API | Source in Forever | Status | Guard / fallback |
|---|---|---|---|
| `Region:CreateAnimationGroup`, `AnimationGroup:CreateAnimation/Play/Stop/SetLooping`, `Animation:SetDuration/SetSmoothing`, `Alpha:SetFromAlpha/SetToAlpha`, `Scale:SetScaleFrom/SetScaleTo/SetOrigin` | SimpleAnimatableObjectAPI, SimpleAnimGroupAPI, SimpleAnimAPI, SimpleAnimAlphaAPI, SimpleAnimScaleAPI documentation | verified-src | pcall; self-test row "animation groups" |
| `Frame:SetScript("OnUpdate")`, `Frame:SetClipsChildren` | SimpleFrameAPIDocumentation.lua | verified-src | SetClipsChildren in pcall |
| `Texture:SetAtlas`, `Texture:SetBlendMode`, `Texture:SetColorTexture` | SimpleTextureBaseAPIDocumentation.lua | verified-src | SetAtlas and SetBlendMode in pcall |
| Atlases `groupfinder-icon-role-large-tank/-heal/-dps`, `checkmark-minimal` | used by Forever's own LFG UI (Blizzard_LFGUtil/Shared/LFGRole.xml and others) | verified-src | self-test row "role and checkmark atlases" (via `C_Texture.GetAtlasInfo`, TextureUtilsDocumentation.lua) |
| `Button:SetFontString` | SimpleButtonAPIDocumentation.lua | verified-src | |
| `GetZoneText()` | listed above | verified-src | open-world group runs are named after the zone; nil shows "Group in the world" |
| `GameTooltip:SetOwner/SetText/Show/Hide` | Blizzard FrameXML global | not in generated docs | nil check before use |

## Added for 0.3.0 (2026-11-11)

Checked in the Forever source (`forever` @ 4cd0ab7). None has run in the client yet. All are cosmetic or
optional: if one fails, SquadRank still works (no minimap button, or a plainer look). Two new self-test rows
cover them: "minimap button" and "flat look".

| API | Source in Forever | Status | Guard / fallback |
|---|---|---|---|
| `Minimap` (global frame) | Blizzard_Minimap/Mainline/Minimap.xml (`<Minimap name="Minimap">`) | verified-src | type check; no button if missing |
| `GetCursorPosition()` | InputDocumentation.lua | verified-src | nil check while dragging |
| `Region:GetCenter`, `Frame:GetEffectiveScale`, `Frame:GetFrameLevel/SetFrameLevel` | SimpleScriptRegionResizingAPI, SimpleFrameAPI documentation | verified-src | |
| `Texture:SetRotation`, `Texture:SetGradient`, `Texture:SetDesaturated`, `Texture:SetTexCoord` | SimpleTextureBaseAPIDocumentation.lua | verified-src | SetRotation, SetGradient, SetDesaturated in pcall |
| `CreateColor` | Blizzard SharedXML (Color.lua) | not in generated docs | checked for nil; plain colour if missing |
| `ScrollFrame:EnableMouseWheel/GetVerticalScrollRange/GetVerticalScroll/SetVerticalScroll`, `OnMouseWheel`, `OnScrollRangeChanged` | SimpleScrollFrameAPIDocumentation.lua | verified-src | self-test row "flat look" |
| `EditBox:SetTextInsets/SetFontObject` | SimpleEditBoxAPIDocumentation.lua | verified-src | |
| `Setting:SetValueChangedCallback` | Blizzard_Settings_Shared/Blizzard_Setting.lua line 265 | verified-src | checked for nil, in pcall |
| Font objects `GameFontHighlightHuge`, `GameFontHighlightHuge2`, `GameFontHighlightMedium`, `GameFontNormalMed2`, `GameFontHighlightExtraSmall` | Blizzard_Fonts_Shared Fonts.xml | verified-src | |
| Textures `Interface\Minimap\UI-Minimap-ZoomButton-Highlight` | Blizzard_Minimap/Mainline/Minimap.xml | verified-src | |
| Textures `Interface\Minimap\MiniMap-TrackingBorder`, `Interface\Minimap\UI-Minimap-Background`, icons `INV_Misc_Note_01`, `INV_Misc_Map_01`, `Trade_Engineering`, `INV_Misc_Book_09` | game files, not referenced in Forever's UI source | **unverified** (art only) | a missing file shows nothing; TESTING step 4 checks them by eye |

## Added for localization (2026-11-12)

| API | Source in Forever | Status | Guard / fallback |
|---|---|---|---|
| `GetLocale()` -> localeName | LocaleDocumentation.lua | verified-src | pcall; English if missing or not a four-letter code |
| `FontString:IsTruncated()` | SimpleFontStringAPIDocumentation.lua | verified-src | pcall; no tooltip if missing |
| `GameTooltip:IsOwned(owner)` | Blizzard FrameXML (GameTooltip) | not in generated docs | checked for nil before use |
| `UNKNOWNOBJECT` (localized "Unknown") | GlobalStrings | already used by Compat | compared only; nil-safe |
| TOC `## Notes-<locale>:` | TOC format (docs/ref/toc-format.md) | documented | English `## Notes:` first |
| Font families with korean / simplifiedchinese / traditionalchinese / russian members | Blizzard_Fonts_Shared/Mainline/Fonts.xml | verified-src | no font change made |

## Added for group types, quests and bosses (2026-11-12)

| API / event | Source in Forever | Status | Guard / fallback |
|---|---|---|---|
| `QUEST_TURNED_IN` (questID, xpReward, moneyReward) | QuestLogDocumentation.lua | verified-src | number check; queued until out of combat |
| `QUEST_WATCH_UPDATE` (questID) | QuestLogDocumentation.lua | verified-src | same |
| `C_QuestLog.GetTitleForQuestID(questID)` -> title? | QuestLogDocumentation.lua | verified-src | pcall; stored title, then "Quest <id>" |
| `C_PvP.GetZonePVPInfo()` -> pvpType, isSubZonePvP, factionName? | PvpInfoDocumentation.lua (namespace C_PvP) | verified-src | checked for nil; no world PvP type if missing |
| `BOSS_KILL` (encounterID, encounterName) | EncounterInfoDocumentation.lua | verified-src | deduplicated with ENCOUNTER_END by ID |
| `ENCOUNTER_END` args 1-2 (encounterID, encounterName) | EncounterInfoDocumentation.lua | verified-src | name cleaned (secret check) and sanitized |
| `EditBox:HighlightText()` | SimpleEditBoxAPIDocumentation.lua | verified-src | |

Self-test: "events seen" now also counts QUEST_TURNED_IN and QUEST_WATCH_UPDATE; the API list checks
`C_QuestLog.GetTitleForQuestID` and `C_PvP.GetZonePVPInfo`.

## Added for avoid list, tooltips and sounds (2026-11-12)

| API | Source in Forever | Status | Guard / fallback |
|---|---|---|---|
| `PlaySound(soundKitID, ...)` | SoundDocumentation.lua | verified-src | type check, pcall; setting can turn it off |
| `SOUNDKIT.IG_PLAYER_INVITE` (880), `TELL_MESSAGE` (3081), `RAID_WARNING` (8959) | Blizzard_SharedXML/Mainline/SoundKitConstants.lua | verified-src | numeric IDs used if SOUNDKIT is missing |
| `TooltipDataProcessor.AddTooltipPostCall(type, func)` | Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua line 199 | verified-src | checked for nil; note in /sr debug |
| `Enum.TooltipDataType.Unit` (2) | TooltipInfoSharedDocumentation.lua | verified-src | checked for nil |
| `GameTooltip:GetUnit()` -> name, unit | Blizzard FrameXML (tooltip mixin) | not in generated docs | pcall; no line if it fails |

| `C_PvP.IsWarModeActive()` -> bool | PvpInfoDocumentation.lua (namespace C_PvP) | verified-src | checked for nil; secret-checked; false if missing |

## Added for contextual alerts (2026-11-13)

**No new game functions are called.** The milestone reuses `Events.On`, `Events.RunOutOfCombat`,
`Compat.Clean`, `Compat.UnitIdentity`, `Compat.Now`, `Players.Find`, `Players.Lookup`,
`Ratings.Summary` and the existing `Toast` queue. Only four event registrations are new.

| Event | Status | Payload used | Guard / fallback |
|---|---|---|---|
| `CHAT_MSG_WHISPER` | Standard client event; **not in the generated API docs checked**; observed in TheList v0.5.10; **unverified in Forever** | first argument (message) **ignored**; third argument (sender name) | `Events.On` registers in `pcall`; a missing event logs and is ignored. Non-string sender is cleaned to nil and dropped. |
| `PLAYER_TARGET_CHANGED` | Standard client event; **unverified in Forever** | none; handler reads `target` through `Compat.UnitIdentity` | Same registration guard; a unit with no identity is dropped. |
| `TRADE_REQUEST` | Standard client event; **not in the generated API docs checked**; observed in TheList; **unverified in Forever** | second argument (requester name) | Same registration guard; `TRADE_SHOW` deliberately not used. |
| `DUEL_REQUESTED` | Standard client event; **not in the generated API docs checked**; observed in TheList; **unverified in Forever** | second argument (challenger name) | Same registration guard. |

**What still needs the client.** Confirm that each event fires in Forever 1.60.1 with the
argument positions above, that `PLAYER_TARGET_CHANGED` fires for players as well as NPCs, and that a
whisper sender arrives as a plain name. `/sr selftest` counts events seen, so a simple in-game check
is to trigger each event and compare the counter before and after.

**Privacy note.** The whisper handler's signature `function(_, _, sender)` means the message body is
never bound to a local and cannot reach the log or the database.

## Live probe for 1.5 (2026-11-16)

Run in the installed Forever client. Status labels: **in-game ✔** = the value or call behaved as expected;
**in-game ✘** = the probe did not give a usable result; **not used** = deliberately avoided even where a call
appears to work.

| API / event | Probe result | Status | How SquadRank uses it |
|---|---|---|---|
| `UnitName(unit)` -> name, realm/surname | returned plain strings | in-game ✔ | `Compat.UnitIdentity`; both parts cleaned |
| `UnitGUID(unit)` | returned a plain string | in-game ✔ | identity key; a secret GUID is dropped |
| `UnitGroupRolesAssigned(unit)` | returned a plain string; `NONE` in Forever manual groups (confirmed by the unknown-role bug, not a new probe) | in-game ✔ | rating role only; `NONE` stays unknown, never guessed as DPS |
| `C_RecentAllies.IsSystemSupported()` | `true` | in-game ✔ | `/sr allies` availability |
| `C_RecentAllies.IsSystemEnabled()` | `true` | in-game ✔ | `/sr allies` availability |
| `C_RecentAllies` data-ready state | `/sr selftest` reported `IsRecentAllyDataReady=true` | in-game ✔ | read-only list and typed-name lookup |
| `C_CombatLog.IsCombatLogRestricted()` | `true` in town and in a dungeon | in-game ✔ | confirms the combat log is not an input |
| `COMBAT_LOG_EVENT_UNFILTERED` registration | registration did not error but the event was ignored | in-game ✘ | **not used**; never registered |
| `C_Secrets.ShouldAurasBeSecret()` | `false` in town, `true` in a dungeon even out of combat | in-game ✔ | never branched on; aura fields are not read |
| `C_UnitAuras.GetAuraDataByIndex(unit, 1, "HELPFUL")` | call succeeded inside `pcall` | in-game ✔ | **not used**; no aura field is read |
| Debuff / threat probes | returned nothing usable | in-game ✘ | **not used** |
| `UnitDetailedThreatSituation` | not called | not used | **never called** |
| `C_GameRules.IsHardcoreActive()` | `false` | in-game ✔ | ruleset tag only |
| LFG completion probe | not a clean boolean | in-game ✘ | not used for any rule |
| `ENCOUNTER_END` / `BOSS_KILL` | counters stayed at `0` (no encounter observed during the probe) | in-game ✘ | optional run details; nothing depends on it |
| `C_RestrictedActions.IsAddOnRestrictionActive()` with no argument | returned nothing | in-game ✘ | called with an explicit type elsewhere |

**Banned by design.** SquadRank does not grade buffs, dispels, interrupts or threat, and the source and tests
must not reference `C_UnitAuras`, `UnitAura`, `UnitBuff`, `UnitDebuff`,
`UnitDetailedThreatSituation`, `CombatLogGetCurrentEventInfo`, `COMBAT_LOG_EVENT` or
`COMBAT_LOG_EVENT_UNFILTERED`. `spec/api_spec.lua` scans every TOC-listed addon file and every spec file and
fails the suite if one of those names appears. The scan builds the names from pieces so the scanner does not
match itself.

**Recent Allies display.** The social frame's recent-ally list and card tooltips are created dynamically by
Blizzard, and the hook was not verified against the installed client source. SquadRank therefore does not hook
that frame. Instead, `/sr allies` reads `C_RecentAllies.GetRecentAllies()` behind `pcall`, cleans each entry,
and lists only entries that match a player already saved locally. It never writes a Blizzard note, pin or
Recent Allies record and never creates a local player record.

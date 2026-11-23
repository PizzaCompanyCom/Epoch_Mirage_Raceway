-- Mirage Raceway Leaderboard: main window, compatible with WoW 3.3.5a / Lua 5.1
local root=CreateFrame('Frame')
local window, board, stats, pages, rows, refresh, showTab
local currentTab='board'
local demoRecords=nil
local asset='Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\leaderboard_bg.tga'
local function DB() return MirageRacewayDB or {} end
local function fmt(s)
 if type(s)~='number' then return '--:--.---' end
 return string.format('%02d:%02d.%03d',math.floor(s/60),math.floor(s)%60,math.floor(s*1000+.5)%1000)
end
local function text(parent,value,size,color)
 local f=parent:CreateFontString(nil,'OVERLAY',size or 'GameFontNormal')
 f:SetText(value or '')
 if color then f:SetTextColor(unpack(color)) end
 return f
end
local function backdrop(frame,r,g,b,a)
 frame:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',tile=false,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 frame:SetBackdropColor(r or .05,g or .06,b or .08,a or .86)
 frame:SetBackdropBorderColor(.56,.43,.23,.95)
end
local icons={Tournament='INV_Misc_Coin_01',['Best Time']='INV_Misc_PocketWatch_01',Leaderboard='INV_Misc_Note_01',['My Statistics']='INV_Misc_PocketWatch_01',Settings='INV_Gizmo_02',Refresh='Ability_Rogue_Sprint',Contacts='INV_Letter_15',Season='INV_Misc_PocketWatch_01',['Reset Season Best']='Ability_Rogue_FeignDeath',['Master Management']='INV_Misc_Note_01',Rules='INV_Misc_Book_09'}
local function makeButton(parent,label,w,h)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetWidth(w);b:SetHeight(h);b:SetText(label)
 local icon=icons[label]
 if icon then
  local t=b:CreateTexture(nil,'OVERLAY');t:SetTexture('Interface\\Icons\\'..icon);t:SetWidth(17);t:SetHeight(17);t:SetPoint('LEFT',b,'LEFT',7,0)
  local fs=b:GetFontString();if fs then fs:ClearAllPoints();fs:SetPoint('LEFT',t,'RIGHT',5,0);fs:SetPoint('RIGHT',b,'RIGHT',-3,0);fs:SetJustifyH('CENTER') end
 end
 return b
end
local function create()
 window=CreateFrame('Frame','MirageRacewayMainWindow',UIParent)
 window:SetWidth(770);window:SetHeight(700);window:SetFrameStrata('DIALOG');window:SetClampedToScreen(true)
 window:SetMovable(true);window:EnableMouse(true);window:RegisterForDrag('LeftButton')
 window:SetScript('OnDragStart',function(self) self:StartMoving() end)
 window:SetScript('OnDragStop',function(self)
  self:StopMovingOrSizing()
  local _,_,_,x,y=self:GetPoint();DB().mainX=x;DB().mainY=y
 end)
 local d=DB();window:SetPoint('CENTER',UIParent,'CENTER',d.mainX or 0,d.mainY or 0)
 window:SetScale(d.mainScale or 1)
 local bg=window:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints(window);bg:SetTexture(asset);bg:SetTexCoord(0,1,.125,.875)
 local tint=window:CreateTexture(nil,'BORDER');tint:SetAllPoints(window);tint:SetTexture(0,0,0,.46)
 -- Racing checkered-flag border. Texture is repeated instead of stretched.
 local borderTexture='Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\checker_border.tga'
 local function checkStrip(point1,point2,width,height,vertical)
  local t=window:CreateTexture(nil,'OVERLAY');t:SetTexture(borderTexture)
  t:SetPoint(point1,window,point1,0,0)
  if point2 then t:SetPoint(point2,window,point2,0,0) end
  t:SetWidth(width);t:SetHeight(height)
  if vertical then t:SetTexCoord(0,1,0,17) else t:SetTexCoord(0,1.5,0,1) end
  return t
 end
 local topCheck=checkStrip('TOPLEFT','TOPRIGHT',770,12,false)
 local bottomCheck=checkStrip('BOTTOMLEFT','BOTTOMRIGHT',770,12,false)
 local leftCheck=checkStrip('TOPLEFT','BOTTOMLEFT',12,700,true)
 local rightCheck=checkStrip('TOPRIGHT','BOTTOMRIGHT',12,700,true)
 local function edgeShade(t) t:SetVertexColor(.88,.83,.7,.94) end
 edgeShade(topCheck);edgeShade(bottomCheck);edgeShade(leftCheck);edgeShade(rightCheck)

 local top=CreateFrame('Frame',nil,window);top:SetPoint('TOPLEFT',12,-12);top:SetPoint('TOPRIGHT',-12,-12);top:SetHeight(62);backdrop(top,.06,.06,.06,.84)
 local title=text(top,'MIRAGE RACEWAY','GameFontNormalHuge',{1,.78,.32});title:SetPoint('LEFT',top,'LEFT',17,7)
 local subtitle=text(top,'BEST TIME & PERSONAL STATISTICS','GameFontHighlightSmall',{.9,.82,.66});subtitle:SetPoint('TOPLEFT',title,'BOTTOMLEFT',0,-4)
 local close=CreateFrame('Button',nil,window,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-7,-7)
 local tabs={}
 local function tab(label,x,which)
  local b=makeButton(window,label,160,29);b:SetPoint('TOPLEFT',window,'TOPLEFT',20+x,-85)
  b:SetScript('OnClick',function() showTab(which) end);tabs[which]=b
 end
 tab('Best Time',0,'board');tab('Tournament',169,'tournament');tab('My Statistics',338,'stats')
 board=CreateFrame('Frame',nil,window);board:SetPoint('TOPLEFT',window,'TOPLEFT',20,-124);board:SetWidth(730);board:SetHeight(515);backdrop(board,.035,.045,.06,.88)
 stats=CreateFrame('Frame',nil,window);stats:SetAllPoints(board);backdrop(stats,.035,.045,.06,.88)
 local tournament=CreateFrame('Frame',nil,window);tournament:SetAllPoints(board);backdrop(tournament,.035,.045,.06,.88)
 local tournamentRefresh=function()end
 local heading=text(board,'TOP 50 RACERS','GameFontNormalLarge',{1,.81,.4});heading:SetPoint('TOPLEFT',16,-12)
 local note=text(board,'OFFICIAL TOP 50','GameFontHighlightSmall',{.75,.77,.78});note:SetPoint('TOPRIGHT',-16,-16)
 local header=CreateFrame('Frame',nil,board);header:SetPoint('TOPLEFT',12,-42);header:SetWidth(706);header:SetHeight(26)
 local hbg=header:CreateTexture(nil,'BACKGROUND');hbg:SetAllPoints(header);hbg:SetTexture(0,0,0,.8)
 local headings={{'RANK',12},{'RACER',95},{'BEST TIME',470}}
 for _,h in ipairs(headings) do local label=text(header,h[1],'GameFontNormalSmall',{.98,.78,.4});label:SetPoint('LEFT',h[2],0) end

 -- Stable race/gender portraits use only Blizzard's built-in 3.3.5 race atlas.
 local function portraitData() local d=DB();d.btPortraits=d.btPortraits or {};return d.btPortraits end
 local function racerKey(name) return name and string.lower(name) end
 local function rememberUnit(unit)
  if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
  local n=UnitName(unit);local key=racerKey(n);if not key then return end
  local _,race=UnitRace(unit);local sex=UnitSex(unit)
  if not race or (sex~=2 and sex~=3) then return end
  local d=portraitData();local item=d[key] or {}
  item.race=race;item.sex=sex;item.faction=UnitFactionGroup(unit)
  d[key]=item
  if MirageRacewayTournament and MirageRacewayTournament.LearnUnit then MirageRacewayTournament:LearnUnit(n,race,sex) end
 end
 local function setRacePortrait(texture,name,race,sex)
  local key=racerKey(name)
  local d=key and portraitData()[key]
  if name and UnitName('player') and string.lower(name)==string.lower(UnitName('player')) then
   local _,pr=UnitRace('player');local ps=UnitSex('player')
   if pr and (ps==2 or ps==3) then
    race=pr;sex=ps
    local pd=portraitData();pd[key]=pd[key] or {};pd[key].race=pr;pd[key].sex=ps
   end
  end
  race=race or (d and d.race)
  sex=tonumber(sex) or (d and tonumber(d.sex))
  local raceName=race and tostring(race):gsub('[^%a]','')
  if raceName and string.lower(raceName)=='scourge' then raceName='Undead' end
  if raceName and (sex==2 or sex==3) then
   -- Achievement character icons are ordinary Interface\Icons textures,
   -- unlike GlueXML character-create textures which may not render in-game.
   local namePart=string.upper(string.sub(raceName,1,1))..string.lower(string.sub(raceName,2))
   if string.lower(raceName)=='nightelf' then namePart='Nightelf' end
   if string.lower(raceName)=='bloodelf' then namePart='Bloodelf' end
   texture:SetTexture('Interface\\Icons\\Achievement_Character_'..namePart..'_'..(sex==3 and 'Female' or 'Male'))
   texture:SetTexCoord(0,1,0,1)
  else
   texture:SetTexture('Interface\\Icons\\INV_Misc_QuestionMark')
   texture:SetTexCoord(0,1,0,1)
  end
 end
 local portraitWatcher=CreateFrame('Frame')
 portraitWatcher:RegisterEvent('PLAYER_TARGET_CHANGED')
 portraitWatcher:RegisterEvent('PARTY_MEMBERS_CHANGED')
 portraitWatcher:RegisterEvent('RAID_ROSTER_UPDATE')
 portraitWatcher:RegisterEvent('PLAYER_ENTERING_WORLD')
 portraitWatcher:SetScript('OnEvent',function()
  rememberUnit('player');rememberUnit('target')
  for i=1,4 do rememberUnit('party'..i) end
  for i=1,40 do rememberUnit('raid'..i) end
  if MirageRacewayBestTimeRefresh then MirageRacewayBestTimeRefresh() end
 end)
 local scroll=CreateFrame('ScrollFrame','MirageRacewayLeaderboardScroll',board,'FauxScrollFrameTemplate')
 scroll:SetPoint('TOPLEFT',board,'TOPLEFT',12,-72);scroll:SetPoint('BOTTOMRIGHT',board,'BOTTOMRIGHT',-29,42)
 rows={}
 for i=1,6 do
  local row=CreateFrame('Frame',nil,board);row:SetWidth(684);row:SetHeight(60);row:SetPoint('TOPLEFT',board,'TOPLEFT',15,-74-(i-1)*63)
  local shade=row:CreateTexture(nil,'BACKGROUND');shade:SetAllPoints(row);shade:SetTexture(.09,.12,.15,.8)
   -- Restore the racing-cloth banner artwork used by v1.0 rows.
   row.fabric=row:CreateTexture(nil,'ARTWORK',nil,-2)
   row.fabric:SetAllPoints(row);row.fabric:SetTexCoord(0,1,.08,.92)
   row.fabric:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\acloth.tga')
   row.fabric:SetVertexColor(.72,.72,.72,.82)
   row.badgeBack=row:CreateTexture(nil,'ARTWORK');row.badgeBack:SetWidth(39);row.badgeBack:SetHeight(39);row.badgeBack:SetPoint('LEFT',row,'LEFT',405,0);row.badgeBack:SetTexture(0,0,0,.72);row.badgeBack:Hide()
   row.teamBadge=row:CreateTexture(nil,'OVERLAY')
   row.teamBadge:SetWidth(34);row.teamBadge:SetHeight(34)
   row.teamBadge:SetPoint('LEFT',row,'LEFT',408,0);row.teamBadge:Hide()
   row.portrait=row:CreateTexture(nil,'OVERLAY');row.portrait:SetWidth(37);row.portrait:SetHeight(37);row.portrait:SetPoint('LEFT',row,'LEFT',46,0);row.portrait:Hide()
  row.rank=text(row,'','GameFontNormal',{1,.8,.35});row.rank:SetPoint('LEFT',9,0)
  row.name=text(row,'','GameFontHighlight');row.name:SetPoint('LEFT',91,0);row.name:SetWidth(305);row.name:SetJustifyH('LEFT')
  row.best=text(row,'','GameFontNormal',{1,.84,.53});row.best:SetPoint('LEFT',468,0);row.best:SetWidth(205);row.best:SetJustifyH('LEFT')
  rows[i]=row
 end
 local empty=text(board,'Loading...','GameFontHighlight',{.83,.85,.87});empty:SetPoint('CENTER',board,'CENTER',0,0)
 local count=text(board,'','GameFontHighlightSmall',{.8,.83,.86});count:SetPoint('BOTTOMLEFT',board,'BOTTOMLEFT',17,14)
 local selected=nil
 MirageRacewayBestTimeUIState={GetSelectedYear=function()return selected end,GetDemoActive=function()return demoRecords~=nil end}
 local function refreshBoard()
  local sync=MirageRacewaySync
  local cache=sync and selected and sync.cache[selected]
  local list=cache and cache.rows or {}
  if demoRecords then
   list={}
    for n,r in pairs(demoRecords) do list[#list+1]={name=n,best=math.floor(r.best*1000+.5),faction=r.faction} end
   table.sort(list,function(a,b)if a.best==b.best then return a.name<b.name end return a.best<b.best end)
   for i,r in ipairs(list) do r.rank=i end
  end
  FauxScrollFrame_Update(scroll,#list,6,63)
  local offset=FauxScrollFrame_GetOffset(scroll)
  for i,row in ipairs(rows) do
   local r=list[i+offset]
    if r then
     row:Show();row.rank:SetText(tostring(r.rank or (i+offset)));row.name:SetText(r.name);row.best:SetText(sync.Format(r.best))
     -- Use the correct team art only when faction is actually known.
     local faction=r.faction
     if not faction and r.name==UnitName('player') then faction=UnitFactionGroup('player') end
     if not faction and portraitData()[racerKey(r.name)] then faction=portraitData()[racerKey(r.name)].faction end
     if faction=='Horde' or faction=='Alliance' then
      row.fabric:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\'..(faction=='Horde' and 'hcloth.tga' or 'acloth.tga'))
      row.fabric:SetVertexColor(.82,.82,.82,.92)
      row.teamBadge:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\'..(faction=='Horde' and 'goblin.tga' or 'gnome.tga'))
      row.teamBadge:SetVertexColor(1,1,1,1);row.teamBadge:Show();row.badgeBack:Hide()
     else
      row.fabric:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\acloth.tga')
      row.fabric:SetVertexColor(.82,.82,.82,.92)
      row.teamBadge:Hide();row.badgeBack:Hide()
     end
     setRacePortrait(row.portrait,r.name,r.race,r.sex)
     row.portrait:Show()
    else row.teamBadge:Hide();row.badgeBack:Hide();row.portrait:Hide();row:Hide() end
  end
  if #list==0 then
   empty:SetText((cache or demoRecords) and 'No Records Yet' or (sync and sync.active and 'Loading...' or 'Leaderboard Unavailable'))
   empty:Show()
  else empty:Hide() end
  count:SetText((cache or demoRecords) and ('Top '..#list..' racers') or '')
  note:SetText(demoRecords and 'DEMO - NOT OFFICIAL' or (selected and ('SEASON '..selected) or 'SERVER DATE UNAVAILABLE'))
 end
 scroll:SetScript('OnVerticalScroll',function(self,offset) FauxScrollFrame_OnVerticalScroll(self,offset,63,refreshBoard) end)
 local seasons=makeButton(board,'Season',138,25);seasons:SetPoint('TOPRIGHT',board,'TOPRIGHT',-14,-7)
 local boardRefresh=makeButton(board,'Refresh',110,25);boardRefresh:SetPoint('RIGHT',seasons,'LEFT',-7,0)
 boardRefresh:SetScript('OnClick',function()if MirageRacewaySync then MirageRacewaySync:RefreshNow(selected)end;refreshBoard()end)
 local function chooseSeason(year)
  if not year then return end
  selected=year;FauxScrollFrame_SetOffset(scroll,0)
  if MirageRacewaySync then MirageRacewaySync:Open(year) end
  refreshBoard()
 end
 seasons:SetScript('OnClick',function(self)
  if not MirageRacewaySync then return end
  local year=MirageRacewaySync.ServerYear();if not year then return end
  local menu={{text='Select Season',isTitle=true,notCheckable=true}}
  for y=year,2026,-1 do
   local sy=y
   menu[#menu+1]={text=tostring(y),notCheckable=true,func=function()chooseSeason(sy)end}
  end
  if not MirageRacewaySeasonMenu then MirageRacewaySeasonMenu=CreateFrame('Frame','MirageRacewaySeasonMenu',UIParent,'UIDropDownMenuTemplate') end
  if DropDownList1 and DropDownList1:IsShown() and UIDROPDOWNMENU_OPEN_MENU==MirageRacewaySeasonMenu then
   CloseDropDownMenus();return
  end
  EasyMenu(menu,MirageRacewaySeasonMenu,self,0,0,'MENU')
 end)
 MirageRacewayBestTimeRefresh=refreshBoard
 local function openBoard()
  local year=MirageRacewaySync and MirageRacewaySync.ServerYear()
  if year then chooseSeason(year) else selected=nil;refreshBoard() end
 end
 local tourTitle=text(tournament,'TOURNAMENT - TOP 50','GameFontNormalLarge',{1,.81,.4});tourTitle:SetPoint('TOPLEFT',16,-12)
 local tourSeason=text(tournament,'','GameFontHighlightSmall',{.75,.77,.78});tourSeason:SetPoint('TOPRIGHT',-16,-16)
 local tourHead=CreateFrame('Frame',nil,tournament);tourHead:SetPoint('TOPLEFT',12,-42);tourHead:SetWidth(706);tourHead:SetHeight(26)
 local thbg=tourHead:CreateTexture(nil,'BACKGROUND');thbg:SetAllPoints(tourHead);thbg:SetTexture(0,0,0,.8)
 for _,h in ipairs({{'RANK',12},{'RACER',95},{'GOLD WON',470}}) do local f=text(tourHead,h[1],'GameFontNormalSmall',{.98,.78,.4});f:SetPoint('LEFT',h[2],0) end
 local tscroll=CreateFrame('ScrollFrame','MirageRacewayTournamentScroll',tournament,'FauxScrollFrameTemplate')
 tscroll:SetPoint('TOPLEFT',tournament,'TOPLEFT',12,-72);tscroll:SetPoint('BOTTOMRIGHT',tournament,'BOTTOMRIGHT',-29,42)
 local trows={}
 for i=1,6 do
  local r=CreateFrame('Frame',nil,tournament);r:SetWidth(684);r:SetHeight(60);r:SetPoint('TOPLEFT',tournament,'TOPLEFT',15,-74-(i-1)*63)
  r.fabric=r:CreateTexture(nil,'ARTWORK');r.fabric:SetAllPoints(r);r.fabric:SetTexCoord(0,1,.08,.92)
  r.portrait=r:CreateTexture(nil,'OVERLAY');r.portrait:SetWidth(37);r.portrait:SetHeight(37);r.portrait:SetPoint('LEFT',r,'LEFT',46,0)
  r.rank=text(r,'','GameFontNormal',{1,.8,.35});r.rank:SetPoint('LEFT',9,0)
  r.name=text(r,'','GameFontHighlight');r.name:SetPoint('LEFT',91,0);r.name:SetWidth(305);r.name:SetJustifyH('LEFT')
  r.team=r:CreateTexture(nil,'OVERLAY');r.team:SetWidth(34);r.team:SetHeight(34);r.team:SetPoint('LEFT',r,'LEFT',408,0)
  r.gold=text(r,'','GameFontNormal',{1,.84,.53});r.gold:SetPoint('LEFT',468,0);r.gold:SetWidth(118);r.gold:SetJustifyH('RIGHT')
  r.coin=r:CreateTexture(nil,'OVERLAY');r.coin:SetTexture('Interface\\Icons\\INV_Misc_Coin_01');r.coin:SetWidth(22);r.coin:SetHeight(22);r.coin:SetPoint('LEFT',r,'LEFT',595,0)
  trows[i]=r
 end
 local tempty=text(tournament,'Loading...','GameFontHighlight');tempty:SetPoint('CENTER',0,0)
 local tcount=text(tournament,'','GameFontHighlightSmall');tcount:SetPoint('BOTTOMLEFT',17,14)
 local tselected=nil
 tournamentRefresh=function()
  local T=MirageRacewayTournament;local cache=T and tselected and T.cache[tselected];local list=cache and cache.rows or {}
  FauxScrollFrame_Update(tscroll,#list,6,63)
  local offset=FauxScrollFrame_GetOffset(tscroll)
  for i,r in ipairs(trows) do
   local item=list[i+offset]
   if item then
    r:Show();r.rank:SetText(tostring(item.rank or (i+offset)));r.name:SetText(item.name);r.gold:SetText(tostring(item.gold or 0))
    local faction=item.faction
    r.fabric:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\'..(faction=='Horde' and 'hcloth.tga' or 'acloth.tga'))
    r.team:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\'..(faction=='Horde' and 'goblin.tga' or 'gnome.tga'))
    if faction~='Horde' and faction~='Alliance' then r.team:Hide() else r.team:Show() end
    r.fabric:SetVertexColor(.82,.82,.82,.92)
    setRacePortrait(r.portrait,item.name,item.race,item.sex)
   else r:Hide() end
  end
  if #list==0 then tempty:Show() else tempty:Hide() end;tempty:SetText(cache and 'No Tournament Records Yet' or 'Tournament Unavailable')
  tcount:SetText('Top '..#list..' racers');tourSeason:SetText(tselected and ('SEASON '..tselected) or 'SERVER DATE UNAVAILABLE')
 end
 tscroll:SetScript('OnVerticalScroll',function(self,offset)FauxScrollFrame_OnVerticalScroll(self,offset,63,tournamentRefresh)end)
 local tseasons=makeButton(tournament,'Season',138,25);tseasons:SetPoint('TOPRIGHT',-14,-7)
 local tourRefresh=makeButton(tournament,'Refresh',110,25);tourRefresh:SetPoint('RIGHT',tseasons,'LEFT',-7,0)
 tourRefresh:SetScript('OnClick',function()if MirageRacewayTournament then MirageRacewayTournament:RefreshNow(tselected)end;tournamentRefresh()end)
 local function chooseTournamentYear(y)
  tselected=y;FauxScrollFrame_SetOffset(tscroll,0)
  if MirageRacewayTournament then MirageRacewayTournament:Open(y) end;tournamentRefresh()
 end
 tseasons:SetScript('OnClick',function(self)
  local y=MirageRacewaySync and MirageRacewaySync.ServerYear();if not y then return end
  local menu={{text='Select Tournament Season',isTitle=true,notCheckable=true}}
  for year=y,2026,-1 do local yr=year;menu[#menu+1]={text=tostring(yr),notCheckable=true,func=function()chooseTournamentYear(yr)end} end
  if not MirageRacewayTournamentSeasonMenu then MirageRacewayTournamentSeasonMenu=CreateFrame('Frame','MirageRacewayTournamentSeasonMenu',UIParent,'UIDropDownMenuTemplate')end
  EasyMenu(menu,MirageRacewayTournamentSeasonMenu,self,0,0,'MENU')
 end)
 MirageRacewayTournamentRefresh=tournamentRefresh
 tournament:SetScript('OnShow',function()if not tselected then chooseTournamentYear(MirageRacewaySync and MirageRacewaySync.ServerYear())else tournamentRefresh()end end)
 local sTitle=text(stats,'MY RACING STATISTICS','GameFontNormalLarge',{1,.81,.4});sTitle:SetPoint('TOPLEFT',stats,'TOPLEFT',17,-17)
 local banner=stats:CreateTexture(nil,'ARTWORK',nil,-2);banner:SetPoint('TOPLEFT',stats,'TOPLEFT',12,-39);banner:SetWidth(705);banner:SetHeight(64);banner:SetTexCoord(0,1,.08,.92)
 local myPortrait=stats:CreateTexture(nil,'OVERLAY',nil,3);myPortrait:SetWidth(45);myPortrait:SetHeight(45);myPortrait:SetPoint('TOPLEFT',stats,'TOPLEFT',25,-47)
 local portraitBorder=CreateFrame('Frame',nil,stats);portraitBorder:SetPoint('TOPLEFT',myPortrait,'TOPLEFT',-3,3);portraitBorder:SetPoint('BOTTOMRIGHT',myPortrait,'BOTTOMRIGHT',3,-3);portraitBorder:SetBackdrop({edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=13});portraitBorder:SetBackdropBorderColor(.95,.77,.3,1)
 local myEmblem=stats:CreateTexture(nil,'OVERLAY');myEmblem:SetWidth(43);myEmblem:SetHeight(43);myEmblem:SetPoint('LEFT',myPortrait,'RIGHT',8,0)
 local myName=text(stats,'','GameFontHighlightLarge',{1,.94,.78});myName:SetPoint('LEFT',myEmblem,'RIGHT',12,0)
 local factionText=text(stats,'','GameFontNormalSmall',{1,.8,.5});factionText:SetPoint('TOPLEFT',myName,'BOTTOMLEFT',0,-5)
 local values={}
 local fields={{'SEASON BEST',18,111},{'LAST SEASON BEST',382,111},{'RACE WINS',18,180},{'RACES COMPLETED',382,180}}
 for i,item in ipairs(fields) do
  local box=CreateFrame('Frame',nil,stats);box:SetPoint('TOPLEFT',stats,'TOPLEFT',item[2],-item[3]);box:SetWidth(331);box:SetHeight(55);backdrop(box,.09,.12,.15,.91)
  local cloth=box:CreateTexture(nil,'ARTWORK',nil,-2);cloth:SetAllPoints(box);cloth:SetTexCoord(0,1,.08,.92)
  cloth:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\'..(UnitFactionGroup('player')=='Horde' and 'hcloth.tga' or 'acloth.tga'))
  cloth:SetAlpha(.85)
  local faction=UnitFactionGroup('player');box:SetBackdropColor(faction=='Horde' and .11 or .05,faction=='Horde' and .21 or .12,faction=='Horde' and .07 or .29,.93)
  local label=text(box,item[1],'GameFontNormalSmall',{1,.9,.68});label:SetPoint('TOPLEFT',12,-8)
  label:SetFont('Fonts\\FRIZQT__.TTF',12,'OUTLINE')
  local value=text(box,'--','GameFontNormalLarge',{1,.85,.48});value:SetPoint('BOTTOMLEFT',72,9);values[i]=value
 end
 local function licenseAchievement()
  if not GetCategoryList or not GetCategoryNumAchievements or not GetAchievementInfo then return nil end
  local categories=GetCategoryList()
  if type(categories)~='table' then return false,nil end
  for _,categoryID in ipairs(categories) do
   local count=GetCategoryNumAchievements(categoryID) or 0
   for index=1,count do
    local id,name,points,completed,month,day,year=GetAchievementInfo(categoryID,index)
    if name and string.lower(name)=='raceway license' then
     if completed then
      local issued='Unknown'
      if month and day and year and month>0 and day>0 then
       local fullYear=year<100 and (2000+year) or year
       issued=string.format('%02d/%02d/%04d',day,month,fullYear)
      end
      return true,issued
     end
     return false,nil
    end
   end
  end
  return false,nil
 end
 local license=CreateFrame('Frame',nil,stats)
 license:SetPoint('TOP',stats,'TOP',0,-313)
 license:SetWidth(390);license:SetHeight(260)
 license:SetScale(.85)
 local paper=license:CreateTexture(nil,'ARTWORK',nil,-2)
 paper:SetAllPoints(license)
 paper:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\driver_license.tga')
 paper:SetTexCoord(0,1,0,341/512)
 -- A separate portrait layer, above the card art, using the same player portrait API as the profile header.
 local photo=license:CreateTexture(nil,'OVERLAY',nil,1)
 -- Square portrait: do not stretch the player's circular portrait to the card's tall photo slot.
 photo:SetPoint('TOPLEFT',license,'TOPLEFT',49,-112)
 photo:SetWidth(69);photo:SetHeight(69)
 photo:SetTexCoord(0,1,0,1)
 photo:SetDrawLayer('OVERLAY',7)
 local licenseEmblem=license:CreateTexture(nil,'OVERLAY',nil,6)
 licenseEmblem:SetPoint('TOPRIGHT',license,'TOPRIGHT',-45,-148)
 licenseEmblem:SetWidth(46);licenseEmblem:SetHeight(46)
 local function licenseField(x,y,width)
  local f=license:CreateFontString(nil,'OVERLAY','GameFontNormal')
  f:SetFont('Fonts\\FRIZQT__.TTF',11)
  f:SetTextColor(.17,.08,.025,1)
  f:SetShadowOffset(0,0)
  f:SetPoint('TOPLEFT',license,'TOPLEFT',x,-y)
  f:SetWidth(width);f:SetJustifyH('LEFT')
  return f
 end
 local nameValue=licenseField(184,104,170)
 local teamValue=licenseField(184,130,130)
 local dateValue=licenseField(218,155,133)
 local numberValue=licenseField(218,182,133)
 local warning=license:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
 warning:SetPoint('CENTER',license,'CENTER',55,-25)
 warning:SetWidth(275);warning:SetJustifyH('CENTER')
 warning:SetTextColor(.65,.08,.035,1)
 warning:SetText('You do not have a license.\nSpeak to the race official.')
 local dim=license:CreateTexture(nil,'ARTWORK',nil,-1)
 dim:SetPoint('TOPLEFT',license,'TOPLEFT',125,-100)
 dim:SetWidth(240);dim:SetHeight(123)
 dim:SetTexture(1,.85,.63,.92)
 local function refreshStats()
  local name=UnitName('player') or 'Unknown'
  myName:SetText(name)
  local faction=UnitFactionGroup('player') or 'Alliance'
  banner:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\'..(faction=='Horde' and 'hcloth.tga' or 'acloth.tga'))
  banner:SetTexCoord(0,1,.08,.92)
  myPortrait:SetTexture(nil)
  SetPortraitTexture(myPortrait,'player')
  myPortrait:SetTexCoord(0,1,0,1)
  myPortrait:Show()
  myEmblem:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\'..(faction=='Horde' and 'goblin.tga' or 'gnome.tga'))
  factionText:SetText(faction=='Horde' and 'GOBLIN RACING  -  HORDE' or 'GNOME RACING  -  ALLIANCE')
  local p=MirageRacewaySync and MirageRacewaySync:Personal() or {}
  local year=MirageRacewaySync and MirageRacewaySync.ServerYear()
  local current=year and p.seasons and p.seasons[year]
  local previous=MirageRacewaySync and MirageRacewaySync:LastSeasonBest()
  values[1]:SetText(MirageRacewaySync and MirageRacewaySync.Format(current) or '--:--.---')
  values[2]:SetText(MirageRacewaySync and MirageRacewaySync.Format(previous or current) or '--:--.---')
  local wins,races=0,0
  if MirageRacewayGetRaceStatistics then wins,races=MirageRacewayGetRaceStatistics() end
  values[3]:SetText(tostring(wins))
  values[4]:SetText(tostring(races))
  local completed,issued=licenseAchievement()
  nameValue:SetText('');teamValue:SetText('');dateValue:SetText('');numberValue:SetText('')
  if completed then
   local db=DB();db.licenseNumbers=db.licenseNumbers or {}
   local key=(GetRealmName and GetRealmName() or 'Realm')..':'..name
   if not db.licenseNumbers[key] then db.licenseNumbers[key]=math.random(100000,999999) end
   nameValue:SetText(name)
   teamValue:SetText(faction=='Horde' and 'Goblins' or 'Gnomes')
   dateValue:SetText(issued or 'Unknown')
   numberValue:SetText(string.format('%06d',db.licenseNumbers[key]))
   photo:SetTexture(nil)
   SetPortraitTexture(photo,'player')
   photo:SetTexCoord(0,1,0,1)
   licenseEmblem:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\'..(faction=='Horde' and 'goblin.tga' or 'gnome.tga'))
   licenseEmblem:Show()
   photo:Show();dim:Hide();warning:Hide()
  else
   photo:Hide();licenseEmblem:Hide();dim:Show();warning:Show()
  end
 end
 local reset=makeButton(stats,'Reset Season Best',174,28);reset:SetPoint('TOPLEFT',stats,'TOPLEFT',18,-253)
 StaticPopupDialogs.MRBT_RESET={text='Reset your current Season Best?',button1='Reset',button2='Cancel',OnAccept=function()if MirageRacewaySync then MirageRacewaySync:Reset();refreshStats() end end,timeout=0,whileDead=1,hideOnEscape=1}
 reset:SetScript('OnClick',function()StaticPopup_Show('MRBT_RESET')end)
 refresh=function() refreshBoard();refreshStats();tournamentRefresh() end
 showTab=function(which)
  currentTab=which;if which=='board' then board:Show() else board:Hide() end;if which=='stats' then stats:Show() else stats:Hide() end;if which=='tournament' then tournament:Show() else tournament:Hide() end
  tabs.board:SetText('Best Time')
  tabs.stats:SetText('My Statistics');tabs.tournament:SetText('Tournament')
  for key,b in pairs(tabs) do if key==which then b:LockHighlight() else b:UnlockHighlight() end end
  if which=='tournament' and MirageRacewayTournament then MirageRacewayTournament:Open() end
  refresh()
 end
 local settings=makeButton(window,'Settings',108,27);settings:SetPoint('BOTTOMLEFT',window,'BOTTOMLEFT',20,16)
 settings:SetScript('OnClick',function() if MirageRacewayOptions then if MirageRacewayOptions:IsShown() then MirageRacewayOptions:Hide() else MirageRacewayOptions:Show();MirageRacewayOptions:Raise() end end end)
 local masterButton=nil
 if MirageRacewaySync and MirageRacewaySync:IsMaster() then
  masterButton=makeButton(window,'Master Management',170,27)
  masterButton:SetPoint('BOTTOMLEFT',window,'BOTTOMLEFT',245,16)
  masterButton:SetScript('OnClick',function()if MirageRacewayToggleMaster then MirageRacewayToggleMaster()end end)
 end
 local contacts=makeButton(window,'Contacts',110,27);contacts:SetPoint('LEFT',settings,'RIGHT',8,0)
 local contactWindow=CreateFrame('Frame','MirageRacewayContactsWindow',UIParent)
 contactWindow:SetWidth(470);contactWindow:SetHeight(340);contactWindow:SetPoint('CENTER',UIParent,'CENTER',150,0)
 contactWindow:SetFrameStrata('FULLSCREEN_DIALOG');contactWindow:SetFrameLevel(250);contactWindow:EnableMouse(true);contactWindow:SetMovable(true);contactWindow:RegisterForDrag('LeftButton')
 contactWindow:SetScript('OnDragStart',function(self)self:StartMoving()end);contactWindow:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
 backdrop(contactWindow,.045,.055,.075,.98)
 local ct=text(contactWindow,'CONTACTS & PROJECT LINKS','GameFontNormalLarge',{1,.8,.38});ct:SetPoint('TOPLEFT',22,-25)
 local cc=CreateFrame('Button',nil,contactWindow,'UIPanelCloseButton');cc:SetPoint('TOPRIGHT',-5,-5);cc:SetFrameLevel(contactWindow:GetFrameLevel()+15);cc:SetScript('OnClick',function()contactWindow:Hide()end)
 local closeContacts=makeButton(contactWindow,'Close',90,26);closeContacts:SetPoint('BOTTOMRIGHT',contactWindow,'BOTTOMRIGHT',-20,18);closeContacts:SetFrameLevel(contactWindow:GetFrameLevel()+10);closeContacts:SetScript('OnClick',function()contactWindow:Hide()end)
 contactWindow:SetScript('OnKeyDown',function(self,key)if key=='ESCAPE' then self:Hide()end end)
 local desc=text(contactWindow,'Report bugs and suggest improvements on GitHub.','GameFontHighlightSmall')
 desc:SetPoint('TOPLEFT',22,-60)
 local authorLabel=text(contactWindow,'Author: Belerda','GameFontNormal')
 authorLabel:SetPoint('TOPLEFT',22,-93)
 local gitLabel=text(contactWindow,'GitHub Repository (select the link and press Ctrl+C):','GameFontNormal')
 gitLabel:SetPoint('TOPLEFT',22,-131)
 local githubURL='https://github.com/PizzaCompanyCom/Epoch_Mirage_Raceway'
 local gitFrame=CreateFrame('Frame',nil,contactWindow)
 gitFrame:SetPoint('TOPLEFT',contactWindow,'TOPLEFT',22,-153)
 gitFrame:SetWidth(426);gitFrame:SetHeight(34)
 gitFrame:SetFrameLevel(contactWindow:GetFrameLevel()+18)
 backdrop(gitFrame,.015,.018,.025,1)
 local git=CreateFrame('EditBox',nil,gitFrame)
 git:SetPoint('TOPLEFT',gitFrame,'TOPLEFT',9,-5)
 git:SetWidth(408);git:SetHeight(24)
 git:SetFontObject('GameFontHighlight')
 git:SetTextColor(1,.86,.46)
 git:SetAutoFocus(false);git:SetMaxLetters(250);git:SetText(githubURL)
 git:SetFrameLevel(gitFrame:GetFrameLevel()+3)
 git:EnableMouse(true)
 git:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
 git:SetScript('OnEnterPressed',function(self)self:HighlightText()end)
 git:SetScript('OnEditFocusLost',function(self)self:SetText(githubURL)end)
 local copy=makeButton(contactWindow,'Select GitHub Link',185,26)
 copy:SetPoint('TOPLEFT',contactWindow,'TOPLEFT',25,-201)
 copy:SetFrameLevel(contactWindow:GetFrameLevel()+20)
 copy:SetScript('OnClick',function()git:SetText(githubURL);git:SetFocus();git:HighlightText()end)
 local info=text(contactWindow,'Found a bug or have an idea? Please share your feedback on GitHub.','GameFontHighlightSmall')
 info:SetWidth(420);info:SetJustifyH('LEFT');info:SetPoint('TOPLEFT',contactWindow,'TOPLEFT',22,-251)
 contactWindow:Hide()
 contacts:SetScript('OnClick',function()if contactWindow:IsShown() then contactWindow:Hide()else contactWindow:Show();contactWindow:SetFrameStrata('FULLSCREEN_DIALOG');contactWindow:SetFrameLevel(250);contactWindow:Raise()end end)
 -- Rules are informational and always open above the addon windows.
 local rulesButton=makeButton(window,'Rules',100,27)
 rulesButton:SetPoint('TOPRIGHT',window,'TOPRIGHT',-20,-85)
 local rulesWin=CreateFrame('Frame','MirageRacewayRulesWindow',UIParent)
 rulesWin:SetWidth(610);rulesWin:SetHeight(550);rulesWin:SetPoint('CENTER',UIParent,'CENTER',0,0)
 rulesWin:SetFrameStrata('FULLSCREEN_DIALOG');rulesWin:SetFrameLevel(500)
 rulesWin:SetMovable(true);rulesWin:EnableMouse(false)
 -- Solid opaque parchment fallback remains visible even if the custom TGA fails to load.
 -- No SetBackdrop on rulesWin: backdrop layers could obscure the parchment texture.
 local paperFallback=rulesWin:CreateTexture(nil,'BACKGROUND')
 paperFallback:SetAllPoints(rulesWin)
 paperFallback:SetTexture('Interface\\Buttons\\WHITE8X8')
 paperFallback:SetVertexColor(.94,.83,.61,1)
 local paper=rulesWin:CreateTexture(nil,'BACKGROUND',nil,1)
 paper:SetPoint('TOPLEFT',rulesWin,'TOPLEFT',7,-7)
 paper:SetPoint('BOTTOMRIGHT',rulesWin,'BOTTOMRIGHT',-7,7)
 paper:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\rules_parchment.tga')
 paper:SetAlpha(1)
 paper:SetVertexColor(1,1,1,1)
 paper:SetTexCoord(0,1,0,1)
 -- Frame used solely for border decoration; it cannot intercept mouse events.
 local paperBorder=CreateFrame('Frame',nil,rulesWin)
 paperBorder:SetAllPoints(rulesWin)
 paperBorder:SetFrameLevel(rulesWin:GetFrameLevel()+1)
 paperBorder:EnableMouse(false)
 paperBorder:SetBackdrop({edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=15,insets={left=0,right=0,top=0,bottom=0}})
 paperBorder:SetBackdropBorderColor(.43,.28,.11,1)
 -- Drag only from the heading, never from the whole rules window.
 local dragHeader=CreateFrame('Frame',nil,rulesWin)
 dragHeader:SetPoint('TOPLEFT',rulesWin,'TOPLEFT',12,-10)
 dragHeader:SetPoint('TOPRIGHT',rulesWin,'TOPRIGHT',-55,-10)
 dragHeader:SetHeight(42)
 dragHeader:SetFrameLevel(rulesWin:GetFrameLevel()+4)
 dragHeader:EnableMouse(true)
 dragHeader:RegisterForDrag('LeftButton')
 dragHeader:SetScript('OnDragStart',function() rulesWin:StartMoving() end)
 dragHeader:SetScript('OnDragStop',function() rulesWin:StopMovingOrSizing() end)
 local rt=text(dragHeader,'MIRAGE RACEWAY - RULES','GameFontNormalLarge',{.30,.15,.045})
 rt:SetPoint('CENTER',dragHeader,'CENTER',20,0)
 local rc=CreateFrame('Button','MirageRacewayRulesCloseButton',rulesWin,'UIPanelCloseButton')
 rc:ClearAllPoints()
 rc:SetPoint('TOPRIGHT',rulesWin,'TOPRIGHT',-7,-7)
 rc:SetWidth(32);rc:SetHeight(32)
 rc:SetFrameStrata('FULLSCREEN_DIALOG')
 rc:SetFrameLevel(rulesWin:GetFrameLevel()+25)
 rc:EnableMouse(true)
 rc:RegisterForClicks('LeftButtonUp')
 rc:SetScript('OnClick',function() rulesWin:Hide() end)
 local rulesText={
  'To obtain a license, you must complete a quest at the Raceway and earn the [Raceway License] achievement.',
  'To start a race, two or more participants must join the queue by speaking to the Dwarf coordinator on the tower; the race will begin once the timer at the top of the screen runs out.',
  'Always use the vehicle\'s first ability, "Accelerator." It can stack up to 3 times, increasing the vehicle\'s speed.',
  'Race power-ups:',
  'Green Rocket - Fires forward over a long distance; slows down any player it hits for 4 seconds.',
  'Red Rocket - Fires in all directions within a 20-yard radius; slows down players for 3 seconds.',
  'Speed - Increases the racer\'s speed.',
  'Jump - Causes the vehicle to leap in the direction it is traveling. There is a chance it may fail to activate.',
  'Oil - Leaves a puddle of oil behind the vehicle, slowing down anyone who drives into it.'
 }
 local scrollFrame=CreateFrame('ScrollFrame','MirageRacewayRulesScrollFrame',rulesWin,'UIPanelScrollFrameTemplate')
 scrollFrame:SetFrameLevel(rulesWin:GetFrameLevel()+6)
 scrollFrame:SetPoint('TOPLEFT',rulesWin,'TOPLEFT',44,-62)
 scrollFrame:SetPoint('BOTTOMRIGHT',rulesWin,'BOTTOMRIGHT',-55,38)
 local scrollChild=CreateFrame('Frame',nil,scrollFrame)
 scrollChild:SetWidth(475)
 scrollChild:SetHeight(800)
 scrollFrame:SetScrollChild(scrollChild)
 local y=-4
 for i,line in ipairs(rulesText) do
  local l=scrollChild:CreateFontString(nil,'OVERLAY','GameFontNormal')
  l:SetWidth(465)
  l:SetFont('Fonts\\FRIZQT__.TTF',13,'')
  l:SetJustifyH('LEFT');l:SetJustifyV('TOP')
  l:SetTextColor(.27,.14,.055,1)
  l:SetPoint('TOPLEFT',scrollChild,'TOPLEFT',4,y)
  l:SetText(line)
  local h=math.max(35, l:GetStringHeight()+12)
  l:SetHeight(h)
  y=y-h-(i==4 and 12 or 16)
 end
 scrollChild:SetHeight(math.max(465,-y+8))
 rulesWin:Hide()
 table.insert(UISpecialFrames,'MirageRacewayRulesWindow')
 rulesButton:SetScript('OnClick',function()
  if rulesWin:IsShown() then rulesWin:Hide() else rulesWin:Show();rulesWin:Raise(); end
 end)
 -- Live Updates replace manual Refresh.
 local minus=makeButton(window,'-',29,27);minus:SetPoint('BOTTOMRIGHT',window,'BOTTOMRIGHT',-130,16)
 local plus=makeButton(window,'+',29,27);plus:SetPoint('LEFT',minus,'RIGHT',4,0)
 local scaleLabel=text(window,'Window Scale','GameFontHighlightSmall',{.95,.85,.68});scaleLabel:SetPoint('RIGHT',minus,'LEFT',-8,0)
 minus:SetScript('OnClick',function() local d=DB();d.mainScale=math.max(.7,math.floor(((d.mainScale or 1)-.1)*10+.5)/10);window:SetScale(d.mainScale) end)
 plus:SetScript('OnClick',function() local d=DB();d.mainScale=math.min(1.3,math.floor(((d.mainScale or 1)+.1)*10+.5)/10);window:SetScale(d.mainScale) end)
 showTab('board');window:Hide()
 window:SetScript('OnHide',function() if MirageRacewaySync then MirageRacewaySync:Close() end if MirageRacewayTournament then MirageRacewayTournament:Close() end end)
 window:SetScript('OnShow',function()openBoard()end)
 MirageRacewayToggleMainWindow=function()
  if window:IsShown() then window:Hide() else refresh();window:Show() end
 end
end
root:RegisterEvent('PLAYER_LOGIN')
root:SetScript('OnEvent',function()
 create()
 -- The main window becomes the default opening surface, with the old settings preserved.
 local previous=SlashCmdList.MIRAGERACEWAY
 if previous then
  SlashCmdList.MIRAGERACEWAY=function(input)
   local cmd=string.lower((input or ''):match('^%s*(.-)%s*$'))
   if cmd=='texturetest79' then
    if not MirageRacewayFormatTest79 then
     local f=CreateFrame('Frame','MirageRacewayFormatTest79',UIParent)
     f:SetWidth(680);f:SetHeight(430);f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG')
     f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton')
     f:SetScript('OnDragStart',f.StartMoving);f:SetScript('OnDragStop',f.StopMovingOrSizing)
     f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=24,insets={left=8,right=8,top=8,bottom=8}})
     local c=CreateFrame('Button',nil,f,'UIPanelCloseButton');c:SetPoint('TOPRIGHT',-5,-5)
     local title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOP',0,-20);title:SetText('MIRAGE RACEWAY - TEXTURE FORMAT TEST v0.7.9')
     local names={'test24.tga','test32.tga','testtop.tga','testblp.blp','testknown.tga','gnome.tga'}
     for i,n in ipairs(names) do
      local x=34+((i-1)%3)*220;local y=-66-math.floor((i-1)/3)*157
      local back=f:CreateTexture(nil,'BACKGROUND');back:SetTexture(.12,.18,.24,1);back:SetWidth(170);back:SetHeight(117);back:SetPoint('TOPLEFT',x,y)
      local tex=f:CreateTexture(nil,'ARTWORK');tex:SetWidth(100);tex:SetHeight(100);tex:SetPoint('TOPLEFT',x+35,y-6)
      tex:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\'..n)
      local label=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');label:SetPoint('TOP',back,'BOTTOM',0,-5);label:SetText(n)
     end
     local note=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');note:SetPoint('BOTTOM',0,17);note:SetText('Compare 24-bit, 32-bit, top-origin, BLP2, existing FX and old emblem')
     MirageRacewayFormatTest79=f
    end
    MirageRacewayFormatTest79:Show();MirageRacewayFormatTest79:Raise();return
   end
   if cmd=='arttest' then
    if not MirageRacewayArtTest then
     local f=CreateFrame('Frame','MirageRacewayArtTest',UIParent);f:SetWidth(510);f:SetHeight(330);f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag('LeftButton');f:SetScript('OnDragStart',f.StartMoving);f:SetScript('OnDragStop',f.StopMovingOrSizing)
     f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=24,insets={left=7,right=7,top=7,bottom=7}})
     local close=CreateFrame('Button',nil,f,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-4,-4)
     local title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOP',0,-18);title:SetText('MIRAGE RACEWAY - ART TEST')
     local names={'hcloth','acloth','goblin','gnome','launch'}
     for i,n in ipairs(names) do
      local t=f:CreateTexture(nil,'ARTWORK');t:SetWidth(i<=2 and 190 or 62);t:SetHeight(i<=2 and 52 or 62)
      if i<=2 then t:SetPoint('TOPLEFT',f,'TOPLEFT',35,-52-(i-1)*78) else t:SetPoint('TOPLEFT',f,'TOPLEFT',50+(i-3)*145,-215) end
      t:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\'..n)
      local l=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');l:SetPoint('TOP',t,'BOTTOM',0,-3);l:SetText(n)
     end
     local native=f:CreateTexture(nil,'ARTWORK');native:SetWidth(40);native:SetHeight(40);native:SetPoint('TOPRIGHT',-55,-66);native:SetTexture('Interface\\Icons\\INV_Misc_QuestionMark')
     MirageRacewayArtTest=f
    end
    MirageRacewayArtTest:Show();MirageRacewayArtTest:Raise();return
   end
   if cmd=='demoleaders' or cmd=='demo leaders' then
    demoRecords={}
    local names={'Rocketgnome','Geargrinder','Dustrunner','Goblinator','Speedwrench','Redrocket','Nitrobolt','Oilspinner','Turbofix','Racechief','Mechaboom','Ironwheel','Fastfuse','Sandblazer','Greasefang'}
    for i,name in ipairs(names) do demoRecords[name]={best=91.3+i*3.71,wins=math.max(0,13-i),races=8+i*3,faction=(i%2==0 and 'Horde' or 'Alliance')} end
    local playerName=UnitName('player')
    if playerName then demoRecords[playerName]={best=88.15,wins=15,races=24,faction=UnitFactionGroup('player'),demoPlayer=true} end
    refresh();showTab('board');window:Show()
    DEFAULT_CHAT_FRAME:AddMessage('|cffefc46e[Mirage Raceway]|r Demonstration racers and your character loaded (not saved).')
    return
   elseif cmd=='cleardemo' or cmd=='demo clear' then
    demoRecords=nil;refresh()
    DEFAULT_CHAT_FRAME:AddMessage('|cffefc46e[Mirage Raceway]|r Demonstration racers cleared.')
    return
   end
   if cmd=='' or cmd=='leaderboard' or cmd=='board' or cmd=='stats' then
    if cmd=='stats' then showTab('stats') elseif cmd~='' then showTab('board') end
    if window:IsShown() and cmd=='' then window:Hide() else refresh();window:Show() end
   elseif cmd=='settings' then
    if MirageRacewayOptions then if MirageRacewayOptions:IsShown() then MirageRacewayOptions:Hide() else MirageRacewayOptions:Show();MirageRacewayOptions:Raise() end end
   else previous(input) end
  end
 end
end)

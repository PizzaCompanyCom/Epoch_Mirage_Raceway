-- Master Management / only Belerda / current verified season
local F=CreateFrame('Frame');F:RegisterEvent('PLAYER_LOGIN')
F:SetScript('OnEvent',function()
 local S=MirageRacewaySync;if not S or not S:IsMaster() then return end
 local win=CreateFrame('Frame','MirageRacewayMasterManagement',UIParent)
 win:SetWidth(560);win:SetHeight(570);win:SetPoint('CENTER',UIParent,'CENTER',240,0)
 win:SetFrameStrata('FULLSCREEN_DIALOG');win:SetFrameLevel(650);win:SetMovable(true);win:EnableMouse(true);
 win:SetScript('OnDragStart',function(self) if self:IsMouseOver() then self:StartMoving() end end);win:SetScript('OnDragStop',win.StopMovingOrSizing)
 win:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=22,insets={left=6,right=6,top=6,bottom=6}})
 win:Hide()
 local title=win:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOPLEFT',20,-18);title:SetText('MASTER MANAGEMENT')
 local close=CreateFrame('Button',nil,win,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-3,-3);close:SetFrameLevel(win:GetFrameLevel()+20);close:EnableMouse(true);close:SetScript('OnClick',function()win:Hide()end)
 local function button(label,x,y,w,callback)
  local b=CreateFrame('Button',nil,win,'UIPanelButtonTemplate');b:SetWidth(w);b:SetHeight(25);b:SetPoint('TOPLEFT',x,y);b:SetText(label);b:SetFrameLevel(win:GetFrameLevel()+8);b:EnableMouse(true);b:RegisterForClicks('LeftButtonUp');b:SetScript('OnClick',callback);return b
 end
 -- Management sections are opened exclusively from the two-button selector.
 local backBest=button('Back',435,-55,105,function()win:Hide();if MirageRacewayMasterSelector then MirageRacewayMasterSelector:Show()end end)
 local search=CreateFrame('EditBox',nil,win,'InputBoxTemplate');search:SetWidth(245);search:SetHeight(25);search:SetPoint('TOPLEFT',25,-58);search:SetAutoFocus(false);search:SetFrameLevel(win:GetFrameLevel()+10);search:EnableMouse(true)
 local selected=nil;local list={};local offset=0;local rows={}
 -- Administrative table: fixed columns, alternating rows, dividers and row selection.
 local bh=CreateFrame('Frame',nil,win);bh:SetPoint('TOPLEFT',25,-89);bh:SetWidth(475);bh:SetHeight(20)
 local bbg=bh:CreateTexture(nil,'BACKGROUND');bbg:SetAllPoints(bh);bbg:SetTexture(0,0,0,.8)
 local function bhead(label,x)
  local f=bh:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');f:SetPoint('LEFT',x,0);f:SetText(label)
 end
 bhead('RACER',9);bhead('BEST TIME',205);bhead('STATUS',330)

 local info=win:CreateFontString(nil,'OVERLAY','GameFontHighlight');info:SetPoint('TOPLEFT',25,-330);info:SetWidth(500);info:SetJustifyH('LEFT');info:SetText('Select a racer')
 local time=CreateFrame('EditBox',nil,win);time:SetWidth(165);time:SetHeight(23);time:SetPoint('TOPLEFT',35,-383);time:SetAutoFocus(false);time:SetFontObject('GameFontHighlight');time:SetTextInsets(7,7,0,0);time:SetMaxLetters(20);time:SetFrameLevel(win:GetFrameLevel()+12);time:EnableMouse(true);time:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}});time:SetBackdropColor(0.05,0.05,0.05,0.95);time:SetBackdropBorderColor(0.75,0.65,0.4,1);time:SetScript('OnEscapePressed',function(self)self:ClearFocus()end);time:SetScript('OnEnterPressed',function(self)self:ClearFocus()end)
 local hint=win:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');hint:SetPoint('TOPLEFT',win,'TOPLEFT',35,-368);hint:SetText('Time (MM+:SS.mmm)')
 local refresh
 local function selectedAction(a)
  if not selected then return end
  local ms
  if a=='EDIT' then
   local m,s,frac=(time:GetText() or ''):match('^(%d+):(%d%d)%.(%d%d%d)$')
   if not m or tonumber(s)>59 then info:SetText('Invalid time. Use MM+:SS.mmm');return end
   ms=(tonumber(m)*60+tonumber(s))*1000+tonumber(frac)
   if ms<=0 then return end
  end
  S:Admin(a,selected,ms);refresh()
 end
 button('Save Time',230,-382,125,function()selectedAction('EDIT')end)
 button('Lock',25,-428,85,function()selectedAction('LOCK')end)
 button('Unlock',115,-428,85,function()selectedAction('UNLOCK')end)
 button('Exclude',205,-428,85,function()selectedAction('EXCLUDE')end)
 button('Include',295,-428,85,function()selectedAction('INCLUDE')end)
 local requests=false
 local reqButton=button('Reset Requests (0)',25,-455,200,function()requests=not requests;selected=nil;refresh()end)
 button('Approve Reset',25,-490,135,function()selectedAction('APPROVE')end)
 button('Reject Reset',165,-490,135,function()selectedAction('REJECT')end)
 for i=1,8 do
  local index=i
  local b=button('',25,-113-(i-1)*25,475,function()
   local r=list[index+offset];if not r then return end
   selected=r.name;info:SetText(r.name..'  |  '..(r.best and S.Format(r.best) or 'No time')..(r.locked and '  [LOCKED]' or '')..(r.excluded and '  [EXCLUDED]' or ''))
   refresh()
  end)
  b:SetHeight(24);b:SetNormalTexture('');b:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight','ADD')
  local shade=b:CreateTexture(nil,'BACKGROUND');shade:SetAllPoints(b);shade:SetTexture(i%2==0 and .075 or .12,.14,.19,.85)
  local line=b:CreateTexture(nil,'ARTWORK');line:SetHeight(1);line:SetPoint('BOTTOMLEFT',0,0);line:SetPoint('BOTTOMRIGHT',0,0);line:SetTexture(.6,.55,.4,.35)
  local function cell(x,width)
   local f=b:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');f:SetPoint('LEFT',x,0);f:SetWidth(width);f:SetJustifyH('LEFT');return f
  end
  b.racer=cell(9,190);b.value=cell(205,118);b.status=cell(330,140)
  rows[i]=b
 end
 local up=button('Up',505,-98,45,function()offset=math.max(0,offset-1);refresh()end)
 local down=button('Down',505,-130,45,function()offset=math.min(math.max(0,#list-8),offset+1);refresh()end)
 refresh=function()
  local y=S.ServerYear();local d=S:MasterData();list={}
  if y and d then
   local q=string.lower(search:GetText() or '')
   if requests then
    for _,r in pairs(d.requests) do if r.year==y and string.find(string.lower(r.name),q,1,true) then list[#list+1]={name=r.name} end end
   else
    local season=d.seasons[y]
    if season then for _,r in pairs(season.racers) do if r.best and string.find(string.lower(r.name),q,1,true) then list[#list+1]=r end end end
   end
  end
  table.sort(list,function(a,b)return string.lower(a.name)<string.lower(b.name)end)
  offset=math.min(offset,math.max(0,#list-8))
  for i,b in ipairs(rows) do
   local r=list[i+offset]
   if r then
    b.racer:SetText(r.name);b.value:SetText(r.best and S.Format(r.best) or '—')
    b.status:SetText((r.locked and 'LOCKED ' or '')..(r.excluded and 'EXCLUDED' or '')..(requests and 'RESET' or ''))
    b:Show()
   else b:Hide() end
  end
  local n=0;if d and y then for _,r in pairs(d.requests) do if r.year==y then n=n+1 end end end
  reqButton:SetText('Reset Requests ('..n..')')
  title:SetText('MASTER MANAGEMENT  -  '..(y or 'DATE UNAVAILABLE'))
 end
 search:SetScript('OnTextChanged',function()offset=0;refresh()end)
 win:SetScript('OnShow',function()win:Raise();close:SetFrameLevel(win:GetFrameLevel()+20);refresh()end)
 local drag=CreateFrame('Frame',nil,win);drag:SetPoint('TOPLEFT',win,'TOPLEFT',10,-8);drag:SetPoint('TOPRIGHT',win,'TOPRIGHT',-42,-8);drag:SetHeight(38);drag:SetFrameLevel(win:GetFrameLevel()+3);drag:EnableMouse(true);drag:RegisterForDrag('LeftButton');drag:SetScript('OnDragStart',function()win:StartMoving()end);drag:SetScript('OnDragStop',function()win:StopMovingOrSizing()end)
 local selector=CreateFrame('Frame','MirageRacewayMasterSelector',UIParent)
 selector:SetWidth(350);selector:SetHeight(155);selector:SetPoint('CENTER',UIParent,'CENTER',240,0)
 selector:SetFrameStrata('FULLSCREEN_DIALOG');selector:SetFrameLevel(650)
 selector:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=22,insets={left=6,right=6,top=6,bottom=6}})
 selector:EnableMouse(true);selector:Hide()
 local st=selector:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');st:SetPoint('TOP',0,-24);st:SetText('MASTER MANAGEMENT')
 local sc=CreateFrame('Button',nil,selector,'UIPanelCloseButton');sc:SetPoint('TOPRIGHT',-3,-3);sc:SetScript('OnClick',function()selector:Hide()end)
 local function choice(label,x,callback)
  local b=CreateFrame('Button',nil,selector,'UIPanelButtonTemplate')
  b:SetWidth(140);b:SetHeight(32);b:SetPoint('TOPLEFT',x,-77);b:SetText(label)
  b:SetFrameLevel(selector:GetFrameLevel()+8);b:SetScript('OnClick',callback)
 end
 choice('Best Time',25,function()selector:Hide();win:Show()end)
 choice('Tournament',185,function()selector:Hide();if MirageRacewayToggleTournamentMaster then MirageRacewayToggleTournamentMaster(true)end end)
 MirageRacewayToggleMaster=function()
  if selector:IsShown() then selector:Hide() else win:Hide();if MirageRacewayTournamentManagement then MirageRacewayTournamentManagement:Hide()end;selector:Show()end
 end
 -- Tournament has a separate independent management window and database.
 local tw=CreateFrame('Frame','MirageRacewayTournamentManagement',UIParent)
 tw:SetWidth(560);tw:SetHeight(570);tw:SetPoint('CENTER',UIParent,'CENTER',240,0)
 tw:SetFrameStrata('FULLSCREEN_DIALOG');tw:SetFrameLevel(650);tw:SetMovable(true);tw:EnableMouse(true)
 tw:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=22,insets={left=6,right=6,top=6,bottom=6}})
 tw:Hide()
 local function tbutton(label,x,y,w,callback)
  local b=CreateFrame('Button',nil,tw,'UIPanelButtonTemplate');b:SetWidth(w);b:SetHeight(25);b:SetPoint('TOPLEFT',x,y);b:SetText(label);b:SetFrameLevel(tw:GetFrameLevel()+8);b:RegisterForClicks('LeftButtonUp');b:SetScript('OnClick',callback);return b
 end
 local tt=tw:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');tt:SetPoint('TOPLEFT',20,-18);tt:SetText('TOURNAMENT MANAGEMENT')
 local tc=CreateFrame('Button',nil,tw,'UIPanelCloseButton');tc:SetPoint('TOPRIGHT',-3,-3);tc:SetFrameLevel(tw:GetFrameLevel()+20);tc:SetScript('OnClick',function()tw:Hide()end)
 tbutton('Back',25,-55,120,function()tw:Hide();selector:Show()end)
 local tsearch=CreateFrame('EditBox',nil,tw,'InputBoxTemplate');tsearch:SetWidth(220);tsearch:SetHeight(25);tsearch:SetPoint('TOPLEFT',25,-90);tsearch:SetAutoFocus(false);tsearch:SetFrameLevel(tw:GetFrameLevel()+18);tsearch:EnableMouse(true);tsearch:SetFontObject('GameFontHighlight');tsearch:SetTextInsets(8,8,0,0);tsearch:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}});tsearch:SetBackdropColor(0.04,0.04,0.04,1);tsearch:SetBackdropBorderColor(0.8,0.7,0.45,1);tsearch:SetScript('OnEscapePressed',function(self)self:ClearFocus()end)
 local tlist={};local toffset=0;local tselected=nil;local trows={};local trefresh
 local th=CreateFrame('Frame',nil,tw);th:SetPoint('TOPLEFT',25,-121);th:SetWidth(470);th:SetHeight(20)
 local thbg=th:CreateTexture(nil,'BACKGROUND');thbg:SetAllPoints(th);thbg:SetTexture(0,0,0,.8)
 local function thead(label,x)
  local f=th:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');f:SetPoint('LEFT',x,0);f:SetText(label)
 end
 thead('RACER',9);thead('GOLD WON',230);thead('TEAM',355)

 local tinfo=tw:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');tinfo:SetPoint('TOPLEFT',25,-340);tinfo:SetWidth(500);tinfo:SetJustifyH('LEFT');tinfo:SetText('Select a racer or enter a new name')
 local tname=CreateFrame('EditBox',nil,tw,'InputBoxTemplate');tname:SetWidth(180);tname:SetHeight(25);tname:SetPoint('TOPLEFT',25,-393);tname:SetAutoFocus(false);tname:SetFrameLevel(tw:GetFrameLevel()+18);tname:EnableMouse(true);tname:SetFontObject('GameFontHighlight');tname:SetTextInsets(8,8,0,0);tname:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}});tname:SetBackdropColor(0.04,0.04,0.04,1);tname:SetBackdropBorderColor(0.8,0.7,0.45,1);tname:SetScript('OnEscapePressed',function(self)self:ClearFocus()end);tname:SetMaxLetters(24)
 local tgold=CreateFrame('EditBox',nil,tw,'InputBoxTemplate');tgold:SetWidth(100);tgold:SetHeight(25);tgold:SetPoint('TOPLEFT',230,-393);tgold:SetAutoFocus(false);tgold:SetFrameLevel(tw:GetFrameLevel()+18);tgold:EnableMouse(true);tgold:SetFontObject('GameFontHighlight');tgold:SetTextInsets(8,8,0,0);tgold:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}});tgold:SetBackdropColor(0.04,0.04,0.04,1);tgold:SetBackdropBorderColor(0.8,0.7,0.45,1);tgold:SetScript('OnEscapePressed',function(self)self:ClearFocus()end);tgold:SetNumeric(true);tgold:SetMaxLetters(9)
 local nameLabel=tw:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');nameLabel:SetPoint('TOPLEFT',25,-371);nameLabel:SetText('Racer Name')
 local goldLabel=tw:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');goldLabel:SetPoint('TOPLEFT',230,-371);goldLabel:SetText('Gold Won')
 local tfaction='Alliance'
 local factionLabel=tw:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');factionLabel:SetPoint('TOPLEFT',365,-371);factionLabel:SetText('Team')
 local factionButton
 factionButton=tbutton('Gnomes',365,-393,155,function()
  tfaction=tfaction=='Alliance' and 'Horde' or 'Alliance';factionButton:SetText(tfaction=='Alliance' and 'Gnomes' or 'Goblins')
 end)
 local function action(a)
  local n=tname:GetText() or '';local g=tonumber(tgold:GetText())
  local ok,msg=MirageRacewayTournament:Admin(a,n,g,tfaction)
  tinfo:SetText(ok and ('Updated: '..n) or (msg or 'Update failed'))
  if ok then trefresh()end
 end
 tbutton('Add Racer',25,-444,145,function()action('ADD')end)
 tbutton('Set Gold',180,-444,145,function()action('SET')end)
 tbutton('Remove Racer',335,-444,145,function()action('REMOVE')end)
 for i=1,8 do
  local idx=i
  local b=tbutton('',25,-145-(i-1)*23,470,function()
   local r=tlist[idx+toffset];if not r then return end
   tselected=r.name;tname:SetText(r.name);tgold:SetText(tostring(r.gold));tfaction=r.faction or 'Alliance'
   factionButton:SetText(tfaction=='Alliance' and 'Gnomes' or 'Goblins')
   tinfo:SetText(r.name..' | '..r.gold..' gold')
  end)
  b:SetHeight(22);b:SetNormalTexture('');b:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight','ADD')
  local shade=b:CreateTexture(nil,'BACKGROUND');shade:SetAllPoints(b);shade:SetTexture(i%2==0 and .075 or .12,.14,.19,.85)
  local line=b:CreateTexture(nil,'ARTWORK');line:SetHeight(1);line:SetPoint('BOTTOMLEFT',0,0);line:SetPoint('BOTTOMRIGHT',0,0);line:SetTexture(.6,.55,.4,.35)
  local function cell(x,width)
   local f=b:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');f:SetPoint('LEFT',x,0);f:SetWidth(width);f:SetJustifyH('LEFT');return f
  end
  b.racer=cell(9,210);b.value=cell(230,115);b.team=cell(355,110)
  trows[i]=b
 end
 tbutton('Up',500,-130,48,function()toffset=math.max(0,toffset-1);trefresh()end)
 tbutton('Down',500,-158,48,function()toffset=math.min(math.max(0,#tlist-8),toffset+1);trefresh()end)
 trefresh=function()
  tlist={};local y=S.ServerYear();local d=MirageRacewayTournament:MasterData()
  local q=string.lower(tsearch:GetText() or '')
  local sd=d and d.seasons and d.seasons[y]
  if sd then for _,r in pairs(sd.racers)do if string.find(string.lower(r.name),q,1,true)then tlist[#tlist+1]=r end end end
  table.sort(tlist,function(a,b)if a.gold==b.gold then return a.name<b.name end return a.gold>b.gold end)
  toffset=math.min(toffset,math.max(0,#tlist-8))
  for i,b in ipairs(trows) do
   local r=tlist[i+toffset]
   if r then
    b.racer:SetText(r.name);b.value:SetText(tostring(r.gold or 0));b.team:SetText(r.faction=='Horde' and 'Goblins' or 'Gnomes');b:Show()
   else b:Hide() end
  end
  tt:SetText('TOURNAMENT MANAGEMENT - '..(y or 'DATE UNAVAILABLE'))
 end
 tsearch:SetScript('OnTextChanged',function()toffset=0;trefresh()end)
 tw:SetScript('OnShow',function()trefresh();tw:Raise();tc:SetFrameLevel(tw:GetFrameLevel()+20)end)
 local tdrag=CreateFrame('Frame',nil,tw);tdrag:SetPoint('TOPLEFT',10,-8);tdrag:SetPoint('TOPRIGHT',-42,-8);tdrag:SetHeight(38);tdrag:SetFrameLevel(tw:GetFrameLevel()+3);tdrag:EnableMouse(true);tdrag:RegisterForDrag('LeftButton');tdrag:SetScript('OnDragStart',function()tw:StartMoving()end);tdrag:SetScript('OnDragStop',function()tw:StopMovingOrSizing()end)
 MirageRacewayToggleTournamentMaster=function(force)
  if force or not tw:IsShown()then tw:Show()else tw:Hide()end
 end

end)

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
 local search=CreateFrame('EditBox',nil,win,'InputBoxTemplate');search:SetWidth(250);search:SetHeight(25);search:SetPoint('TOPLEFT',25,-58);search:SetAutoFocus(false);search:SetFrameLevel(win:GetFrameLevel()+10);search:EnableMouse(true)
 local selected=nil;local list={};local offset=0;local rows={}
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
 for i=1,9 do
  local index=i
  local b=button('',25,-92-(i-1)*26,475,function()
   local r=list[index+offset];if not r then return end
   selected=r.name;info:SetText(r.name..'  |  '..(r.best and S.Format(r.best) or 'No time')..(r.locked and '  [LOCKED]' or '')..(r.excluded and '  [EXCLUDED]' or ''))
  end)
  rows[i]=b
 end
 local up=button('Up',505,-98,45,function()offset=math.max(0,offset-1);refresh()end)
 local down=button('Down',505,-130,45,function()offset=math.min(math.max(0,#list-9),offset+1);refresh()end)
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
  offset=math.min(offset,math.max(0,#list-9))
  for i,b in ipairs(rows) do local r=list[i+offset];if r then b:SetText(r.name..'  '..(r.best and S.Format(r.best) or 'Reset pending'));b:Show()else b:Hide()end end
  local n=0;if d and y then for _,r in pairs(d.requests) do if r.year==y then n=n+1 end end end
  reqButton:SetText('Reset Requests ('..n..')')
  title:SetText('MASTER MANAGEMENT  -  '..(y or 'DATE UNAVAILABLE'))
 end
 search:SetScript('OnTextChanged',function()offset=0;refresh()end)
 win:SetScript('OnShow',function()win:Raise();close:SetFrameLevel(win:GetFrameLevel()+20);refresh()end)
 local drag=CreateFrame('Frame',nil,win);drag:SetPoint('TOPLEFT',win,'TOPLEFT',10,-8);drag:SetPoint('TOPRIGHT',win,'TOPRIGHT',-42,-8);drag:SetHeight(38);drag:SetFrameLevel(win:GetFrameLevel()+3);drag:EnableMouse(true);drag:RegisterForDrag('LeftButton');drag:SetScript('OnDragStart',function()win:StartMoving()end);drag:SetScript('OnDragStop',function()win:StopMovingOrSizing()end)
 MirageRacewayToggleMaster=function()if win:IsShown()then win:Hide()else win:Show()end end
end)

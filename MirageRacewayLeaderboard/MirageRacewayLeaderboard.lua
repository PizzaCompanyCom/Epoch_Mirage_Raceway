-- Mirage Raceway Leaderboard v0.1.0 / WoW 3.3.5a
local ADDON = ...
local f = CreateFrame('Frame')
local defaults = {hud=true,boost=true,rockets=true,victory=true,sounds=true,personal=true,scale=.56,opacity=.9,debug=false,updateAlerts=true,visualTheme="animated",animationQuality="full",particleEffects=true,glowFlicker=true,cleanEdges=true,countdownEnabled=true,countdownScale=2.5,debuffAnimations=true,syncMode="client"}
local db, raceStart, running, finished, lastStart, lastFinish, lastBonus, countdownEnd
local hud, timerText, statusText, bestText, notice, minimap, options, countdownFX
local announcedCountdownEnd=nil
local elapsedFinal = 0
local wasInRaceCar = false
local startAnchorX,startAnchorY,exitedStart,reenteredStart,requiresReentry=nil,nil,false,false,false
local function racePosition()
 if not GetPlayerMapPosition then return nil end
 local x,y=GetPlayerMapPosition('player')
 if type(x)~='number' or type(y)~='number' or (x==0 and y==0) then return nil end
 return x,y
end
local function updateStartArea()
 if not startAnchorX then return end
 local x,y=racePosition();if not x then return end
 local distance=math.sqrt((x-startAnchorX)^2+(y-startAnchorY)^2)
 if distance>.015 then exitedStart=true end
 if exitedStart and distance<.005 then reenteredStart=true end
end
local function cancelRace()
 if running then running=false;finished=false;raceStart=nil;elapsedFinal=0 end
end
local hudClosedThisRide = false
local noticeUntil = 0
local noticeKind = nil
local noticeLast = 0
local player = UnitName('player') or 'Unknown'
-- A global race announcement is not evidence that this character entered the race.
local function inOwnRaceCar()
 local v=UnitName('vehicle')
 if v and string.find(string.lower(v),'rocket car',1,true) then return true end
 if UnitInVehicle and UnitInVehicle('player') then
  local pet=UnitName('pet')
  if pet and string.find(string.lower(pet),'rocket car',1,true) then return true end
 end
 return false
end
local function log(s) DEFAULT_CHAT_FRAME:AddMessage('|cffd8a94c[Mirage Raceway]|r '..s) end
local function safeSound(path)
 if db and db.sounds then PlaySoundFile(path) end
end
local sounds={start='Sound\\Interface\\RaidWarning.wav',bonus='Sound\\Interface\\MapPing.wav',victory='Sound\\Interface\\LevelUp.wav'}
local function fmt(sec)
 sec=math.max(0,sec or 0)
 return string.format('%02d:%02d.%03d',math.floor(sec/60),math.floor(sec)%60,math.floor(sec*1000+.5)%1000)
end
local function getBest()
 if MirageRacewaySync then local p=MirageRacewaySync:Personal();return p.all and p.all/1000 end
 local v=db and db.records and db.records[player]
 return v and v.best
end
local function updateBest()
 if bestText then bestText:SetText(getBest() and fmt(getBest()) or '--:--.---') end
end
local function showNotice(title,kind,detail,duration)
 if not notice then return end
 -- v0.3.0 uses the separate borderless FX layer instead of legacy notices.
 return
 --[[
 noticeKind=kind
 notice.title:SetText(title)
 notice.detail:SetText(detail or '')
 if kind=='victory' then notice.title:SetTextColor(1,.81,.25)
 elseif kind=='rockets' then notice.title:SetTextColor(1,.32,.2)
 elseif kind=='boost' then notice.title:SetTextColor(.3,.85,1)
 else notice.title:SetTextColor(.7,1,.6) end
 notice:SetAlpha(1); notice:Show(); noticeUntil=GetTime()+(duration or 2.5)
 ]]
end
local function startRace(source)
 local now=GetTime()
 if not inOwnRaceCar() then return end
 if requiresReentry and not reenteredStart then return end
 if running then
  if reenteredStart then cancelRace();reenteredStart=false;exitedStart=false end
  return
 end
 if lastStart and now-lastStart<8 then return end
 local x,y=racePosition()
 if requiresReentry and not x then return end
 startAnchorX,startAnchorY=x,y;requiresReentry=true;exitedStart=false;reenteredStart=false
 running=true; finished=false; raceStart=now; lastStart=now; announcedCountdownEnd=nil; countdownEnd=nil; elapsedFinal=0; if countdownFX then countdownFX:Hide() end
 statusText:SetText(''); statusText:SetTextColor(.5,1,.55)
 if db.hud and not hudClosedThisRide then hud:Show() end; showNotice('GO! GO! GO!','start','RACE STARTED',2)
 -- Silent Result: race-start sound disabled.
 if db.debug then log('START detected: '..(source or '?')) end
end
-- First-run statistics import from Epoch Reborn's racing achievements.
-- Criteria quantity is a number of FIRST-PLACE finishes, not all race entries.
local raceAchievementIDs={5010,5011,5012} -- Bronze Award, Silver Trophy, Gold Trophy
local function achievementWinProgress()
 if type(GetAchievementInfo)~='function' or type(GetAchievementCriteriaInfo)~='function' then return nil end
 local best=nil
 for _,id in ipairs(raceAchievementIDs) do
  local ok,achievementID,name,points,completed=pcall(GetAchievementInfo,id)
  if ok and achievementID then
   local count=type(GetAchievementNumCriteria)=='function' and GetAchievementNumCriteria(id) or 0
   for index=1,count do
    local success,description,criteriaType,done,quantity,required=pcall(GetAchievementCriteriaInfo,id,index)
    if success and type(quantity)=='number' and quantity>=0 then
     local value=math.floor(quantity)
     if type(required)=='number' and required>0 then value=math.min(value,required) end
     best=math.max(best or 0,value)
    end
   end
   -- Completed achievements supply a guaranteed minimum even if criteria
   -- details are hidden by the client. Gold's threshold is not assumed.
   if completed and id==5010 then best=math.max(best or 0,10) end
   if completed and id==5011 then best=math.max(best or 0,50) end
  end
 end
 return best
end
local function raceStatistics()
 if not db then return 0,0 end
 db.raceStats=db.raceStats or {wins=0,races=0}
 local st=db.raceStats
 st.wins=math.max(0,math.floor(tonumber(st.wins) or 0))
 st.races=math.max(st.wins,math.floor(tonumber(st.races) or 0))
 local imported=achievementWinProgress()
 if imported~=nil then
  if not st.achievementBaselineImported then
   -- First-run initialization: races equal wins, unless a larger number
   -- has already been tracked locally by a prior version.
   st.wins=math.max(st.wins,imported)
   st.races=math.max(st.races,st.wins)
   st.achievementBaselineImported=true
  else
   -- Achievement progress may catch up asynchronously; never decrease counts.
   st.wins=math.max(st.wins,imported)
   st.races=math.max(st.races,st.wins)
  end
 end
 return st.wins,st.races
end
MirageRacewayGetRaceStatistics=raceStatistics
local function finishRace(place,source)
 local now=GetTime()
 if lastFinish and now-lastFinish<5 then return end
 if not running then
  if db.debug then log('Finish received without tracked start; result not timed.') end
  showNotice(place==1 and '1ST PLACE!' or 'RACE FINISHED','victory','Timer unavailable',5)
  -- Silent Result: no finish popup.
  return
 end
 lastFinish=now; elapsedFinal=now-raceStart; running=false; finished=true
  -- Initialize the achievement baseline before recording this new finish.
  raceStatistics()
  db.raceStats.races=db.raceStats.races+1
  if place==1 then db.raceStats.wins=db.raceStats.wins+1 end
 statusText:SetText(''); statusText:SetTextColor(1,.82,.32)
 timerText:SetText(fmt(elapsedFinal))
 -- Legacy records retained for migration safety, no longer used for public ranking.
 local oldBest=getBest()
 local isBest=not oldBest or math.floor(elapsedFinal*1000+.5)<math.floor(oldBest*1000+.5)
 if MirageRacewaySync then MirageRacewaySync:Finish(elapsedFinal) end
 updateBest()
 local label=place and (place==1 and '1ST PLACE — VICTORY!' or ('PLACE '..place..' — FINISHED!')) or 'RACE FINISHED!'
 showNotice(label,'victory',fmt(elapsedFinal)..(isBest and '  NEW PERSONAL BEST!' or ''),6)
 -- Finish visual effects preserved; no result popup sounds.
 -- Silent Result: no finish popup or sound.
 -- FX layer plays the finish banner, followed by the personal record when applicable.
 -- Silent Result: no race-finish chat announcement.
 if db.debug then log('FINISH source: '..(source or '?')) end
end
local function powerup(kind,spell)
 local now=GetTime()
 if lastBonus and lastBonus[kind] and now-lastBonus[kind]<3 then return end
 lastBonus=lastBonus or {}; lastBonus[kind]=now
 if kind=='boost' and not db.boost then return end
 if kind=='rockets' and not db.rockets then return end
 showNotice(kind=='boost' and 'SPEED BOOST!' or 'RED ROCKETS!',kind,spell or '',2.5)
 -- v0.3.0 FX layer plays bonus sounds.
 if db.debug then log('BONUS '..kind..' ('..(spell or '')..')') end
end
local function processMessage(msg,source)
 if not msg then return end
 local lower=string.lower(msg)
 -- Text strings observed in Epoch Reborn screenshots. Can be extended after diagnostics.
 if string.find(lower,'kickoff in 15 seconds',1,true) then
  announcedCountdownEnd=GetTime()+15
  if not inOwnRaceCar() then return end
  countdownEnd=announcedCountdownEnd
  if db.hud and not hudClosedThisRide then hud:Show() end
  statusText:SetText(''); showNotice('RACE STARTING!','start','15 SECONDS',3)
  if db.debug then log('PRESTART via '..source) end
 elseif string.find(lower,"and they're taking off! look at them go!",1,true) then
  startRace(source)
 else
  local p=string.match(lower,'you finished in place%s+(%d+)')
  if p then finishRace(tonumber(p),source)
  elseif db.debug and (string.find(lower,'raceway',1,true) or string.find(lower,'checkpoint',1,true)) then
   log(source..': '..msg)
  end
 end
end
local function createUI()
 hud=CreateFrame('Frame','MirageRacewayHUD',UIParent)
 hud:SetWidth(290); hud:SetHeight(142); hud:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-100,120); hud:SetClampedToScreen(false)
 hud:SetMovable(true); hud:EnableMouse(true); hud:RegisterForDrag('LeftButton')
 hud:SetScript('OnDragStart',function(self) self:StartMoving() end)
 hud:SetScript('OnDragStop',function(self)
  self:StopMovingOrSizing()
  local cx,cy=self:GetCenter()
  local ux,uy=UIParent:GetCenter()
  if cx and ux then
   -- Store the actual released position without a clamp that causes snapping.
   db.hudX=cx-ux
   db.hudY=cy-uy
   self:ClearAllPoints();self:SetPoint('CENTER',UIParent,'CENTER',db.hudX,db.hudY)
  end
 end)
 -- Illustrated Speed Freeks chronometer. The dial readouts are live FontStrings.
 hud:SetWidth(360);hud:SetHeight(360)
 local art=hud:CreateTexture(nil,'BACKGROUND')
 art:SetAllPoints(hud)
 art:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\chronometer_hud.tga')
 local title=hud:CreateFontString(nil,'OVERLAY','GameFontNormal')
 title:SetPoint('TOP',hud,'TOP',0,-33);title:SetText('') -- Title is decorative artwork
 statusText=hud:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 statusText:SetPoint('CENTER',hud,'CENTER',0,43)
 statusText:SetFont('Fonts\\FRIZQT__.TTF',16,'OUTLINE');statusText:SetTextColor(.48,1,.38)
 statusText:SetText('')
 timerText=hud:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
 timerText:SetPoint('CENTER',hud,'CENTER',0,-6)
 timerText:SetFont('Fonts\\FRIZQT__.TTF',46,'THICKOUTLINE')
 timerText:SetTextColor(1,.76,.12);timerText:SetText('00:00.00')
 bestText=hud:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 bestText:SetPoint('CENTER',hud,'CENTER',0,-68)
 bestText:SetFont('Fonts\\FRIZQT__.TTF',20,'OUTLINE')
 local close=CreateFrame('Button',nil,hud,'UIPanelCloseButton')
 close:SetWidth(29);close:SetHeight(29)
 close:SetPoint('TOPRIGHT',hud,'TOPRIGHT',-30,-42)
 close:SetScript('OnClick',function()hudClosedThisRide=true;hud:Hide() end)
 hud:SetScript('OnEnter',function(self)GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText('Drag to move | Close with X');GameTooltip:Show()end)
 hud:SetScript('OnLeave',function()GameTooltip:Hide()end)
 notice=CreateFrame('Frame','MirageRacewayNotice',UIParent); notice:SetWidth(430); notice:SetHeight(85); notice:SetPoint('CENTER',UIParent,'CENTER',0,265)
 notice.title=notice:CreateFontString(nil,'OVERLAY','GameFontNormalLarge'); notice.title:SetPoint('CENTER',0,10); notice.title:SetFont('Fonts\\FRIZQT__.TTF',29,'OUTLINE')
 notice.detail=notice:CreateFontString(nil,'OVERLAY','GameFontHighlight'); notice.detail:SetPoint('TOP',notice.title,'BOTTOM',0,-8)
 notice:Hide()
 countdownFX=CreateFrame('Frame','MirageRacewayCountdownFX',UIParent)
 countdownFX:SetFrameStrata('HIGH');countdownFX:SetWidth(620);countdownFX:SetHeight(480);countdownFX:SetPoint('CENTER',UIParent,'CENTER',0,75)
 local glow=countdownFX:CreateTexture(nil,'BACKGROUND');glow:SetAllPoints();glow:SetTexture('Interface\\SpellActivationOverlay\\IconAlert');glow:SetBlendMode('ADD');glow:SetVertexColor(1,.64,.12,.55)
 local digitFrame=CreateFrame('Frame',nil,countdownFX);digitFrame:SetWidth(620);digitFrame:SetHeight(470);digitFrame:SetPoint('CENTER',countdownFX,'CENTER',0,12)
 local digit=digitFrame:CreateFontString(nil,'OVERLAY','GameFontNormalHuge');digit:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF',80,'OUTLINE');digit:SetWidth(540);digit:SetHeight(360);digit:SetJustifyH('CENTER');digit:SetJustifyV('MIDDLE');digit:SetPoint('CENTER',digitFrame,'CENTER',0,0);digit:SetTextColor(1,.85,.35)
 local caption=countdownFX:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');caption:SetPoint('CENTER',0,-120);caption:SetText('GET READY!')
 -- v0.8.38: render countdown digits as textures; avoids font rendering clamps.
 local digitTexture=countdownFX:CreateTexture(nil,'ARTWORK')
 digitTexture:SetPoint('CENTER',countdownFX,'CENTER',0,12)
 digitTexture:SetBlendMode('BLEND')
 digitTexture:Hide()
 digit:Hide()
 countdownFX.digit=digit;countdownFX.digitFrame=digitFrame;countdownFX.digitTexture=digitTexture;countdownFX.glow=glow;countdownFX:Hide()
 -- Standalone movable launcher. Reset legacy offsets that could leave the old minimap icon off-screen.
 minimap=CreateFrame('Button','MirageRacewayMinimapButton',Minimap)
 minimap:SetWidth(34);minimap:SetHeight(34);minimap:SetFrameStrata('MEDIUM');minimap:SetFrameLevel(Minimap:GetFrameLevel()+3)
 minimap:SetClampedToScreen(true);minimap:SetMovable(true);minimap:EnableMouse(true)
 minimap:RegisterForClicks('LeftButtonUp','RightButtonUp');minimap:RegisterForDrag('LeftButton')
 local icon=minimap:CreateTexture(nil,'OVERLAY')
 icon:SetWidth(20);icon:SetHeight(20);icon:SetPoint('CENTER',minimap,'CENTER',-11,13);icon:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\minimap_pipe_round.tga')
 icon:SetTexCoord(0,1,0,1);icon:SetDrawLayer('OVERLAY',1)
 minimap.icon=icon
 local ring=minimap:CreateTexture(nil,'OVERLAY')
 ring:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder');ring:SetWidth(54);ring:SetHeight(54)
 ring:SetPoint('CENTER',minimap,'CENTER',0,0);ring:SetDrawLayer('OVERLAY',2)
 minimap:SetPoint('CENTER',Minimap,'CENTER',-75,-75)
 minimap:SetScript('OnDragStart',function(self)self:StartMoving()end)
 minimap:SetScript('OnDragStop',function(self)
  self:StopMovingOrSizing()
  local x,y=self:GetCenter();local ux,uy=UIParent:GetCenter()
  db.iconX=x-ux;db.iconY=y-uy;db.iconAnchorV2=true
 end)
 minimap:SetScript('OnClick',function(self,button)
  if button=='RightButton' then
   if MirageRacewayOptions then if MirageRacewayOptions:IsShown() then MirageRacewayOptions:Hide() else MirageRacewayOptions:Show();MirageRacewayOptions:Raise() end end
  elseif MirageRacewayToggleMainWindow then MirageRacewayToggleMainWindow() end
 end)
 minimap:SetScript('OnEnter',function(self)
  GameTooltip:SetOwner(self,'ANCHOR_LEFT');GameTooltip:AddLine('Mirage Raceway Leaderboard')
  GameTooltip:AddLine('Left click: Leaderboard | Right click: Settings | Drag: Move',1,1,1);GameTooltip:Show()
 end)
 minimap:SetScript('OnLeave',function()GameTooltip:Hide()end)
 minimap:Show()
 -- LibDataBroker / LibDBIcon bridge: use an existing compatible library when present.
 -- The standard named Minimap child above remains the fallback for legacy button bags.
 local ldb=LibStub and LibStub('LibDataBroker-1.1',true)
 local dbicon=LibStub and LibStub('LibDBIcon-1.0',true)
 if ldb and dbicon then
  local broker=ldb:NewDataObject('MirageRacewayBestTime',{
   type='launcher',text='Mirage Raceway Best Time',
   icon='Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\minimap_pipe_round.tga',
   OnClick=function(_,button) local fn=minimap:GetScript('OnClick');if fn then fn(minimap,button) end end,
   OnTooltipShow=function(t) t:AddLine('Mirage Raceway Best Time');t:AddLine('Left: Leaderboard | Right: Settings',1,1,1) end
  })
  if broker then
   db.minimapIcon=db.minimapIcon or {hide=false}
   dbicon:Register('MirageRacewayBestTime',broker,db.minimapIcon)
   minimap:Hide()
  end
 end
 options=CreateFrame('Frame','MirageRacewayOptions',UIParent); options:SetWidth(435); options:SetHeight(870); options:SetPoint('CENTER'); options:SetFrameStrata('FULLSCREEN_DIALOG'); options:SetFrameLevel(100); options:EnableMouse(true); options:SetMovable(true); options:RegisterForDrag('LeftButton')
 options:SetScript('OnShow',function(self) self:SetFrameStrata('FULLSCREEN_DIALOG'); self:SetFrameLevel(100); self:Raise() end)
 options:SetScript('OnDragStart',function(self) self:StartMoving() end); options:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
 options:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
 local header=options:CreateFontString(nil,'OVERLAY','GameFontNormalLarge'); header:SetPoint('TOP',0,-22); header:SetText('Mirage Raceway v'..(GetAddOnMetadata and (GetAddOnMetadata('MirageRacewayLeaderboard','Version') or '1.1.17') or '1.1.17'))
 local close=CreateFrame('Button',nil,options,'UIPanelCloseButton'); close:SetPoint('TOPRIGHT',-5,-5)
 local keys={{'hud','Race HUD'},{'boost','Speed Boost Effects'},{'rockets','Rocket Effects'},{'victory','Victory Animation'},{'sounds','Race Sounds'},{'personal','Show Personal Best'},{'debug','Debug Messages'}}
 for i,entry in ipairs(keys) do
  local key,label=entry[1],entry[2]
  local cb=CreateFrame('CheckButton',nil,options,'UICheckButtonTemplate'); cb:SetPoint('TOPLEFT',22,-47-(i-1)*30)
  cb.label=cb:CreateFontString(nil,'OVERLAY','GameFontHighlight'); cb.label:SetPoint('LEFT',cb,'RIGHT',3,0); cb.label:SetText(label)
  cb:SetScript('OnClick',function(self) db[key]=self:GetChecked() and true or false; if key=='hud' then if db.hud then hud:Show() else hud:Hide() end end; if key=='personal' then if db.personal then bestText:Show() else bestText:Hide() end end end)
  options['cb_'..key]=cb
 end
 local updates=CreateFrame('CheckButton',nil,options,'UICheckButtonTemplate')
 updates:SetPoint('TOPLEFT',options,'TOPLEFT',235,-47-6*30)
 local updatesLabel=updates:CreateFontString(nil,'OVERLAY','GameFontHighlight')
 updatesLabel:SetPoint('LEFT',updates,'RIGHT',3,0);updatesLabel:SetText('Update Alerts')
 updates:SetScript('OnClick',function(self) db.updateAlerts=self:GetChecked() and true or false end)
 options.cb_updateAlerts=updates
 updates:SetScript('OnEnter',function(self)
  GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
  GameTooltip:AddLine('Addon Version Alerts',1,.85,.3)
  GameTooltip:AddLine('Detects newer versions installed by other players in your guild or group. Does not check GitHub directly.',1,1,1,true)
  GameTooltip:Show()
 end)
 updates:SetScript('OnLeave',function()GameTooltip:Hide()end)
 local function slider(label,y,min,max,step,key,display)
  local s=CreateFrame('Slider','MirageRacewaySlider'..key,options,'OptionsSliderTemplate'); s:SetWidth(260); s:SetHeight(17); s:SetPoint('TOP',0,y); s:SetMinMaxValues(min,max); s:SetValueStep(step)
  getglobal(s:GetName()..'Low'):SetText(tostring(min)); getglobal(s:GetName()..'High'):SetText(tostring(max))
  s:SetScript('OnValueChanged',function(self,val)
   val=math.floor(val/step+.5)*step; db[key]=val; hud:SetScale(db.scale); hud:SetAlpha(db.opacity); notice:SetScale(db.scale); notice:SetAlpha(db.opacity)
   getglobal(self:GetName()..'Text'):SetText(label..': '..display(val))
  end)
  options['slider_'..key]=s
 end
 slider('HUD Scale',-285,.4,1.5,.05,'scale',function(v) return math.floor(v*100+.5)..'%' end)
 slider('HUD Opacity',-335,.3,1,.05,'opacity',function(v) return math.floor(v*100+.5)..'%' end)
 -- Animated FX is the only supported visual theme. Keep the theme row as a
 -- read-only indicator so the remaining visual settings retain their positions.
 local themeLabel=options:CreateFontString(nil,'OVERLAY','GameFontNormal');themeLabel:SetPoint('TOPLEFT',options,'TOPLEFT',35,-382);themeLabel:SetText('Visual Theme')
 local themeValue=options:CreateFontString(nil,'OVERLAY','GameFontHighlight');themeValue:SetPoint('LEFT',themeLabel,'RIGHT',22,0);themeValue:SetText('Animated FX')
 local function refreshTheme() db.visualTheme='animated' end
 options.refreshTheme=refreshTheme
 local qualityLabel=options:CreateFontString(nil,'OVERLAY','GameFontNormal');qualityLabel:SetPoint('TOPLEFT',options,'TOPLEFT',35,-425);qualityLabel:SetText('Animation Quality')
 local qualityButton=CreateFrame('Button',nil,options,'UIPanelButtonTemplate');qualityButton:SetWidth(155);qualityButton:SetHeight(24);qualityButton:SetPoint('LEFT',qualityLabel,'RIGHT',10,0)
 local qualities={'full','reduced','off'}
 local function refreshQuality() qualityButton:SetText((db.animationQuality or 'full'):upper()) end
 qualityButton:SetScript('OnClick',function()
  local current=db.animationQuality or 'full';local index=1
  for i,v in ipairs(qualities) do if v==current then index=i end end
  db.animationQuality=qualities[index%3+1];refreshQuality()
 end)
 options.refreshQuality=refreshQuality;refreshQuality()
 local function fxCheck(key,label,x)
  local cb=CreateFrame('CheckButton',nil,options,'UICheckButtonTemplate');cb:SetPoint('TOPLEFT',options,'TOPLEFT',25,x)
  cb.label=cb:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');cb.label:SetPoint('LEFT',cb,'RIGHT',3,0);cb.label:SetText(label)
  cb:SetScript('OnClick',function(self) db[key]=self:GetChecked() and true or false; if key=='cleanEdges' and MirageRacewayFXRefreshTheme then MirageRacewayFXRefreshTheme() end end)
  options['cb_'..key]=cb
 end
 fxCheck('particleEffects','Particle Effects',-465)
 fxCheck('glowFlicker','Glow & Flicker',-495)
 fxCheck('cleanEdges','Clean Transparent Edges',-525)
 fxCheck('countdownEnabled','Enable Countdown',-555)
 fxCheck('debuffAnimations','Debuff Effects',-585)
 local countdownLabel=options:CreateFontString(nil,'OVERLAY','GameFontNormal');countdownLabel:SetPoint('TOP',options,'TOP',0,-641);countdownLabel:SetText('Countdown Scale')
 local cs=CreateFrame('Slider','MirageRacewaySliderCountdownScale',options,'OptionsSliderTemplate');cs:SetWidth(260);cs:SetHeight(17);cs:SetPoint('TOP',options,'TOP',0,-667);cs:SetMinMaxValues(1,3);cs:SetValueStep(.25)
 getglobal(cs:GetName()..'Low'):SetText('100%');getglobal(cs:GetName()..'High'):SetText('300%')
 cs:SetScript('OnValueChanged',function(self,v) db.countdownScale=math.floor(v*4+.5)/4;getglobal(self:GetName()..'Text'):SetText(math.floor(db.countdownScale*100+.5)..'%') end)
 options.slider_countdownScale=cs
 -- v0.8.27: Fixed Master identity. Transport/synchronization is not yet active.
 local syncTitle=options:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
 syncTitle:SetPoint('TOP',options,'TOP',0,-712)
 syncTitle:SetText('Leaderboard Synchronization')
 local masterName=options:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 masterName:SetPoint('TOPLEFT',options,'TOPLEFT',28,-740)
 masterName:SetText('Master Character: Belerda (Locked)')
 local roleLabel=options:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
 roleLabel:SetPoint('TOPLEFT',options,'TOPLEFT',28,-762)
 roleLabel:SetText('Synchronization Mode:')
 local clientRole=CreateFrame('CheckButton',nil,options,'UICheckButtonTemplate')
 clientRole:SetPoint('TOPLEFT',options,'TOPLEFT',35,-778)
 local clientText=clientRole:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 clientText:SetPoint('LEFT',clientRole,'RIGHT',3,0);clientText:SetText('Client (Default)')
 local masterRole=CreateFrame('CheckButton',nil,options,'UICheckButtonTemplate')
 masterRole:SetPoint('LEFT',clientRole,'RIGHT',155,0)
 local masterText=masterRole:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 masterText:SetPoint('LEFT',masterRole,'RIGHT',3,0);masterText:SetText('Master')
 local function isMasterCharacter()
  return (UnitName('player') or '')=='Belerda'
 end
 local function refreshSyncRole()
  if db.syncMode~='master' or not isMasterCharacter() then db.syncMode='client' end
  clientRole:SetChecked(db.syncMode=='client')
  masterRole:SetChecked(db.syncMode=='master')
 end
 StaticPopupDialogs['MRL_MASTER_ACCESS_DENIED']={
  text='Master mode is restricted to Belerda.',button1='OK',
  timeout=0,whileDead=1,hideOnEscape=1,preferredIndex=3,
 }
 clientRole:SetScript('OnClick',function() db.syncMode='client';refreshSyncRole() end)
 masterRole:SetScript('OnClick',function()
  if not isMasterCharacter() then
   db.syncMode='client';refreshSyncRole();StaticPopup_Show('MRL_MASTER_ACCESS_DENIED')
  else
   db.syncMode='master';refreshSyncRole()
  end
 end)
 local syncStatus=options:CreateFontString(nil,'OVERLAY','GameFontDisableSmall')
 syncStatus:SetPoint('TOP',options,'TOP',0,-819)
 syncStatus:SetText('Synchronization: Not yet active (planned for v0.9.0)')
 options.refreshSyncRole=refreshSyncRole
 refreshSyncRole()
 -- Standalone command-driven test console. Never mutates saved race records via previews.
 local tests=CreateFrame('Frame','MirageRacewayTestConsole',UIParent)
 tests:SetWidth(640);tests:SetHeight(345);tests:SetFrameStrata('FULLSCREEN_DIALOG');tests:SetFrameLevel(110)
 tests:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
 tests:EnableMouse(true)
 local testTitle=tests:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');testTitle:SetPoint('TOP',0,-18);testTitle:SetText('MIRAGE RACEWAY - TEST COMMANDS')
 local testClose=CreateFrame('Button',nil,tests,'UIPanelCloseButton');testClose:SetPoint('TOPRIGHT',-5,-5)
 local function runTest(command)
  local handler=SlashCmdList and SlashCmdList.MIRAGERACEWAY
  if handler then handler(command) end
 end
 local testCommands={
  {'All FX','fx demo'},{'Stop FX','fx stop'},{'5s Countdown','countdown'},{'Boost','fx boost'},
  {'Jump','fx jump'},{'Jump Failed','fx jumpfailed'},{'Oil Bonus','fx oil'},{'Green Rocket','fx green'},{'Red Rocket','fx red'},
  {'1st Place','fx first'},{'2nd Place','fx second'},{'3rd Place','fx third'},{'No Podium','fx lose'},
  {'Personal Record','fx record'},{'Oil Slowdown','fx oilhit'},{'Rocket Hit','fx rockethit'},{'Rocket Dodged','fx dodge'},{'Both Debuffs','fx debuffdemo'},
  {'Texture Test','fx texturetest'},{'Demo Racers','demoleaders'},{'Clear Demo','cleardemo'},{'Show TOP','top'},
  {'Race History','history'},{'Start Race Test','starttest'},{'Finish Race Test','finishtest'},{'Debug On/Off','debug'},
  {'Spell Debug ON/OFF','spell toggle'},{'Show Spell Log','spell show'},{'Clear Spell Log','spell clear'}
 }
 for i,entry in ipairs(testCommands) do
  local col=(i-1)%4;local row=math.floor((i-1)/4)
  local b=CreateFrame('Button',nil,tests,'UIPanelButtonTemplate');b:SetWidth(145);b:SetHeight(27)
  b:SetPoint('TOPLEFT',tests,'TOPLEFT',20+col*153,-47-row*32)
  b:SetText(entry[1]);local command=entry[2]
  b:SetScript('OnClick',function()runTest(command)end)
  b:SetScript('OnEnter',function(self)GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:AddLine('/mrl '..command,1,.85,.4);GameTooltip:Show()end)
  b:SetScript('OnLeave',function()GameTooltip:Hide()end)
 end
 tests:Hide()
 local function positionTests()
  options:SetScale(.88);options:ClearAllPoints();options:SetPoint('TOP',UIParent,'TOP',0,-12)
  tests:SetScale(.88);tests:ClearAllPoints();tests:SetPoint('TOP',options,'BOTTOM',0,-3)
 end
 local testToggle=CreateFrame('Button',nil,options,'UIPanelButtonTemplate');testToggle:SetWidth(170);testToggle:SetHeight(24)
 testToggle:SetPoint('BOTTOM',options,'BOTTOM',0,9);testToggle:SetText('Test Commands')
 testToggle:SetScript('OnClick',function()
  if tests:IsShown() then tests:Hide() else positionTests();tests:Show();tests:Raise() end
 end)
 testClose:SetScript('OnClick',function()tests:Hide()end)
 options:SetScript('OnHide',function()tests:Hide()end)

 local help=options:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); help:SetPoint('BOTTOM',0,36); help:SetText('/mrl fx demo  |  /mrl top  |  /mrl history')
 options:Hide()
end
local function applySettings()
 db.visualTheme="animated"
 if not db.hudLayoutV816 then
  if db.scale==1 then db.scale=.7 end
  db.hudLayoutV816=true
 end
 if not db.hudScaleV818 then
  db.scale=math.max(.4,math.min(1.5,(db.scale or .7)*.8))
  db.hudScaleV818=true
 end
 hud:SetScale(db.scale); hud:SetAlpha(db.opacity); if db.hud and (inOwnRaceCar() or running or countdownEnd) and not hudClosedThisRide then hud:Show() else hud:Hide() end; if db.personal then bestText:Show() else bestText:Hide() end
 notice:SetScale(db.scale)
 if db.hudX then hud:ClearAllPoints(); hud:SetPoint('CENTER',UIParent,'CENTER',db.hudX,db.hudY or 170) end
 if db.iconAnchorV2 and db.iconX then minimap:ClearAllPoints();minimap:SetPoint('CENTER',UIParent,'CENTER',db.iconX,db.iconY or 0) end
 for k in pairs(defaults) do if options['cb_'..k] then options['cb_'..k]:SetChecked(db[k]) end end
 options.slider_scale:SetValue(db.scale); options.slider_opacity:SetValue(db.opacity); if options.slider_countdownScale then options.slider_countdownScale:SetValue(db.countdownScale or 2.5) end; if options.refreshTheme then options.refreshTheme() end; if options.refreshQuality then options.refreshQuality() end; if options.refreshSyncRole then options.refreshSyncRole() end
 updateBest()
end
local function sortedRecords()
 local t={}
 for name,r in pairs(db.records or {}) do if r.best then table.insert(t,{name=name,best=r.best,wins=r.wins or 0}) end end
 table.sort(t,function(a,b) if a.best==b.best then return a.name<b.name end return a.best<b.best end)
 return t
end
-- v0.8.31: Countdown diagnostics (no visual changes).
local countdownDiagActive=false
local function countdownDiagSnapshot(reason)
 local function num(v) return type(v)=='number' and string.format('%.3f',v) or tostring(v) end
 local function frameInfo(tag,obj)
  if not obj then log('[Countdown Debug] '..tag..': MISSING'); return end
  local scale=(obj.GetScale and obj:GetScale()) or 'n/a'
  local effective=(obj.GetEffectiveScale and obj:GetEffectiveScale()) or 'n/a'
  local width=(obj.GetWidth and obj:GetWidth()) or 'n/a'
  local height=(obj.GetHeight and obj:GetHeight()) or 'n/a'
  local shown=(obj.IsShown and obj:IsShown()) and 'YES' or 'NO'
  log('[Countdown Debug] '..tag..' scale='..num(scale)..' effective='..num(effective)..' size='..num(width)..'x'..num(height)..' shown='..shown)
 end
 log('[Countdown Debug] '..reason..' setting='..num(db.countdownScale)..' enabled='..tostring(db.countdownEnabled)..' remaining='..tostring(countdownEnd and math.ceil(countdownEnd-GetTime()) or 'none'))
 frameInfo('UIParent',UIParent)
 frameInfo('countdownFX',countdownFX)
 frameInfo('digitFrame',countdownFX and countdownFX.digitFrame)
 local digit=countdownFX and countdownFX.digit
 frameInfo('digit',digit)
 local digitTexture=countdownFX and countdownFX.digitTexture
 frameInfo('digitTexture',digitTexture)
 if digitTexture then log('[Countdown Debug] bitmap digit='..tostring(countdownFX.lastTextureDigit)..' texture='..tostring(digitTexture:GetTexture())) end
 if digit and digit.GetFont then
  local path,size,flags=digit:GetFont()
  log('[Countdown Debug] digit font='..tostring(path)..' size='..num(size)..' flags='..tostring(flags)..' text='..tostring(digit:GetText()))
  local stringHeight=(digit.GetStringHeight and digit:GetStringHeight()) or 'n/a'
  local stringWidth=(digit.GetStringWidth and digit:GetStringWidth()) or 'n/a'
  log('[Countdown Debug] glyph width='..num(stringWidth)..' height='..num(stringHeight)..' scaledHeight='..(type(stringHeight)=='number' and num(stringHeight*((digit.GetEffectiveScale and digit:GetEffectiveScale()) or 1)) or 'n/a'))
 end
end
SLASH_MIRAGERACEWAY1='/mrl'; SLASH_MIRAGERACEWAY2='/mirageraceway'
SlashCmdList.MIRAGERACEWAY=function(input)
 local cmd=string.lower((input or ''):match('^%s*(.-)%s*$'))
 if cmd=='inspect' or cmd:match('^inspect%s+') then
  if MirageRacewayInspectorCommand then MirageRacewayInspectorCommand(cmd:match('^inspect%s*(.-)%s*$')) end
 elseif cmd=='spell' or cmd:match('^spell%s+') then
  if MirageRacewaySpellDebugCommand then MirageRacewaySpellDebugCommand(cmd:match('^spell%s*(.-)%s*$')) else log('Spell Debug module unavailable.') end
 elseif cmd=='fx' or cmd:match('^fx%s+') then
  local arg=cmd:match('^fx%s*(.-)%s*$')
  if MirageRacewayFXCommand then MirageRacewayFXCommand(arg) else log('FX module unavailable. Check addon load errors.') end
 elseif cmd=='countdown debug' then
  countdownDiagActive=true
  countdownDiagSnapshot('Manual snapshot')
  log('[Countdown Debug] Next /mrl countdown will log the first displayed digit; use /mrl countdown debug again while digits are visible.')
 elseif cmd=='countdown debug off' then
  countdownDiagActive=false
  log('[Countdown Debug] Automatic snapshot OFF.')
 elseif cmd=='countdown' then
  countdownEnd=GetTime()+5; if countdownFX then countdownFX.lastDigit=nil;countdownFX.lastTextureDigit=nil;countdownFX.lastFontSize=nil;if db.countdownEnabled then countdownFX:Show() end end
  log('Five-second countdown preview (no race result saved).')
 elseif cmd=='test' then
  log('TEST MODE: simulated start, bonus and finish. No record will be saved.')
  showNotice('SPEED BOOST!','boost','Accelerate',2.5); safeSound(sounds.bonus)
 elseif cmd=='starttest' then startRace('manual test')
 elseif cmd=='finishtest' then finishRace(1,'manual test')
 elseif cmd=='top' then
  local t=sortedRecords(); log('TOP 50 LOCAL BEST TIMES ('..#t..' recorded racers)')
  for i=1,math.min(50,#t) do log(i..'. '..t[i].name..' - '..fmt(t[i].best)..' | Wins '..t[i].wins) end
 elseif cmd=='history' then
  for i=1,math.min(10,#(db.history or {})) do local r=db.history[i]; log(r.date..'  '..fmt(r.time)..'  Place '..tostring(r.place or '?')) end
 elseif cmd=='debug' then db.debug=not db.debug; log('Debug '..(db.debug and 'ON' or 'OFF'))
 elseif cmd=='resetpos' then db.hudX=nil; db.hudY=nil; hud:ClearAllPoints(); hud:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-100,120); log('HUD position reset.')
 elseif cmd=='help' then log('/mrl spell on|off|show|clear | /mrl countdown | /mrl countdown debug | /mrl fx oilhit|rockethit|debuffdemo | /mrl fx demo | /mrl top | /mrl history | /mrl debug | /mrl resetpos')
 else if options:IsShown() then options:Hide() else options:Show() end end
end
f:RegisterEvent('ADDON_LOADED'); f:RegisterEvent('PLAYER_LOGIN');f:RegisterEvent('PLAYER_DEAD');f:RegisterEvent('PLAYER_LOGOUT')
f:RegisterEvent('CHAT_MSG_MONSTER_YELL'); f:RegisterEvent('CHAT_MSG_MONSTER_SAY'); f:RegisterEvent('CHAT_MSG_SYSTEM'); f:RegisterEvent('CHAT_MSG_RAID_BOSS_EMOTE'); f:RegisterEvent('CHAT_MSG_RAID_BOSS_WHISPER')
f:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
f:SetScript('OnEvent',function(self,event,...)
 if event=='ADDON_LOADED' then
  local name=...
  if name~='MirageRacewayLeaderboard' then return end
  MirageRacewayDB=MirageRacewayDB or {}; db=MirageRacewayDB
  for k,v in pairs(defaults) do if db[k]==nil then db[k]=v end end
  db.records=db.records or {}; db.history=db.history or {}
 elseif event=='PLAYER_LOGIN' then
  if not db then return end
  player=UnitName('player') or player
  raceStatistics(); createUI(); applySettings(); log('Loaded. /mrl help | Debug: /mrl debug')
 elseif event=='PLAYER_DEAD' or event=='PLAYER_LOGOUT' then
  cancelRace()
 elseif event=='COMBAT_LOG_EVENT_UNFILTERED' then
  if not db or not running then return end
  local timestamp,subevent,srcGUID,srcName,srcFlags,dstGUID,dstName,dstFlags,spellId,spellName=...
  if subevent~='SPELL_AURA_APPLIED' and subevent~='SPELL_AURA_REFRESH' then return end
  if not spellName then return end
  local spell=string.lower(spellName)
  -- Only effects on the player's controlled vehicle, player, or pet; never world objects.
  local mine=(dstGUID and (dstGUID==UnitGUID('player') or dstGUID==UnitGUID('vehicle') or dstGUID==UnitGUID('pet')))
  if not mine then return end
  if string.find(spell,'red rockets',1,true) then powerup('rockets',spellName) end
 else
  if db and hud then processMessage((...),event) end
 end
end)
local tick=0
local vehicleTick=0
local function isRaceCar() return inOwnRaceCar() end
f:SetScript('OnUpdate' ,function(self,dt)
 if not hud then return end
 vehicleTick=vehicleTick+dt
 if vehicleTick>=.2 then
  vehicleTick=0
  local inside=isRaceCar()
  updateStartArea()
  if running and not inside then cancelRace() end
  if inside~=wasInRaceCar then
   wasInRaceCar=inside
   if inside then
    if announcedCountdownEnd and announcedCountdownEnd>GetTime() and not running then countdownEnd=announcedCountdownEnd end
    hudClosedThisRide=false
    if db and db.hud then hud:Show() end
   else hud:Hide() end
  end
 end
 tick=tick+dt
 if tick<.03 then return end
 tick=0
 if running then timerText:SetText(fmt(GetTime()-raceStart))
 elseif countdownEnd then
  local remaining=math.ceil(countdownEnd-GetTime())
  if remaining>0 then timerText:SetText(string.format('00:%02d',remaining)); statusText:SetText('')
   if countdownFX and db.countdownEnabled and remaining<=5 then
    countdownFX:Show();countdownFX.digit:SetText(tostring(remaining))
    local phase=(countdownEnd-GetTime())%1
    local pulse=1+.22*phase
    -- v0.8.38: bitmap digits, sized directly in frame units.
    local targetScale=math.max(1,math.min(3,db.countdownScale or 2.5))
    local appliedScale=targetScale*(1+.12*phase)
    local digitFrame=countdownFX.digitFrame
    digitFrame:SetScale(1)
    countdownFX.digit:Hide()
    local digitTexture=countdownFX.digitTexture
    if digitTexture then
     if countdownFX.lastTextureDigit~=remaining then
      digitTexture:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\countdown_'..tostring(remaining))
      countdownFX.lastTextureDigit=remaining
     end
     digitTexture:SetWidth(180*appliedScale)
     digitTexture:SetHeight(180*appliedScale)
     digitTexture:Show()
    end
    countdownFX.glow:SetAlpha(.2+.5*phase)
    if countdownFX.lastDigit~=remaining then
     if countdownDiagActive then countdownDiagSnapshot('Displayed digit '..tostring(remaining)) end
     countdownFX.lastDigit=remaining;safeSound(sounds.bonus)
    end
   elseif countdownFX then countdownFX:Hide() end
  else countdownEnd=nil;if countdownFX then countdownFX:Hide() end;timerText:SetText('00:00.00'); statusText:SetText('') end
 end
 if notice and notice:IsShown() then
  local left=noticeUntil-GetTime()
  if left<=0 then notice:Hide()
  elseif left<.5 then notice:SetAlpha(left*2*(db.opacity or .9))
  else notice:SetAlpha(db.opacity or .9) end
 end
end)

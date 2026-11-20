-- Mirage Raceway v0.8.23: verified spell-ID debuffs with vehicle GUID checks.
local frame,art,glow,particles={},nil,nil,{}
local root='Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\'
local kind=nil
local start=0
local duration=3.1
local function settings() return MirageRacewayDB or {} end
local function init()
 frame=CreateFrame('Frame','MirageRacewayDebuffEffects',UIParent)
 frame:SetSize(540,220)
 frame:SetPoint('BOTTOM',UIParent,'BOTTOM',0,125)
 frame:SetFrameStrata('HIGH')
 art=frame:CreateTexture(nil,'ARTWORK')
 art:SetSize(512,256);art:SetPoint('CENTER')
 glow=frame:CreateTexture(nil,'BACKGROUND')
 glow:SetTexture('Interface\\Buttons\\WHITE8X8')
 glow:SetBlendMode('ADD');glow:SetSize(400,30);glow:SetPoint('CENTER')
 for i=1,14 do
  local p=frame:CreateTexture(nil,'OVERLAY')
  p:SetTexture('Interface\\Buttons\\WHITE8X8');p:SetBlendMode('ADD')
  p:SetSize(4+i%3,4+i%3);p:SetPoint('CENTER')
  particles[i]=p
 end
 frame:Hide()
 frame:SetScript('OnUpdate',function(self,dt)
  if not kind then return end
  local t=GetTime()-start
  if t>=duration then self:Hide();kind=nil;return end
  local cfg=settings()
  local q=cfg.animationQuality or 'full'
  local dynamic=q~='off'
  local alpha=math.min(1,t/.22,(duration-t)/.45)*(cfg.opacity or .9)
  self:SetAlpha(alpha)
  self:SetScale((cfg.scale or 1)*(dynamic and (1+.05*math.sin(t*12)*math.exp(-t*2)) or 1))
  art:ClearAllPoints()
  art:SetPoint('CENTER',self,'CENTER',dynamic and (kind=='rockethit' and math.sin(t*35)*math.max(0,8-t*9) or math.sin(t*9)*3) or 0,0)
  glow:SetVertexColor(kind=='oilhit' and .3 or 1,kind=='oilhit' and 1 or .38,.04,1)
  glow:SetAlpha(cfg.glowFlicker~=false and q~='off' and math.max(0,1-t/1.6)*.22 or 0)
  for i,p in ipairs(particles) do
   local angle=i*2.4
   local dist=25+t*(kind=='rockethit' and 105 or 60)+(i%4)*11
   p:ClearAllPoints();p:SetPoint('CENTER',self,'CENTER',math.cos(angle)*dist,math.sin(angle)*dist*.4)
   p:SetVertexColor(kind=='oilhit' and .42 or 1,kind=='oilhit' and 1 or .5,kind=='oilhit' and .05 or .1)
   p:SetAlpha(cfg.particleEffects~=false and q~='off' and math.max(0,1-t/2)*.8 or 0)
  end
 end)
end
local function playSound(k)
 if settings().sounds==false then return end
 local filename=k=='rockethit' and 'RocketHit.wav' or 'OilSlowdown.wav'
 local custom='Interface\\AddOns\\MirageRacewayLeaderboard\\Sounds\\'..filename
 local ok,played=pcall(PlaySoundFile,custom)
 if not ok or played==false then
  pcall(PlaySoundFile,k=='rockethit' and 'Sound\\Interface\\RaidWarning.wav' or 'Sound\\Interface\\MapPing.wav')
 end
end

function MirageRacewayDebuffPreview(k)
 if settings().debuffAnimations==false then return end
 if not frame or not frame.SetPoint then init() end
 if k~='oilhit' and k~='rockethit' then return end
 kind=k;start=GetTime()
 local theme='animated'
 art:SetTexture(nil)
 art:SetTexture(root..'debuff_'..theme..'_'..k..'.tga')
 art:SetTexCoord(0,1,0,1)
 frame:SetScale(settings().scale or 1)
 frame:SetAlpha(0);frame:Show()
 playSound(k)
end

-- v0.8.11: server combat-log recognition, never infer ownership from the shared "Rocket Car" name.
local detection=CreateFrame('Frame')
local recent={}
local function mine(guid)
 if not guid then return false end
 return guid==UnitGUID('player') or guid==UnitGUID('vehicle') or guid==UnitGUID('pet')
end
local function trigger(k, cooldown)
 if settings().debuffAnimations==false then return end
 local now=GetTime()
 if recent[k] and now-recent[k]<(cooldown or 2.5) then return end
 recent[k]=now
 if k=='jumpfailed' then
  if MirageRacewayJumpFailedBanner then MirageRacewayJumpFailedBanner() end
 elseif k=='dodge' then
  if MirageRacewayDodgeBanner then MirageRacewayDodgeBanner() end
 else
  MirageRacewayDebuffPreview(k)
 end
end
-- Rocket Dodged: illustrated themed banner, with animated slide/glow.
local dodgeFrame=nil
function MirageRacewayDodgeBanner()
 if settings().debuffAnimations==false then return end
 if not dodgeFrame then
  dodgeFrame=CreateFrame('Frame','MirageRacewayDodgeFX',UIParent)
  dodgeFrame:SetSize(580,150)
  dodgeFrame:SetPoint('TOP',UIParent,'TOP',0,-125)
  dodgeFrame:SetFrameStrata('HIGH')
  dodgeFrame.art=dodgeFrame:CreateTexture(nil,'ARTWORK')
  dodgeFrame.art:SetAllPoints(dodgeFrame)
  dodgeFrame.glow=dodgeFrame:CreateTexture(nil,'BACKGROUND')
  dodgeFrame.glow:SetTexture('Interface\\Buttons\\WHITE8X8')
  dodgeFrame.glow:SetVertexColor(.02,.75,.9,.35)
  dodgeFrame.glow:SetBlendMode('ADD')
  dodgeFrame.glow:SetSize(400,8)
  dodgeFrame.glow:SetPoint('BOTTOM',dodgeFrame,'BOTTOM',0,17)
  dodgeFrame:Hide()
  dodgeFrame:SetScript('OnUpdate',function(self)
   local t=GetTime()-(self.started or 0)
   if t>=2.6 then self:Hide();return end
   self:SetAlpha(math.min(1,t/.22,(2.6-t)/.48))
   local slide= t<.34 and (-70*(1-t/.34)) or (t>2.1 and 35*(t-2.1)/.5 or 0)
   self.art:ClearAllPoints()
   self.art:SetPoint('CENTER',self,'CENTER',slide,0)
   self.art:SetSize(580,150)
   self.glow:SetAlpha(.35+.25*math.abs(math.sin(t*9)))
  end)
 end
 local theme='animated'
 dodgeFrame.art:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\dodge_'..theme..'.tga')
 dodgeFrame.started=GetTime();dodgeFrame:SetAlpha(0);dodgeFrame:Show()
 if settings().sounds~=false then PlaySoundFile('Interface\\AddOns\\MirageRacewayLeaderboard\\Sounds\\RocketDodge.wav') end
end

-- Jump Failed: dedicated theme-specific banner, separate from successful Jump pickup.
-- SPELL_DAMAGE_SHIELD_MISSED (87516) is NOT sufficient proof that Jump activation failed.
local jumpFailedFrame=nil
function MirageRacewayJumpFailedBanner()
 if settings().debuffAnimations==false then return end
 if not jumpFailedFrame then
  jumpFailedFrame=CreateFrame('Frame','MirageRacewayJumpFailedFX',UIParent)
  jumpFailedFrame:SetWidth(580);jumpFailedFrame:SetHeight(150)
  jumpFailedFrame:SetPoint('BOTTOM',UIParent,'BOTTOM',0,125)
  jumpFailedFrame:SetFrameStrata('HIGH')
  jumpFailedFrame.art=jumpFailedFrame:CreateTexture(nil,'ARTWORK')
  jumpFailedFrame.art:SetAllPoints(jumpFailedFrame)
  jumpFailedFrame:Hide()
  jumpFailedFrame:SetScript('OnUpdate',function(self)
   local t=GetTime()-(self.started or 0)
   if t>=2.7 then self:Hide();return end
   self:SetAlpha(math.max(0,math.min(1,t/.2,(2.7-t)/.5)))
   local slide=t<.32 and -65*(1-t/.32) or 0
   self.art:ClearAllPoints();self.art:SetPoint('CENTER',self,'CENTER',slide,0)
   if settings().animationQuality~='off' then
    self.art:SetVertexColor(1,.85+.15*math.abs(math.sin(t*14)),.85+.15*math.abs(math.sin(t*14)),1)
   else self.art:SetVertexColor(1,1,1,1) end
  end)
 end
 local theme='animated'
 jumpFailedFrame.art:SetTexture('Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\jumpfailed_'..theme..'.tga')
 jumpFailedFrame.started=GetTime();jumpFailedFrame:SetAlpha(0);jumpFailedFrame:Show()
 if settings().sounds~=false then pcall(PlaySoundFile,'Sound\\Interface\\RaidWarning.wav') end
end

detection:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
detection:SetScript('OnEvent',function(self,event,...)
 local _,sub,srcGUID,srcName,srcFlags,dstGUID,dstName,dstFlags,spellID,spellName,spellSchool,missType=...
 if not mine(dstGUID) then return
 elseif sub=='SPELL_AURA_APPLIED' or sub=='SPELL_AURA_REFRESH' then
  if tonumber(spellID)==87509 then trigger('rockethit',2.5)
  elseif tonumber(spellID)==87521 then
   -- World/finish-line Tar Puddle auras can affect other cars. Require the
   -- actual slow aura on our occupied vehicle, not merely a matching log name.
   local affected=false
   for _,unit in ipairs({'vehicle','pet'}) do
    if UnitExists(unit) and UnitGUID(unit)==dstGUID then
     for i=1,40 do
      local name=UnitDebuff(unit,i)
      if not name then break end
      if string.find(string.lower(name),'tar puddle',1,true) then affected=true;break end
     end
    end
    if affected then break end
   end
   if affected then trigger('oilhit',2.5) end
  end
 elseif sub=='SPELL_MISSED' and missType=='IMMUNE' then
  local name=type(spellName)=='string' and string.lower(spellName) or ''
  if string.find(name,'rocket',1,true) then trigger('dodge',2.5) end
 end
end)

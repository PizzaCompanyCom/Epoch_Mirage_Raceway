-- Mirage Raceway v0.3.0: borderless graffiti FX, WoW 3.3.5a / Lua 5.1.
local root=CreateFrame('Frame')
local names={'boost','jump','oil','green','red','first','second','third','lose','record'}
local aliases={accelerate='boost',speed='boost',rocketjump='jump',oilspill='oil',greenrocket='green',redrocket='red',win='first',loss='lose',best='record'}
local colors={boost={.12,.72,1},jump={1,.72,.18},oil={.73,.25,1},green={.28,1,.24},red={1,.21,.14},first={1,.77,.16},second={.5,.81,1},third={1,.51,.22},lose={1,.3,.22},record={.6,1,.15}}
local fx,art,flash,streaks={},nil,nil,{}
local glows={},{}
local burst=nil
local animatedParts={}
local animatedRays={}
local animatedBadge=nil
local animatedFlash=nil
local movingObject=nil
local movingKind=nil
local current,started,duration=nil,0,0
local themePath='Interface\\AddOns\\MirageRacewayLeaderboard\\Textures\\'
local queue,queueAt={},0
local textureTestFrame=nil
local lastSeen={}
local debuffDemoNext=nil
local function db() return MirageRacewayDB or {} end
local function artPath(kind) return themePath..'speed_'..kind..'.tga' end
local function applyArt(kind)
 if not art then return end
 -- Clear the previous texture first: otherwise failed loads can leave the old image visible.
 art:SetTexture(nil)
 art:SetTexture(artPath(kind))
 art:SetTexCoord(0,1,0,1)
end
MirageRacewayFXRefreshTheme=function() if art and current then applyArt(current) end end
local function chat(msg) DEFAULT_CHAT_FRAME:AddMessage('|cffffc66d[Mirage FX]|r '..msg) end
local function create()
 fx=CreateFrame('Frame','MirageRacewayEffectsFrame',UIParent)
 fx:SetWidth(560);fx:SetHeight(170);fx:SetPoint('CENTER',UIParent,'CENTER',0,270)
 fx:SetFrameStrata('HIGH');fx:Hide()
 art=fx:CreateTexture(nil,'ARTWORK');art:SetWidth(560);art:SetHeight(140);art:SetPoint('CENTER',fx,'CENTER',0,0)
 flash=fx:CreateTexture(nil,'BACKGROUND');flash:SetTexture('Interface\\Buttons\\WHITE8X8');flash:SetBlendMode('ADD')
 flash:SetWidth(480);flash:SetHeight(80);flash:SetPoint('CENTER',fx,'CENTER',0,0)
 burst=fx:CreateTexture(nil,'BACKGROUND');burst:SetTexture(themePath..'fx_glow.tga');burst:SetBlendMode('ADD');burst:SetWidth(270);burst:SetHeight(130);burst:SetPoint('CENTER',fx,'CENTER',0,0)
 -- Animated FX: independent moving layers over the illustrated base art.
 animatedFlash=fx:CreateTexture(nil,'BACKGROUND')
 animatedFlash:SetTexture(themePath..'anim_burst.tga');animatedFlash:SetBlendMode('ADD')
 animatedFlash:SetWidth(560);animatedFlash:SetHeight(160);animatedFlash:SetPoint('CENTER',fx,'CENTER',0,0)
 movingObject=fx:CreateTexture(nil,'OVERLAY')
 movingObject:SetWidth(190);movingObject:SetHeight(115)
 movingObject:SetPoint('CENTER',fx,'CENTER',-240,0)
 animatedBadge=fx:CreateTexture(nil,'OVERLAY')
 animatedBadge:SetTexture(themePath..'anim_rocket.tga');animatedBadge:SetBlendMode('ADD')
 animatedBadge:SetWidth(110);animatedBadge:SetHeight(72);animatedBadge:SetPoint('CENTER',fx,'CENTER',-300,0)
 for i=1,18 do
  local t=fx:CreateTexture(nil,'OVERLAY');t:SetTexture(themePath..'anim_spark.tga');t:SetBlendMode('ADD')
  t:SetWidth(12);t:SetHeight(12);t:SetPoint('CENTER',fx,'CENTER',0,0)
  animatedParts[i]=t
 end
 for i=1,7 do
  local t=fx:CreateTexture(nil,'ARTWORK');t:SetTexture(themePath..'anim_streak.tga');t:SetBlendMode('ADD')
  t:SetWidth(130);t:SetHeight(28);t:SetPoint('CENTER',fx,'CENTER',0,0)
  animatedRays[i]=t
 end
 for i=1,24 do
  local t=fx:CreateTexture(nil,'OVERLAY');t:SetTexture('Interface\\Buttons\\WHITE8X8');t:SetBlendMode('ADD')
  t:SetWidth(i%4+2);t:SetHeight(i%4+2);t:SetPoint('CENTER',fx,'CENTER',0,0)
  streaks[i]=t
 end
 for i=1,8 do
  local t=fx:CreateTexture(nil,'OVERLAY');t:SetTexture(themePath..'fx_glow.tga');t:SetBlendMode('ADD');t:SetWidth(30);t:SetHeight(30);t:SetPoint('CENTER',fx,'CENTER',0,0);glows[i]=t
 end
end
local function play(kind)
 if db().sounds==false then return end
 local sound=(kind=='first' or kind=='record') and 'Sound\\Interface\\LevelUp.wav' or
  ((kind=='second' or kind=='third' or kind=='lose') and 'Sound\\Interface\\RaidWarning.wav' or 'Sound\\Interface\\MapPing.wav')
 PlaySoundFile(sound)
end
local function enabled(kind)
 if kind=='boost' or kind=='jump' or kind=='oil' then return db().boost~=false end
 if kind=='green' or kind=='red' then return db().rockets~=false end
 if kind=='record' then return db().personal~=false end
 return db().victory~=false
end
local function show(kind,force)
 kind=aliases[kind] or kind
 if not colors[kind] or (not force and not enabled(kind)) then return false end
 local now=GetTime()
 if not force and lastSeen[kind] and now-lastSeen[kind]<2.5 then return false end
 lastSeen[kind]=now;current=kind;started=now
 duration=(kind=='record' or kind=='first') and 4.5 or ((kind=='second' or kind=='third' or kind=='lose') and 3.8 or 2.9)
 local c=colors[kind]
 applyArt(kind)
 movingKind=kind
 movingObject:SetTexture(themePath..'moving_'..kind..'.tga')
 movingObject:SetVertexColor(1,1,1,1)
 flash:SetVertexColor(c[1],c[2],c[3],.4)
 burst:SetVertexColor(c[1],c[2],c[3],.7)
 for _,t in ipairs(glows) do t:SetVertexColor(c[1],c[2],c[3],1) end
 for i,t in ipairs(streaks) do t:SetVertexColor(c[1],c[2],c[3],1) end
 fx:SetScale(db().scale or 1);fx:SetAlpha(0);fx:Show();play(kind)
 return true
end
-- The legacy Racing/Illustrated texture comparison is no longer available.
local function textureTest() chat('Only Animated FX is available. Use /mrl fx demo to preview.') end
local function startDemo()
 queue={};for i,k in ipairs(names) do queue[i]=k end
 queueAt=GetTime();chat('Demo: 10 effects, one every 4 seconds. /mrl fx stop to cancel.')
end
-- Called by the race tracker only after it has calculated the actual personal-best result.
-- Never infer a record from db.history[1], which may belong to a previous race.
MirageRacewayFXFinish=function(place,isPersonalBest)
 if not fx then return end
 local kind=place==1 and 'first' or (place==2 and 'second' or (place==3 and 'third' or 'lose'))
 queue={}
 local displayed=show(kind,false)
 if isPersonalBest and enabled('record') then
  if displayed then
   queue[1]='record'
   queueAt=GetTime()+duration+0.3
  else
   show('record',false)
  end
 end
end
-- Explicit API called by the main slash handler; no competing slash registrations.
MirageRacewayFXCommand=function(arg)
 arg=string.lower(arg or ''):match('^%s*(.-)%s*$')
 if arg=='dodge' or arg=='rocketdodge' then
  if MirageRacewayDodgeBanner then MirageRacewayDodgeBanner();chat('Preview: rocket dodged') end
 elseif arg=='oilhit' or arg=='rockethit' then
  if MirageRacewayDebuffPreview then MirageRacewayDebuffPreview(arg);chat('Debuff preview: '..arg) end
 elseif arg=='jumpfailed' then
  if MirageRacewayJumpFailedBanner then MirageRacewayJumpFailedBanner() end
 elseif arg=='debuffdemo' then
  if MirageRacewayDebuffPreview then MirageRacewayDebuffPreview('oilhit') end
  debuffDemoNext=GetTime()+3.6
  chat('Debuff demo: oil slowdown, then rocket hit.')
 elseif arg=='texturetest' then textureTest()
 elseif arg=='demo' or arg=='all' then startDemo()
 elseif arg=='stop' then queue={};debuffDemoNext=nil;fx:Hide();chat('FX demo stopped.')
 elseif colors[aliases[arg] or arg] then queue={};show(arg,true);chat('Preview: '..arg)
 else chat('/mrl fx boost|jump|oil|green|red|first|second|third|lose|record|oilhit|rockethit|dodge|jumpfailed|debuffdemo|demo|stop|texturetest') end
end
local function spellKind(name)
 if type(name)~='string' then return end
 name=string.lower(name)
 if string.find(name,'red rocket',1,true) then return 'red' end
 if string.find(name,'green rocket',1,true) then return 'green' end
 if string.find(name,'oil spill',1,true) or string.find(name,'oil slick',1,true) then return 'oil' end
 if string.find(name,'rocket jump',1,true) or string.find(name,'jump',1,true) then return 'jump' end
 -- Accelerate is a vehicle action, not a picked-up speed bonus.
end
root:RegisterEvent('PLAYER_LOGIN')
root:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
root:RegisterEvent('CHAT_MSG_MONSTER_YELL');root:RegisterEvent('CHAT_MSG_MONSTER_SAY')
root:RegisterEvent('CHAT_MSG_SYSTEM');root:RegisterEvent('CHAT_MSG_RAID_BOSS_EMOTE')
root:RegisterEvent('CHAT_MSG_RAID_BOSS_WHISPER')
root:SetScript('OnEvent',function(self,event,...)
 if event=='PLAYER_LOGIN' then
  create();chat('v0.7.1 effects loaded. /mrl fx demo')
 elseif event=='COMBAT_LOG_EVENT_UNFILTERED' then
  -- Do not treat casts or self-applied vehicle auras as item pickups.
  -- Spell Debug remains available to identify actual pickup events.
  return
 else
  local msg=select(1,...)
  if type(msg)~='string' then return end
  if event=='CHAT_MSG_SYSTEM' then
   local low=string.lower(msg)
   if string.find(low,'you picked up',1,true) then
    if string.find(low,'nitrous',1,true) or string.find(low,'nutrous',1,true) then show('boost',false)
    elseif string.find(low,'green rocket',1,true) then show('green',false)
    elseif string.find(low,'red rocket',1,true) then show('red',false)
    elseif string.find(low,'tar puddle',1,true) or string.find(low,'oil',1,true) then show('oil',false)
    elseif string.find(low,'jump',1,true) then show('jump',false) end
   end
  end
 end
end)
root:SetScript('OnUpdate',function(self,dt)
 if not art then return end
 local now=GetTime()
 if debuffDemoNext and now>=debuffDemoNext then debuffDemoNext=nil;if MirageRacewayDebuffPreview then MirageRacewayDebuffPreview('rockethit') end end
 if #queue>0 and now>=queueAt then
  local nextKind=table.remove(queue,1);show(nextKind,true);queueAt=now+duration+0.3
 end
 if not fx:IsShown() then return end
 local quality=db().animationQuality or 'full'
 local particles=db().particleEffects~=false and quality~='off'
 local glowing=db().glowFlicker~=false and quality~='off'
 local elapsed=now-started;local remaining=duration-elapsed
 local animated=quality~='off'
 local animFactor=quality=='reduced' and .55 or 1
 if remaining<=0 then fx:Hide();current=nil;return end
 local col=colors[current] or colors.boost
 local alpha=math.min(1,elapsed/.24,remaining/.55)*(db().opacity or .9)
 fx:SetAlpha(alpha);fx:SetScale((db().scale or 1)*(quality=='off' and 1 or (1+.13*math.exp(-elapsed*5))))
 art:ClearAllPoints();art:SetPoint('CENTER',fx,'CENTER',(quality=='off' and 0 or math.sin(elapsed*17)*math.max(0,3-elapsed*7)),0)
 flash:SetAlpha(glowing and (math.max(0,1-elapsed*3)*.45+math.max(0,math.sin(elapsed*13))*.08) or 0)
 burst:SetAlpha(glowing and math.max(0,1-elapsed*1.8)*.48 or 0)
 burst:SetWidth(260+elapsed*110);burst:SetHeight(110+elapsed*36)
 art:SetAlpha(glowing and (.94+.06*math.sin(elapsed*11)) or 1)
 -- Third visual theme: moving rocket, outward streaks, spark shower and radial burst.
 -- Animated layers are hidden in the two original themes.
 animatedFlash:SetVertexColor(col[1],col[2],col[3],1)
 animatedFlash:SetAlpha(animated and glowing and math.max(0,(1-elapsed/1.4))*(.34+.25*math.abs(math.sin(elapsed*15))) or 0)
 animatedFlash:SetWidth(400+math.min(elapsed,1.4)*150)
 animatedBadge:SetVertexColor(col[1],col[2],col[3],1)
 animatedBadge:SetAlpha(false and animated and (current=='green' or current=='red' or current=='boost' or current=='jump') and math.min(1,elapsed*6)*math.min(1,remaining/.5) or 0)
 -- Independent themed object: rocket flight, bouncing cup/medals, compressing spring,
 -- tipping oil, racing stopwatch, flag flutter and turbo surges.
 movingObject:SetAlpha(animated and math.min(1,elapsed*5)*math.min(1,remaining/.45) or 0)
 if animated then
  local t=math.min(elapsed,2.2)
  local x,y,w,h=-220,0,170,112
  if current=='red' or current=='green' then
   x=-360+t*360*animFactor;y=18+math.sin(t*8)*10;w=200;h=100
  elseif current=='jump' then
   x=-214;y=-32+math.abs(math.sin(t*8))*38;w=155;h=math.max(45,115*(.72+.28*math.sin(t*12)))
  elseif current=='first' then
   x=-210;y=-110+math.min(t*240,135)+math.abs(math.sin(t*7))*18;w=155;h=125
  elseif current=='second' or current=='third' then
   x=-210;y=math.abs(math.sin(t*6))*22;w=135+math.abs(math.sin(t*5))*18;h=125
  elseif current=='oil' then
   x=-215+math.min(t*35,35);y=-12-math.min(t*17,17);w=175+math.min(t*40,40);h=105
  elseif current=='record' then
   x=-215;y=math.sin(t*13)*7;w=155+math.sin(t*9)*9;h=125
  elseif current=='lose' then
   x=-205;y=math.sin(t*8)*12;w=165+math.sin(t*8)*12;h=120
  else
   x=-210+math.sin(t*16)*12;y=math.sin(t*11)*6;w=170+math.sin(t*12)*16;h=105
  end
  movingObject:SetWidth(w);movingObject:SetHeight(h)
  movingObject:ClearAllPoints();movingObject:SetPoint('CENTER',fx,'CENTER',x,y)
 end
 animatedBadge:ClearAllPoints()
 animatedBadge:SetPoint('CENTER',fx,'CENTER',-310+math.min(elapsed,1.6)*350*animFactor,25+math.sin(elapsed*9)*9)
 for i,t in ipairs(animatedParts) do
  local phase=i*2.39996
  local progress=(elapsed*(.65+(i%5)*.13)+i*.071)%1
  local radius=(20+progress*300)*animFactor
  local x=math.cos(phase)*radius
  local y=math.sin(phase)*radius*.34
  t:ClearAllPoints();t:SetPoint('CENTER',fx,'CENTER',x,y)
  local size=7+(i%5)*4+(1-progress)*9;t:SetWidth(size);t:SetHeight(size)
  t:SetVertexColor(col[1],col[2],col[3],1)
  t:SetAlpha(animated and particles and (1-progress)*math.min(1,elapsed*5)*math.min(1,remaining/.5)*.95 or 0)
 end
 for i,t in ipairs(animatedRays) do
  local direction=i%2==0 and 1 or -1
  local move=((elapsed*160*animFactor+i*61)%560)-280
  t:ClearAllPoints();t:SetPoint('CENTER',fx,'CENTER',move,(-3+i)*14+math.sin(elapsed*5+i)*5)
  t:SetVertexColor(col[1],col[2],col[3],1)
  t:SetAlpha(animated and glowing and math.min(1,elapsed*4)*math.min(1,remaining/.4)*(.15+.16*math.abs(math.sin(elapsed*10+i))) or 0)
 end
 for i,t in ipairs(streaks) do
  local phase=(elapsed*165+i*43)%490
  t:ClearAllPoints();t:SetPoint('CENTER',fx,'CENTER',phase-245,math.sin(i*4.2)*46)
  t:SetAlpha(particles and math.min(.8,remaining/.7)*math.min(1,elapsed*3) or 0)
 end
 for i,t in ipairs(glows) do
  local theta=i*2.39996+elapsed*(quality=='full' and 2.2 or 1.1)
  local radius=45+((i*37+elapsed*65)%175)
  t:ClearAllPoints();t:SetPoint('CENTER',fx,'CENTER',math.cos(theta)*radius,math.sin(theta)*radius*.28)
  local sz=16+(i%4)*10+math.sin(elapsed*9+i)*5;t:SetWidth(sz);t:SetHeight(sz)
  t:SetAlpha(particles and glowing and math.max(0,math.sin(elapsed*5+i))*math.min(1,remaining/.7)*.7 or 0)
 end
end)

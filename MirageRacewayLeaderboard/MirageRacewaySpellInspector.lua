-- Mirage Raceway Spell Inspector v0.8.35. WoW 3.3.5a / Interface 30300.
-- Read-only diagnostics. No game files, spells, or race statistics are modified.
local active=false
local events={}
local maxEvents=2000
local sessionID=nil
local sessionStart=0
local captureCount=0
local lastAutoSave=0
local function store()
 MirageRacewayInspectorLogs=MirageRacewayInspectorLogs or {version=1,sessions={}}
 local data=MirageRacewayInspectorLogs
 if type(data.sessions)~='table' then data.sessions={} end
 return data
end
-- Initialize the SavedVariable as soon as this Lua file is executed.
-- This makes it possible to distinguish a missing module from an empty log.
store()
local function openSession()
 local data=store()
 local session={started=date('%Y-%m-%d %H:%M:%S'),character=UnitName('player') or '?',realm=GetRealmName() or '?',events={},closed=false}
 data.sessions[#data.sessions+1]=session
 while #data.sessions>8 do table.remove(data.sessions,1) end
 sessionID=#data.sessions
 sessionStart=GetTime()
 captureCount=0
 return session
end
local function currentSession()
 local data=store()
 local session=data.sessions[sessionID or 0]
 if not session or session.closed then return openSession() end
 return session
end
local function closeSession()
 if not sessionID then return end
 local session=store().sessions[sessionID]
 if session then session.closed=true;session.ended=date('%Y-%m-%d %H:%M:%S') end
 sessionID=nil
end
local auraHistory={}
local pending={}
local watchAuras=true
local lastSnapshot=0
local ownGUIDs={}
local tracked={ [87509]=true,[87516]=true,[87520]=true,[87521]=true,[87523]=true,[87525]=true,[87527]=true,[87529]=true,[87531]=true }
local function say(s)
 if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cff66ddff[MRL Inspector]|r '..tostring(s)) end
end
local function idInfo(id)
 id=tonumber(id)
 if not id or id<1 or id>10000000 then say('Enter a valid spell ID. Example: /mrl inspect 87516');return end
 local name,rank,icon,castTime,minRange,maxRange=GetSpellInfo(id)
 say('Spell ID '..id..': '..tostring(name or 'UNKNOWN (client has no spell info)'))
 say('Rank='..tostring(rank)..' Icon='..tostring(icon)..' Cast(ms)='..tostring(castTime)..' Range='..tostring(minRange)..'-'..tostring(maxRange))
end
local function auraScan(unit)
 if not UnitExists(unit) then say(unit..': not available');return end
 say(unit..' GUID='..tostring(UnitGUID(unit)))
 local count=0
 for _,kind in ipairs({'BUFF','DEBUFF'}) do
  for i=1,40 do
   local name,rank,icon,stacks,dispel,duration,expires,caster,stealable,consolidate,id
   if kind=='BUFF' then name,rank,icon,stacks,dispel,duration,expires,caster,stealable,consolidate,id=UnitBuff(unit,i)
   else name,rank,icon,stacks,dispel,duration,expires,caster,stealable,consolidate,id=UnitDebuff(unit,i) end
   if not name then break end
   count=count+1
   say(kind..' ['..i..'] ID='..tostring(id)..' '..name..' stacks='..tostring(stacks)..' duration='..tostring(duration)..' caster='..tostring(caster))
  end
 end
 if count==0 then say(unit..': no visible auras') end
end
local function refreshOwn()
 for _,u in ipairs({'player','vehicle','pet'}) do
  if UnitExists(u) then local g=UnitGUID(u);if g then ownGUIDs[g]=GetTime() end end
 end
 for g,t in pairs(ownGUIDs) do if GetTime()-t>15 then ownGUIDs[g]=nil end end
end
local function own(g)
 return g and (g==UnitGUID('player') or g==UnitGUID('vehicle') or g==UnitGUID('pet') or ownGUIDs[g]~=nil)
end
local function short(g)
 return g and tostring(g) or '-'
end
local function save(s)
 local line=string.format('[%s +%.3fs] %s',date('%Y-%m-%d %H:%M:%S'),GetTime()-sessionStart,s)
 events[#events+1]=line
 if #events>300 then table.remove(events,1) end
 local session=currentSession()
 session.events[#session.events+1]=line
 if #session.events>maxEvents then table.remove(session.events,1) end
 captureCount=captureCount+1
 -- Avoid flooding chat during high-frequency combat log activity.
 if captureCount<=15 then say(line) end
end
-- The aura snapshot is a client observation, not proof of server-side movement/speed changes.
local function snapshot(unit)
 local result={}
 if not UnitExists(unit) then return result,nil end
 for _,kind in ipairs({'BUFF','DEBUFF'}) do
  for i=1,40 do
   local n,r,tex,stacks,dispel,duration,expires,caster,stealable,consolidate,id
   if kind=='BUFF' then n,r,tex,stacks,dispel,duration,expires,caster,stealable,consolidate,id=UnitBuff(unit,i)
   else n,r,tex,stacks,dispel,duration,expires,caster,stealable,consolidate,id=UnitDebuff(unit,i) end
   if not n then break end
   if id and (tracked[id] or string.find(string.lower(n),'rocket',1,true) or string.find(string.lower(n),'jump',1,true) or string.find(string.lower(n),'puddle',1,true) or string.find(string.lower(n),'nitrous',1,true) or string.find(string.lower(n),'slow',1,true)) then
    result[kind..':'..id]={id=id,name=n,stacks=stacks or 0,duration=duration or 0,expires=expires or 0,kind=kind}
   end
  end
 end
 return result,UnitGUID(unit)
end
local function compareAuras(reason,force)
 if not active or not watchAuras then return end
 refreshOwn()
 for _,unit in ipairs({'player','vehicle','pet'}) do
  local current,guid=snapshot(unit)
  local previous=auraHistory[unit]
  if not previous or previous.guid~=guid then
   auraHistory[unit]={guid=guid,auras=current}
   if guid then save('AURA BASELINE '..unit..' GUID='..short(guid)..' ('..reason..')') end
  else
   for key,v in pairs(current) do
    if not previous.auras[key] then save('AURA + '..unit..' '..v.kind..' ID='..v.id..' '..v.name..' stacks='..v.stacks..' dur='..string.format('%.1f',v.duration)..' ('..reason..')')
    elseif previous.auras[key].stacks~=v.stacks then save('AURA STACK '..unit..' ID='..v.id..' '..previous.auras[key].stacks..'->'..v.stacks) end
   end
   for key,v in pairs(previous.auras) do if not current[key] then save('AURA - '..unit..' '..v.kind..' ID='..v.id..' '..v.name..' ('..reason..')') end end
   previous.auras=current
  end
 end
end
local function queueSnapshot(reason)
 pending[#pending+1]={at=GetTime()+0.20,reason=reason}
 if #pending>12 then table.remove(pending,1) end
end
local frame=CreateFrame('Frame')
frame:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
frame:RegisterEvent('UNIT_AURA')
frame:RegisterEvent('UNIT_ENTERED_VEHICLE')
frame:RegisterEvent('UNIT_EXITED_VEHICLE')
frame:RegisterEvent('PLAYER_ENTERING_WORLD')
frame:SetScript('OnEvent',function(self,event,...)
 if not active then return end
 if event~='COMBAT_LOG_EVENT_UNFILTERED' then
  if event=='UNIT_AURA' then local unit=...;if unit=='player' or unit=='vehicle' or unit=='pet' then compareAuras('UNIT_AURA') end
  else refreshOwn();auraHistory={};compareAuras(event) end
  return
 end
 refreshOwn()
 local timestamp,sub,srcGUID,srcName,srcFlags,dstGUID,dstName,dstFlags,spellID,spellName,spellSchool,extra1,extra2=...
 if type(spellID)~='number' then return end
 local low=type(spellName)=='string' and string.lower(spellName) or ''
 if not tracked[spellID] and not string.find(low,'rocket',1,true) and not string.find(low,'jump',1,true) and not string.find(low,'puddle',1,true) and not string.find(low,'nitrous',1,true) then return end
 local msg=tostring(sub)..' ID='..spellID..' '..tostring(spellName)..' SRC='..short(srcGUID)..(own(srcGUID) and '[OWN]' or '')..' DST='..short(dstGUID)..(own(dstGUID) and '[OWN]' or '')
 if string.find(tostring(sub),'MISSED',1,true) then msg=msg..' missType='..tostring(extra1)..' extra2='..tostring(extra2) end
 save(msg)
 if own(srcGUID) or own(dstGUID) then queueSnapshot(sub..' '..spellID) end
end)
frame:SetScript('OnUpdate',function(self,elapsed)
 if not active then return end
 lastSnapshot=lastSnapshot+elapsed
 if lastSnapshot>=0.5 then lastSnapshot=0;compareAuras('poll') end
 local now=GetTime()
 for i=#pending,1,-1 do
  if now>=pending[i].at then local why=pending[i].reason;table.remove(pending,i);compareAuras('after '..why) end
 end
end)
function MirageRacewayInspectorCommand(arg)
 arg=tostring(arg or ''):match('^%s*(.-)%s*$')
 local lower=string.lower(arg)
 if lower=='on' then
  if active then say('Recording already ON.');return end
  openSession();active=true; auraHistory={};pending={};refreshOwn();compareAuras('capture started')
  say('Persistent recording ON. Session '..sessionID..'. Up to 2000 events; use /mrl inspect save before /reload.')
 elseif lower=='off' or lower=='save' then
  active=false;closeSession()
  say('Session closed. Use /reload or log out to write WTF/Account/<account>/SavedVariables/MirageRacewayLeaderboard.lua to disk.')
 elseif lower=='status' then
  local data=store();say('Inspector module v0.8.35 loaded; SavedVariables table='..tostring(type(MirageRacewayInspectorLogs))..'.')
  say('Capture '..(active and 'ON' or 'OFF')..', aura watch '..(watchAuras and 'ON' or 'OFF')..', session events '..captureCount..', sessions '..#data.sessions..', limit '..maxEvents..' per session.')
 elseif lower=='watch on' then watchAuras=true;auraHistory={};say('Own vehicle aura watch ON.')
 elseif lower=='watch off' then watchAuras=false;say('Own vehicle aura watch OFF.')
 elseif lower=='snapshot' then auraScan('player');auraScan('vehicle');auraScan('pet');compareAuras('manual');if active then save('MANUAL SNAPSHOT requested') end
 elseif lower=='clear' then
  events={};MirageRacewayInspectorLogs={version=1,sessions={}};sessionID=nil
  if active then openSession() end
  say('Persistent Inspector sessions cleared (will be written on next /reload or logout).')
 elseif lower=='log' then
  say('Last '..math.min(25,#events)..' of '..#events..' events:')
  for i=math.max(1,#events-24),#events do say(events[i]) end
 elseif lower=='auras' then
  auraScan('player');auraScan('vehicle');auraScan('pet');auraScan('target')
 elseif lower:match('^auras%s+') then
  local unit=lower:match('^auras%s+(%a+)$')
  if unit=='player' or unit=='vehicle' or unit=='pet' or unit=='target' then auraScan(unit) else say('Allowed units: player, vehicle, pet, target') end
 elseif lower:match('^track%s+%d+$') then
  local id=tonumber(lower:match('%d+'));tracked[id]=true;say('Now tracking ID '..id)
 elseif lower:match('^untrack%s+%d+$') then
  local id=tonumber(lower:match('%d+'));tracked[id]=nil;say('Stopped tracking ID '..id)
 elseif lower:match('^%d+$') then idInfo(lower)
 else
  say('Commands: /mrl inspect <spellID> | on | off | save | status | log | clear | snapshot | watch on/off')
  say('/mrl inspect auras [player|vehicle|pet|target] | track <ID> | untrack <ID>')
  say('Suggested IDs: 87509 87516 87520 87521 87525 87531')
 end
end

-- Persist sessions on normal client logout/reload; SavedVariables are written by WoW itself.
local persistFrame=CreateFrame('Frame')
persistFrame:RegisterEvent('PLAYER_LOGIN')
persistFrame:RegisterEvent('PLAYER_LOGOUT')
persistFrame:SetScript('OnEvent',function(self,event)
 if event=='PLAYER_LOGIN' then store();say('Inspector v0.8.35 ready. /mrl inspect status to verify persistent logging.')
 elseif event=='PLAYER_LOGOUT' then if active then active=false;closeSession() end end
end)

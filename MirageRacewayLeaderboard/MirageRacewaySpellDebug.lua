-- Mirage Raceway Spell Debug: temporary local diagnostics, WoW 3.3.5a.
local enabled=false
local entries={}
local maxEntries=180
local watched={[87531]=true,[26334]=true,[26336]=true,[87523]=true,[87525]=true,[87509]=true}
local function say(msg)
 if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cff65d9ff[MRL Spell Debug]|r '..tostring(msg)) end
end
local function shortGUID(guid)
 if not guid then return '-' end
 return tostring(guid):sub(-12)
end
local function myGUID(guid)
 if not guid then return false end
 return guid==UnitGUID('player') or guid==UnitGUID('vehicle') or guid==UnitGUID('pet')
end
local function add(msg)
 local entry=string.format('[%.1f] %s',GetTime(),msg)
 entries[#entries+1]=entry
 if #entries>maxEntries then table.remove(entries,1) end
 if enabled then say(entry) end
end
local frame=CreateFrame('Frame')
frame:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
frame:RegisterEvent('CHAT_MSG_SYSTEM')
frame:RegisterEvent('UNIT_AURA')
local lastAuras={}
local function scanAuras(unit)
 if not UnitExists(unit) then return end
 local key=unit
 local current={}
 for i=1,40 do
  local name,rank,icon,count,debuffType,duration,expirationTime,caster,stealable,shouldConsolidate,spellId=UnitBuff(unit,i)
  if not name then break end
  if watched[spellId] then current[spellId]='BUFF' end
 end
 for i=1,40 do
  local name,rank,icon,count,debuffType,duration,expirationTime,caster,stealable,shouldConsolidate,spellId=UnitDebuff(unit,i)
  if not name then break end
  if watched[spellId] then current[spellId]='DEBUFF' end
 end
 local previous=lastAuras[key] or {}
 for id,kind in pairs(current) do if not previous[id] then add('AURA GAIN '..unit..' '..kind..' '..id..' '..(GetSpellInfo(id) or '?')) end end
 for id,kind in pairs(previous) do if not current[id] then add('AURA LOST '..unit..' '..kind..' '..id..' '..(GetSpellInfo(id) or '?')) end end
 lastAuras[key]=current
end
frame:SetScript('OnEvent',function(self,event,...)
 if not enabled then return end
 if event=='COMBAT_LOG_EVENT_UNFILTERED' then
  -- 3.3.5a passes combat log fields as event arguments (no CombatLogGetCurrentEventInfo).
  local timestamp,subevent,sourceGUID,sourceName,sourceFlags,destGUID,destName,destFlags,spellId,spellName,spellSchool,extra=...
  if type(spellId)~='number' then return end
  local lower=type(spellName)=='string' and string.lower(spellName) or ''
  local relevant=watched[spellId] or (string.find(lower,'rocket',1,true) or string.find(lower,'puddle',1,true) or string.find(lower,'nitrous',1,true) or string.find(lower,'jump',1,true) or string.find(lower,'powerup',1,true))
  if not relevant then return end
  local srcOwn=myGUID(sourceGUID) and ' [MY SOURCE]' or ''
  local dstOwn=myGUID(destGUID) and ' [MY TARGET]' or ''
  local info=string.format('%s ID=%d %s | SRC=%s(%s)%s -> DST=%s(%s)%s',tostring(subevent),spellId,tostring(spellName or '?'),tostring(sourceName or '?'),shortGUID(sourceGUID),srcOwn,tostring(destName or '?'),shortGUID(destGUID),dstOwn)
  if subevent=='SPELL_MISSED' or subevent=='SPELL_AURA_BROKEN_SPELL' then info=info..' | EXTRA='..tostring(extra) end
  add(info)
 elseif event=='CHAT_MSG_SYSTEM' then
  local msg=select(1,...)
  if type(msg)=='string' then
   local low=string.lower(msg)
   if string.find(low,'picked up',1,true) or string.find(low,'rocket',1,true) or string.find(low,'puddle',1,true) or string.find(low,'nitrous',1,true) then add('SYSTEM '..msg) end
  end
 elseif event=='UNIT_AURA' then
  local unit=...
  if unit=='player' or unit=='vehicle' or unit=='pet' then scanAuras(unit) end
 end
end)
MirageRacewaySpellDebugCommand=function(arg)
 arg=string.lower(tostring(arg or '')):match('^%s*(.-)%s*$')
 if arg=='on' or (arg=='toggle' and not enabled) then
  enabled=true;lastAuras={};say('ON. Pick up ONE bonus, then use it. /mrl spell show prints saved events.');scanAuras('player');scanAuras('vehicle');scanAuras('pet')
 elseif arg=='off' or (arg=='toggle' and enabled) then
  enabled=false;say('OFF. Captured '..#entries..' events; /mrl spell show to review.')
 elseif arg=='clear' then entries={};lastAuras={};say('Log cleared.')
 elseif arg=='show' then
  say('Saved events: '..#entries..' (showing last 30).')
  for i=math.max(1,#entries-29),#entries do say(entries[i]) end
 elseif arg=='status' then say((enabled and 'ON' or 'OFF')..', saved '..#entries..' events.')
 else say('Commands: /mrl spell on | off | toggle | show | clear | status') end
end

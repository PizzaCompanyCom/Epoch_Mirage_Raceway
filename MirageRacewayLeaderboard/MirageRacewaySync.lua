-- Mirage Raceway Best Time 1.1 / Epoch Reborn / Lua 5.1
-- All official data is held by Belerda. Clients keep only personal records and RAM snapshots.
local S={cache={},subscribers={},pending={},selected=nil,seq=0,active=nil,elapsed=0,heartbeat=0,versionCheck=0,masterOnline=false,session=tostring(math.floor(GetTime()*1000)),requests={},viewOpen=false}
MirageRacewaySync=S
local PREFIX='MRBT11'
-- Suppress only the expected offline-whisper error from our own Master probes.
-- Do not suppress unrelated server/system messages or messages from other addons.
local lastMasterWhisper=-1000
local masterOfflineUntil=0
local lastManualRefresh=-1000
local initialFetched={}
local AUTO_CHECK_SECONDS=7200
local function masterUnavailable(message)
 local m=string.lower(message or '')
 return m:find('belerda',1,true) and (m:find('no player named',1,true) or m:find('not online',1,true) or m:find('not found',1,true) or m:find('currently playing',1,true))
end
if type(ChatFrame_AddMessageEventFilter)=='function' then
 ChatFrame_AddMessageEventFilter('CHAT_MSG_SYSTEM',function(_,_,message)
  if GetTime()-lastMasterWhisper<12 and masterUnavailable(message) then
   masterOfflineUntil=GetTime()+AUTO_CHECK_SECONDS
   S.masterOnline=false
   return true
  end
  return false
 end)
end
local function DB() return MirageRacewayDB or {} end
local function name() return UnitName('player') or '' end
local function master() return string.lower(name())=='belerda' end
local function realm() return string.lower((GetRealmName and GetRealmName()) or 'unknown') end
local function key(n) return realm()..':'..string.lower(n or '') end
local function millis(t) if type(t)~='number' or t<=0 or t~=t or t>1e9 then return nil end return math.floor(t*1000+.5) end
local function fmt(ms) if not ms then return '--:--.---' end local sec=math.floor(ms/1000);return string.format('%02d:%02d.%03d',math.floor(sec/60),sec%60,ms%1000) end
S.Format=fmt
local function valid(ms) return type(ms)=='number' and ms==math.floor(ms) and ms>0 and ms<1000000000000 end
local function serverYear()
 -- CalendarGetDate is provided by the WotLK calendar API; no local-clock fallback.
 if type(CalendarGetDate)~='function' then return nil end
 local ok,weekday,month,day,year=pcall(CalendarGetDate)
 if not ok or type(year)~='number' or type(month)~='number' or type(day)~='number' then return nil end
 if year<2026 or year>2100 or month<1 or month>12 or day<1 or day>31 then return nil end
 return year
end
S.ServerYear=serverYear
-- All client-to-Master protocols share one offline detector and one error filter.
function S:SendToMaster(prefix,msg,force)
 if type(SendAddonMessage)~='function' then return false end
 if master() then return false end
 if not force and GetTime()<masterOfflineUntil then return false end
 lastMasterWhisper=GetTime()
 SendAddonMessage(prefix,msg,'WHISPER','Belerda')
 return true
end
function S:MasterOffline() return GetTime()<masterOfflineUntil end
function S:MasterAvailable() masterOfflineUntil=0;self.masterOnline=true end
local function send(msg,to,force)
 if type(SendAddonMessage)~='function' then return false end
 if to then SendAddonMessage(PREFIX,msg,'WHISPER',to);return true end
 return S:SendToMaster(PREFIX,msg,force)
end
local function fields(msg)
 local a={};for x in string.gmatch(msg..'|','(.-)|') do a[#a+1]=x end;return a
end
local function id() S.seq=S.seq+1;return name()..'-'..S.session..'-'..S.seq end
local function personal()
 local d=DB();d.btPersonal=d.btPersonal or {all=nil,seasons={},generation={},pending=nil,reset=nil}
 local p=d.btPersonal
 p.seasons=p.seasons or {};p.generation=p.generation or {}
 if not p.migrated then
  local old=d.records and d.records[name()]
  if old and type(old.best)=='number' and old.best>0 then p.all=math.floor(old.best*1000+.5) end
  p.migrated=true
 end
 return p
end
local function official()
 local d=DB();d.btMaster=d.btMaster or {seasons={},seen={},requests={}};return d.btMaster
end
local function validateMaster()
 local m=official()
 if type(m.seasons)~='table' or type(m.requests)~='table' then return false end
 for year,season in pairs(m.seasons) do
  if type(year)~='number' or type(season)~='table' or type(season.racers)~='table' then return false end
  for k,r in pairs(season.racers) do
   if type(k)~='string' or type(r)~='table' or type(r.name)~='string' then return false end
   if r.best~=nil and not valid(r.best) then return false end
   if r.generation~=nil and (type(r.generation)~='number' or r.generation<0) then return false end
  end
 end
 return true
end
local function seasonData(y)
 local m=official();m.seasons[y]=m.seasons[y] or {racers={},version=0};return m.seasons[y]
end
local function racer(y,n)
 local s=seasonData(y);local k=key(n);s.racers[k]=s.racers[k] or {name=n,generation=0};return s.racers[k],s
end
local function top(y)
 local result={};local s=official().seasons[y]
 if s then for _,r in pairs(s.racers) do if valid(r.best) and not r.excluded then result[#result+1]={name=r.name,best=r.best,faction=r.faction,class=r.class,race=r.race,sex=r.sex} end end end
 table.sort(result,function(a,b) if a.best==b.best then return string.lower(a.name)<string.lower(b.name) end return a.best<b.best end)
 while #result>50 do table.remove(result) end
 local rank=0;local previous=nil
 for i,r in ipairs(result) do if r.best~=previous then rank=i end;r.rank=rank;previous=r.best end
 return result
end
local function notify()
 if type(MirageRacewayBestTimeRefresh)=='function' then MirageRacewayBestTimeRefresh() end
end
local outbound={}
local function queue(msg,to) outbound[#outbound+1]={msg=msg,to=to} end
local function encode(y,token,to)
 local s=official().seasons[y];local out={'DATA',token,tostring(y),S.session,tostring(s and s.version or 0)}
 local list=top(y)
 -- One addon message per row; bounded packet length; completion only after END.
 queue(table.concat(out,'|'),to)
 for i,r in ipairs(list) do queue(table.concat({'ROW',token,tostring(i),r.name,tostring(r.best),tostring(r.rank),r.faction or '',r.class or '',r.race or '',r.sex or ''},'|'),to) end
 queue('END|'..token..'|'..#list,to)
end
local function push(y)
 local s=seasonData(y);s.version=s.version+1
 -- The Master must refresh its own Top 50 snapshot after official DB changes.
 -- Otherwise it keeps displaying the old cache while clients get a CHANGED event.
 if master() then S.cache[y]={rows=top(y),version=s.version,session=S.session} end
 for who in pairs(S.subscribers) do send('CHANGED|'..tostring(y)..'|'..tostring(s.version)..'|'..S.session,who) end
 notify()
end
local function ack(who,token,status,y,g) send(table.concat({'ACK',token,status,tostring(y),tostring(g)},'|'),who) end
local function onMaster(sender,a)
 local op=a[1];local y=serverYear()
 if S.dbValid==false then return end
 if op=='HELLO' then send('HELLOACK|'..tostring(y or 0)..'|'..S.session,sender)
 elseif op=='SUB' or op=='GET' then
  local sy=tonumber(a[2]);local token=a[3]
  if not y or not sy or sy>y or sy<2026 or not token then return end
  if op=='SUB' and sy==y then S.subscribers[sender]=true end
  encode(sy,token,sender)
 elseif op=='UNSUB' then S.subscribers[sender]=nil
 elseif op=='RESULT' then
  local sy,gen,token,ms=tonumber(a[2]),tonumber(a[3]),a[4],tonumber(a[5]);if not token then return end
  if not y then ack(sender,token,'TEMPORARY_UNAVAILABLE',sy or 0,gen or 0);return end
  if sy~=y then ack(sender,token,'OLD_SEASON',sy or 0,gen or 0);return end
  if not valid(ms) or not gen or gen<0 or gen~=math.floor(gen) then ack(sender,token,'INVALID_RESULT',sy,gen or 0);return end
  local r=racer(sy,sender)
  if a[6]=='Alliance' or a[6]=='Horde' then r.faction=a[6] end
  if a[7] and a[7]~='' then r.class=a[7] end
  if a[8] and a[8]~='' then r.race=a[8] end
  if tonumber(a[9])==2 or tonumber(a[9])==3 then r.sex=tonumber(a[9]) end
  if gen<r.generation then ack(sender,token,'OLD_GENERATION',sy,gen);return end
  if gen>r.generation then ack(sender,token,'OLD_GENERATION',sy,gen);return end
  if r.locked then ack(sender,token,'LOCKED',sy,gen);return end
  if not r.best or ms<r.best then r.best=ms;ack(sender,token,'ACCEPTED',sy,gen);push(sy)
  else ack(sender,token,'NO_IMPROVEMENT',sy,gen) end
 elseif op=='RESET' then
  local sy,gen,token=tonumber(a[2]),tonumber(a[3]),a[4];if not token then return end
  if not y then ack(sender,token,'TEMPORARY_UNAVAILABLE',sy or 0,gen or 0);return end
  if sy~=y then ack(sender,token,'OLD_SEASON',sy or 0,gen or 0);return end
  if not gen or gen<0 or gen~=math.floor(gen) then ack(sender,token,'INVALID_RESULT',sy,0);return end
  local r=racer(sy,sender)
  if gen<=r.generation then ack(sender,token,'OLD_GENERATION',sy,gen);return end
  if r.locked then official().requests[key(sender)]={name=sender,year=sy,generation=gen,token=token};notify();return end
  r.generation=gen;r.best=nil;ack(sender,token,'ACCEPTED',sy,gen);push(sy)
 end
end
local function onClient(sender,a)
 if string.lower(sender or '')~='belerda' then return end
 S:MasterAvailable()
 local op=a[1]
 if op=='HELLOACK' then masterOfflineUntil=0;S.masterOnline=true;S.masterSession=a[3];S:Resync()
 elseif op=='ACK' then
  local p=personal();local token,status,sy,gen=a[2],a[3],tonumber(a[4]),tonumber(a[5]);local pending=p.pending
  if pending and pending.id==token and pending.year==sy and pending.generation==gen then
   if status=='ACCEPTED' or status=='NO_IMPROVEMENT' or status=='LOCKED' or status=='OLD_SEASON' or status=='OLD_GENERATION' or status=='INVALID_RESULT' then p.pending=nil end
  end
  if p.reset and p.reset.id==token and p.reset.year==sy and p.reset.generation==gen then
   if status~='TEMPORARY_UNAVAILABLE' then p.reset=nil;if p.pending and status=='ACCEPTED' then S:Resync() end end
  end
 elseif op=='DATA' then
  local token=a[2];if not S.active or token~=S.active.id or tonumber(a[3])~=S.active.year then return end
  S.active.rows={};S.active.session=a[4];S.active.version=tonumber(a[5]) or 0
 elseif op=='ROW' then
  local q=S.active;if not q or q.id~=a[2] or not q.rows then return end
  local index=tonumber(a[3]);local ms=tonumber(a[5]);if index and index>=1 and index<=50 and valid(ms) then q.rows[index]={name=a[4],best=ms,rank=tonumber(a[6]) or index,faction=a[7],class=a[8],race=a[9],sex=tonumber(a[10])} end
 elseif op=='END' then
  local q=S.active;if not q or q.id~=a[2] or not q.rows then return end
  local count=tonumber(a[3]);if not count or count<0 or count>50 then return end
  local t={};for i=1,count do if not q.rows[i] then return end;t[i]=q.rows[i] end
  S.cache[q.year]={rows=t,version=q.version,session=q.session};S.active=nil;notify()
 elseif op=='CHANGED' then
  if S.viewOpen and S.selected==tonumber(a[2]) and S.selected==serverYear() then S:Request(S.selected,true) end
 end
end
function S:Request(year,subscribe,force)
 if not year then return end
 if not master() and self.selected==serverYear() and year~=self.selected then send('UNSUB') end
 if self.active then self.active=nil end
 self.selected=year;self.seq=self.seq+1
 if master() then self.cache[year]={rows=top(year),version=(official().seasons[year] or {}).version or 0,session=self.session};self.active=nil;notify();return end
 if not force and self:MasterOffline() then self.active=nil;notify();return end
 local token=id();local msg=(subscribe and 'SUB|' or 'GET|')..year..'|'..token
 if send(msg,nil,force) then self.active={id=token,year=year,age=0,attempt=1,subscribe=subscribe} else self.active=nil end
 notify()
end
function S:Open(year)
 self.viewOpen=true;self.selected=year
 -- Switching tabs or revisiting a season uses the current in-memory snapshot.
 -- The initial discovery and explicit Refresh handle fetching.
 if master() then self:Request(year,year==serverYear())
 elseif not initialFetched[year] and not self.cache[year] then
  initialFetched[year]=true;self:Request(year,year==serverYear())
 else notify() end
end
function S:RefreshNow(year)
 year=year or self.selected or serverYear()
 if not year then return false end
 if not master() and GetTime()-lastManualRefresh<10 then return false end
 lastManualRefresh=GetTime()
 self:Request(year,year==serverYear(),true)
 return true
end
function S:Close()
 self.viewOpen=false;self.active=nil;if not master() then send('UNSUB') end
end
function S:Resync()
 local p=personal();local y=serverYear()
 if y then
  if p.pending and p.pending.year~=y then p.pending=nil end
  if p.reset and p.reset.year~=y then p.reset=nil end
 end
 if not p.pending and not p.reset and y and p.seasons[y] then
  p.generation[y]=p.generation[y] or 0
  p.pending={year=y,generation=p.generation[y],best=p.seasons[y],id=id()}
 end
 if p.reset then
  local msg=table.concat({'RESET',p.reset.year,p.reset.generation,p.reset.id},'|')
  if master() then onMaster(name(),fields(msg)) else send(msg) end
 elseif p.pending then
  local msg=table.concat({'RESULT',p.pending.year,p.pending.generation,p.pending.id,p.pending.best,UnitFactionGroup('player') or '',select(2,UnitClass('player')) or '',select(2,UnitRace('player')) or '',UnitSex('player') or ''},'|')
  if master() then if serverYear() then onMaster(name(),fields(msg));p.pending=nil end else send(msg) end
 end
 if self.viewOpen and self.selected and not self.cache[self.selected] and not self:MasterOffline() then self:Request(self.selected,self.selected==y) end
end
function S:Finish(seconds)
 if master() and S.dbValid==false then return end
 local ms=millis(seconds);if not ms then return end
 local p=personal();if not p.all or ms<p.all then p.all=ms end
 local y=serverYear();if not y then notify();return end
 if not p.seasons[y] or ms<p.seasons[y] then
  p.seasons[y]=ms;p.generation[y]=p.generation[y] or 0
  p.pending={year=y,generation=p.generation[y],best=ms,id=id()}
  if not p.reset then self:Resync() end
 end
 notify()
end
function S:Reset()
 if master() and S.dbValid==false then return end
 local y=serverYear();if not y then return end
 local p=personal();p.seasons[y]=nil;p.generation[y]=(p.generation[y] or 0)+1;p.pending=nil
 p.reset={year=y,generation=p.generation[y],id=id()};self:Resync();notify()
end
function S:LastSeasonBest()
 local y=serverYear();if not y then return nil end
 local p=personal()
 -- One previous season only. Never substitute an All-Time result.
 return p.seasons[y-1] or (p.lastSeasonYear==y-1 and p.lastSeasonBest or nil)
end
function S:Personal() return personal() end
function S:IsMaster() return master() end
function S:MasterData() if master() then return official() end end
function S:Admin(action,n,ms)
 if not master() or S.dbValid==false then return false end
 local y=serverYear();if not y then return false end
 local r=racer(y,n);local changed=false
 if action=='EDIT' and valid(ms) then r.best=ms;r.locked=true;changed=true
 elseif action=='LOCK' then r.locked=true;changed=true
 elseif action=='UNLOCK' then r.locked=false;changed=true
 elseif action=='EXCLUDE' then r.excluded=true;changed=true
 elseif action=='INCLUDE' then r.excluded=nil;changed=true
 elseif action=='APPROVE' or action=='REJECT' then
  local req=official().requests[key(n)];if not req or req.year~=y then return false end
  if action=='APPROVE' then r.best=nil;r.locked=false;r.generation=req.generation;changed=true end
  ack(req.name,req.token,action=='APPROVE' and 'ACCEPTED' or 'LOCKED',req.year,req.generation)
  official().requests[key(n)]=nil
 end
 if changed then push(y) else notify() end
 return true
end
local e=CreateFrame('Frame');e:RegisterEvent('CHAT_MSG_ADDON');e:RegisterEvent('PLAYER_LOGIN')
e:SetScript('OnEvent',function(self,event,...)
 if event=='PLAYER_LOGIN' then
  if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX) end
  if master() then
   S.dbValid=validateMaster()
   personal() -- Migrate legacy personal bests for the Master as well.
   if not S.dbValid then DEFAULT_CHAT_FRAME:AddMessage('|cffff4040[Mirage Raceway] Database Validation Failed|r') end
  else personal();send('HELLO') end
  return
 end
 local prefix,msg,channel,sender=...;if prefix~=PREFIX or channel~='WHISPER' then return end
 sender=(sender or ''):match('^([^%-]+)') or ''
 local a=fields(msg)
 if master() then onMaster(sender,a) else onClient(sender,a) end
end)
local update=CreateFrame('Frame');local lastYear=nil;local outboundClock=0;local masterSelfSyncClock=0
update:SetScript('OnUpdate',function(self,dt)
 S.elapsed=S.elapsed+dt;S.heartbeat=S.heartbeat+dt;S.versionCheck=S.versionCheck+dt
 outboundClock=outboundClock+dt
 if #outbound>0 and outboundClock>=.06 then
  outboundClock=0;local packet=table.remove(outbound,1);send(packet.msg,packet.to)
 end
 local y=serverYear()
 if y and lastYear and y~=lastYear then
  local p=personal();p.pending=nil;p.reset=nil;S.cache[y]=nil
  -- Retain just the immediately preceding season for My Statistics.
  local previous=p.seasons[y-1]
  if previous then p.lastSeasonYear=y-1;p.lastSeasonBest=previous
  elseif p.lastSeasonYear~=y-1 then p.lastSeasonYear=nil;p.lastSeasonBest=nil end
  for old in pairs(p.seasons) do if old~=y then p.seasons[old]=nil;p.generation[old]=nil end end
  if master() then for k,req in pairs(official().requests) do if req.year~=y then official().requests[k]=nil end end end
  if S.viewOpen then S:Open(y) end
 end
 if y then lastYear=y end
 -- Reconcile the Master's own season PB against the official database periodically.
 -- Unlike the old one-shot login import, this also recovers when the server year
 -- or personal SavedVariables become available after initial login.
 if master() and S.dbValid~=false and y then
  masterSelfSyncClock=(masterSelfSyncClock or 0)+dt
  if masterSelfSyncClock>=15 then
   masterSelfSyncClock=0
   local p=personal()
   local pb=p.seasons[y]
   if valid(pb) then
    local current=official().seasons[y]
    local existing=current and current.racers and current.racers[key(name())]
    local generation=p.generation[y] or 0
    -- An older self-reset can remain pending forever because the Master does not
    -- receive its own ACK through the client handler. Clear it ONLY when the
    -- official reset generation already matches and the player has a valid
    -- current-season PB queued at that same generation. Do not clear a newer
    -- reset request, a locked record, or an excluded record.
    if p.reset and p.reset.year==y and p.reset.generation==generation
       and existing and existing.generation==generation
       and not existing.locked and not existing.excluded
       and p.pending and p.pending.year==y
       and p.pending.generation==generation and valid(p.pending.best) then
     p.reset=nil
    end
    if not p.reset and (not existing or (not existing.locked and not existing.excluded and
        (not existing.generation or existing.generation==generation) and
        (not valid(existing.best) or pb<existing.best))) then
     local msg=table.concat({'RESULT',y,generation,id(),pb,UnitFactionGroup('player') or '',select(2,UnitClass('player')) or '',select(2,UnitRace('player')) or '',UnitSex('player') or ''},'|')
     onMaster(name(),fields(msg))
     -- Local Master submissions do not go through onClient ACK handling.
     local updated=official().seasons[y]
     local record=updated and updated.racers and updated.racers[key(name())]
     if record and record.generation==generation and valid(record.best) and record.best<=pb
        and p.pending and p.pending.year==y and p.pending.generation==generation then
      p.pending=nil
     end
    end
   end
  end
 end
 if S.active and S.elapsed>=.25 then
  local q=S.active;q.age=q.age+S.elapsed
  if q.age>=10 then
   if q.attempt==1 and not S:MasterOffline() then q.attempt=2;q.age=0;q.id=id();q.rows=nil;send((q.subscribe and 'SUB|' or 'GET|')..q.year..'|'..q.id)
   else S.active=nil;notify() end
  end
 end
 if S.heartbeat>=AUTO_CHECK_SECONDS then S.heartbeat=0;if not master() then send('HELLO',nil,true) end end
 if S.versionCheck>=AUTO_CHECK_SECONDS then S.versionCheck=0;if S.viewOpen and S.selected==y and not master() and not S:MasterOffline() then S:Request(y,true) end end
 S.elapsed=0
end)

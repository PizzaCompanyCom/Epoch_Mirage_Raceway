-- Tournament leaderboard: Master Belerda is the only writer. Independent of race times.
-- Protocol: bounded rows, tokenized snapshots, year-specific data, no client persistence.
local T={cache={},pending={},subscribers={},seq=0,selected=nil,viewOpen=false,active=nil,elapsed=0,poll=0}
MirageRacewayTournament=T
local PREFIX='MRTO12'
local AUTO_CHECK_SECONDS=7200
local lastManualRefresh=-1000
local initialFetched={}
local function isMaster()return MirageRacewaySync and MirageRacewaySync:IsMaster()end
local function year()return MirageRacewaySync and MirageRacewaySync.ServerYear()end
local function db()local d=MirageRacewayDB or {};d.btTournament=d.btTournament or {seasons={}};d.btTournament.seasons=d.btTournament.seasons or {};return d.btTournament end
local function season(y)
 local d=db();d.seasons[y]=d.seasons[y] or {racers={},version=0};return d.seasons[y]
end
local function validName(n)return type(n)=='string' and #n>=2 and #n<=24 and n:match('^[%a]+$')~=nil end
local function send(msg,to,force)
 if not SendAddonMessage then return false end
 if to then SendAddonMessage(PREFIX,msg,'WHISPER',to);return true end
 if MirageRacewaySync and MirageRacewaySync.SendToMaster then
  return MirageRacewaySync:SendToMaster(PREFIX,msg,force)
 end
 return false
end
local function split(s)local a={};for x in string.gmatch((s or '')..'|','(.-)|')do a[#a+1]=x end;return a end
local function token()T.seq=T.seq+1;return (UnitName('player') or 'unknown')..'-'..math.floor(GetTime()*1000)..'-'..T.seq end
local function list(y)
 local t={};local d=db().seasons[y]
 if d then for _,r in pairs(d.racers) do
  if type(r.gold)=='number' and r.gold>=0 and r.gold==math.floor(r.gold) then t[#t+1]={name=r.name,gold=r.gold,faction=r.faction,class=r.class,race=r.race,sex=r.sex} end
 end end
 table.sort(t,function(a,b)if a.gold==b.gold then return string.lower(a.name)<string.lower(b.name)end return a.gold>b.gold end)
 while #t>50 do table.remove(t) end
 local rank,previous=0,nil
 for i,r in ipairs(t)do if r.gold~=previous then rank=i end;r.rank=rank;previous=r.gold end
 return t
end
local function notify()if MirageRacewayTournamentRefresh then MirageRacewayTournamentRefresh()end end
local outbound={}
local function queue(msg,to)outbound[#outbound+1]={msg=msg,to=to}end
local function snapshot(y,id,to)
 local d=db().seasons[y];local t=list(y)
 queue(table.concat({'DATA',id,y,d and d.version or 0},'|'),to)
 for i,r in ipairs(t)do queue(table.concat({'ROW',id,i,r.name,r.gold,r.rank,r.faction or '',r.class or '',r.race or '',r.sex or ''},'|'),to)end
 queue('END|'..id..'|'..#t,to)
end
local function changed(y)
 local d=season(y);d.version=d.version+1
 for who in pairs(T.subscribers)do send('CHANGED|'..y..'|'..d.version,who)end
 T.cache[y]={rows=list(y),version=d.version};notify()
end
function T:MasterData()if isMaster()then return db()end end
function T:Admin(action,n,gold,faction)
 if not isMaster() or not year() or not validName(n)then return false,'Invalid racer name' end
 local d=season(year());local k=string.lower(n)
 if action=='REMOVE' then if not d.racers[k]then return false,'Racer not found'end;d.racers[k]=nil
 elseif action=='ADD' then
  if d.racers[k]then return false,'Racer already exists'end
  if type(gold)~='number' or gold<0 or gold>999999999 or gold~=math.floor(gold)then return false,'Invalid gold amount'end
  if faction~='Alliance' and faction~='Horde'then return false,'Choose a team'end
  d.racers[k]={name=n,gold=gold,faction=faction}
 elseif action=='SET' then
  local r=d.racers[k];if not r then return false,'Racer not found'end
  if type(gold)~='number' or gold<0 or gold>999999999 or gold~=math.floor(gold)then return false,'Invalid gold amount'end
  r.gold=gold;if faction=='Alliance' or faction=='Horde'then r.faction=faction end
 else return false,'Unknown action'end
 changed(year());return true
end
function T:LearnUnit(n,race,sex)
 if not isMaster() or not year() or not n or not race or (sex~=2 and sex~=3) then return end
 local d=season(year());local r=d.racers[string.lower(n)]
 if r and (r.race~=race or r.sex~=sex) then r.race=race;r.sex=sex;changed(year()) end
end
function T:Request(y,force)
 if not y or y<2026 or not year() or y>year()then return end
 self.selected=y
 if isMaster()then local d=db().seasons[y];self.cache[y]={rows=list(y),version=d and d.version or 0};self.active=nil;notify();return end
 if not force and MirageRacewaySync and MirageRacewaySync:MasterOffline() then self.active=nil;notify();return end
 local id=token();local msg='GET|'..y..'|'..id..'|'..(y==year() and '1' or '0')
 if send(msg,nil,force) then self.active={id=id,year=y,rows=nil,age=0,retries=0} else self.active=nil end
 notify()
end
function T:Open(y)
 self.viewOpen=true;self.selected=y or self.selected or year()
 if isMaster() then self:Request(self.selected)
 elseif self.selected and not initialFetched[self.selected] and not self.cache[self.selected] then
  initialFetched[self.selected]=true;self:Request(self.selected)
 else notify() end
end
function T:RefreshNow(y)
 y=y or self.selected or year()
 if not y then return false end
 if not isMaster() and GetTime()-lastManualRefresh<10 then return false end
 lastManualRefresh=GetTime();self:Request(y,true);return true
end
function T:Close()self.viewOpen=false;self.active=nil;if not isMaster()then send('UNSUB')end end
local events=CreateFrame('Frame');events:RegisterEvent('PLAYER_LOGIN');events:RegisterEvent('CHAT_MSG_ADDON')
events:SetScript('OnEvent',function(_,event,...)
 if event=='PLAYER_LOGIN' then if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX)end;return end
 local prefix,msg,channel,sender=...;if prefix~=PREFIX or channel~='WHISPER'then return end
 sender=(sender or ''):match('^([^%-]+)') or ''
 local a=split(msg);local op=a[1]
 if isMaster()then
  if op=='GET'then
   local y=tonumber(a[2]);if not y or not year() or y<2026 or y>year() or not a[3]then return end
   if a[4]=='1' and y==year()then T.subscribers[sender]=true end
   snapshot(y,a[3],sender)
  elseif op=='UNSUB'then T.subscribers[sender]=nil end
 else
  if string.lower(sender)~='belerda'then return end
  if MirageRacewaySync and MirageRacewaySync.MasterAvailable then MirageRacewaySync:MasterAvailable() end
  if op=='DATA'then local q=T.active;if not q or q.id~=a[2] or q.year~=tonumber(a[3])then return end;q.rows={};q.version=tonumber(a[4]) or 0
  elseif op=='ROW'then
   local q=T.active;if not q or not q.rows or q.id~=a[2]then return end
   local i,g=tonumber(a[3]),tonumber(a[5]);if not i or i<1 or i>50 or not g or g<0 or g>999999999 or g~=math.floor(g)then return end
   q.rows[i]={name=a[4],gold=g,rank=tonumber(a[6]) or i,faction=a[7],class=a[8],race=a[9],sex=tonumber(a[10])}
  elseif op=='END'then
   local q=T.active;if not q or not q.rows or q.id~=a[2]then return end
   local n=tonumber(a[3]);if not n or n<0 or n>50 then return end
   local t={};for i=1,n do if not q.rows[i]then return end;t[i]=q.rows[i]end
   T.cache[q.year]={rows=t,version=q.version};T.active=nil;notify()
  elseif op=='CHANGED'then if T.viewOpen and T.selected==year()then T:Request(T.selected)end end
 end
end)
local updater=CreateFrame('Frame');local outboundClock=0;updater:SetScript('OnUpdate',function(_,dt)
 outboundClock=outboundClock+dt
 if #outbound>0 and outboundClock>=.06 then outboundClock=0;local packet=table.remove(outbound,1);send(packet.msg,packet.to)end
 T.elapsed=T.elapsed+dt;T.poll=T.poll+dt
 if T.active and T.elapsed>=.25 then
  T.active.age=T.active.age+T.elapsed
  if T.active.age>10 then
   local q=T.active
   if q.retries==0 and not (MirageRacewaySync and MirageRacewaySync:MasterOffline()) then q.retries=1;q.age=0;q.id=token();q.rows=nil;send('GET|'..q.year..'|'..q.id..'|'..(q.year==year() and '1' or '0'))
   else T.active=nil;notify()end
  end
 end
 if T.poll>=AUTO_CHECK_SECONDS then T.poll=0;if T.viewOpen and T.selected==year()then T:Request(T.selected)end end
 T.elapsed=0
end)

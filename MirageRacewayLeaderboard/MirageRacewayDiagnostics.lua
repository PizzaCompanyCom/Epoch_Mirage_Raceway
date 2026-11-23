-- Read-only diagnostic for Mirage Raceway Best Time v1.2.4
-- Run /mrdiag on Belerda and copy the output.
local function say(msg)
 if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cffd6b45b[MR DIAG]|r '..tostring(msg)) end
end
local function show(value)
 if value==nil then return 'nil' end
 if type(value)=='boolean' then return value and 'true' or 'false' end
 return tostring(value)
end
local function stamp(ms)
 if type(ms)~='number' then return show(ms) end
 local sec=math.floor(ms/1000)
 return string.format('%02d:%02d.%03d (%d ms)',math.floor(sec/60),sec%60,ms%1000,ms)
end
local function count(t)
 local n=0
 if type(t)=='table' then for _ in pairs(t) do n=n+1 end end
 return n
end
local function diagnose()
 local S=MirageRacewaySync
 local d=MirageRacewayDB
 local player=UnitName('player') or '?'
 local realm=GetRealmName and GetRealmName() or '?'
 local y=S and S.ServerYear and S.ServerYear()
 say('--- v1.2.7 / TOP50 TRACE READ ONLY ---')
 say('Player='..player..' Realm='..realm..' Year='..show(y))
 say('Sync loaded='..show(type(S)=='table')..' Master='..show(S and S.IsMaster and S:IsMaster())..' dbValid='..show(S and S.dbValid))
 say('DB='..type(d)..' Personal='..type(d and d.btPersonal)..' Official='..type(d and d.btMaster))
 local p=d and d.btPersonal
 if type(p)=='table' then
  local ps=type(p.seasons)=='table' and p.seasons or {}
  local pg=type(p.generation)=='table' and p.generation or {}
  say('Personal Season Best='..stamp(y and ps[y])..' AllTime='..stamp(p.all))
  say('Personal generation='..show(y and pg[y])..' pending='..show(p.pending and p.pending.id)..' reset='..show(p.reset and p.reset.id))
  if p.pending then say('Pending year='..show(p.pending.year)..' gen='..show(p.pending.generation)..' best='..stamp(p.pending.best)) end
  if p.reset then say('Reset year='..show(p.reset.year)..' gen='..show(p.reset.generation)) end
 else say('Personal record MISSING') end
 local m=d and d.btMaster
 if type(m)=='table' then
  say('Master seasons='..count(m.seasons)..' requests='..count(m.requests))
  local season=type(m.seasons)=='table' and y and m.seasons[y]
  say('Current season record='..type(season)..' racers='..count(season and season.racers)..' version='..show(season and season.version))
  if type(season)=='table' and type(season.racers)=='table' then
   local k=string.lower(realm)..':'..string.lower(player)
   local r=season.racers[k]
   say('Expected key='..k..' exists='..show(r~=nil))
   if not r then
    for rk,rv in pairs(season.racers) do
     if type(rv)=='table' and type(rv.name)=='string' and string.lower(rv.name)==string.lower(player) then
      say('NAME MATCH with DIFFERENT KEY: '..tostring(rk))
     end
    end
   else
    say('Official best='..stamp(r.best)..' generation='..show(r.generation))
    say('Official locked='..show(r.locked)..' excluded='..show(r.excluded)..' name='..show(r.name))
   end
  end
 else say('Official database MISSING') end
 local season=m and m.seasons and y and m.seasons[y]
 if type(season)=='table' and type(season.racers)=='table' then
  local candidates={}
  for rk,r in pairs(season.racers) do
   local best=r and r.best
   local valid=type(best)=='number' and best==math.floor(best) and best>0 and best<1000000000000
   local eligible=valid and not r.excluded
   say('DB ROW '..tostring(rk)..' name='..show(r and r.name)..' best='..stamp(best)..' valid='..show(valid)..' excluded='..show(r and r.excluded)..' eligible='..show(eligible))
   if eligible then candidates[#candidates+1]={name=r.name,best=best} end
  end
  table.sort(candidates,function(a,b)if a.best==b.best then return string.lower(a.name)<string.lower(b.name) end return a.best<b.best end)
  say('ELIGIBLE TOP count='..#candidates)
  for i,r in ipairs(candidates) do if i<=50 then say('TOP '..i..' '..show(r.name)..' '..stamp(r.best)) end end
 end
 local cache=S and S.cache and y and S.cache[y]
 say('SYNC CACHE year='..show(y)..' exists='..show(cache~=nil)..' version='..show(cache and cache.version)..' rows='..count(cache and cache.rows))
 if cache and type(cache.rows)=='table' then
  for i,r in ipairs(cache.rows) do say('CACHE '..i..' '..show(r.name)..' '..stamp(r.best)) end
 end
 local ui=MirageRacewayBestTimeUIState
 say('UI selected='..show(ui and ui.GetSelectedYear and ui.GetSelectedYear())..' demo='..show(ui and ui.GetDemoActive and ui.GetDemoActive()))
 say('TOC version='..show(GetAddOnMetadata and GetAddOnMetadata('MirageRacewayLeaderboard','Version')))
 say('--- END /mrdiag ---')
end
SLASH_MIRAGERACEWAYDIAG1='/mrdiag'
SlashCmdList.MIRAGERACEWAYDIAG=diagnose

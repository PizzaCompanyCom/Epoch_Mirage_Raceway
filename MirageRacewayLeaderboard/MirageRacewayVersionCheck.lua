-- Mirage Raceway version discovery for WoW 3.3.5a (Lua 5.1).
-- Peer-to-peer only: no web requests and no claims about latest GitHub release.
local PREFIX='MRVER1'
local addon='MirageRacewayLeaderboard'
local myVersion=(GetAddOnMetadata and GetAddOnMetadata(addon,'Version')) or '0'
local elapsed=0
local first=true
local announced=false
local seen={}
local function enabled()
 return not MirageRacewayDB or MirageRacewayDB.updateAlerts~=false
end
local function numbers(v)
 local out={}
 for n in string.gmatch(tostring(v or ''),'%d+') do out[#out+1]=tonumber(n) end
 return out
end
local function newer(a,b)
 local aa,bb=numbers(a),numbers(b)
 for i=1,math.max(#aa,#bb) do
  local x,y=aa[i] or 0,bb[i] or 0
  if x~=y then return x>y end
 end
 return false
end
local function send(payload,channel,target)
 if type(SendAddonMessage)=='function' then SendAddonMessage(PREFIX,payload,channel,target) end
end
local function broadcast()
 if not enabled() then return end
 -- Limit discovery to existing social groups; never post to public chat channels.
 if IsInGuild and IsInGuild() then send('Q|'..myVersion,'GUILD') end
 if GetNumRaidMembers and GetNumRaidMembers()>0 then
  send('Q|'..myVersion,'RAID')
 elseif GetNumPartyMembers and GetNumPartyMembers()>0 then
  send('Q|'..myVersion,'PARTY')
 end
end
local f=CreateFrame('Frame')
f:RegisterEvent('PLAYER_LOGIN')
f:RegisterEvent('CHAT_MSG_ADDON')
f:RegisterEvent('PARTY_MEMBERS_CHANGED')
f:RegisterEvent('RAID_ROSTER_UPDATE')
f:RegisterEvent('GUILD_ROSTER_UPDATE')
local nextGroupProbe=0
f:SetScript('OnEvent',function(self,event,...)
 if event=='PLAYER_LOGIN' then
  if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX) end
  return
 end
 if event=='CHAT_MSG_ADDON' then
  local prefix,msg,channel,sender=...
  if prefix~=PREFIX or type(msg)~='string' or not enabled() then return end
  local own=UnitName('player') or ''
  local senderName=(sender or ''):match('^([^%-]+)') or ''
  if string.lower(senderName)==string.lower(own) then return end
  local kind,version=msg:match('^(%u)|([%d%.]+)$')
  if not kind or not version or #version>24 then return end
  if newer(version,myVersion) then
   if not MirageRacewayDB.newestPeerVersion or newer(version,MirageRacewayDB.newestPeerVersion) then
    MirageRacewayDB.newestPeerVersion=version
   end
   if not announced then
    announced=true
    DEFAULT_CHAT_FRAME:AddMessage('|cffffd100[Mirage Raceway]|r Newer addon version detected: v'..version..' (installed: v'..myVersion..'). Open Contacts to copy the GitHub link.')
   end
  end
  if kind=='Q' and channel~='WHISPER' then
   local now=GetTime()
   if not seen[sender] or now-seen[sender]>120 then
    seen[sender]=now
    -- Respond directly, not to the whole guild/party.
    send('V|'..myVersion,'WHISPER',sender)
   end
  end
  return
 end
 -- Roster changes are coalesced; no repeated bursts when joining groups.
 nextGroupProbe=GetTime()+12
end)
f:SetScript('OnUpdate',function(self,dt)
 elapsed=elapsed+dt
 if first and elapsed>=25 then
  first=false;elapsed=0;broadcast()
 elseif not first and elapsed>=300 then
  elapsed=0;broadcast()
 end
 if nextGroupProbe>0 and GetTime()>=nextGroupProbe then
  nextGroupProbe=0;broadcast()
 end
end)

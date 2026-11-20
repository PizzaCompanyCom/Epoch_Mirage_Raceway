Mirage Raceway Best Time v1.1 - Epoch Reborn / WoW 3.3.5a
========================================================
Install MirageRacewayLeaderboard into Interface/AddOns. Keep folder name unchanged.
Install the SAME addon on every participating racer and on Belerda.
Only the character Belerda is Master. All UI is in English.

/mrl          Open/close main window
/mrl board    Open Best Time
/mrl stats    Open My Statistics
/mrl settings Open options

Best Time: Official Top 50 per season; rank, racer, best time; shared ranks for ties.
Personal: All-Time Best, current Season Best, confirmed Reset Season Best.
Master Management (Belerda): search racers, Save Time, Lock, Unlock, Exclude,
Include, approve/reject locked reset requests.

Network: addon WHISPER MRBT11; ACKs; reconnect resync; Top 50 live notifications;
10-second request timeout, one automatic retry, RAM-only season cache.
Annual seasons: strict server calendar date from CalendarGetDate(). No local clock
fallback. If this API is absent/invalid on Epoch Reborn, season submission and
season tables are unavailable; All-Time Best still works. This must be tested in game.

Start: existing Epoch Reborn announcer message retained. A conservative map-coordinate
exit/re-entry guard is used after the first tracked start. It requires a valid
GetPlayerMapPosition result and movement away/back from the initial start position.
This is NOT a guaranteed track-boundary detector. If coordinates are unavailable,
subsequent starts are intentionally blocked rather than accepting unverified starts.
The first start after login still relies on the original race announcement; this
cannot guarantee login-inside-start-zone protection without authoritative zone data.

Official times are validated for positive millisecond values, year, generation,
locks and sender identity, but the WoW addon protocol CANNOT prove that a modified
client actually completed a race. Master must be online to save official results.
SavedVariables are persisted by WoW on normal logout/reload, not guaranteed on crash.

v1.1 is an initial implementation build and has not been tested in Epoch Reborn.
Back up your existing SavedVariables before installing. Legacy records are retained
for rollback; legacy personal best is imported to All-Time once when available.

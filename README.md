# Internet-Connectivity-Test
Batch Script to Test The Internet Connectivity Test in Windows

## The script
- Pings 61.247.179.9 (Gateway) and 1.1.1.1 (Internet)
- Sends an SMS through your USB modem (via COM port, change the COM-port number) when either or both are down
- Logs every event to a text file (NetWatchdog.log in the same folder)
- Creates two state flags (GATEWAY_DOWN.flag and INTERNET_DOWN.flag)
- When both targets are back up it waits 10 consecutive successful minutes (10 passes) before sending the “all clear” SMS and deleting the state flags.

## Scheduling the script
- Press Win+R → taskschd.msc → Create Task
- General → Name: NetWatchdog → “Run whether user is logged on or not” (supply credentials)
- Triggers → New → “On a schedule” → Daily → Repeat task every: 1 minutes → for a duration of: Indefinitely
- Actions → New → Program/script: C:\Windows\System32\cmd.exe
- Add arguments: /c "C:\Scripts\NetWatchdog.bat"
- Conditions → un-tick “Start the task only if the computer is on AC power” (if needed)
- OK → supply credentials → Done.

## Notes / customisation
- Change SMS_COMPORT to the actual COM port your USB modem appears on.
- Change SMS_TARGET to the destination mobile number (include country code).
- If your modem needs a different AT command sequence (e.g. AT+CMGS="+number"\r\nmessage\x1A) edit the :SENDSMS section.
- Logs will accumulate in the same folder as the script (NetWatchdog.log).

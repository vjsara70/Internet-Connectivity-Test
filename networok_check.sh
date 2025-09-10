#!/usr/bin/env bash
# ------------------------------------------------------------------
#  Network / Internet watchdog  –  now with RESTORE notifications
#  5th-Floor, House-40, Road-3, Sector-10, Uttara
# ------------------------------------------------------------------
set -euo pipefail

########################################
#  CONFIG – change only here
########################################
GATEWAY="8.8.8.8"               # ISP gateway (or any reliable hop)
INTERNET="1.1.1.1"              # True Internet host
PING_COUNT=3                    # packets per test
LOGFILE="/var/log/netwatch.log"
SPEEDTEST_CLI="/usr/bin/speedtest-cli"   # apt install speedtest-cli
MIN_DOWN_MB=50                  # alert when download < this
CONSECUTIVE_FAIL=3              # how many times below MIN_DOWN_MB before alert
CHECK_EVERY_SEC=180             # 3 min – only used by systemd timer unit
SMS1="+88017XXXXXXXX"           # 1st mobile for Internet-down / restored
SMS2="+88018XXXXXXXX"           # 2nd mobile for Internet-down / restored
SMS_GATEWAY="+88019XXXXXXXX"    # mobile for Gateway-down
TG_CHAT_ID="-100XXXXXXXXX"      # Telegram chat id
TG_BOT_TOKEN="XXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
PUSHO_APP="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"   # Pushover app token
PUSHO_USER="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"   # Pushover user key
STATE_FILE="/tmp/netwatch_last_state"          # persistent state between runs
SPEED_COUNTER_FILE="/tmp/netwatch_speed_counter"
########################################

#---- helper functions ----------------------------------------------
log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOGFILE"
}

send_sms() {
    local msg="$1"
    local numbers="$2"
    # Replace with your own SMS-api/gateway command
    for num in $numbers; do
        curl -sS -X POST https://your.sms.gateway.example/sendsms \
             -d "username=youruser" -d "password=yourpass" \
             -d "number=$num" -d "message=$msg" >> "$LOGFILE" 2>&1 || true
    done
}

send_tg() {
    local msg="$1"
    curl -sS -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
         -d chat_id="$TG_CHAT_ID" -d text="$msg" >> "$LOGFILE" 2>&1 || true
}

send_pushover() {
    local title="NetWatch Alert"
    local msg="$1"
    curl -sS -X POST https://api.pushover.net/1/messages.json \
         -F "token=$PUSHO_APP" -F "user=$PUSHO_USER" \
         -F "title=$title" -F "message=$msg" >> "$LOGFILE" 2>&1 || true
}

broadcast() {
    local msg="$1"
    local sms_list="${2:-}"      # optional 2nd arg – SMS numbers
    log "$msg"
    [[ -n $sms_list ]] && send_sms "$msg" "$sms_list"
    send_tg   "$msg"
    send_pushover "$msg"
}

#---- network tests -------------------------------------------------
gateway_ok=false
internet_ok=false

if ping -q -c "$PING_COUNT" "$GATEWAY" >/dev/null 2>&1; then
    gateway_ok=true
    if ping -q -c "$PING_COUNT" "$INTERNET" >/dev/null 2>&1; then
        internet_ok=true
    fi
fi

#---- determine current state ---------------------------------------
last_state=$(cat "$STATE_FILE" 2>/dev/null || echo "UP")

if ! $gateway_ok; then
    current_state="GATEWAY_DOWN"
elif ! $internet_ok; then
    current_state="INTERNET_DOWN"
else
    current_state="UP"
fi

#---- state changed? -------------------------------------------------
if [[ "$current_state" != "$last_state" ]]; then
    case "$current_state" in
        UP)
            broadcast "Internet connectivity RESTORED. Everything is back to normal. 5th Floor, House 40, Road 3, Sector 10, Uttara. ($(date '+%F %T'))" "$SMS1 $SMS2"
            ;;
        GATEWAY_DOWN)
            broadcast "Gateway Network/Internet Line is Down. Please Check. 5th Floor, House 40, Road 3, Sector 10, Uttara. ($(date '+%F %T'))" "$SMS_GATEWAY"
            ;;
        INTERNET_DOWN)
            broadcast "Internet Line is Down. Please Check. 5th Floor, House 40, Road 3, Sector 10, Uttara. ($(date '+%F %T'))" "$SMS1 $SMS2"
            ;;
    esac
    echo "$current_state" > "$STATE_FILE"
fi

#---- speed test only when fully UP ---------------------------------
if [[ "$current_state" == "UP" ]]; then
    if [[ -x $SPEEDTEST_CLI ]]; then
        result=$($SPEEDTEST_CLI --simple 2>/dev/null) || true
        if [[ -n "$result" ]]; then
            down=$(echo "$result" | awk '/Download/{print $2}')
            up=$(echo "$result"   | awk '/Upload/{print $2}')
            latency=$(echo "$result" | awk '/Ping/{print $2}')
            jitter=$(echo "$result"  | awk '/Jitter/{print $2}')
            log "SPEEDTEST ok: Down=${down}Mbit/s Up=${up}Mbit/s Ping=${latency}ms Jitter=${jitter}ms"
            # Counter logic for low-speed
            if (( $(awk -v d="$down" 'BEGIN{print (d<'"$MIN_DOWN_MB"')}') )); then
                cnt=$(cat "$SPEED_COUNTER_FILE" 2>/dev/null || echo 0)
                ((cnt++))
                echo "$cnt" > "$SPEED_COUNTER_FILE"
                if (( cnt >= CONSECUTIVE_FAIL )); then
                    broadcast "Internet Speed is problem. Please check. 5th Floor, House 40, Road 3, Sector 10, Uttara. Down=${down}Mbit/s Up=${up}Mbit/s at $(date '+%F %T')" "$SMS1 $SMS2"
                    rm -f "$SPEED_COUNTER_FILE"
                fi
            else
                rm -f "$SPEED_COUNTER_FILE"
            fi
        else
            log "SPEEDTEST failed – speedtest-cli returned empty"
        fi
    else
        log "SPEEDTEST skipped – speedtest-cli not found"
    fi
fi

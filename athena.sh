#!/bin/bash

# Telegram Config
TOKEN="1429088807:AAFDbK2vjvtOOqwALyZrSY_50qspu45CC18" # Bot Token
CHATID="-1001471632092"
BOT_MSG_URL="https://api.telegram.org/bot${TOKEN}/sendMessage"
BOT_LOG_URL="https://api.telegram.org/bot${TOKEN}/sendDocument"
BOT_STICKER_URL="https://api.telegram.org/bot${TOKEN}/sendSticker"

# General Rom Settings
device="violet"
rom="p404"
build="eng"
zip="out/target/product/violet/*unofficial*.zip"
make="make bacon"
clean="" # make installclean(preffered) , make clean

# Upload Stuffs
gdrivedir="Dark-world" # Directory to upload the file
index="https://index.nipin-joker.workers.dev/0:/" # gdrive index link
rclone="gdrive" # rclone remote

# Build Machine details
cores=$(nproc --all)
os=$(cat /etc/issue)
time=$(TZ="Asia/Kolkata" date "+%a %b %d %r")

# send saxx msgs to tg
tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

# send the error logs to tg
tg_post_log() {
	curl --progress-bar -F document=@"$1" "$BOT_LOG_URL" \
	-F chat_id="$CHATID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
  -F caption="$2"
}

# send a nice sticker ro act as a sperator between builds
tg_post_sticker() {
    curl -s -X POST "$BOT_STICKER_URL" -d chat_id="$CHATID" \
        -d sticker="CAACAgUAAxkBAAECHIJgXlYR8K8bYvyYIpHaFTJXYULy4QACtgIAAs328FYI4H9L7GpWgR4E"
}

#start off by sending a trigger msg
tg_post_sticker
tg_post_msg "<b>Build Triggered ⌛</b>%0A<b>===============</b>%0A<b>Rom : </b><code>$rom</code>%0A<b>Machine : </b><code>$os</code>%0A<b>Cores : </b><code>$cores</code>%0A<b>Time : </b><code>$time</code>"

# Build Time
source build/envsetup.sh

ccache -M 75G
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
rm  log.txt
rm -rf $zip

if [ -z "$clean" ]; then
	echo "Dirty Building"
else
	$clean
fi

START=$(date +%s)
lunch "${rom}"_"${device}"-"${build}"

# Let's compile by parts!
make api-stubs-docs
make hiddenapi-lists-docs
make system-api-stubs-docs
make test-api-stubs-docs

$make |& tee log.txt

END=$(date +%s)
BUILDTIME=$(echo $((${END} - ${START})) | awk '{print int ($1/3600)" Hours:"int(($1/60)%60)"Minutes:"int($1%60)" Seconds"}')

if [ ! -f $zip ]; then # Much better logic than previous
  tg_post_msg "<b> Build Failed for $rom ❌</b>%0A<b>Wasted Time : </b><code>$BUILDTIME</code>"
  tg_post_log "log.txt" "Full Build Log"
  sed '/FAILED/,$!d' log.txt >errlog.txt
  tg_post_log "errlog.txt" "Error Log"
else
  size="$(du -h ${zip}|awk '{print $1}')"
	mdsum="$(md5sum ${zip}|awk '{print $1}')"
  file=$(basename $zip)
  rclone -P copy $zip $rclone:$gdrivedir 
  glink="$(rclone link ${rclone}:${gdrivedir}/${file})" # fetches the drive link
  indexlink="${index}/${gdrivedir}/${file}" # sets up an index link also

  # Success msg to tg
  tg_post_msg "<b>Build Success ✅</b>%0A<b>===============</b>%0A<b>File : </b><code>$file</code>%0A<b>Size : </b><code>$size</code>%0A<b>MD5 : </b><code>$mdsum</code>%0A<b>Download Links : </b><a href='$glink'>🔗Gdrive Link</a><b> || </b><a href='$indexlink'>🔗Index Link</a>%0A<b>Build Time : </b><code>$BUILDTIME</code>"
fi

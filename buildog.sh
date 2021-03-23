#!/bin/bash

# General Rom Settings

rom="colt"
build="userdebug"
zip="out/target/product/violet/*Official*.zip"
make="make colt"
clean=""

# Upload Stuffs
gdrivedir="Colt-test"
index="https://builds.athuld.workers.dev/0:"
rclone="gdrive"

# Build Machine details
cores=$(nproc --all)
os=$(cat /etc/issue)
time=$(TZ="Asia/Kolkata" date "+%a %b %d %r")

# Get a sticker to be sent to act as a cool seperator
if [ ! -f ~/.sticker/sticker.webp ]; then
	curl -L https://builds.athuld.workers.dev/0:/sticker.webp --create-dirs -o ~/.sticker/sticker.webp
fi

# Build Start Message
read -r -d '' msg <<EOT
<b>Build Started</b>
<b>============</b>
<b>ROM:-</b> <pre>${rom}</pre>
<b>SERVER:-</b> <pre>${os}</pre>
<b>CORES:-</b> <pre>${cores}</pre> 
<b>Build Type:-</b> <pre>${build}</pre>
<b>Time:-</b> <pre>${time}</pre>
EOT

telegram-send --sticker ~/.sticker/sticker.webp
telegram-send --format html "${msg}"

# Build Time
source build/envsetup.sh

export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
rm output.txt log.txt
rm -rf $zip

if [ -z "$clean" ]; then
	echo "Dirty Building"
else
	$clean
fi

START=$(date +%s)
lunch "${rom}"_violet-"${build}"
$make |& tee output.txt

END=$(date +%s)
BUILDTIME=$(echo $((${END} - ${START})) | awk '{print int ($1/3600)" Hours: "int(($1/60)%60)" Minutes: "int($1%60)" Seconds"}')

# Check if the Build Succeeded or not
check="$(tail -n 2 ./output.txt | grep success)"

if [ -z "$check" ]; then
	telegram-send --pre "Build Failed!"
	if [ -z "$(grep FAILED output.txt)" ]; then
		errLog="$(inu -f ./output.txt command p)"
		wait
	else
		sed '/FAILED/,$!d' output.txt >>log.txt
		errLog="$(inu -f ./log.txt command p)"
		wait
	fi

	# Send Error msg along with del.dog
	read -r -d '' err <<EOT
<b>Error Log</b>
<b>========</b>

<b>ROM:-</b> <pre>${rom}</pre>
<b>Error:- </b> <a href="${errLog}">here</a>
<b>Build Time:-</b> <pre>${BUILDTIME}</pre>
EOT

	telegram-send --format html "${err}" --disable-web-page-preview
else
	telegram-send --pre "Build Successful!...Uploading.."
	rclone -P copy $zip $rclone:$gdrivedir
	file=$(basename $zip)
	size="$(du -h ${zip}|awk '{print $1}')"
	mdsum="$(md5sum ${zip}|awk '{print $1}')"
	wait

	glink="$(rclone link gdrive:$gdrivedir/${file})"
	index="${index}/${gdrivedir}/${file}"

	#Success msg along with Download links
	read -r -d '' succ <<EOT
<b>Download Links</b>
<b>==============</b>

<b>ROM:-</b> <pre>${rom}</pre>
<b>Build Type:-</b> <pre>${build}</pre>
<b>Size :- </b> <pre>${size}</pre>
<b>md5sum:- </b> <pre>${mdsum}</pre>
<b>GDrive Link:- </b> <a href="${glink}">here</a>
<b>Index Link:- </b> <a href="${index}">here</a>
<b>Build Time:-</b> <pre>${BUILDTIME}</pre>
EOT

	telegram-send --format html "${succ}" --disable-web-page-preview
fi

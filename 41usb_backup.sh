# Delete existing modification from file, if it exists
sed -i '/#START_MOD/,/#END_MOD/d' /etc/udev/script/add_usb_storage.sh

# Delete exit from end of the file
sed -i '/^exit$/d' /etc/udev/script/add_usb_storage.sh

# Add call to usb backup script after drive mounts
cat <<'EOF' >> /etc/udev/script/add_usb_storage.sh
#START_MOD
# Weirdly, inserting storage results in a remount of all storage.
# This script is thus run twice in paralel, which causes problems.
# Only run the backup if the SDcard was inserted
if [ $MOUNTPATH/$HDTAG$HDNUM == "/data/UsbDisk1" ]; then
	# Wait for the other script to finish
	sleep 10
	echo "Running backup script due to insertion of $1" >> /tmp/usb_add_info
	# Run backup script
	/etc/udev/script/usb_backup.sh &
fi
exit
#END_MOD
EOF

cat <<'EOF' > /etc/udev/script/usb_backup.sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
# Kill an existing backup process if running 
# (this can happen if you insert two disks one after the other)
if [ -e /tmp/backup.pid ]; then
	kill $(cat /tmp/backup.pid)
	killall rsync
	sleep 1
fi
echo $$ > /tmp/backup.pid
SD_MOUNTPOINT=/data/UsbDisk1/Volume1
STORE_DIR=.vst
PHOTO_DIR=sd-import
# Check if an SD card is inserted (always mounted at the same mount point on the Rav Filehub)
check_sdcard() {
	while read device mountpoint fstype remainder; do
		if [ "$mountpoint" == "$SD_MOUNTPOINT" ]; then
			# Get the UUID for the SD card. Create one if it doesn't already exist
			local uuid_file
			uuid_file="$SD_MOUNTPOINT"/.uuid
			if [ -e $uuid_file ]; then
				sd_uuid=`cat $uuid_file`
			else
				sd_uuid=`cat /proc/sys/kernel/random/uuid`
				echo "$sd_uuid" > $uuid_file
			fi
			return 1
		fi
	done < /proc/mounts
	return 0
}
# Check if a USB drive is attached which is initialize for storing monitoring data
check_storedrive() {
	while read device mountpoint fstype remainder; do
		if [ ${device:0:7} == "/dev/sd" -a -e "$mountpoint/$STORE_DIR"/rsync ]; then
			# Add the store dir (containing rsync binary) to the PATH
			export PATH="$mountpoint/$STORE_DIR":$PATH
			store_mountpoint="$mountpoint"
			# Grab device serial number (unused: remove code?)
			store_id=$(udevadm info -a -p  $(udevadm info -q path -n ${device:0:8}) | grep -m 1 "ATTRS{serial}" | cut -d'"' -f2)
			# Grab filesystem
			store_fs=$fstype
			return 1
		fi
	done < /proc/mounts
	return 0
}
# If no SD card is inserted, just exit.
check_sdcard
sdcard=$?
check_storedrive
storedrive=$?
# If both a valid store drive and SD card are mounted,
# check if there are files to backup
if [ $sdcard -eq 1 -a $storedrive -eq 1 ]; then
	# Check to see if there's more than DCIM to check
	if [ -f "$store_mountpoint/$STORE_DIR"/sources.cnf ]; then
		. "$store_mountpoint/$STORE_DIR/sources.cnf"
		echo "Found file with: $sources" >> /tmp/usb_add_info
	fi
	# If no folders are found in sources.cnf check DCIM
	if [ -z "$sources" ]; then
		sources="DCIM"
	fi
	# Use temporary folder to work around pipeline subshell, can't use mkfifo etc (lose output)
	echo "$sources" > /tmp/bkp_sources
	# Check folders for files to copy, remove empty folders from the list
	while IFS= read -r source; do
		echo "Checking if not empty: $source" >> /tmp/usb_add_info
		if [ "$(find "$SD_MOUNTPOINT/$source" -type f -print)" ]; then
			if [ -z "$source_list" ]; then
				source_list="$source"
			else
				source_list="$source_list"$'\n'"$source"
			fi
		fi
	done < /tmp/bkp_sources
	rm /tmp/bkp_sources
	echo "Source folders found:" >> /tmp/usb_add_info
	echo "$source_list" >> /tmp/usb_add_info
fi
# If both a valid store drive and SD card are mounted, and we have files to backup,
# copy the SD card contents to the store drive
if [ $sdcard -eq 1 -a $storedrive -eq 1 -a -n "$source_list" ]; then
	# Check if we have a swap file on the target that isn't already in use
	if [ -z "$(grep "$store_mountpoint" /proc/swaps)" -a -e "$store_mountpoint/$STORE_DIR"/swapfile ]; then
		echo "Enable swap at $store_mountpoint/$STORE_DIR/swapfile" >> /tmp/usb_add_info
		swapon "$store_mountpoint/$STORE_DIR"/swapfile
	fi
	# Get the date of the latest file on the SD card
	last_file="$SD_MOUNTPOINT"/DCIM/`ls -1c "$SD_MOUNTPOINT"/DCIM/ | tail -1`
	last_file_date=`stat "$last_file" | grep Modify | sed -e 's/Modify: //' -e 's/[:| ]/_/g' | cut -d . -f 1`
	# Organize the photos in a folder for each SD card by UUID,
	# organize in subfolders by date of latest photo being imported
	target_dir="$store_mountpoint/$PHOTO_DIR"/"$sd_uuid"/"$last_file_date"
	# Incoming dir and uuid folders are left as an artifact on the backup drive
	incoming_dir="$store_mountpoint/$PHOTO_DIR"/incoming/"$sd_uuid"
	partial_dir="$store_mountpoint/$PHOTO_DIR"/incoming/.partial
	mkdir -p $target_dir
	mkdir -p $incoming_dir
	# Copy the files from the sd card to the target dir,
	# Uses filename and size to check for duplicates
	echo "Copying SD card to $target_dir" >> /tmp/usb_add_info
	# Blink internet LED while rsync is working (normally either on or off)
	/usr/sbin/pioctl internet 2
	if [ $store_fs == "tntfs" ]; then
		# if ntfs then avoid timestamp errors
		rsync_opt="vrm"
	else
		# Otherwise preserve timestamps
		rsync_opt="vrtm"
	fi
	printf '%s\n' "$source_list" | while IFS= read -r backup_src; do
		echo "Running rsync for $backup_src" >> /tmp/usb_add_info
		# Create the target in the backup folder, change path to single folder
		backup_dst=$(echo "$backup_src" | sed 's/\//./g')
		mkdir "$target_dir/$backup_dst"
		# Backup to the created folder
		rsync -$rsync_opt --size-only --modify-window=2 --remove-source-files --log-file "$incoming_dir/$last_file_date.rsync.log" --partial-dir "$partial_dir" --exclude ".?*" "$SD_MOUNTPOINT/$backup_src/" "$target_dir/$backup_dst"
		echo "Copy of $backup_src to $backup_dst done" >> /tmp/usb_add_info
		# Remove empty folders. Rsync only removes files
		find "$SD_MOUNTPOINT/$backup_src"/* -type d -print | sed '1!G;h;$!d' | while IFS= read -r rm_folder; do
			rmdir "$rm_folder"
		done
	done
	backup_done=1
fi
# Stop swap on backup disk to aid unmount
if [ -n "$(grep "$store_mountpoint" /proc/swaps)" ]; then
	echo "Disable swap file" >> /tmp/usb_add_info
	swapoff "$store_mountpoint/$STORE_DIR"/swapfile
fi
# Write memory buffer to disk
sync
# Stop internet LED blinking when rsync is done (Wifidisk scripts seem to do this twice, for good measure)
/usr/sbin/pioctl internet 3
sleep 0.5
/usr/sbin/pinctl internet 3
rm /tmp/backup.pid
if [ $backup_done -eq 1 ]; then
	echo "Backup done..." >> /tmp/usb_add_info
else
	echo "Nothing to backup..." >> /tmp/usb_add_info
fi
exit
EOF

# Make executable
chmod +x /etc/udev/script/usb_backup.sh

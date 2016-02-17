# Add a swapfile on the data store drive 
# (rsync needs this for large file copies)

# Skip if /etc/init.d/swap is already in FW
# 2015-09-25: use (existing) directory .vst/ for hosting swapfile
# 2016-02-05: Don't use sdcard for swapfile. /etc/init.d/vstfunc creates a .vst there...

if ! grep -q SWAP= /etc/firmware
then
{
# F800 .064 and WD03 .016 firmwares appear to use/create .vst/swapfile
echo "No SWAP= setting found in /etc/firmware, not modifying swap"
}
else
{
# Disable system SWAP, when WD01 remounts storage it doesn't issue a swapoff.
# Instead we start and stop swap in the backup script.
sed -i 's/^SWAP=.*/SWAP=noswap/' /etc/firmware
# create swap init script, to overwrite the "exit 0" one
cat <<'EOF' > /etc/init.d/swap
# Swap initialization on external medium
#rm -f /tmp/swapinfo
echo "Running $0" > /tmp/swapinfo
grep '^/dev/' /proc/mounts \
| while read device mountpoint fstype remainder
do
    echo "Checking $device at $mountpoint"
    if [ ${device:0:7} == "/dev/sd" -a -e "$mountpoint/.vst" ] && [[ $mountpoint != /data/UsbDisk1/* ]]
    then
        swapfile="$mountpoint/.vst/swapfile"
        # exit if $swapfile already in use
        if grep "^$swapfile\b" /proc/swaps
        then
            echo "Already using $swapfile"
            exit 0
        fi
        if [ -e "$swapfile" ]
        then
            echo "Found $swapfile"
            ls -l "$swapfile"
        else
            echo "Creating $swapfile"
            # large blocksize is flash-friendlier
            dd if=/dev/zero of="$swapfile" bs=1024k count=64
            # may have failed (lack of space etc.)
            if [ $? -ne 0 ]
            then
                rm -f "$swapfile"
                continue
            fi
            sync
        fi
        # no "file" command, no way to guess whether already initialized
        #file "$swapfile"
        # create swapfile signature
        mkswap "$swapfile"
        swapon "$swapfile"
        if [ $? -ne 0 ]
        then
            echo "$swapfile not used for swap, removing"
            rm -f "$swapfile"
            continue
        fi
        echo "Swap activated on $swapfile"
        exit 0
    fi
done >> /tmp/swapinfo 2>&1
exit 0
EOF
# Make executable, and run right now to create and test
chmod +x /etc/init.d/swap
echo pre-apply:
free
/etc/init.d/swap
echo post-apply:
free
echo swap log:
cat /tmp/swapinfo
}
fi

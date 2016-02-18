## RAVpower WD02 & WD01 ##

**Merged fbartels rsync files for sdcard backup**
I've not experienced empty files as I've been told fbartels has on his WD02.

**ToDo/Done:**
- [x] usb_backup.sh Include test to see if the destination is NTFS. Wifidisk code includes Tuxera ntfs-3g code which seems fine at copying at high speed but is unable to copy timestamps to the destination files and folders. Testing needed to see if removing -t when backing up to an NTFS destination resolves the SIGHUPS I've seen and smoothes things out.
- [x] Upload rsync to v3.1.1 , steve8x8 included 3.1.0 (not urgent as doesn't seem to fix anything for me, but is a fair bit smaller). Not found a 3.1.2 mipsel binary yet, please let me know if you have one.
- [x] Add busybox v1.21.1. Copy to and create symlinks in the .vst folder on the backup drive, then change the path in scripts to include this path.
- [ ] Add script to rsync backup files to online storage. Need to test the speed but likely to be faster than rsync for local backup. Problem: WD01 has no way of detecting cost of consumed bandwidth. The risk of incurring high costs are too great when tethered on mobile broadband. Possible switches could be a file on the backup drive (can move or rename using the "RAV filehub" app or via SMB). Then again, it may well be easier to use a smartphone app to do so (smb to online storage), but this would not be unattended.
- [x] Document using newer busybox via .vst on USB disk (adds missing tools like recursive grep when troubleshooting) [see below]
- [x] Prevent swap file from using sdcard. I'd prefer to use the USB HD instead for speed and less load on flash. went one step further and stopped auto starting swap file. When inserting anything storage a;; storage gets remounted to ensure the SDcard uses /dev/sda. This process doesn't stop the swap and thus things break with /proc/swaps showing a swap file at /.vst/swapfile that doesn't exist and has the highest priority. Solution is to add a swapon and swapoff to the backup script before and after rsync is called.
- [ ] Test if stopping services speeds up or makes rsync more stable (reduce cpu and memory load, restart services when done)
- [x] Add ability to backup other folders than DCIM. The script now looks for the file "sources.cnf" which is expected to contain the $sources variable as per below. I have a digital camera that stores videos in an obscure location. Each path results in a folder in the sd-import/<uuid>/<date> folder where paths are converted to folders by replacing slashes with dots. In my case I end up with a DCIM and "PRIVATE.AVCHD.BDMV" folders.
- [x] Added post rsync routine to clean up subfolders. rsync does remove files but not folders from the source.
- [x] Added log files in the incoming folder so there's an archive of what the backup script did and if things ran well. At least if something goes wrong, we have something to help us find out what it was.
- [x] Added extra logging to /tmp/usb_add_info. This is lost on reboot but helps troubleshooting via Telnet.

Example sources.cnf file:
```
# Folders to check for files to backup
sources="DCIM
PRIVATE/AVCHD/BDMV"
```

Before anyone asks. No the timestamp issue is not a common permission problem when mounting. "touch -t" works perfectly to update the timestamp of files on an NTFS mount. (Had to use a current busybox to test.) If you really must keep the timestamps when backing up to NTFS, you could have rsync just copy the files. And then add some code to update the timestamps (touch) before removing the old files. Too much work when I don't really care about the file timestamps when there's EXIF data that has a timestamp as well. Or reformat your backup disk to something else...

**The following blurb is still from steve8x8 that I forked the code from. Kudos to all those who've invested their time.**

When I had purchased a [http://www.ravpower.com/catalog/product/search/filehub](RAVPower FileHub)
[http://www.ravpower.com/rp-wd02-filehub-6000mah-power-bank-black.html](WD02), I quickly found that it wouldn't be
safe to operate in a public network, with lots of open ports, `telnet` being quite prominent.

There was a [https://web.archive.org/web/20141112135713/http://www.isartor.org/wiki/Securing_your_RavPower_Filehub_RP-WD01](Wiki page "**Securing your RavPower Filehub RP-WD01**" on http://www.isartor.org), and soon thereafter I found
[https://github.com/digidem/filehub-config](the original `filehub-config`), which was the starting
point for my own modifications.

I found that (on my WD02 - which is somewhat different from the WD01, details to be investigated)
some of the code snippets ("*scriptlets*") didn't work, and that they were combined in "some" order:
   * the name of the ethernet interface was wrong (that seems to be one of those differences)
   * the firewall would not be modified if the uplink was enabled/disabled
   * there was no IPv6 support
   * something didn't work with swap
   * a few scriptlets I didn't (and still don't) understand

What I did:
   * add prefix numbers for proper ordering of scriptlets
   * disable part of the scriptlets (in particular, the ones dealing with USB storage)
   * change makefile to make use of scriptlet numbering, and add comments to show "where this part came from"
   * add a new ntp.cfg for use in Europe
   * use `/.internal/donottouch/` instead of `/monitoreo/no_tocar/`; /.vst/swapfile to mimic recent FWs
   * debug, and change the firewall code, and the swap code
   * add logging (write all output next to the script)
   * patch /etc/*passwd to re-allow root logins
   * LEDs blink while `EnterRouterMode.sh` script is run - works for my WD02, need feedback for other devices
      * (In `telnet` console, run `/usr/sbin/pioctl {internet,status,wifi} {2,3}` - what happens?)
   * Add a `ChangePassword.sh` script that syncs encrypted passwords in multiple places (to be run in a `telnet` session)

This has been tested with firmwares up to 2.000.014, I didn't upgrade further yet since later fw versions may have telnetd disabled (or worse)
and therefore appreciate your feedback.

If you have a copy of previous firmware versions for WD01, WD02 or WD03 (or similar hardware), please contact me
(steve8x8 at googlemail).

Changes have been submitted to the original author but not incorporated so far, and since this fork has diverged
a lot, this will perhaps never happen anymore.

---

### Findings about firmware upgrades ###

Split off into [a separate page](doc/Firmwares.md).

### Further reading ###

Some [links](doc/Links.md).

---

Future plans:
   * support newer fw releases (when detailed info is available)
   * work for WD01 and WD03 (and perhaps future hardware) - need detailed info
   * think about supporting a USB 3G modem (???)
   * ... (suggestions welcome)

---

The old README is [here](doc/README_orig.md).

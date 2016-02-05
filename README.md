## RAVpower WD02 & WD01 ##

**Merged fbartels rsync files for sdcard backup**

The following blurb is still from steve8x8 that I forked the code from. Kudos to all those who've invested their time.

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

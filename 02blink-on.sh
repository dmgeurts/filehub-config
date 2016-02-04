# start blinking LEDs
# WD01: internet and wifi work, RW and battery status LEDs not blinking
# 
/usr/sbin/pioctl internet 2
sleep 0.2
#/usr/sbin/pioctl status 2
#sleep 0.2
/usr/sbin/pioctl wifi 2

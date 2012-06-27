#!/bin/sh
#git test
# v5 Removed NoFlip setting and added XBMC sync settings.
# v4 Adding support for XBMC Live
# v3 Added check for .nvidia-settings-rc
#
if [ "$(whoami)" = "root" ]; then echo "Do not run as root."; exit; fi
if [ ! "$DISPLAY" = "" ]; then echo "Run in a TTY. Press CTRL-ALT-F1"; exit; fi

###
echo "1/6 Backing up settings"
[ -d "$HOME/old" ] \
 || mkdir "$HOME/old"
[ ! -f "$HOME/old/xorg.conf" ] && [ -f /etc/X11/xorg.conf ] \
 && cp /etc/X11/xorg.conf "$HOME/old"
[ ! -f "$HOME/old/.nvidia-settings-rc" ] && [ -f $HOME/.nvidia-settings-rc ] \
 && cp "$HOME/.nvidia-settings-rc" "$HOME/old"
[ ! -f "$HOME/old/guisettings.xml" ] \
 && cp "$HOME/.xbmc/userdata/guisettings.xml" "$HOME/old"

echo "2/6 Applying Xorg settings"
sudo bash -c "echo '\
Section \"Device\"
        Identifier \"nvidia\"
        Driver  \"nvidia\"
        Option  \"NoLogo\"              \"true\"
        Option  \"DynamicTwinView\"     \"false\"
        Option  \"FlatPanelProperties\" \"Scaling = Native\"
        Option  \"ModeValidation\"      \"NoVesaModes, NoXServerModes,\
 NoVertRefreshCheck, NoHorizSyncCheck\"
        Option  \"UseDisplayDevice\"    \"DFP-1\"
        Option  \"ModeDebug\"           \"true\"
	Option  \"HWCursor\"            \"false\"
EndSection

Section \"Screen\"
        Identifier      \"screen\"
        Device          \"nvidia\"
        SubSection      \"Display\"
                Modes \"1920x1080_60\"
        EndSubSection
EndSection

Section \"Extensions\"
        Option  \"Composite\"           \"false\"
EndSection

' > /etc/X11/xorg.conf"

echo "3/6 Restarting Xorg to find available modes"
if [ -f /var/run/lightdm.pid ]; then 
 sudo service lightdm restart
else
 sudo service xbmc-live stop
 sleep 5
 sudo service xbmc-live start
fi
sleep 5
sudo bash -c "sed -n 's/(from: EDID)//g;/- Modes/,/- End/p' \
 /var/log/Xorg.0.log | cut -c32- | sed 's/^/# /g' >>/etc/X11/xorg.conf"

echo "4/6 Adding 23.97Hz and 59.94Hz to xorg.conf"
modes="$(sed -n '/- Modes/,/- End/p' /var/log/Xorg.0.log | sed 's/.*(0)://g' \
 | awk '/CEA-861B Format (32|16)/{printf $1 " "}')"
[ "$modes" = "" ] || sudo sed -i "s/Modes \".*/Modes $modes/" /etc/X11/xorg.conf
if [ -f /var/run/lightdm.pid ]; then 
 sudo service lightdm restart
else
 sudo service xbmc-live stop
 sleep 5
 sudo service xbmc-live start
fi

echo "5/6 Applying NVIDIA settings"
if [ -f /usr/lib/libgtk-x11-2.0.so.0 ]; then
 sleep 5
 export DISPLAY=:0
 nvidia-settings -a "SyncToVBlank=1" \
 		 -a "AllowFlipping=1" \
 		 -a "FSAAAppControlled=1" \
 		 -a "OpenGLImageSettings=3" \
 		 -a "LogAniso=0" \
 		 -a "GPUScaling=1,1"
 nvidia-settings -r
fi

echo "6/6 Applying XBMC settings"
f="$HOME/.xbmc/userdata/guisettings.xml"
v="usedisplayasclock";	sed -i "s/<$v>.*</<$v>true</"	$f
v="synctype";		sed -i "s/<$v>.*</<$v>0</"	$f
v="adjustrefreshrate";	sed -i "s/<$v>.*</<$v>true</"	$f
v="rendermethod";	sed -i "s/<$v>.*</<$v>4</"	$f
v="vsync";		sed -i "s/<$v>.*</<$v>2</"	$f
v="usepbo";		sed -i "s/<$v>.*</<$v>true</"	$f

echo "--- All done"

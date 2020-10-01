#!/bin/bash
function jumpto
{
    label=$1
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}
start=${1:-"start"}

jumpto $start

start:

echo -e "Initialising...\n"
sleep 1

REQUIRED_PKG="expect"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo "Checking for $REQUIRED_PKG:"
[[ "install ok installed" == "$PKG_OK" ]] && echo -e "$REQUIRED_PKG is installed!\n" || echo -e "$REQUIRED_PKG is not installed!\n"
if [ "" = "$PKG_OK" ]; then
  echo -e "Downloading and installing $REQUIRED_PKG now..."
  sudo apt install $REQUIRED_PKG -y
fi

read -rep $'Firstly have you been able to connect to your device using the GUI and is it a remembered device? (If its in the bluetooth menu on the panel when you click it then it is remembered) [y/n]:\n' GUI
case $GUI in
  y|Y) jumpto GUI ;;
  n|N) echo -e "Starting manual mode...\n" & jumpto manual ;; 
  *) echo "Invalid response exiting..." & sleep 2 & exit ;; 
esac

manual:

sudo killall bluealsa &> /dev/null
pulseaudio --start &> /dev/null

echo '#!/usr/bin/expect -f

set prompt "#"

spawn sudo bluetoothctl
expect -re $prompt
send "power on\r"
sleep 1
expect -re $prompt
send "agent on\r"
sleep 1
expect -re $prompt
send "default-agent\r"
sleep 1
expect -re $prompt
send "scan on\r"
sleep 5
interact' >> bluetooth_step1.sh
sleep 1
sudo chmod +x bluetooth_step1.sh
lxterminal --title "Bluetooth Program: Step 1" -e ./bluetooth_step1.sh & child=$!
let "child++"
echo -e "A new window will have just opened and is now scanning for your device\n"
echo -e "It may take a few seconds for your device to be found when it is it'll show the device name and a sequence of characters that look something like this:\n"
echo -e "C0:DC:DA:40:C8:C8\n"
echo -e "That is what is known as a MAC address and is what identifies your device every device has a different MAC address\n"
read -rep $'Please enter the MAC address of your device in this window [n/N to cancel]\n' MAC
case $MAC in  
  n|N) kill $child & exit ;; 
  *) kill $child ;; # The child must die xD
esac

sudo rm -rf ./bluetooth_step1.sh

jumpto connect

GUI:

read -rep $'Okay now right click on the sound icon and click on the name of your device. Has it now got a green tick next to it? [y/n]\n' connected
case $connected in
  y|Y)  echo -e "Starting MAC address finder...\n" ;;
  n|N) echo -e "Starting manual mode...\n" & jumpto manual ;; 
  *) echo -e "Invalid response exiting...\n" & sleep 2 & exit ;; 
esac

sudo killall bluealsa &> /dev/null
pulseaudio --start &> /dev/null

echo '#!/usr/bin/expect -f

set prompt "#"

spawn sudo bluetoothctl
expect -re $prompt
send "info\r"
interact' >> bluetooth_step1.sh
sleep 1
sudo chmod +x bluetooth_step1.sh
lxterminal --title "Bluetooth Program: Step 1" -e ./bluetooth_step1.sh & child=$!
let "child++"
echo -e "A new window will have just opened and has listed the device you just connected using the gui\n"
echo -e "It will now show a bunch of information we simply want the text on the first line next to 'Device' which looks something like this:\n"
echo -e "C0:DC:DA:40:C8:C8\n"
echo -e "That is what is known as a MAC address and is what identifies your device every device has a different MAC address\n"
read -rep $'Please enter the MAC address of your device in this window [n/N to cancel]\n' MAC
case $MAC in  
  n|N) kill $child & exit ;; 
  *) kill $child ;; 
esac

sleep 1
sudo rm -rf ./bluetooth_step1.sh

connect:

read -rep $'Please enter the name of the device\n' NAME

echo "#!/bin/bash

MAC="$MAC"

echo '#!/usr/bin/expect -f

set prompt "'"#"'"

spawn sudo bluetoothctl
expect -re \$prompt
send "'"power on\r"'"
sleep 1
expect -re \$prompt
send "'"agent on\r"'"
sleep 1
expect -re \$prompt
send "'"default-agent\r"'"
sleep 1
expect -re \$prompt
send "'"pair '$MAC'\r"'"
sleep 1
expect -re \$prompt
send "'"trust '$MAC'\r"'"
sleep 1
expect -re \$prompt
send "'"connect '$MAC'\r"'"
sleep 3
expect -re \$prompt
sleep 1
send "'"quit\r"'"
expect eof
' >> bluetooth_step2.sh
sleep 2
sudo chmod +x bluetooth_step2.sh
./bluetooth_step2.sh

sleep 1
sudo rm -rf ./bluetooth_step2.sh

sleep 2
arrMAC=(\${MAC//:/ })
pacmd set-card-profile bluez_card.\${arrMAC[0]}_\${arrMAC[1]}_\${arrMAC[2]}_\${arrMAC[3]}_\${arrMAC[4]}_\${arrMAC[5]} a2dp_sink
pacmd set-default-sink bluez_sink.\${arrMAC[0]}_\${arrMAC[1]}_\${arrMAC[2]}_\${arrMAC[3]}_\${arrMAC[4]}_\${arrMAC[5]}.a2dp_sink
echo -e 'WOW Your device is now connected opening volume control...\n'
lxterminal --command='alsamixer' --geometry=20x20
" >> "$NAME connect.sh"
sleep 2
sudo chmod +x "$NAME connect.sh"
./"$NAME connect.sh"
echo "A file called $NAME connect.sh was just created simply run this whenever you want to reconnect to the same device!"

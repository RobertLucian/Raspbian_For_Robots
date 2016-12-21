#! /bin/bash
echo -e "\E[32m"
echo "  _____            _                                ";
echo " |  __ \          | |                               ";
echo " | |  | | _____  _| |_ ___ _ __                     ";
echo " | |  | |/ _ \ \/ / __/ _ \ '__|                    ";
echo " | |__| |  __/>  <| ||  __/ |                       ";
echo " |_____/ \___/_/\_\\__\___|_| _        _            ";
echo " |_   _|         | |         | |      (_)           ";
echo "   | |  _ __   __| |_   _ ___| |_ _ __ _  ___  ___  ";
echo "   | | | '_ \ / _\` | | | / __| __| '__| |/ _ \/ __|";
echo "  _| |_| | | | (_| | |_| \__ \ |_| |  | |  __/\__ \ ";
echo " |_____|_| |_|\__,_|\__,_|___/\__|_|  |_|\___||___/ ";
echo -e "\E[0m"
echo "Welcome to GrovePi Installer."
echo " "
echo "Requirements:"
echo "1) Must be connected to the internet"
echo "2) This script must be run as root user"
echo " "
echo "Steps:"
echo "1) Installs package dependencies:"
echo "   - python-pip       alternative Python package installer"
echo "   - git              fast, scalable, distributed revision control system"
echo "   - libi2c-dev       userspace I2C programming library development files"
echo "   - python-serial    pyserial - module encapsulating access for the serial port"
echo "   - python-rpi.gpio  Python GPIO module for Raspberry Pi"
echo "   - i2c-tools        This Python module allows SMBus access through the I2C /dev"
echo "   - python-smbus     Python bindings for Linux SMBus access through i2c-dev"
echo "   - arduino          AVR development board IDE and built-in libraries"
echo "   - minicom          friendly menu driven serial communication program"
echo "2) Installs wiringPi in GrovePi/Script"
echo "3) Removes I2C and SPI from modprobe blacklist /etc/modprobe.d/raspi-blacklist.conf"
echo "4) Adds I2C-dev, i2c-bcm2708 and spi-dev to /etc/modules"
echo "5) Installs gertboard avrdude_5.10-4_armhf.deb package"
echo "6) Runs gertboard setup"
echo "   - configures avrdude"
echo "   - downloads gertboard known boards and programmers"
echo "   - replaces avrsetup with gertboards version"
echo "   - in /etc/inittab comments out lines containing AMA0"
echo "   - in /boot/cmdline.txt removes: console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1"
echo "   - in /usr/share/arduino/hardware/arduino creates backup of boards.txt"
echo "   - in /usr/share/arduino/hardware/arduino creates backup of programmers.txt"
echo " "
echo "Special thanks to Joe Sanford at Tufts University. This script was derived from his work. Thank you Joe!"
echo " "

echo " "
echo "Check for internet connectivity..."
echo "=================================="
wget -q --tries=2 --timeout=100 --output-document=/dev/null http://raspberrypi.org
if [ $? -eq 0 ];then
	echo "Connected"
else
	echo "Unable to Connect, try again !!!"
	exit 0
fi

echo " "
echo "Installing Dependencies"
echo "======================="
sudo apt-get install python-pip git libi2c-dev python-serial python-rpi.gpio i2c-tools python-smbus arduino minicom python-dev
sudo pip install -U RPi.GPIO
echo "Dependencies installed"

# Check if WiringPi Installed
# Check if WiringPi Installed and has the latest version.  If it does, skip the step.
version=`gpio -v`       # Gets the version of wiringPi installed
set -- $version         # Parses the version to get the number
WIRINGVERSIONDEC=$3     # Gets the third word parsed out of the first line of gpio -v returned.
                                        # Should be 2.32
echo $WIRINGVERSIONDEC >> tmpversion    # Store to temp file
VERSION=$(sed 's/\.//g' tmpversion)     # Remove decimals
rm tmpversion                           # Remove the temp file

if [ $VERSION -eq '232' ]; then

	echo "FOUND WiringPi Version 2.32 No installation needed."
else
	echo "Did NOT find WiringPi Version 2.32"
	# Check if the Dexter directory exists.
	DIRECTORY='/home/pi/Dexter'
	if [ -d "$DIRECTORY" ]; then
		# Will enter here if $DIRECTORY exists, even if it contains spaces
		echo "Dexter Directory Found!"
	else
		mkdir /home/pi/Dexter
	fi
	# Install wiringPi
	cd /home/pi/Dexter 	# Change directories to Dexter
	git clone https://github.com/DexterInd/wiringPi/  # Clone directories to Dexter.
	cd wiringPi
	./build
	echo "wiringPi Installed"
fi
# End check if WiringPi installed

echo " "
echo "Removing blacklist from /etc/modprobe.d/raspi-blacklist.conf . . ."
echo "=================================================================="
if grep -q "#blacklist i2c-bcm2708" /etc/modprobe.d/raspi-blacklist.conf; then
	echo "I2C already removed from blacklist"
else
	sudo sed -i -e 's/blacklist i2c-bcm2708/#blacklist i2c-bcm2708/g' /etc/modprobe.d/raspi-blacklist.conf
	echo "I2C removed from blacklist"
fi
if grep -q "#blacklist spi-bcm2708" /etc/modprobe.d/raspi-blacklist.conf; then
	echo "SPI already removed from blacklist"
else
	sudo sed -i -e 's/blacklist spi-bcm2708/#blacklist spi-bcm2708/g' /etc/modprobe.d/raspi-blacklist.conf
	echo "SPI removed from blacklist"
fi

#Adding in /etc/modules
echo " "
echo "Adding I2C-dev and SPI-dev in /etc/modules . . ."
echo "================================================"
if grep -q "i2c-dev" /etc/modules; then
	echo "I2C-dev already there"
else
	echo i2c-dev >> /etc/modules
	echo "I2C-dev added"
fi
if grep -q "i2c-bcm2708" /etc/modules; then
	echo "i2c-bcm2708 already there"
else
	echo i2c-bcm2708 >> /etc/modules
	echo "i2c-bcm2708 added"
fi
if grep -q "spi-dev" /etc/modules; then
	echo "spi-dev already there"
else
	echo spi-dev >> /etc/modules
	echo "spi-dev added"
fi

echo " "
echo "Making I2C changes in /boot/config.txt . . ."
echo "================================================"

# First delete any instances.  
sudo sed -e s/"dtparam=i2c1=on"//g -i /boot/config.txt
sudo sed -e s/"dtparam=i2c_arm=on"//g -i /boot/config.txt
echo dtparam=i2c1=on >> /boot/config.txt
echo dtparam=i2c_arm=on >> /boot/config.txt

#Adding ARDUINO setup files
echo " "
echo "Making changes to Arduino . . ."
echo "==============================="
cd /tmp
wget http://project-downloads.drogon.net/gertboard/avrdude_5.10-4_armhf.deb
sudo dpkg -i avrdude_5.10-4_armhf.deb
sudo chmod 4755 /usr/bin/avrdude

cd /tmp
wget http://project-downloads.drogon.net/gertboard/setup.sh
chmod +x setup.sh
sudo ./setup.sh

echo " "
echo "Making libraries global . . ."
echo "============================="
sudo cp /home/pi/Desktop/GrovePi/Script/grove.pth /usr/lib/python2.7/dist-packages/grove.pth

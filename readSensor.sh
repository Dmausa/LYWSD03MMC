#!/bin/bash
# This script uses common linux applications to get Temperature e Humidify data from Xiaomi LYWSD03MMC sensor.
#
# This script is a modification from original version to use mosquitto_pub to send data over MQTT to a broker.
# Thanks to the author.
#
# Reference: http://www.d0wn.com/using-bash-and-gatttool-to-get-readings-from-xiaomi-mijia-lywsd03mmc-temperature-humidity-sensor/
#
# This version works fine in a Raspberry Pi 3+.
# Use crontab to scheduler an execution every minute.
#
# Dependences (often resolved with apt install):
# - bluez
# - awk
# - bc
# - mosquitto_pub
#
# Use the command below to find the device mac address 
#    sudo hcitool lescan
#
# 

# Assign default values if parameters are not provided
mac_address_list=${1:-"MAC address missing"}
sensor_name=${2:-"Sensor"}
timer_seconds=${3:-0} #Will run only once if not provided or if set to 0.
mqtt_server=${4:-"localhost"}

while true; do
    for count in ${!mac_address_list[@]}; do
        idx=$(expr "$count" + "1")
        mac_address=${mac_address_list[$count]}
        sensor_name_idx="$sensor_name$idx"

        bt=$(timeout 15 gatttool -b $mac_address --char-write-req --handle='0x0038' --value="0100" --listen)
        if [ -z "$bt" ]
        then
            echo "The reading failed"
        else
            echo "Got data"
            #echo $bt 
            temphexa=$(echo $bt | awk -F ' ' '{print $12$11}'| tr [:lower:] [:upper:] )
            humhexa=$(echo $bt | awk -F ' ' '{print $13}'| tr [:lower:] [:upper:])
            temperature100=$(echo "ibase=16; $temphexa" | bc)
            humidity=$(echo "ibase=16; $humhexa" | bc)
            temperature=$(echo "scale=2;$temperature100/100"|bc)
            echo $temperature
            echo $humidity
    
            if [ ! ${#temperature} -ge 6 ] 
            then
            mosquitto_pub -h $mqtt_server -m $temperature -t /LYWSD03MMC/$sensor_name_idx/Temperature -d
            fi

            if [ ! ${#humidity} -ge 3 ] 
            then
            mosquitto_pub -h $mqtt_server -m $humidity -t /LYWSD03MMC/$sensor_name_idx/Humidity -d
            fi
        fi
    done

  if [ "$timer_seconds" -eq 0 ]; then
    break  # Exit the loop after running once
  fi
  # Sleep for the specified time before running again
  sleep "$timer_seconds"  # Wait for the specified time
done




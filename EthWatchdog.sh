#!/bin/ash

readonly lastProcessedActionStoragePath='/tmp/EthWatchdogStorage.txt'
readonly interfaceFingerprint='Atheros AR8216/AR8236/AR8316 ag71xx-mdio.0:00: Port 1'
readonly freezePeriod=15000000

getCurrentAction(){
	dmesg					|
		grep -F "$interfaceFingerprint" |
		tail -n 1

	return $?
}

getPreviousAction(){
	dmesg					|
		grep -F "$interfaceFingerprint"	|
		tail -n 2			|
		head -n 1

	return $?
}

getLastProcessedAction(){
	if [ ! -f "$lastProcessedActionStoragePath" ]; then
		return 1
	fi

	cat "$lastProcessedActionStoragePath"
	return $?
}

setLastProcessedAction(){
	if [ $# -lt 1 ]; then
		return 127
	fi

	local action="$1"

	echo "$action" > "$lastProcessedActionStoragePath"
	return $?
}

getActionTimestamp(){
	if [ $# -lt 1 ]; then
		return 127
	fi

	local action="$1"

	local timestamp=$(
		echo "$action" 			|
		grep -oE '^\[[0-9]*\.[0-9]*\]'  |
		grep -oE '[0-9]*\.[0-9]*'
	)

	timestamp=${timestamp/\./}

	echo "$timestamp"

	return $?
}

getActionStatus(){
        if [ $# -lt 1 ]; then                               
                return 127                                  
        fi                                                  
                                                                         
        local action="$1"

	echo "$action"				|
		grep -oE 'is (up|down)$'	|
		grep -oE '(up|down)'
	
	return $?
}



currentAction=$(getCurrentAction)
echo "\$currentAction=[$currentAction]"
if [ -z "$currentAction" ]; then
	exit 0
fi

currentActionTime=$(getActionTimestamp "$currentAction")
currentActionStatus=$(getActionStatus "$currentAction")

echo "\$currentActionTime=[$currentActionTime]"
echo "\$currentActionStatus=[$currentActionStatus]"

lastProcessedAction=$(getLastProcessedAction)
echo "\$lastProcessedAction=[$lastProcessedAction]"

lastProcessedActionTime=$(getActionTimestamp "$lastProcessedAction")
lastProcessedActionStatus=$(getActionStatus "$lastProcessedAction")

echo "\$lastProcessedActionTime=[$lastProcessedActionTime]"
echo "\$lastProcessedActionStatus=[$lastProcessedActionStatus]"

if [ "$lastProcessedActionTime" == "$currentActionTime" ] && [ "$lastProcessedActionStatus" == "$currentActionStatus" ]; then
	echo "Same. Nothing has happened. Exiting."
	exit 0
fi

setLastProcessedAction "$currentAction"

previousAction=$(getPreviousAction)
previousActionTime=$(getActionTimestamp "$previousAction")
previousActionStatus=$(getActionStatus "$previousAction")

echo "\$previousAction=[$previousAction]"
echo "\$previousActionTime=[$previousActionTime]"
echo "\$previousActionStatus=[$previousActionStatus]"

echo "Status has changed [$previousActionStatus] -> [$currentActionStatus]"
echo "Previous status has lasted during period of [$previousActionTime] - [$currentActionTime]"

if [ "$currentActionTime" -lt $freezePeriod ]; then
	echo "Too early for disconnection. Exiting."
	exit 0
fi


if [ "$previousActionStatus" == "down" ] && [ "$currentActionStatus" == "up" ]; then
	echo "Going to reconnect eth0.2 ..."
	
	ifconfig eth0.2 down
	ifconfig eth0.2 up

	echo "Done."
fi

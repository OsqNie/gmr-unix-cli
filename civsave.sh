#!/bin/sh

CONFIGFILE="civsave.config"
SAVE_ARCHIVE="old_saves"
WEBURL="http://multiplayerrobot.com/api/Diplomacy/"
BASE_URL="http://multiplayerrobot.com/"


if ! [ -e $CONFIGFILE ]; then
    echo "Type your player authentication key and press [ENTER]"
    read authkey
    echo "AUTHKEY=\"${authkey}\"" >> $CONFIGFILE
    echo "Type the game id and press [ENTER]"
    read gameid
    echo "GAMEID=\"${gameid}\"" >> $CONFIGFILE
    echo "Now enter the absolute path to your saved games folder"
    echo "without trailing slash and press [ENTER]"
    read savepath
    echo "SAVEPATH=\"${savepath}\"" >> $CONFIGFILE
    echo "Reading player id from server..."
    playerid=$(curl "${WEBURL}AuthenticateUser?authKey=${authkey}")
    echo "Player id ${playerid}"
    echo "PLAYERID=\"${playerid}\"" >> $CONFIGFILE
fi

source $CONFIGFILE

case "$1" in
    help)
        echo "gmr-cli - a Giant Multiplayer Robot command line manager"
        echo ""
        echo "Download and upload your data to GMR"
        echo ""
        echo "Arguments:"
        echo "help - Display this help"
        echo "reset - Delete config file"
        echo "down - Download the latest turn file"
        echo "up - Upload the latest save file in your specified folder"
	echo "set - Switch to the save config {}_civsave.config"
	echo "save - Save the current config file to $SAVE_ARCHIVE/"
        echo ""
        echo "New configs are automatically prompted at startup if no config"
        echo "file is detected"
        ;;

    reset)
        echo "Removing old configs..."
        if [ -e $CONFIGFILE ]; then
            rm $CONFIGFILE
            echo "Done!"
        else
            echo "File not found, nothing removed"
        fi
        ;;

    down)
        echo "Downloading the latest game file..."
        if ! [ -e "${SAVEPATH}/GMR_Game_${GAMEID}_Play_Me.Civ5Save" ]; then
            rm "${SAVEPATH}/GMR_Game_${GAMEID}_Play_Me.Civ5Save"
        fi
            curl -o "${SAVEPATH}/GMR_Game_${GAMEID}_Play_Me.Civ5Save" "${WEBURL}GetLatestSaveFileBytes?authKey=${AUTHKEY}&GAMEID=${GAMEID}"
        ;;


    up)
        echo "Fetching turn data"
        # This ugly-ass piece of python finds the respective game id and returns the number
	turn=$(curl -s "${WEBURL}GetGamesAndPlayers?playerIDText=${PLAYERID}&authKey=${AUTHKEY}" | \
		python -c "
import sys, json
for game in json.load(sys.stdin)['Games']:
	if (game['GameId'] == ${GAMEID}):
		print game['CurrentTurn']['TurnId']
		sys.exit()
")
        if [ -z "$turn" ]; then
            echo "Turn data could not be fetched. Are you online?"
        else
            echo "Success! Turn ${turn}"
        fi
        newest=$(ls -t "${SAVEPATH}"/*.Civ5Save | head -1)
        echo "Newest save file detected in ${newest}. Copying..."

	rm tmp/*
	cp "${newest}" "tmp/${turn}.Civ5Save" 
	up_file=tmp/${turn}.Civ5Save 

	echo "Done!"

        if [ -e "${up_file}" ];then
            echo "Submitting turn..."
	    status=$(curl \
		   -F "turnId=${turn}" \
		   -F "isCompressed=False" \
		   -F "authKey=${AUTHKEY}" \
		   -F "saveFileUpload=@${up_file}" \
		      ${BASE_URL}Game/UploadSaveClient)
            echo "Response: ${status}"
        else
            echo "Could not open the save file"
        fi
        ;;

    set)
	echo "Switching to $2..."
	if [ -e "$SAVE_ARCHIVE/$2_civsave.config" ];then
	    cp "$SAVE_ARCHIVE/$2_civsave.config" civsave.config
            echo "Done!"
	else
            echo "Could not find the save by name $2."
        fi
        ;;

    save)
	echo "Saving the config file..."
	if [ ! -d "$SAVE_ARCHIVE" ]; then
	    echo "Save folder not found, creating folder $SAVE_ARCHIVE"
	    mkdir $SAVE_ARCHIVE
	fi
	echo "Copying file..."
	cp $CONFIGFILE $SAVE_ARCHIVE/$2_$CONFIGFILE
        echo "Done!"
	;;      

    *)
        echo "Hi!"
        ;;
esac

#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# Set variables
GAMEDIR="/$directory/ports/starship"

# Exports
export LD_LIBRARY_PATH="$GAMEDIR/libs:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG=$sdl_controllerconfig
export PATCHER_FILE="$GAMEDIR/tools/otrgen"
export PATCHER_GAME="$(basename "${0%.*}")" # This gets the current script filename without the extension
export PATCHER_TIME="5 to 10 minutes"

# CD and set permissions
cd $GAMEDIR
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1
$ESUDO chmod +x -R $GAMEDIR/*

# Check imgui.ini and modify if needed
input_file="imgui.ini"
temp_file="imgui_temp.ini"
skip_section=0
# Loop through each line in the input file
while IFS= read -r line; do
    # Check if the line is a window header
    if [[ "$line" =~ ^\[Window\]\[Main\ Game\] || "$line" =~ ^\[Window\]\[Main\ -\ Deck\] ]]; then
        skip_section=1  # Set the flag to skip modifications for this section
    elif [[ "$line" =~ ^\[Window\] ]]; then
        skip_section=0  # Reset the flag for other windows
    fi

    # Modify Pos and Size only if the current section is not skipped
    if [[ $skip_section -eq 0 ]]; then
        if [[ "$line" =~ ^Pos=.* ]]; then
            echo "Pos=30,30" >> "$temp_file"
        elif [[ "$line" =~ ^Size=.* ]]; then
            echo "Size=400,300" >> "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    else
        # If skipping, write the line unchanged
        echo "$line" >> "$temp_file"
    fi
done < "$input_file"

# Replace the original file with the modified one
mv "$temp_file" "$input_file"

# Check if we need to generate any o2r files
if [ ! -f "sf64.otr" ]; then
    # Ensure we have a rom file before attempting to generate o2r
    if ls *.*64 1> /dev/null 2>&1; then
        if [ -f "$controlfolder/utils/patcher.txt" ]; then
            source "$controlfolder/utils/patcher.txt"
            $ESUDO kill -9 $(pidof gptokeyb)
        else
            pm_message "This port requires the latest version of PortMaster."
        fi
    else
        pm_message "Missing ROM files! Can't generate o2r!"
    fi
fi

# Check if OTR files were generated
if [ ! -f "sf64.otr" ]; then
    echo "No otr found, can't run the game!"
    exit 1
fi

# Run the game
pm_message "Loading, please wait... (might take a while!)"
$GPTOKEYB "Starship" -c "starship.gptk" & 
pm_platform_helper "$GAMEDIR/Starship"
./Starship

# Cleanup
rm -rf "$GAMEDIR/logs/"
pm_cleanup

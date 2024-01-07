# This script provides a comprehensive framework for a directory selection system, designed
# to learn from user behaviour using frequency and recency metrics to rank directories. Special
# attention has been paid to Termux's environment and Android's filesystem characteristics.
# The comments explain functionality and the design rationale behind different sections to ensure
# clarity and effective maintainability. The purpose of this Zsh code snippet, is to
# empower, automate and augment Zsh commandline functionality, specifically in relation to a system
# directory search. This script defines a function called sssdir that allows the user to select a
# directory using fzf, a command-line fuzzy finder. The function also uses a history file to keep
# track of the directories the user has visited and rank them based on frequency and recency. The
# function also includes an animated indicator to show the progress of the search.
# The function can be invoked with or without an argument. If an argument is supplied, it will be
# used as a query to search for directories. If no argument is supplied, it will use the history
# file to present the most relevant directories.
#
# **************************************************×*******************************************
#
# DATE:                 Sunday January 7, 2024
# WRITER:               Beauford A. Stenberg
# PROJECT NAME:         sssdir (v.1.0)
# WEBJOURNAL:           https://hashnode.com/@b9Joker108
# X:                    https://x.com/AntonBeauford
# WHATSAPP:             https://wa.me/61442507449
# GITHUB PROFILE:       https://www.github.com/b9Joker108
# GITHUB REPOSITORY:    https://github.com/b9Joker108/sssdir/tree/main
# LICENCE:              GNU GENERAL PUBLIC LICENSE (Version 3)
#
#
# **********************************************************************************************
#
# Optimal Zsh shebang
#! /data/data/com.termux/files/usr/bin/zsh

# Define home, storage and history file directory paths in the Termux environment.
HOME_DIR="/data/data/com.termux/files/home"
STORAGE_DIR="$HOME_DIR/storage"
HISTORY_FILE="$HOME_DIR/.dir_history"

# Define animated search indicator with large, colourful, randomly changing dots.
spinner() {
    local pid=$1 # The process id of the background search command
    local delay=0.1 # The delay between each frame of the animation
    local colors=(
        '\e[1;91m' '\e[1;92m' '\e[1;93m' '\e[1;94m' '\e[1;95m' '\e[1;96m'
    )  # Bright color escape sequences
    local nc='\e[0m'  # Reset color escape sequence

    # Hide cursor and save position
    tput civis
    echo -en "\e[s"

    # Enhanced spinner frames with larger dots and randomized colors
    local frames=(
        '⣾'  # Full block
        '⣽'  # Lower half block
        '⣻'  # Upper half block
        '⢹'  # Diagonal blocks
    )
    while kill -0 "$pid" 2>/dev/null; do # While the search command is still running
        local i=$((RANDOM % ${#frames[@]}))  # Randomly select a frame
        local color=${colors[$((RANDOM % ${#colors[@]}))]}  # Randomly select a color
        echo -en "\e[u${color}${frames[$i]}${nc} Performing search..." # Display indicator with frame
        sleep "$delay" # Wait for the delay
    done

    # Clear line and show cursor
    echo -en "\e[u\e[2K\e[?25h"
}

# Update history with the selected directory
update_history() {
    local dir="$1" # The selected directory
    local timestamp=$(date +%s) # The current timestamp

    # Temporarily redirect history if it doesn't have dir; otherwise, increment freq.
    touch "${HISTORY_FILE}.tmp" # Create a temporary file
    awk -v dir="$dir" -v ts="$timestamp" -F'\t' '
        BEGIN { OFS=FS } # Set the output field separator to the same as the input field separator
        {
            if ($1 == dir) { # If the directory is already in the history file
                $2++;  # Increase frequency
                $3=ts  # Update timestamp
                printed=1 # Set a flag to indicate that the directory was found
            }
            print $0 # Print the line
        }
        END {
            if (!printed) { # If the directory was not found in the history file
                print dir, 1, ts  # Add a new entry with frequency 1 and current timestamp
            }
        }
    ' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && \
    mv -f "${HISTORY_FILE}.tmp" "$HISTORY_FILE"  # Use -f option to force overwrite without prompt
}

# Score the directories based on frequency and recency
calculate_scores() {
    awk -v now="$(date +%s)" -F'\t' '
        # Priority score calculation: frequent folders with a fresh timestamp get a low weight
        print int($2 / (now - $3 + 1)), $1
    ' "$HISTORY_FILE" | sort -n | cut -d" " -f2- # Sort the directories by score & print dir names
}

# Main function for using fzf to navigate directories
sssdir() {
    local query="$1" # The optional argument for the search query
    local selection # The variable to store the selected directory

    if [[ -n "$query" ]]; then # If the query is not empty
        # Run search with indicator animation
        (
            find "$HOME_DIR" "$STORAGE_DIR" -type d -iname "*$query*" -print 2>/dev/null | \
            sort | fzf --height 40% --border --prompt "Select Directory: "
        ) &  # Run the search command in the background and pipe the output to fzf
        spinner $!  # Run the indicator function with the background process id
        wait $!  # Wait for the background process to finish
        selection=$(cat "${!}f")  # Get selection from named pipe of background process
    else # If the query is empty
        # Select directory based on history if no query supplied
        selection=$(calculate_scores | fzf --height 40% --border --prompt "Select Directory: " --tac)
        # --tac in the above, lists results starting from most recent
    fi

    if [[ -n "$selection" ]] && [[ -d "$selection" ]]; then
            # In above, if selection is not empty & is a valid directory
        # Change directory & update history if valid selection made
        cd "$selection" || return # Change directory or return if failed
        update_history "$selection" # Update the history file with the selected directory
        echo "Navigated to: $selection" # Print a confirmation message
    else # If the selection is empty or invalid
        echo "Directory selection was cancelled or an error occurred." # Print an error message
    fi
}

# Make sure history file exists; if not, create it
[[ ! -f "$HISTORY_FILE" ]] && touch "$HISTORY_FILE"

# To execute, the function is to be manually triggered by user

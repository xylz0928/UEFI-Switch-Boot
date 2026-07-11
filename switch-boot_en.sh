#!/usr/bin/env bash

# ============================================================================
# switch-boot - One-time GRUB boot entry switcher
# Supports single-key response: press q to cancel immediately, Enter to confirm default
# ============================================================================

set -o errexit
set -o nounset
set -o pipefail

# ----------------------------------------------------------------------------
# Color definitions (using tput for better compatibility)
# ----------------------------------------------------------------------------
if [ -t 1 ]; then
    readonly COLOR_RED=$(tput setaf 1)
    readonly COLOR_GREEN=$(tput setaf 2)
    readonly COLOR_YELLOW=$(tput setaf 3)
    readonly COLOR_RESET=$(tput sgr0)
else
    readonly COLOR_RED=""
    readonly COLOR_GREEN=""
    readonly COLOR_YELLOW=""
    readonly COLOR_RESET=""
fi

# ----------------------------------------------------------------------------
# Error handling function
# ----------------------------------------------------------------------------
error_exit() {
    printf "${COLOR_RED}Error: %s${COLOR_RESET}\n" "$*" >&2
    exit 1
}

# ----------------------------------------------------------------------------
# Privilege check
# ----------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    error_exit "This script requires root privileges, please use: sudo switch-boot"
fi

# ----------------------------------------------------------------------------
# Check GRUB configuration file
# ----------------------------------------------------------------------------
GRUB_CFG="/boot/grub/grub.cfg"
if [ ! -f "$GRUB_CFG" ]; then
    error_exit "GRUB configuration file not found: $GRUB_CFG"
fi

# ----------------------------------------------------------------------------
# Parse GRUB menu entries
# ----------------------------------------------------------------------------
if ! mapfile -t menu_items < <(awk -F\' '/^menuentry / {print $2}' "$GRUB_CFG" 2>/dev/null); then
    error_exit "Failed to parse GRUB configuration file"
fi

if [ ${#menu_items[@]} -eq 0 ]; then
    error_exit "No GRUB boot entries found"
fi

# ----------------------------------------------------------------------------
# Display menu list
# ----------------------------------------------------------------------------
printf "\n${COLOR_GREEN}====== GRUB Boot Menu Entries ======${COLOR_RESET}\n"
for i in "${!menu_items[@]}"; do
    printf "  %2d : %s\n" "$i" "${menu_items[$i]}"
done
printf "${COLOR_GREEN}=====================================${COLOR_RESET}\n\n"

# ----------------------------------------------------------------------------
# Auto-detect default target (Windows)
# ----------------------------------------------------------------------------
DEFAULT_INDEX=-1
DEFAULT_TITLE=""
for i in "${!menu_items[@]}"; do
    if [[ "${menu_items[$i]}" =~ Windows|Boot[[:space:]]Manager ]]; then
        DEFAULT_INDEX="$i"
        DEFAULT_TITLE="${menu_items[$i]}"
        break
    fi
done

if [ "$DEFAULT_INDEX" -eq -1 ]; then
    DEFAULT_INDEX=0
    DEFAULT_TITLE="${menu_items[0]}"
    printf "${COLOR_YELLOW}Warning: No Windows entry found, defaulting to: %s${COLOR_RESET}\n" "$DEFAULT_TITLE"
fi

# ----------------------------------------------------------------------------
# Display prompt information
# ----------------------------------------------------------------------------
printf "${COLOR_GREEN}Default selected:${COLOR_RESET} [%d] %s\n" "$DEFAULT_INDEX" "$DEFAULT_TITLE"
printf "Waiting ${COLOR_YELLOW}10${COLOR_RESET} seconds, will auto-reboot into the above if no action.\n"
printf "Press ${COLOR_YELLOW}Enter${COLOR_RESET} to confirm default, type ${COLOR_YELLOW}index${COLOR_RESET} to switch to another entry, "
printf "or press ${COLOR_YELLOW}q${COLOR_RESET} to cancel immediately\n"
printf "\nYour choice: "

# ----------------------------------------------------------------------------
# Read user input (single character or number, 10-second timeout)
# ----------------------------------------------------------------------------
TARGET=""
# Use -n1 to read one character, -t for timeout
if read -r -t 10 -n1 key; then
    # Check if empty (Enter key)
    if [ -z "$key" ]; then
        TARGET="$DEFAULT_TITLE"
        printf "\n\n${COLOR_GREEN}Default confirmed${COLOR_RESET}\n"
    elif [ "$key" = "q" ] || [ "$key" = "Q" ]; then
        printf "\n\n${COLOR_GREEN}Operation cancelled, system will not reboot.${COLOR_RESET}\n"
        exit 0
    elif [[ "$key" =~ ^[0-9]$ ]]; then
        # Only pressed a single digit (0-9), but it might be a single-digit index
        # Need to wait for user to decide if more digits are coming
        # Process: record the digit, then continue reading the complete input
        number="$key"
        # Wait 2 more seconds to see if additional digits are entered
        printf "\n"
        if read -r -t 2 -n1 extra; then
            # If another digit was entered, concatenate
            if [[ "$extra" =~ ^[0-9]$ ]]; then
                number="${number}${extra}"
                # Continue reading until non-digit or timeout
                while read -r -t 1 -n1 extra2; do
                    if [[ "$extra2" =~ ^[0-9]$ ]]; then
                        number="${number}${extra2}"
                    else
                        break
                    fi
                done
            fi
        fi
        printf "\n"
        if [ "$number" -ge 0 ] && [ "$number" -lt "${#menu_items[@]}" ]; then
            TARGET="${menu_items[$number]}"
            printf "${COLOR_GREEN}Switched to:${COLOR_RESET} [%d] %s\n" "$number" "$TARGET"
        else
            error_exit "Index %d out of range (0-%d)" "$number" "$((${#menu_items[@]} - 1))"
        fi
    else
        # Other keys (e.g. letters) treated as invalid, use default
        TARGET="$DEFAULT_TITLE"
        printf "\n\n${COLOR_YELLOW}Invalid input, using default selection${COLOR_RESET}\n"
    fi
else
    # Timeout
    TARGET="$DEFAULT_TITLE"
    printf "\n\n${COLOR_YELLOW}Input timeout, automatically selecting default${COLOR_RESET}\n"
fi

# ----------------------------------------------------------------------------
# Execute grub-reboot
# ----------------------------------------------------------------------------
printf "\n${COLOR_GREEN}Setting next boot entry to:${COLOR_RESET} %s\n" "$TARGET"

if ! grub-reboot "$TARGET" 2>/dev/null; then
    error_exit "grub-reboot failed, please check if the target entry exists: %s" "$TARGET"
fi

# ----------------------------------------------------------------------------
# Confirm and reboot
# ----------------------------------------------------------------------------
printf "\n${COLOR_GREEN}✓ Successfully set, system will reboot now...${COLOR_RESET}\n"
printf "${COLOR_YELLOW}Hint: Press Ctrl+C to cancel reboot (but the boot entry has already been set)${COLOR_RESET}\n"
sleep 3

systemctl reboot -i

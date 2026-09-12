#!/bin/bash
# set -e

# ==============================================================================
# 0. SCRIPT LOCATION (fix: don't rely on caller's $PWD)
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==============================================================================
# 1. GLOBAL COLORS, LOGGING & UI HELPERS
# ==============================================================================
RESET='\e[0m'
BOLD='\e[1m'
BLUE='\e[34m'
CYAN='\e[36m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'

# Initialize Log File
LOG_FILE="$SCRIPT_DIR/setup.log"
echo "===================================================" >"$LOG_FILE"
echo "Dotfiles Setup Execution - $(date +'%Y-%m-%d %H:%M:%S')" >>"$LOG_FILE"
echo "===================================================" >>"$LOG_FILE"

# Dual-Output Formatting Helpers
print_header() {
	echo -e "\n${BOLD}${BLUE}:: $1${RESET}"
	echo -e "\n[$(date +'%H:%M:%S')] === MODULE: $1 ===" >>"$LOG_FILE"
}

print_step() {
	printf "  %-45s " "$1"
	# Log the step start without a newline, so the status appends to the same line
	printf "[%s] %-45s " "$(date +'%H:%M:%S')" "$1" >>"$LOG_FILE"
}

print_success() {
	printf "[ ${GREEN}DONE${RESET} ]\n"
	echo "[ DONE ]" >>"$LOG_FILE"
}

print_skip() {
	printf "[ ${YELLOW}SKIP${RESET} ]\n"
	echo "[ SKIP ]" >>"$LOG_FILE"
}

print_fail() {
	printf "[ ${RED}FAIL${RESET} ]\n"
	echo "[ FAIL ]" >>"$LOG_FILE"
}

print_info() {
	echo -e "  ${CYAN}$1${RESET}"
	echo "[$(date +'%H:%M:%S')] INFO: $1" >>"$LOG_FILE"
}

# ==============================================================================
# 2. CORE FUNCTIONS
# ==============================================================================

function check_sudo() {
	print_header "System Verification"

	# 1. Prevent running the script completely as root
	print_step "Checking execution context"
	if [ "$EUID" -eq 0 ]; then
		print_fail
		echo -e "  ${RED}-> FATAL: Do not run this script as root (e.g., sudo ./setup.sh).${RESET}"
		echo -e "  ${CYAN}-> Run it as your normal user. The script will ask for your password safely.${RESET}"
		exit 1
	fi
	print_success

	# 2. Ask for the password upfront and validate sudo access
	print_step "Verifying sudo privileges"
	# 'sudo -v' asks for the password and caches the credential
	if sudo -v >/dev/null 2>&1; then
		print_success
	else
		print_fail
		echo -e "  ${RED}-> FATAL: You need sudo privileges to run this script.${RESET}"
		exit 1
	fi

	# 3. Background keep-alive loop
	(while true; do
		sudo -n true
		sleep 60
		kill -0 "$$" || exit
	done 2>/dev/null) &
}

function apt_install() {
	local PKG_NAME="${2:-$1}"
	print_step "apt: $PKG_NAME"

	if dpkg -s "$PKG_NAME" &>/dev/null; then
		print_skip
	else
		sudo apt-get install -y "$PKG_NAME" >>"$LOG_FILE" 2>&1
		local apt_status=$?

		if [ $apt_status -eq 0 ]; then
			print_success
		else
			print_fail
		fi
	fi
}

function pipx_install() {
	local APP="$1"

	print_step "pipx: $APP"
	if ! command -v "$APP" &>/dev/null; then
		if pipx install "$APP" >/dev/null 2>&1; then
			print_success
		else
			print_fail
			return 1
		fi
	else
		print_skip
	fi
}

# The Master Symlink Engine: Handles backups, readlink skips, and forcing replacements
function create_symlink() {
	local src="$1"
	local target="$2"
	local name
	name=$(basename "$target")

	print_step "link: $name"

	# 1. Ensure parent directory exists
	mkdir -p "$(dirname "$target")"

	# 2. Backup if it's a real file
	if [ -e "$target" ] && [ ! -L "$target" ]; then
		mv "$target" "${target}.bak"
		ln -sf "$src" "$target"
		print_success
	# 3. Skip if symlink already points to the correct dotfile
	elif [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
		print_skip
	# 4. Otherwise, create/force replace the link
	else
		ln -sf "$src" "$target"
		print_success
	fi
}

# ==============================================================================
# 3. SETUP MODULES
# ==============================================================================

function setup_pipx() {
	print_header "Pipx"
	apt_install pipx
	print_step "pipx: ensurepath"
	pipx ensurepath >/dev/null 2>&1 || true
	print_success
}

function setup_syncthing() {
	print_header "Syncthing"
	apt_install syncthing

	print_step "service: syncthing@$USER.service"
	if ! systemctl is-active --quiet syncthing@$USER.service; then
		sudo systemctl enable --now syncthing@$USER.service >/dev/null 2>&1
		print_success
	else
		print_skip
	fi
}

function setup_conan() {
	print_header "Conan"
	pipx_install conan
	create_symlink "$SCRIPT_DIR/conan" "$HOME/.conan2/profiles"
}

function setup_grub() {
	print_header "GRUB Bootloader"
	local GRUB_THEMES_DIR="/usr/share/grub/themes"
	local MY_GRUB_THEMES="$SCRIPT_DIR/grub"

	for theme_dir in "$MY_GRUB_THEMES"/*; do

		if [ -e "$theme_dir" ]; then
			# Safely create a NEW variable for the basename
			local theme_name=$(basename "$theme_dir")

			case "$theme_name" in
			Elegant-grub2-themes | some_other_theme | test_theme)
				continue
				;;
			esac

			local target="$GRUB_THEMES_DIR/$theme_name"

			print_step "link (sudo): $theme_name"

			if [ -e "$target" ] && [ ! -L "$target" ]; then
				sudo mv "$target" "${target}.bak"
				# Link using the absolute path ($theme_dir)
				sudo ln -sf "$theme_dir" "$target"
				print_success
			elif [ -L "$target" ] && [ "$(readlink "$target")" = "$theme_dir" ]; then
				print_skip
			else
				# Link using the absolute path ($theme_dir)
				sudo ln -sf "$theme_dir" "$target"
				print_success
			fi
		fi
	done

	sudo mkdir -p "/usr/share/grub/themes/custom_theme"
	sudo chown $USER:$USER "/usr/share/grub/themes/custom_theme/background.jpg" >> $LOG_FILE

	print_step "Updating GRUB configuration"
	sudo update-grub >>"$LOG_FILE" 2>&1
	print_success
}

function setup_kitty() {
	print_header "Kitty Terminal"
	apt_install kitty
	create_symlink "$SCRIPT_DIR/kitty" "$HOME/.config/kitty"
}

function setup_fzf() {
	print_header "FZF"
	apt_install fzf
}

function setup_lazygit() {
	print_header "LazyGit"
	apt_install lazygit
}

function setup_fd_find() {
	print_header "FD Find"
	apt_install fdfind fd-find

	print_step "link: fd -> fdfind shim"
	mkdir -p "$HOME/.local/bin"
	if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
		ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
		print_success
	else
		print_skip
	fi
}

function setup_ripgrep() {
	print_header "RipGrep"
	apt_install rg ripgrep
}

function setup_unzip() {
	print_header "Unzip"
	apt_install unzip
}

function setup_lua() {
	print_header "Lua"
	print_step "apt: lua5.4 stack"
	if sudo apt-get install -y lua5.4 liblua5.4-dev luajit libluajit-5.1-dev luarocks >/dev/null 2>&1; then
		print_success
	else
		print_fail
	fi
}

function setup_neovim() {
	print_header "NeoVim Dependencies"

	# Using the updated quiet functions
	setup_fzf
	setup_lazygit
	setup_fd_find
	setup_ripgrep
	setup_unzip
	setup_lua
	apt_install gcc build-essential

	print_header "NeoVim"
	apt_install nvim neovim
	create_symlink "$SCRIPT_DIR/nvim" "$HOME/.config/nvim"
}

function setup_tlp() {
	print_header "TLP Power Management"
	apt_install tlp

	local _TLP_DIR="/etc/tlp.d"
	sudo mkdir -p "$_TLP_DIR"

	for file in "$SCRIPT_DIR/tlp"/*; do
		if [ -f "$file" ]; then
			local filename target
			filename=$(basename "$file")
			target="$_TLP_DIR/$filename"

			print_step "link (sudo): $filename"

			if [ -e "$target" ] && [ ! -L "$target" ]; then
				sudo mv "$target" "${target}.bak"
			fi

			# Since TLP requires sudo, we handle the symlink manually here
			if [ -L "$target" ] && [ "$(readlink "$target")" = "$file" ]; then
				print_skip
			else
				sudo ln -sf "$file" "$target"
				print_success
			fi
		fi
	done

	print_step "service: tlp.service"
	sudo systemctl enable --now tlp.service >>"$LOG_FILE" 2>&1
	print_success
}

function setup_tmux() {
	print_header "Tmux"
	apt_install tmux
	apt_install acpi

	create_symlink "$SCRIPT_DIR/tmux" "$HOME/.config/tmux"

	if tmux ls &>/dev/null; then
		print_info "Tmux session detected. Sourcing live configuration..."
		tmux source-file "$HOME/.config/tmux/tmux.conf"
	fi
}

function setup_vsCode() {
	print_header "VS Code"
	create_symlink "$SCRIPT_DIR/vsCode/settings.json" "$HOME/.config/Code/User/settings.json"
}

function setup_tldr() {
	print_header "TLDR (tealdeer)"
	apt_install tldr tealdeer

	print_step "Updating tldr database"
	if command -v tldr &>/dev/null; then
		tldr --update >/dev/null 2>&1
		print_success
	else
		print_skip
	fi
}

function setup_xfconf() {
	print_header "XFCE Configuration (xfconf)"

	local MY_CONF="$SCRIPT_DIR/xfconf/xfce-perchannel-xml"
	local _XFCONF_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"

	# 1. Stop the daemon BEFORE touching the files
	print_step "Stopping xfconfd daemon"
	if pgrep -x "xfconfd" >/dev/null; then
		killall xfconfd
		print_success
	else
		print_fail
	fi

	# 2. Ensure target directory exists
	mkdir -p "$_XFCONF_DIR"

	# 3. Loop through individual XML configs
	for CONF in "$MY_CONF"/*; do

		# Changed to -f to ensure it's a file, not a directory
		if [ -f "$CONF" ]; then
			local conf_name=$(basename "$CONF")
			local target="$_XFCONF_DIR/$conf_name"

			print_step "link: $conf_name"

			# Removed sudo: Everything here belongs to the user
			if [ -e "$target" ] && [ ! -L "$target" ]; then
				mv "$target" "${target}.bak"
				ln -sf "$CONF" "$target"
				print_success
			elif [ -L "$target" ] && [ "$(readlink "$target")" = "$CONF" ]; then
				print_skip
			else
				ln -sf "$CONF" "$target"
				print_success
			fi
		fi
	done

	print_step "Starting xfconfd"
	xfsettingsd --replace &>/dev/null &
	disown
	print_success
}

function setup_fonts() {
	print_header "Fonts Setup"

	apt_install wget

	local _FONT_DIR="$HOME/.local/share/fonts"
	mkdir -p "$_FONT_DIR"

	local URLS=(
		"https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip"
		"https://download.jetbrains.com/fonts/JetBrainsMono-2.304.zip"
		"https://github.com/i-tu/Hasklig/releases/download/v1.2/Hasklig-1.2.zip"
		"https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/Monoid.zip"
		"https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/CascadiaCode.zip"
		"https://github.com/be5invis/Iosevka/releases/download/v34.8.1/PkgTTC-SGr-Iosevka-34.8.1.zip"
		"https://github.com/be5invis/Iosevka/releases/download/v34.8.1/PkgTTC-SGr-IosevkaTerm-34.8.1.zip"
		"https://github.com/be5invis/Iosevka/releases/download/v34.8.1/PkgTTC-SGr-IosevkaTermSlab-34.8.1.zip"
		"https://github.com/be5invis/Iosevka/releases/download/v34.8.1/PkgTTC-SGr-IosevkaSlab-34.8.1.zip"
		"https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/SourceCodePro.zip"
		"https://github.com/source-foundry/Hack/releases/download/v3.003/Hack-v3.003-ttf.tar.gz"
		"https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/RobotoMono.zip"
	)

	print_info "Synchronizing fonts..."
	local _TMP_DIR
	_TMP_DIR=$(mktemp -d)

	local SAVE_CURSOR='\e[s'
	local RESTORE_CLEAR='\e[u\e[J'

	for url in "${URLS[@]}"; do
		local filename folder_name target_dir
		filename=$(basename "$url")
		filename="${filename%%\?*}"
		folder_name=$(echo "$filename" | sed -e 's/\.zip$//' -e 's/\.tar\.gz$//')
		target_dir="$_FONT_DIR/$folder_name"

		printf "  %-45s ${SAVE_CURSOR}\n" "$folder_name"

		if [ -d "$target_dir" ]; then
			printf "${RESTORE_CLEAR}[ ${YELLOW}SKIP${RESET} ]\n"
			continue
		fi

		echo "[$(date +'%H:%M:%S')] DOWNLOAD START: $url" >>"$LOG_FILE"
		echo "[$(date +'%H:%M:%S')] DESTINATION: $_TMP_DIR/$filename" >>"$LOG_FILE"

		if wget -q --show-progress --timeout=15 --tries=3 -O "$_TMP_DIR/$filename" "$url"; then

			if [ -f "$_TMP_DIR/$filename" ]; then
				echo "[$(date +'%H:%M:%S')] DOWNLOAD SUCCESS: $filename verified on disk." >>"$LOG_FILE"
			fi

			mkdir -p "$target_dir"
			case "$filename" in
			*.zip) unzip -q -o "$_TMP_DIR/$filename" -d "$target_dir" >>"$LOG_FILE" 2>&1 || true ;;
			*.tar.gz | *.tgz) tar -xzf "$_TMP_DIR/$filename" -C "$target_dir" >>"$LOG_FILE" 2>&1 || true ;;
			*) mv "$_TMP_DIR/$filename" "$target_dir/" || true ;;
			esac

			echo "[$(date +'%H:%M:%S')] EXTRACT SUCCESS: Installed to $target_dir" >>"$LOG_FILE"
			printf "${RESTORE_CLEAR}[ ${GREEN}DONE${RESET} ]\n"
		else
			echo "[$(date +'%H:%M:%S')] DOWNLOAD FAIL: Wget returned an error for $url" >>"$LOG_FILE"
			printf "${RESTORE_CLEAR}[ ${RED}FAIL${RESET} ]\n"
		fi

		rm -f "$_TMP_DIR/$filename"
	done

	rm -rf "$_TMP_DIR"

	print_step "Updating system font cache"
	fc-cache -f -v >/dev/null || true
	print_success
}

function setup_zshrc() {
	print_header "Zsh Configuration"

	create_symlink "$SCRIPT_DIR/zshrc" "$HOME/.zshrc"
}

function setup_daily_wallpaper() {
	print_header "Daily Wallpaper"

	apt_install git
	apt_install jq
	apt_install nc netcat-openbsd
	apt_install find findutils

	sudo mkdir -p /usr/share/backgrounds/bing-daily
	sudo chown $USER:$USER /usr/share/backgrounds/bing-daily

	sudo mkdir -p "/usr/share/grub/themes/custom_theme"
	sudo chown $USER:$USER "/usr/share/grub/themes/custom_theme"

	local REPO_DIR="$HOME/Public/Daily_Wallpaper"
	local SCRIPT_PATH="$REPO_DIR/daily_wallpaper.sh"
	local CRON_SCHEDULE="0 0 * * *"
	local CRON_RULE="$CRON_SCHEDULE $SCRIPT_PATH 2>&1 | logger -t bing.log"

	print_step "git clone: Daily-Wallpaper"
	if [ -d "$REPO_DIR" ]; then
		print_skip
	else
		if git clone -q https://github.com/ravirajkarn/Daily-Wallpaper.git "$REPO_DIR" >/dev/null 2>&1; then
			print_success
		else
			print_fail
			return 1
		fi
	fi

	chmod +x "$SCRIPT_PATH" 2>/dev/null || true

	print_step "Running wallpaper script now"
	nohup bash "$SCRIPT_PATH" >/dev/null 2>&1 &
	disown
	print_success

	print_step "cron job: daily_wallpaper"
	if crontab -l 2>/dev/null | grep -Fq "$SCRIPT_PATH"; then
		print_skip
	else
		(
			crontab -l 2>/dev/null
			echo "$CRON_RULE"
		) | crontab -
		print_success
	fi
}

function setup_bat() {
	print_header "Bat (batcat)"

	apt_install batcat bat

	print_step "link: bat executable"
	mkdir -p "$HOME/.local/bin"

	if [ ! -L "$HOME/.local/bin/bat" ]; then
		ln -s /usr/bin/batcat "$HOME/.local/bin/bat"
		print_success
	else
		print_skip
	fi
}

# function setup_js() {
# 	apt_install typescript
# 	apt_install pnpm
# }

function setup_CppDev() {
	print_header "C++ Development Toolchain"

	apt_install gcc build-essential
	apt_install g++ g++
	apt_install gdb
	apt_install clang
	apt_install clang-format
	apt_install cmake
	apt_install ninja ninja-build
	apt_install meson
}

function setup_nody_greeter() {
	print_header "Nody Greeter"

	apt_install lightdm
	apt_install gir1.2-glib-2.0
	apt_install gir1.2-gtk-3.0
	apt_install libgirepository1.0-dev
	apt_install libcairo2
	apt_install liblightdm-gobject-1-0

	print_step "install: nody-greeter"

	if [ ! -f "/usr/sbin/nody-greeter" ] && ! command -v nody-greeter &>/dev/null; then

		local _TEMP_DIR=$(mktemp -d)

		{
			pushd "$_TEMP_DIR"
			local LATEST_URL=$(wget -qO- https://api.github.com/repos/JezerM/nody-greeter/releases/latest | grep "browser_download_url.*debian\.deb" | cut -d '"' -f 4)
			local DEB_FILE=$(basename "$LATEST_URL")

			echo "========================================"
			echo "DOWNLOAD START: $LATEST_URL"
			echo "DESTINATION: $_TEMP_DIR/$DEB_FILE"
			echo "========================================"

			wget -q "$LATEST_URL"

			if [ -f "$DEB_FILE" ]; then
				echo "DOWNLOAD SUCCESS: $DEB_FILE verified at $_TEMP_DIR"
				echo "Starting installation..."
				sudo apt-get install -y "./$DEB_FILE"
			else
				echo "DOWNLOAD FAIL: $DEB_FILE was not found in $_TEMP_DIR after wget!"
				exit 1
			fi
			popd
		} >>"$LOG_FILE" 2>&1

		local build_status=$?

		rm -rf "$_TEMP_DIR"

		if [ $build_status -eq 0 ]; then
			print_success
		else
			print_fail
			echo -e "  ${RED}-> Installation crashed! Check ${YELLOW}$LOG_FILE${RED} for details.${RESET}"
			exit 1
		fi
	else
		print_skip
	fi

	print_step "config: lightdm.conf"
	local _LIGHTDM_CONF="/etc/lightdm/lightdm.conf"

	if [ -f "$_LIGHTDM_CONF" ]; then

		if grep -q "^greeter-session=nody-greeter" "$_LIGHTDM_CONF"; then
			print_skip
		else
			if grep -Eq "^#?[[:space:]]*greeter-session=" "$_LIGHTDM_CONF"; then
				sudo sed -i 's/^#*[[:space:]]*greeter-session=.*/greeter-session=nody-greeter/' "$_LIGHTDM_CONF"

			elif grep -q "^\[Seat:\*\]" "$_LIGHTDM_CONF"; then
				sudo sed -i '/^\[Seat:\*\]/a greeter-session=nody-greeter' "$_LIGHTDM_CONF"

			else
				echo -e "\n[Seat:*]\ngreeter-session=nody-greeter" | sudo tee -a "$_LIGHTDM_CONF" >/dev/null
			fi
			print_success
		fi
	else
		print_fail
		echo -e "  ${CYAN}-> $_LIGHTDM_CONF not found! Is LightDM installed?${RESET}"
	fi

	local MY_CONF="$SCRIPT_DIR/web-greeter/themes"
	local WEB_GREETER_THEMES="/usr/share/web-greeter/themes"

	sudo mkdir -p "$WEB_GREETER_THEMES"

	for theme_dir in "$MY_CONF"/*; do

		if [ -e "$theme_dir" ]; then
			local theme_name=$(basename "$theme_dir")
			case "$theme_name" in
			litarvan | some_other_theme | test_theme)
				continue
				;;
			esac
			local target="$WEB_GREETER_THEMES/$theme_name"

			print_step "link (sudo): $theme_name"

			if [ -e "$target" ] && [ ! -L "$target" ]; then
				sudo mv "$target" "${target}.bak"
				sudo ln -sf "$theme_dir" "$target"
				print_success
			elif [ -L "$target" ] && [ "$(readlink "$target")" = "$theme_dir" ]; then
				print_skip
			else
				sudo ln -sf "$theme_dir" "$target"
				print_success
			fi
		fi
	done
}

function setup_xfce_lock() {
	print_header "XFCE Lock & Screensaver Routing"

	# 1. Stop running Xfce screensaver
	print_step "config: stop xfce4-screensaver"
	if pgrep -f "xfce4-screensaver" >/dev/null; then
		xfce4-screensaver-command --exit >>"$LOG_FILE" 2>&1 || true
		print_success
	else
		print_skip
	fi

	# 2. Apply Xfce Lock Settings (Bridge to LightDM/dm-tool)
	print_step "config: route lock to dm-tool"
	if command -v xfconf-query >/dev/null 2>&1; then
		local CURRENT_LOCK=$(xfconf-query -c xfce4-session -p /general/LockCommand 2>/dev/null || echo "")

		if [ "$CURRENT_LOCK" == "dm-tool lock" ]; then
			print_skip
		else
			xfconf-query -c xfce4-session -p /general/LockCommand -n -t string -s "dm-tool lock" >>"$LOG_FILE" 2>&1
			print_success
		fi
	else
		print_fail
		print_info "xfconf-query not found. Make sure you are inside an active XFCE session."
	fi

	# 3. Force off native screensaver toggles
	print_step "config: disable native screensaver"
	if command -v xfconf-query >/dev/null 2>&1; then
		xfconf-query -c xfce4-screensaver -p /saver/enabled -n -t bool -s false >>"$LOG_FILE" 2>&1 || true
		xfconf-query -c xfce4-screensaver -p /lock/enabled -n -t bool -s false >>"$LOG_FILE" 2>&1 || true
		print_success
	else
		# If xfconf-query fails, we skip gracefully to avoid breaking the script
		print_skip
	fi
}

function setup_touchpad() {
	print_header "X11 Touchpad Configuration"
	print_step "config: 30-touchpad.conf"

	local _CONF_DIR="/etc/X11/xorg.conf.d"
	local _CONF_FILE="$_CONF_DIR/30-touchpad.conf"

	# Idempotency check: If the file exists and contains our specific settings, skip it.
	if [ -f "$_CONF_FILE" ] && grep -q 'Option "Tapping" "on"' "$_CONF_FILE" && grep -q 'Option "AccelSpeed" "0.5"' "$_CONF_FILE"; then
		print_skip
	else
		# 1. Ensure the directory exists (logging any output)
		sudo mkdir -p "$_CONF_DIR" >>"$LOG_FILE" 2>&1

		# 2. Write the configuration cleanly using tee
		sudo tee "$_CONF_FILE" >/dev/null <<'EOF'
Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
    Option "AccelSpeed" "0.5"
EndSection
EOF

		# 3. Log the successful file creation to the master log
		echo "[$(date +'%H:%M:%S')] INFO: Wrote libinput touchpad config to $_CONF_FILE" >>"$LOG_FILE"
		print_success
	fi
}

function setup_js() {
	print_header "Node.js & JavaScript Tooling"

	# 1. Install npm (this automatically pulls in nodejs as a dependency)
	apt_install npm

	# 2. Install pnpm globally using npm
	print_step "npm: pnpm"
	if ! command -v pnpm &>/dev/null; then
		# Install globally via sudo, routing output to our master log
		if sudo npm install -g pnpm >>"$LOG_FILE" 2>&1; then
			print_success
		else
			print_fail
		fi
	else
		print_skip
	fi

	# 3. Optional: Install TypeScript globally (since you had it in your old commented-out code!)
	print_step "npm: typescript"
	if ! command -v tsc &>/dev/null; then
		if sudo npm install -g typescript >>"$LOG_FILE" 2>&1; then
			print_success
		else
			print_fail
		fi
	else
		print_skip
	fi
}

function setup_webkit_theme_litarvan() {
	print_header "Litarvan Web Greeter Theme"
	print_step "build & install: litarvan"

	local THEME_DIR="$SCRIPT_DIR/web-greeter/themes/litarvan"
	local TARGET_DIR="/usr/share/web-greeter/themes/litarvan"

	# Idempotency check: Skip if it's already installed
	if [ -f "$TARGET_DIR/index.theme" ]; then
		print_skip
	else
		if [ -d "$THEME_DIR" ]; then

			{
				# 1. Moveing into the directory to build
				pushd "$THEME_DIR"
				bash ./build.sh

				# 2. Creating target system directory
				sudo mkdir -p "$TARGET_DIR"

				# 3. Extract the tarball.
				sudo tar -xf lightdm-webkit-theme-litarvan-*.tar.gz -C "$TARGET_DIR" --strip-components=1

				popd
			} >>"$LOG_FILE" 2>&1

			local build_status=$?

			if [ $build_status -eq 0 ]; then
				print_success
			else
				print_fail
				echo -e "  ${RED}-> Litarvan build failed! Check ${YELLOW}$LOG_FILE${RED} for details.${RESET}"
			fi
		else
			print_fail
			print_info "Theme directory not found: $THEME_DIR"
		fi
	fi
}

# _SILENT=$PWD/silent/install.sh
# if [ ! command -v sddm ] &>/dev/null; then
#     echo "Installing sddm"
#     sudo apt-get install -y sddm
# fi
# $_SILENT
# echo

# ==============================================================================
# 4. MODULE GROUPS
# ==============================================================================

function run_core() {
	sudo apt-get update
	echo
	setup_pipx
	pipx upgrade-all || true
	echo
	apt_install wget2
	apt_install unzip
}

function run_fonts() {
	setup_fonts
}

function run_terminal() {
	setup_kitty
	setup_zshrc
	setup_tmux
	setup_bat
}

function run_dev() {
	setup_neovim
	setup_vsCode
	setup_conan
	setup_CppDev
	setup_tldr
	apt_install shfmt
	setup_js
}

function run_desktop() {
	setup_tlp
	setup_touchpad
	setup_syncthing
	setup_grub
	setup_xfconf
	setup_nody_greeter
	setup_webkit_theme_litarvan
	setup_xfce_lock
	setup_daily_wallpaper
}

function run_apps() {
	apt_install inkscape
	apt_install gimp
	apt_install libreoffice
	apt_install okular
}

function run_all() {
	run_core
	run_fonts
	run_terminal
	run_dev
	run_desktop
	run_apps
}

# ==============================================================================
# 5. EXECUTION ENGINE
# ==============================================================================

function show_help() {
	echo -e "${BOLD}${BLUE}Dotfiles Setup Script${RESET}"
	echo -e "Usage: $0 [module1] [module2] [function_name] ..."
	echo ""
	echo -e "${CYAN}Available Groups:${RESET}"
	echo "  all       - Run absolutely everything (Default)"
	echo "  core      - Update apt, install pipx, wget2, unzip"
	echo "  fonts     - Download and install system fonts"
	echo "  terminal  - Kitty, Zsh, Tmux, Bat"
	echo "  dev       - Neovim, VS Code, C++ Dev tools, Conan, etc."
	echo "  desktop   - LightDM, Grub, XFCE configs, TLP, Wallpaper"
	echo "  apps      - GIMP, Inkscape, LibreOffice"
	echo ""
	echo -e "${CYAN}Specific Functions:${RESET}"
	echo "  You can also pass the exact name of any setup function."
	echo "  The 'setup_' prefix is optional."
	echo ""
	echo -e "${CYAN}Examples:${RESET}"
	echo "  $0 fonts terminal   # Run two module groups"
	echo "  $0 setup_neovim     # Run one specific function"
	echo "  $0 tmux             # Smart matching: runs 'setup_tmux'"
}

function main() {
	check_sudo

	if [ $# -eq 0 ]; then
		run_all
		return
	fi

	for arg in "$@"; do
		case $arg in
		all) run_all ;;
		core) run_core ;;
		fonts) run_fonts ;;
		terminal) run_terminal ;;
		dev) run_dev ;;
		desktop) run_desktop ;;
		apps) run_apps ;;
		help | -h | --help)
			show_help
			exit 0
			;;
		*)
			if declare -F "$arg" >/dev/null; then
				"$arg"

			elif declare -F "setup_$arg" >/dev/null; then
				"setup_$arg"

			else
				echo -e "${RED}[ FAIL ] Unknown module or function: $arg${RESET}"
				echo "Run '$0 help' to see available options."
				exit 1
			fi
			;;
		esac
	done
}

main "$@"

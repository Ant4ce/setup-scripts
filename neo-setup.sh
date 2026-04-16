#! /bin/bash
set -o errexit   # abort on nonzero exitstatus
set -o nounset   # abort on unbound variable
set -o pipefail  # don't hide errors within pipes

#Function to check for right condition to run script in UCRT64 minty with admin priveleges. 
function yes_or_no {
  while true; do
    read -p "$* [y/n]: " yn
    case $yn in 
      [Yy]*) return 0 ;;
      [Nn]*) echo "Aborting... " ; return 1 ;;
    esac
  done
}

case $OSTYPE in 
  #Linux Distros
  linux-gnu)
  DISTRO=$(cat /etc/os-release | grep -Po "(?<=^ID=).*")
    case $DISTRO in
      
      ubuntu)
          echo "DISTRO: $DISTRO"
          echo "Are you running it with: 'sudo -E ./<SCRIPT_NAME>' ????"
          yes_or_no "Script REQUIRES SUDO permissions & env variables... Are you running it as above?"
          RESULT=$?
          if [ $RESULT -eq 1 ]; then 
            echo "Re-run script with sudo permissions. STOPPING."
            exit 1
          fi
          REG_USER=$(echo $SUDO_USER)
          echo "Regular username is: $REG_USER"
          REG_HOME="/home/$REG_USER"
          echo "User home directory is: $REG_HOME"
          yes_or_no "Proceed with these settings?"
          RESULT2=$?
          if [ $RESULT2 -eq 1 ] ; then 
            echo "User cancelled installation. STOPPING. DONE."
            exit 1
          fi
          if ! apt update && apt upgrade -y ; then 
            echo "Failed to do system update && upgrade. STOPPING."
            exit 1
          fi
          if ! apt install git curl -y ; then 
            echo "Failed to install git & curl. STOPPING "
            exit 1
          fi
          echo "Succesfully installed git, curl and updated the system. CONTINUING..."
          echo "Installing neovim with curl..."
          if ! (cd $REG_HOME && sudo -u $REG_USER -E curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz); then 
            echo "Failed to install neovim. STOPPING."
            exit 1
          fi 
          echo "Ensuring no existing Neovim installation, if so removing."
          rm -rf /opt/nvim-linux-x86_64
          echo "Unpacking tarball..."
          if ! tar -C /opt -xzf $REG_HOME/nvim-linux-x86_64.tar.gz; then
            echo "Failed to unpack tarbal of neovim."
            exit 1
          fi 
          echo "Unpacked tarbal into /opt"
          echo "Exporting PATH to include nvim binary and adding it to .bashrc config."
          export PATH="$PATH:/opt/nvim-linux-x86_64/bin/"
          sudo -u $REG_USER -E echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin/"' >> $REG_HOME/.bashrc
          echo "Installing Modified AudioLink Mono FONT..."
          # OLD way of installing the font directly from their website, but it had not glyphs so it wasn't a nerd font.
          # if curl -L -o "/home/$USER/Downloads/AudioLinkFont.zip" https://audiolink.dev/gallery/AudioLinkMono.zip ; then
          #   if unzip ~/Downloads/AudioLinkFont.zip -d ~/.local/share/fonts ; then 
          #   if rm ~/Downloads/AudioLinkFont.zip ; then
          #     else
          #       echo "Failed to remove temp files from Downloads. STOPPING."
          #   fi
          #   else 
          #     echo "Failed to unzip files into ~/.local/share/fonts directory."
          #   fi
          # else
          #   echo "Failed to download Audio-link font with CURL. STOPPING."
          # fi:
          if ! sudo -u $REG_USER git clone https://github.com/Ant4ce/ALAsNerdFont.git  \
            $REG_HOME/.local/share/fonts/ ; then 
            echo "Failed to clone Nerd Font from git repo. STOPPING."
            exit 1
          fi
          if ! sudo -u $REG_USER -E fc-cache -fv ; then
            echo "Failed to update font cache. STOPPING."
            exit 1
          fi
          echo "Succesfully Installed Modified Audio-Link Font and updated the font-cache. CONTINUING..."
          echo "Setting new font as gnome-terminal default..."
          # Gets the profile number of the GNOME-terminal, so that I can change the values later.
          TEMP_VAR=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d \')
          # Sets the font for the GNOME terminal in Ubuntu, tested on 24.04LTS.
          # OLD basic font without the nerd font glyphs.
          #gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$TEMP_VAR/" font "AudioLink Mono 14"

          # This command does require it to be run as the regular user as running with root will result 
          # in failure to commit changes with dconf.
          # The reason it doesn't work with sudo/root is because the "dconf" command which gsettings uses 
          # here needs to know the D-Bus the user uses
          # which is stored in $DBUS_SESSION_BUS_ADDRESS and this is not set in the sude environment we 
          # run the script with so we have to change to the regular user.
          sudo -u $REG_USER -E gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$TEMP_VAR/" font "AudioLinkMono Nerd Font Mono 14"
          # This is to allow the system to use the configured font and not the default. 
          sudo -u $REG_USER -E gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$TEMP_VAR/" use-system-font false

          echo "SUCCESSFULLY SET the font of the terminal. CONTINUING..."
          echo "You will need to RESTART the machine to see proper changes to font applied. CONTINUING..."

          if ! sudo -u $REG_USER git clone https://github.com/Ant4ce/files-neo-setup.git $REG_HOME/.config/nvim/ ; then 
            echo "Failed to clone neo-config repo. STOPPING."
            exit 1
          fi 
          echo "Successfully installed neovim config files. CONTINUING..."
          echo "Installing Rust..."
          # This command doesn't work without running the "sh" command at the end with "sudo -u $REG_USER". This is because 
          # it will default back to running the "sh" shell command as the root user since this script is run with sudo. 
          # Also note that sh in ubuntu/debian is a symlink to run with "dash" which is a faster superset implementation of sh. 
          if ! sudo -u $REG_USER -E curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sudo -u $REG_USER -E sh -s -- -y ; then
            echo "Failed to install Rust. STOPPING."
            exit 1
          fi 
          echo "Installed Rust. CONTINUING..."
          # Can't seem to get this to be recognized by the below command to use cargo to install tree-sitter-cli. So removed. 
          # export PATH="$PATH:$REG_HOME/.cargo/bin"
          echo "Installing C compiler and libraries including LLVM for rust treesitter-cli installation..."
          if ! apt install -y clang libclang-dev llvm pkg-config npm ; then 
            echo "Failed to install clang, libclang-dev, llvm, pkg-config. STOPPING."
            exit 1
          fi
          echo "Successfully Installed clang and other libraries, CONTINUING..."
          echo "Installing treesitter-cli... Required for nvim-treesitter..."
          # Normally would be able to invoke cargo normally but apparently "sudo -E" in this case can't preserve the $PATH variable.
          # It seems that the environment variables get sanitized in this case. As a fix will call cargo directly from it's binary location.
          # NOTE ALTERNATIVE:
          # One other way to get around this is to run the following line with "env" to explicitely pass PATH to the next command:
          # sudo -u $REG_USER -E env PATH="$PATH:$REG_HOME/.cargo/bin" cargo install --locked tree-sitter-cli
          if ! sudo -u $REG_USER -E $REG_HOME/.cargo/bin/cargo install --locked tree-sitter-cli ; then 
            echo "Failed to install treesitter-cli. STOPPING."
            exit 1
          fi
          echo "SUCCESSFULLY Installed tree-sitter-cli. CONTINUING..."
          echo "To complete the installation REBOOT..."
          echo "############### Finished the script. DONE. ######################"
        ;;
      arch)
        echo "$DISTRO is the DISTRO."


        echo "This script expects to be run on KDE plasma on arch linux. If not say no to next prompt!"
        yes_or_no "OS_TYPE: $DISTRO \n Script requires SUDO permissions... Are you running it with sudo? [y/n]"
        RESULT=$?
        if [ $RESULT -eq 1 ]; then 
          echo "Re-run script with sudo permissions. STOPPING."
          exit 1
        fi
        echo "Starting script..."
        REG_USER="$SUDO_USER"
        REG_HOME="$SUDO_HOME"
        # Have to check what version of kwriteconfig is used as this changes with plasma over time.
        K_VERSION=0

        # Check for version happens here.
        if command -v kwriteconfig5 ; then
          echo "Found kwriteconfig5 setting it."
          K_VERSION=5
          sleep 1
        else
          echo "Didn't find kwriteconfig5, checking for version 6..."
          if command -v kwriteconfig6 ; then
            echo "Found version 6, setting it."
            K_VERSION=6
            sleep 1
          else 
            echo "Don't have either kwriteconfig5 or 6, installing kconfig package..."
            if pacman -S kconfig ; then
              echo "Successfully installed kconfig package."
              echo "Continuing..."
              sleep 2
              K_VERSION=$(pacman -Qi kconfig | grep -i version | grep -oP '[[:digit:]]+' | head -n1)
              echo "New stored version of kwriteconfig: $K_VERSION"
              sleep 2
            else 
              echo "Failed to install kconfig package, check what is wrong."
              echo "ERROR."
              exit 1
            fi
          fi
        fi
        # end of checking for version.
        if ! pacman -Syu --noconfirm ; then 
          echo "Failed to update system. STOPPING."
          exit 1
        fi
        if ! (sudo -u $REG_USER -E curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sudo -u $REG_USER sh -s -- -y) ; then
            echo "Failed to install Rust. STOPPING."
            exit 1
        fi 
        echo "Installed Rust. CONTINUING..."
        echo "Installing extra packages..."
        if ! pacman -S --noconfirm git curl tree-sitter-cli neovim wl-clipboard unzip npm ; then
          echo "Failed to install packages."
          exit 1
        fi
        echo "Succesfully installed extra packages. CONTINUING..."

        if ! sudo -u $REG_USER mkdir $REG_HOME/.local/share/fonts ; then 
          echo "Failed to create Fonts folder under $REG_HOME/.local/share/. STOPPING."
          exit 1
        fi
        echo "Created fonts folder. CONTINUING..."

        if ! sudo -u $REG_USER git clone https://github.com/Ant4ce/ALAsNerdFont.git  $REG_HOME/.local/share/fonts/ ; then 
          echo "Failed to clone Audio-link nerd font into $REG_HOME/.local/share/fonts, STOPPING."
          exit 1
        fi
        if ! sudo -u $REG_USER fc-cache -fv ; then 
          echo "Failed to update the nerd fonts with fc-cache. STOPPING."
          exit 1
        fi
        echo "Succesfully installed Audio-Link Nerd Font. CONTINUING..."
        echo "Setting new font as Konsole default."
        # Old line removed as: doesn't always work as sudo starts a new process which does not inherit stdin,
        # however the here-doc (the part with EOF) is processed by the original shell and then passed on to 
        # the new process. But since the sudo spawned process doesn't have access to the stdin it fails. 
        # Note that stdin is a file descriptor just like stdout and stderr
        # sudo -u $REG_USER install -D /dev/stdin $REG_HOME/.local/share/konsole/mynerd.profile <<EOF

        # The indentation here is weird on purpose, has to do with the way bash expect's the EOF statement.
        # It expects it at the beginning of the line. 
        su - $REG_USER -c "install -D /dev/stdin $REG_HOME/.local/share/konsole/mynerd.profile <<EOF
[General]
Name=Ant4ceNerd
Command=/bin/bash

[Appearance]
EOF"
        echo "Succesfully created profile config file for konsole."
        echo "Editing it with kwriteconfig$K_VERSION..."
        # these last 2 if statements are just to configure the Konsole terminal, which is under KDE plasma
        # which uses this "kwriteconfig" tool for this task.
        if [ $K_VERSION -eq 0 ] ; then 
          echo "K_VERSION was not changed from 0, STOPPING."
          echo "K_VERSION CHECK - FAILED."
          exit 1
        else 
          echo "K_VERSION CHECK - GOOD."
          sleep 1
        fi
        # tried to make this 1 command but can only reliably set one Key per kwriteconfig command.
        if sudo -u $REG_USER kwriteconfig$K_VERSION \
          --file $REG_HOME/.local/share/konsole/mynerd.profile \
          --group General \
          --key Name "Ant4ceNerd" ; then
          echo "Success. CONTINUING..."
        else 
          echo "Failed to set Name in [General]. STOPPING."
          exit 1
        fi
        if sudo -u $REG_USER kwriteconfig$K_VERSION \
          --file $REG_HOME/.local/share/konsole/mynerd.profile \
          --group General \
          --key Command "/bin/bash" ; then
          echo "Success. CONTINUING..."
        else 
          echo "Failed to set Command /bin/bash in [General]. STOPPING."
          exit 1
        fi
        if sudo -u $REG_USER kwriteconfig$K_VERSION \
          --file $REG_HOME/.local/share/konsole/mynerd.profile \
          --group Appearance \
          --key Font \
          "AudioLinkMono Nerd Font Mono,12,-1,5,50,0,0,0,0,0" ; then 
          echo "Changed config. Now trying to set it to default..."
        else 
          echo "Failed to change config with kwriteconfig. STOPPING."
          exit 1
        fi
        if sudo -u $REG_USER kwriteconfig$K_VERSION \
          --file $REG_HOME/.config/konsolerc \
          --group "Desktop Entry" \
          --key DefaultProfile \
          "mynerd.profile" ; then
          echo "Successfully set new profile as default for the Konsole. DONE"
          echo "you should restart the Konsole to see the changes."
          echo "Getting ready to install my neovim configs..."
          echo "Making directory"
          sleep 2
          sudo -u $REG_USER mkdir -p $REG_HOME/.config/nvim/ 
        else 
          echo "Failed to set config to new default. STOPPING."
          exit 1
        fi
        if sudo -u $REG_USER git clone https://github.com/Ant4ce/files-neo-setup.git $REG_HOME/.config/nvim/ ; then 
          echo "Succesfully cloned Neovim config files. DONE."
          echo "SUCCESSFULLY FINISHED setting up the konsole."
          echo "Restart the Terminal/Konsole to see changes in font."
          echo "##############SCRIPT FINISHED SUCCESFULLY#############"
        else
          echo "Failed to install neovim config files into $REG_HOME/.config/nvim/"
          exit 1
        fi
      ;;
    esac

    ;;
  #Windows
  cygwin)
    echo "$OSTYPE is a Windows ENV"

    yes_or_no "Are you running MSYS2 UCRT64 mintty shell as administrator? [y/n]"
    RESULT=$?
    if [ $RESULT -eq 1 ]; then 
      echo "Switch to priviledged administrator shell to run this script."
      exit 1
    fi
    #Install neovim
    if ! pacman -S --noconfirm mingw-w64-ucrt-x86_64-neovim ; then 
      echo "FAILED to install neovim. STOPPING."
      exit 1
    fi
    echo "SUCCESS installed neovim, continuing with setup..."
    if ! pacman -S --noconfirm git ; then 
      echo "FAILED to install git. STOPPING."
      exit 1
    fi
    echo "SUCCESS installed git, continuing..."
    if ! git clone https://github.com/Ant4ce/files-neo-setup.git ~/.config/nvim/ ; then 
      echo "FAILED to clone setup files. STOPPING."
      exit 1
    fi
    export XDG_CONFIG_HOME=~/.config/
    echo "exported XDG_CONFIG_HOME env variable. Continuing..."
    echo "export XDG_CONFIG_HOME=~/.config/" >> ~/.bashrc
    echo "changed '.bashrc' file. Continuing..."
    echo "Downloading nerd font: minw-w64-ucrt-x86_64-otf-atkinson-hyperlegible-mono-nerd"
    if ! pacman -S --noconfirm mingw-w64-ucrt-x86_64-ttf-0xproto-nerd ; then
      echo "Failed to install nerd font."
      exit 1
    fi
    echo "Downloaded nerd font (0xproto), now trying to install it within msys2 (mintty terminal)..."
    # Temporary directory to hold .ttf files.
    mkdir /c/temp
    if ! cp /ucrt64/share/fonts/TTF/*.ttf /c/temp/ ; then
      echo "Failed to transfer .ttf files to temp location...STOPPING."
      exit 1
    fi
    echo "Succesfully transfered .ttf files to temp folder..."
    if ! powershell.exe -NoProfile -Command "Get-ChildItem 'C:\temp\*.ttf' | ForEach-Object { Copy-Item \$_.FullName -Destination \$env:WINDIR\\Fonts }" ; then 
      echo "Failed to copy items over with powershell command to C:\Windows\Fonts directory... STOPPING."
      exit 1
    fi

    echo "Successfully Copied .ttf files into C:\\Windows\\Fonts"
    if ! powershell.exe -NoProfile -Command "New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' -Name '0xProto Nerd Font' -Value '0xProtoNerdFont-Regular.ttf' -PropertyType String -Force" ; then 
      echo "Failed to add registry entry for font in Windows... STOPPING."
      exit 1
    fi
    echo "Successfully added registry entry of Font to Windows..."
    echo "Cleaning up temp folder and contents..."
    rm -rf /c/temp
    if ! touch ~/.minttyrc ; then
      echo ".minttyrc already Exists... STOPPING."
      exit 1
    fi
    if grep -q '^Font=0xProto Nerd Font$' ~/.minttyrc ; then 
      echo "~/.minttyrc file already has contents"
      echo "FINISHED SUCCESSFULLY."
      exit 1
    fi
    printf '\nFont=0xProto Nerd Font\nFontHeight=11\n' >> ~/.minttyrc

    if ! pacman -S --noconfirm mingw-w64-ucrt-x86_64-rust mingw-w64-ucrt-x86_64-clang ; then 
      echo "Failed to install rust."
      exit 1
    fi
    echo "Installed rust & clang & llvm (NOTE: llvm not strictly necessary). Continuing..."
    export LIBCLANG_PATH=/ucrt64/bin
    echo "Adding LIBCLANG_PATH export to .bashrc"
    echo "export LIBCLANG_PATH=/ucrt64/bin" >> ~/.bashrc
    echo "Installing treesitter cli... required for nvim-treesitter."
    if ! cargo install --locked tree-sitter-cli ; then 
      echo "Failed to install treesitter-cli from cargo."
      exit 1
    fi
    echo "Installed tree-sitter-cli successfully"
    echo "Updating PATH to run installed binaries for tree-sitter..."
    USER=$(whoami)
    export PATH="$PATH:/c/Users/$USER/.cargo/bin"
    # Weird quotes pattern here because I don't immediately want to expand $PATH but i do want to expand $USER into it's value to add in the path. 
    # Single quotes [''] make it a string litteral on the outsides and the double quotes [""] allow for variable expansion.
    echo 'export PATH="$PATH:/c/Users/'"$USER"'/.cargo/bin"' >> ~/.bashrc
    echo "############# DONE #######################"
    printf "'tree-sitter --version' \n --above command should run \n"
    echo "You should see icons inside of NVIM when you open neo-tree"
    echo "FINSISHED SUCCESSFULLY! \n Type NVIM to start and expect Lazy to show and install packages."
    echo "Now close this windows and reopen mintty to see Font changes too. FINISHED SCRIPT."
    ;;
esac


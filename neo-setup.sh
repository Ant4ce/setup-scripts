#! /bin/bash

#Function to check for right condition to run script in UCRT64 minty with admin priveleges. 
function yes_or_no_mintty {
  while true; do
    read -p "$* [y/n]: " yn
    case $yn in 
      [Yy]*) return 0 ;;
      [Nn]*) echo "Aborting... " ; return 1 ;;
    esac
  done
}

# OS detection for right commands
# linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  DISTRO=$(cat /etc/os-release | grep -Po "(?<=^ID=).*")
  echo $DISTRO
  
  if [[ "$DISTRO" == "ubuntu" ]]; then 
    if apt update && apt upgrade -y ; then 
      if apt install git curl -y ; then 
        echo "Succesfully installed git, curl and updated the system. CONTINUING..."
        
        echo "Installing neovim with curl..."
        if curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz ; then 
          echo "Ensuring no existing Neovim installation, if so removing."
          sudo rm -rf /opt/nvim-linux-x86_64
          echo "Unpacking tarball."
          sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
          echo "Unpacked tarbal into /opt"
          echo "Exporting PATH to include nvim binary and adding it to .bashrc config."
          export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
          echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' >> ~/.bashrc
          echo "Installing New FONT. CONTINUING..."
          # TODO replace this with cloning from git repo for modified AudioLink font to include the glyphs.
          if curl -L -o "/home/$USER/Downloads/AudioLinkFont.zip" https://audiolink.dev/gallery/AudioLinkMono.zip ; then
            if unzip ~/Downloads/AudioLinkFont.zip -d ~/.local/share/fonts ; then 
              if fc-cache -fv ; then
                echo "Succesfully Installed Audio-Link Font and updated the font-cache. CONTINUING..."
                echo "REMOVING temp files from download folder..."
                if rm ~/Downloads/AudioLinkFont.zip ; then
                  echo "DONE removing temp files from download folder."

                  echo "Setting AudioLink Mono as the font for the bash terminal."

                  # Gets the profile number of the GNOME-terminal, so that I can change the values later.
                  export TEMP_VAR=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d \')
                  # Sets the font for the GNOME terminal in Ubuntu, tested on 24.04LTS.
                  gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$TEMP_VAR/" font "AudioLink Mono 14"
                  echo "SUCCESSFULLY SET the font of the terminal. CONTINUING..."

                  if git clone https://github.com/Ant4ce/files-neo-setup.git ~/.config/nvim/ ; then 
                    echo "Successfully installed neovim config files. CONTINUING..."
                    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y ; then
                      echo "Installed Rust. CONTINUING..."
                      echo "Installing C compiler and libraries including LLVM for rust treesitter-cli installation..."
                      if apt install -y clang libclang-dev llvm pkg-config ; then 
                        echo "Successfully Installed clang and other libraries, CONTINUING..."
                        echo "Installing treesitter-cli... Required for nvim-treesitter..."
                        if cargo install --locked tree-sitter-cli ; then 
                          echo "SUCCESSFULLY Installed tree-sitter-cli. CONTINUING..."
                          # TODO Patch the font with nerd fonts tool in order to add the glyphs to the AudioLink Mono font. 
                          # Add it on a seperate github repo so that you can download it from there instead.
                        else
                          echo "Failed to install treesitter-cli. STOPPING."
                        fi
                      else 
                        echo "Failed to install clang, libclang-dev, llvm, pkg-config. STOPPING."
                      fi
                    else
                      echo "Failed to install Rust. STOPPING."
                    fi
                  else
                    echo "Failed to clone neo-config repo. STOPPING."
                  fi

                else
                  echo "Failed to remove temp files from Downloads. STOPPING."
                fi
              else 
                echo "Failed to update font cache. STOPPING."
              fi
            else 
              echo "Failed to unzip files into ~/.local/share/fonts directory."
            fi
          else
            echo "Failed to download Audio-link font with CURL. STOPPING."
          fi
        else
          echo "Failed to install neovim. STOPPING."
        fi
      else 
        echo "Failed to install git & curl. STOPPINGudo "
      fi
    else 
      echo "Failed to do system update && upgrade. STOPPING."
    fi
  
# Windows detection 
elif [[ "$OSTYPE" == "cygwin" ]]; then
  echo "$OSTYPE is a Windows ENV"

  yes_or_no_mintty "Are you running MSYS2 UCRT64 mintty shell as administrator? [y/n]"
  RESULT=$?
  if [ $RESULT -eq 0 ]; then 
    #Install neovim
    if pacman -S --noconfirm mingw-w64-ucrt-x86_64-neovim ; then 
      echo "SUCCESS installed neovim, continuing with setup..."
      if pacman -S --noconfirm git ; then 
        echo "SUCCESS installed git, continuing..."
        if git clone https://github.com/Ant4ce/files-neo-setup.git ~/.config/nvim/ ; then 
          export XDG_CONFIG_HOME=~/.config/
          echo "exported XDG_CONFIG_HOME env variable. Continuing..."
          echo "export XDG_CONFIG_HOME=~/.config/" >> ~/.bashrc
          echo "changed '.bashrc' file. Continuing..."
          echo "Downloading nerd font: minw-w64-ucrt-x86_64-otf-atkinson-hyperlegible-mono-nerd"
          if pacman -S --noconfirm mingw-w64-ucrt-x86_64-ttf-0xproto-nerd ; then
            echo "Downloaded nerd font (0xproto), now trying to install it within msys2 (mintty terminal)..."
            # Temporary directory to hold .ttf files.
            mkdir /c/temp
            if cp /ucrt64/share/fonts/TTF/*.ttf /c/temp/ ; then
              echo "Succesfully transfered .ttf files to temp folder..."
              if powershell.exe -NoProfile -Command "Get-ChildItem 'C:\temp\*.ttf' | ForEach-Object { Copy-Item \$_.FullName -Destination \$env:WINDIR\\Fonts }" ; then 

                echo "Successfully Copied .ttf files into C:\\Windows\\Fonts"
                if powershell.exe -NoProfile -Command "New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' -Name '0xProto Nerd Font' -Value '0xProtoNerdFont-Regular.ttf' -PropertyType String -Force" ; then 
                  echo "Successfully added registry entry of Font to Windows..."
                  echo "Cleaning up temp folder and contents..."
                  rm -rf /c/temp
                  if touch ~/.minttyrc ; then
                    if ! grep -q '^Font=0xProto Nerd Font$' ~/.minttyrc ; then 
                      printf '\nFont=0xProto Nerd Font\nFontHeight=11\n' >> ~/.minttyrc

                      if pacman -S --noconfirm mingw-w64-ucrt-x86_64-rust mingw-w64-ucrt-x86_64-clang ; then 
                        echo "Installed rust & clang & llvm (NOTE: llvm not strictly necessary). Continuing..."
                        export LIBCLANG_PATH=/ucrt64/bin
                        echo "Adding LIBCLANG_PATH export to .bashrc"
                        echo "export LIBCLANG_PATH=/ucrt64/bin" >> ~/.bashrc
                        echo "Installing treesitter cli... required for nvim-treesitter."
                        if cargo install --locked tree-sitter-cli ; then 
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
                        else 
                          echo "Failed to install treesitter-cli from cargo."
                        fi
                      else 
                        echo "Failed to install rust."
                      fi
                    else 
                      echo "~/.minttyrc file already has contents"
                      echo "FINISHED SUCCESSFULLY."
                    fi
                  else 
                    echo ".minttyrc already Exists... STOPPING."
                  fi
                else 
                  echo "Failed to add registry entry for font in Windows... STOPPING."
                fi
              else 
                echo "Failed to copy items over with powershell command to C:\Windows\Fonts directory... STOPPING."
              fi
            else 
              echo "Failed to transfer .ttf files to temp location...STOPPING."
            fi
          else 
            echo "Failed to install nerd font."
          fi

        else
          echo "FAILED to clone setup files. STOPPING."
        fi
      else
        echo "FAILED to install git. STOPPING."
      fi
    else
      echo "FAILED to install neovim. STOPPING."
    fi

  else
    echo "Switch to priviledged administrator shell to run this script."
  fi

else 
  printf "OS type is not supported. \nOnly Ubuntu, Arch and Windows (MSYS2) are currently supported. \n"

fi

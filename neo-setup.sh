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
                          echo "You should see icons inside of NVIM when you open neo-tree"
                          echo "FINSISHED SUCCESSFULLY!\nType NVIM to start and expect Lazy to show and install packages."
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

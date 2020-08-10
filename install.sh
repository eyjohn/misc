#!/bin/bash
echo "Installing dotfiles"

BASE="$( cd "$(dirname "$0")" ; pwd -P )"

source "$BASE/functions.sh"

if [ ! -L ~/.dotfiles ]; then
  echo "Adding .dotfiles link"
  ln -s "$BASE" ~/.dotfiles
fi

mkdir -m 0700 ~/.ssh

DIRS=(.profile.d/ bin/ .ssh/config.d .ssh/sockets)
mkdir -p ${DIRS[@]/#/~/}

TARGETS=(.bash_aliases .gitconfig .gitignore_global)
cp -asvb ${TARGETS[@]/#/~/.dotfiles/} ~/

# .ssh/config.d doesn't support backups
cp -asvi ~/.dotfiles/.ssh/config.d/github ~/.ssh/config.d/

[ ! -f ~/.ssh/config ] && echo > ~/.ssh/config # Add blank line for prepend to work
prepend_file ~/.ssh/config 'Include config.d/*'
insert_file ~/.profile 'for f in ~/.profile.d/*[^~]; do source $f; done'

if grep -q '#force_color_prompt=yes' ~/.bashrc; then 
  echo "Patching .bashrc to force_color_prompt=yes"
  sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/' ~/.bashrc
fi

if git --git-dir "$BASE/.git" remote get-url origin | grep -q ://github.com && confirm "Patch git remote to ssh variant? [y/n]:"; then 
  GIT_REMOTE=github:$(git remote get-url origin | sed 's%.*://github\.com/\(.*\)\.git%\1%')
  git --git-dir "$BASE/.git" remote set-url origin "$GIT_REMOTE"
fi

if confirm "Install and configure npm? [y/n]: "; then
  sudo apt -y install npm
  touch ~/.npmrc
  sed -i "/^prefix/d" ~/.npmrc
  mkdir -p ~/.npm-packages/
  echo prefix = ~/.npm-packages/ > ~/.npmrc
  cp -asvb ~/.dotfiles/.profile.d/15_npm_path ~/.profile.d/
fi

if confirm "Install and configure golang? [y/n]: "; then
  sudo apt -y install golang-go
  cp -asvb ~/.dotfiles/.profile.d/16_go_path ~/.profile.d/
fi

if confirm "Install kubectl? [y/n]: "; then
  sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update
  sudo apt-get install -y kubectl
fi

if which kubectl > /dev/null && confirm "Install kubectl autocomplete? [y/n]: "; then
  cp -asvb ~/.dotfiles/.profile.d/18_kubectl_autocomplete ~/.profile.d/
fi

if confirm "Install brig (Brigade CLI)? [y/n]: "; then
  curl -s https://api.github.com/repos/brigadecore/brigade/releases/latest \
    | grep "browser_download_url.*linux-amd64" \
    | cut -d '"' -f 4 \
    | wget -i - -O ~/bin/brig
  chmod +x ~/bin/brig
  cp -asvb ~/.dotfiles/.profile.d/17_brigade_namespace ~/.profile.d/
fi

if confirm "Install gcloud SDK? [y/n]: "; then
  # Add the Cloud SDK distribution URI as a package source
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

  # Import the Google Cloud Platform public key
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

  # Update the package list and install the Cloud SDK
  sudo apt-get update && sudo apt-get -y install google-cloud-sdk
fi

# WSL Specifics
WSL_VERSION=$(wsl.exe -l -v | sed $'s/[^[:print:]\t]//g' | grep -a '[*]' | awk '{print $4}')
if [ -n "$WSL_VERSION" ]; then
  echo "Detected WSL Environment, Version: $WSL_VERSION"
  source $BASE/wsl/install.sh
fi

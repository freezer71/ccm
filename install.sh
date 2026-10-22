#!/bin/zsh
# Installe ccm : lien ~/.local/bin/ccm vers bin/ccm, et ~/.local/bin dans le PATH.
#
# Depuis un clone :      zsh install.sh
# Sans clone :           curl -fsSL https://raw.githubusercontent.com/freezer71/ccm/main/install.sh | zsh
# Relancer le script met à jour une installation existante.
emulate -L zsh
setopt no_unset pipe_fail err_exit

REPO=${CCM_REPO:-https://github.com/freezer71/ccm.git}
SRC=${CCM_INSTALL_DIR:-$HOME/.local/share/ccm}
BIN=${CCM_BIN_DIR:-$HOME/.local/bin}

die() { print -ru2 -- "install: $*"; exit 1 }
say() { print -r -- "• $*" }

[[ $OSTYPE == darwin* ]] || die "ccm ne fonctionne que sous macOS (trousseau, plutil)."
command -v git >/dev/null || die "git est introuvable (xcode-select --install)."

# Lancé depuis un clone : on installe ce clone. Sinon (curl | zsh) : on clone
# dans $SRC, ou on le met à jour s'il existe déjà.
script=${(%):-%x}
if [[ -f $script && -f ${script:A:h}/bin/ccm ]]; then
  SRC=${script:A:h}
  say "Installation depuis $SRC"
elif [[ -d $SRC/.git ]]; then
  say "Mise à jour de $SRC"
  git -C $SRC pull --ff-only --quiet
else
  say "Téléchargement dans $SRC"
  mkdir -p ${SRC:h}
  git clone --quiet $REPO $SRC
fi

chmod +x $SRC/bin/ccm
mkdir -p $BIN
ln -sfn $SRC/bin/ccm $BIN/ccm
say "Commande installée : $BIN/ccm → $SRC/bin/ccm"

# ~/.local/bin dans le PATH des prochains terminaux.
if (( ! ${path[(Ie)$BIN]} )); then
  line="export PATH=\"${BIN/#$HOME/\$HOME}:\$PATH\""
  if ! grep -qsF -- $line ~/.zshrc; then
    print -rl -- "" "# ccm" $line >> ~/.zshrc
    say "Ajouté à ~/.zshrc : $line"
  fi
  say "Ouvrez un nouveau terminal (ou « source ~/.zshrc ») pour utiliser « ccm »."
fi

if ! command -v claude >/dev/null; then
  say "Attention : « claude » est introuvable. Installez Claude Code avant d'utiliser ccm :"
  say "https://docs.claude.com/fr/docs/claude-code/setup"
fi

say "Terminé. Essayez : ccm list"

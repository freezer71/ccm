# Installation

## Prérequis

- **macOS**. `ccm` utilise le trousseau macOS (`security`), `plutil` et le `date` de BSD :
  il ne fonctionne pas sous Linux ni sous Windows.
- **zsh**, le shell par défaut de macOS. Le script se lance avec `/bin/zsh`, quel que
  soit votre shell.
- **Claude Code**, installé et déjà connecté à votre compte habituel : la commande
  `claude` doit être dans le `PATH`.

  ```sh
  claude --version
  ```

  Sinon, voir la [documentation de Claude Code](https://docs.claude.com/fr/docs/claude-code/setup).

Les autres outils utilisés (`curl`, `shasum`, `uuidgen`, `security`, `plutil`) sont livrés
avec macOS.

## Installation rapide

```sh
curl -fsSL https://raw.githubusercontent.com/freezer71/ccm/main/install.sh | zsh
```

Le script :

1. clone le dépôt dans `~/.local/share/ccm` (ou le met à jour s'il y est déjà) ;
2. crée le lien `~/.local/bin/ccm` vers `bin/ccm` ;
3. ajoute `~/.local/bin` au `PATH` dans `~/.zshrc` s'il n'y est pas déjà ;
4. prévient si la commande `claude` est introuvable.

Il peut être relancé sans risque : il ne crée pas de doublon dans `~/.zshrc`.
Ouvrez ensuite un nouveau terminal.

Depuis un clone existant, `zsh install.sh` installe ce clone-là au lieu d'en télécharger un.

Emplacements réglables : `CCM_INSTALL_DIR` (dossier du code), `CCM_BIN_DIR` (dossier de
la commande), `CCM_REPO` (adresse du dépôt).

## Installation manuelle

```sh
git clone https://github.com/freezer71/ccm.git ~/.local/share/ccm
mkdir -p ~/.local/bin
ln -sf ~/.local/share/ccm/bin/ccm ~/.local/bin/ccm
```

Le dossier cloné doit rester en place : la commande installée est un lien vers lui.
Si `command -v ccm` n'affiche rien, ajoutez `~/.local/bin` au `PATH`, puis ouvrez un
nouveau terminal :

```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

## Vérifier

```sh
ccm help
ccm list
```

`ccm list` doit afficher le compte `main`, c'est-à-dire votre `~/.claude` actuel, avec son
email. Le dossier `~/.ccm` est créé à ce premier lancement.

## Ajouter un compte

```sh
ccm add pro
ccm pro
```

Au premier `ccm pro`, Claude Code demande de se connecter : choisissez l'autre compte.
Les lancements suivants ne le demandent plus. Les conversations, `CLAUDE.md`,
`settings.json`, plugins, skills, hooks et agents sont ceux de `~/.claude`.

Voir le [README](README.md) pour toutes les commandes.

## Mettre à jour

Relancez la commande d'installation, ou :

```sh
git -C ~/.local/share/ccm pull
```

## Lancer les tests

```sh
zsh ~/.local/share/ccm/test/ccm_test.zsh
```

Les tests tournent dans un dossier temporaire, avec de faux `claude`, `security` et
`curl` : ils ne touchent ni à `~/.claude`, ni à `~/.ccm`, ni au trousseau, et
n'appellent pas l'API.

## Désinstaller

1. Supprimez chaque compte ajouté, ce qui efface aussi sa connexion dans le trousseau :

   ```sh
   ccm list          # pour voir les noms
   ccm rm pro        # pour chaque compte sauf main
   ```

   Les conversations sont conservées dans `~/.claude`.

2. Supprimez `ccm` lui-même :

   ```sh
   rm -rf ~/.ccm ~/.local/bin/ccm ~/.local/share/ccm
   ```

`~/.claude` et la connexion du compte `main` ne sont jamais modifiés.

## Variables d'environnement

| Variable        | Par défaut   | Rôle                                                    |
| --------------- | ------------ | ------------------------------------------------------- |
| `CCM_HOME`      | `~/.ccm`     | Dossier des comptes, des noms et du cache d'usage       |
| `CCM_SHARED`    | `~/.claude`  | Dossier partagé entre tous les comptes (compte `main`)  |
| `CCM_USAGE_TTL` | `60`         | Secondes pendant lesquelles `ccm list` réutilise un relevé d'usage |

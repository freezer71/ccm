#!/bin/zsh
# Tests de ccm : un faux `claude` et un faux `security` enregistrent ce qu'on leur passe.
emulate -L zsh
setopt no_unset

ROOT=${0:A:h:h}
CCM=$ROOT/bin/ccm
fails=0

setup() {
  T=$(mktemp -d)
  export HOME=$T/home CCM_HOME=$T/ccm CCM_SHARED=$T/home/.claude
  mkdir -p $HOME $CCM_SHARED/projects $T/bin
  print -r -- '{"oauthAccount":{"emailAddress":"main@example.com"},"mcpServers":{"m":{"command":"x"}}}' > $HOME/.claude.json
  cat > $T/bin/claude <<'EOF'
#!/bin/zsh
print -r -- "CONFIG=${CLAUDE_CONFIG_DIR-<unset>}" > $LOG
print -r -- "ARGS=$*" >> $LOG
EOF
  cat > $T/bin/security <<'EOF'
#!/bin/zsh
print -r -- "security $*" >> $LOG.security
[[ $1 == find-generic-password && -n ${FAKE_CREDS-} ]] && print -r -- $FAKE_CREDS
exit 0
EOF
  cat > $T/bin/curl <<'EOF'
#!/bin/zsh
# Faux curl : -o reçoit le corps, -D les en-têtes, la sortie le code HTTP.
print -r -- "$*" >> $LOG.curl
cat >> $LOG.curl
local body= headers=
while (( $# )); do
  case $1 in -o) body=$2; shift ;; -D) headers=$2; shift ;; esac
  shift
done
[[ -n ${FAKE_CURL_FAIL-} ]] && { print -n 000; exit 7 }
[[ -n $headers ]] && print -r -- "retry-after: 300" > $headers
[[ -n $body ]] && print -r -- $FAKE_USAGE > $body
print -n ${FAKE_CODE:-200}
EOF
  chmod +x $T/bin/claude $T/bin/security $T/bin/curl
  export PATH=$T/bin:$PATH LOG=$T/log CCM_SECURITY=$T/bin/security
}

real() { print -r -- ${1:A} }

check() { # check <description> <commande...>
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then print -r -- "ok   $desc"
  else print -r -- "FAIL $desc"; fails=$((fails + 1)); fi
}

setup

check "add crée un profil"                $CCM add pro
dir=$(real $CCM_HOME/profiles/pro)
check "projects est partagé"              test "$(real $dir/projects)" = "$(real $CCM_SHARED/projects)"
check "history.jsonl est partagé"         test "$(readlink $dir/history.jsonl)" = "$CCM_SHARED/history.jsonl"
check "settings.json est partagé"         test -L $dir/settings.json
check "les serveurs MCP sont copiés"      grep -q '"m"' $dir/.claude.json

$CCM pro -c --model opus
check "lance claude avec le bon dossier"  grep -qx "CONFIG=$dir" $LOG
check "transmet les arguments"            grep -qx "ARGS=-c --model opus" $LOG

CLAUDE_CONFIG_DIR=/autre $CCM main
check "main n'utilise pas CLAUDE_CONFIG_DIR" grep -qx "CONFIG=<unset>" $LOG

check "rename garde le même dossier"      $CCM rename pro travail
check "le nouveau nom pointe au même endroit" test "$(real $CCM_HOME/profiles/travail)" = "$dir"
check "l'ancien nom n'existe plus"        test ! -e $CCM_HOME/profiles/pro

print -r -- '{"oauthAccount":{"emailAddress":"pro@example.com"}}' > $dir/.claude.json
check "list affiche les emails"           eval "$CCM list | grep travail | grep -q pro@example.com"
check "list affiche main"                 eval "$CCM list | grep main | grep -q main@example.com"

now_ms=$(( $(date +%s) * 1000 ))
cat > $dir/.claude.json <<EOF
{"oauthAccount":{"emailAddress":"pro@example.com"},
 "cachedUsageUtilization":{"fetchedAtMs":$((now_ms - 7200000)),"utilization":{
   "five_hour":{"utilization":34,"resets_at":"2000-01-01T00:00:00.1+00:00"},
   "seven_day":{"utilization":70,"resets_at":"2999-01-01T00:00:00.1+00:00"}}}}
EOF
check "list affiche l'usage de la semaine" eval "$CCM list | grep travail | grep -q '70%'"
check "session expirée = réinitialisée"   eval "$CCM list | grep travail | grep -q 'réinit'"
check "list affiche l'âge du relevé"       eval "$CCM list | grep travail | grep -q 'il y a 2 h'"
check "pas d'usage = tiret"               eval "$CCM list | grep main | grep -q ' — '"

# Usage en direct : jeton lu dans le trousseau, envoyé à l'API d'usage.
calls() { grep -c "^-sS" $LOG.curl 2>/dev/null || print 0 }
export FAKE_CREDS="{\"claudeAiOauth\":{\"accessToken\":\"sk-ant-oat-SECRET\",\"expiresAt\":$((now_ms + 3600000))}}"
export FAKE_USAGE='{"five_hour":{"utilization":12.0,"resets_at":"2999-01-01T00:00:00.1+00:00"},"seven_day":{"utilization":45.0,"resets_at":"2999-01-01T00:00:00.1+00:00"}}'
check "list affiche l'usage en direct"    eval "$CCM list | grep travail | grep '12%' | grep '45%' | grep -qv '('"
check "le jeton n'est pas dans les arguments" eval "! grep -v '^Authorization' $LOG.curl | grep -q SECRET"
check "le jeton est envoyé en en-tête"    grep -q '^Authorization: Bearer sk-ant-oat-SECRET' $LOG.curl
check "main lit sa propre entrée"         grep -q 'find-generic-password -s Claude Code-credentials -w' $LOG.security
before=$(calls); $CCM list >/dev/null
check "pas de nouvel appel avant 60 s"    test $(calls) -eq $before

# L'API limite (429) : on garde le dernier relevé et on attend retry-after.
touch -t $(date -v-1H +%Y%m%d%H%M) $CCM_HOME/usage/*.json  # plus récent que le cache de Claude Code (2 h)
before=$(calls)
check "429 = dernier relevé conservé"     eval "FAKE_CODE=429 $CCM list | grep travail | grep -q '12%'"
check "429 = un appel par compte"         test $(calls) -eq $(( before + 2 ))
before=$(calls); $CCM list >/dev/null
check "429 = plus d'appel avant retry-after" test $(calls) -eq $before

rm -rf $CCM_HOME/usage
check "échec réseau = cache de Claude Code" eval "FAKE_CURL_FAIL=1 $CCM list | grep travail | grep -q '70%'"
rm -rf $CCM_HOME/usage
export FAKE_CREDS="{\"claudeAiOauth\":{\"accessToken\":\"sk-ant-oat-SECRET\",\"expiresAt\":$((now_ms - 1000))}}"
check "jeton expiré = cache, signalé"     eval "$CCM list | grep travail | grep '70%' | grep -q 'expiré'"
unset FAKE_CREDS FAKE_USAGE

check "refuse un nom réservé"            eval "! $CCM add list"
check "refuse un nom invalide"            eval "! $CCM add 'a b'"
check "refuse un doublon"                 eval "! $CCM add travail"
check "refuse un profil inconnu"          eval "! $CCM inconnu"

check "rm supprime le profil"             $CCM rm travail
check "le dossier du compte est supprimé" test ! -e $dir
check "rm efface la connexion du trousseau" grep -q "delete-generic-password" $LOG.security
check "rm efface le cache d'usage"        eval "! ls $CCM_HOME/usage | grep -qv '^Claude_Code-credentials\.'"
check "les conversations restent"         test -d $CCM_SHARED/projects

check "rm main ne touche pas ~/.claude"   $CCM rm main
check "~/.claude est intact"              test -d $CCM_SHARED/projects

rm -rf $T
(( fails == 0 )) && print "Tous les tests passent." || { print "$fails échec(s)."; exit 1; }

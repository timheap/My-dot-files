#!/bin/bash

set -eE -o functrace
failure() {
	local lineno=$1
	local msg=$2
	echo "Failed at $lineno: $msg"
}
trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

source ~/.bashrc.d/colours.sh

T="tmux -q"
VERSION=`tmux -V | cut -d' ' -f2`
SESSION_NAME="$1"

# True if the tmux version is at least the version passed in, or higher.
function is_version() {
	test_version=$1
	actual_version=$VERSION

	best_version=$( sort -r <( echo "$test_version" ; echo "$actual_version" ) | head -n 1 )

	[[ "$best_version" == "$actual_version" ]]
}

function t-set-option() {
	$T set-option -gqs "$@"
}

SET_OPTION="set-option -gqs"

# Import some environment variables
function import_env() {
	local env_var="$1"
	local env_default="$2"

	# If the environment variable is not set already
	if ! tmux show-environment "$env_var" &>/dev/null ; then
		if tmux show-environment -g "$env_var" &>/dev/null ; then
			# Get the variable from the global environment
			$T set-environment "$env_var" "$( tmux show-environment -g "$env_var" | sed 's/^[^=]*=//' )"
		elif [[ $# -ge 2 ]] ; then
			# Otherwise use the default
			$T set-environment "$env_var" "$env_default"
		fi
	fi
}
if tmux has-session ; then
	import_env "DISPLAY" ":0"
	import_env "SSH_AGENT_PID"
	import_env "SSH_AUTH_SOCK"
	import_env "GPG_AGENT_INFO"
	import_env "DBUS_SESSION_BUS_ADDRESS"
fi

# Control-q for prefix. Bugger all uses it, and it is close
t-set-option prefix "C-q"

# Using vim + tmux requires instant escape codes
t-set-option escape-time 0

t-set-option allow-rename off
t-set-option display-time 3000
t-set-option mouse on
t-set-option mouse-resize-pane on
t-set-option mouse-select-pane on
t-set-option mouse-select-window on

# Status bar style
# The colour scheme is purple:
# * colour219 (bright) for focused items
# * colour125 (mid) for other items
# * colour053 (dark) for spacing/padding
t-set-option status-style bg=colour$TMUX_FILL
t-set-option status-position top

t-set-option status-left ' #S '
t-set-option status-left-style "fg=colour$TMUX_ACTIVE bg=black"
t-set-option status-left-length 30


t-set-option status-right ''
t-set-option status-right-length 0

t-set-option status-interval 0

t-set-option pane-active-border-style fg=colour$TMUX_ACTIVE
t-set-option pane-border-style fg=colour$TMUX_FILL

t-set-option window-status-current-style "fg=black bg=colour$TMUX_ACTIVE"
t-set-option window-status-current-format "❨#I│#W❩"

t-set-option window-status-style "fg=black bg=colour$TMUX_INACTIVE"
t-set-option window-status-format " #I│#W "

t-set-option message-command-style "fg=colour$TMUX_ACTIVE bg=black"
t-set-option message-style "fg=black bg=colour$TMUX_ACTIVE"


### tmux bindings


## Window management

# PREFIX C-Q: Last window
$T bind '`' last-window

# S-left/S-right: Switch windows
$T bind -n S-left prev
$T bind -n S-right next

# PREFIX T/t to switch windows, ala vim
# Useful when terminals do not support Shift+arrows (Terminal.app)
$T bind T prev
$T bind t next

# PREFIX S-left/S-right: Move windows
$T bind -r S-left  swap-window -t -1
$T bind -r S-right swap-window -t +1

# PREFIX ^C: Create named window
$T bind-key ^C command-prompt -p 'name:' "new-window -n '%1'"


## Pane management

# Split panes using | and -
$T bind '\' split-window -h
$T bind '|' split-window -h
$T bind '-' split-window -v
$T bind '_' split-window -v

# Remove default split pane binding since we replaced it
$T unbind %
$T unbind '"'

# Prefix C-Q for last pane
$T bind ^Q last-pane

# Prefix F for fullscreen
$T bind ^F resize-pane -Z
$T unbind 'z'

# Disable repeatable keys when switching panes
$T bind-key Up    select-pane -U
$T bind-key Down  select-pane -D
$T bind-key Left  select-pane -L
$T bind-key Right select-pane -R

# Select panes with S-M-arrows
$T bind-key -n S-M-Up    select-pane -U
$T bind-key -n S-M-Down  select-pane -D
$T bind-key -n S-M-Left  select-pane -L
$T bind-key -n S-M-Right select-pane -R


## Misc bindings

# Reload this conf file
$T bind ^r run-shell "~/.tmux.d/conf.sh 1>/dev/null"

# Don't exit copy mode when selecting with the mouse
# $T bind -tvi-copy MouseDragEnd1Pane copy-selection -s


### Quick program launching

# PREFIX S-_: Open small terminal below or above
$T bind-key "_" split-window -vp 20
$T bind-key "+" new-window -dn '__split__' '\;' move-pane -vbp 80 -s ':__split__.'

# PREFIX S->: Open small terminal to the right or left
$T bind-key ">" split-window -hp 30
$T bind-key "<" new-window -dn '__split__' '\;' move-pane -hbp 70 -s ':__split__.'

$T bind-key C-y run-shell "tmux save-buffer - | DISPLAY=${DISPLAY:-:0} xclip -i -selection clipboard"
$T bind-key C-p run-shell "DISPLAY=${DISPLAY:-:0} xclip -i -selection clipboard | tmux load-buffer -" '\;' paste-buffer

$T run-shell "~/.tmux.d/tmux-yank/yank.tmux"



# Source local tmux commands
if [[ -e ~/.tmux.conf.local.sh ]] ; then
	$HOME/.tmux.conf.local.sh
fi

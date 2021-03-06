# Python configuration and helpers
# --------------------------------

# Settings for python shells
export PYTHONSTARTUP=~/.pythonrc
export PYTHONDONTWRITEBYTECODE=1
export PYTHON_VENV_NAME=".venv"

# Locally installed python packages
if [[ -z "$PYTHONPATH" ]] ; then
	local_python="$HOME/.local/lib/python2.7/site-packages"
	if [[ -d "$local_python" ]] ; then
		export PYTHONPATH="$local_python"
	fi
	unset local_python
fi

# Warn about using the global pip. This usually means we forgot to activate a
# virtualenv
system_pip=`env -i bash -c which pip &>/dev/null`
if [[ $? -eq 0 ]] ; then
	last_pip_time=0
	pip_cooldown=300 # five minutes
	function pip() {
		current_pip=`which pip`
		if [[ "$current_pip" == "$system_pip" ]] ; then
			current_time="$( date +%s )"
			if [[ "$(( $last_pip_time + $pip_cooldown ))" -le $current_time ]] ; then
				echo "You are using the system-wide pip."
				read -r -p "Are you sure you want to do this? [y/N] " response
			else
				response="y"
			fi

			case $response in
				[yY])
					$current_pip $@
					last_pip_time=$current_time
					;;
				*) ;;
			esac
		else
			$current_pip $@
		fi
	}
fi

# Make and source a virtualenv in the current directory
alias mkvenv.python=_mkvenv_python
function _mkvenv_python() {
	local venv="$PYTHON_VENV_NAME"
	local dir="${1:-`pwd`}"
	local pip="${dir}/$venv/bin/pip"
	python3 -mvenv "$dir/$venv"

	"$pip" install --upgrade pip wheel

	[ -e "${dir}/requirements.txt" ] && "$pip" install -r "${dir}/requirements.txt"
	[ -e "${dir}/setup.py" ] && "$pip" install -e "${dir}"

	_venv_up "$dir"
}

# Find all .pyc and __pycache__ files and delete them
function rmpycache() {
	find "${1:-.}" '(' -name __pycache__ -o -name '*.pyc' ')' -exec rm -rf '{}' '+' -prune
}

#!/usr/bin/env bash

readonly red='\e[0;31m'
readonly green='\e[0;32m'
readonly yellow='\e[0;33m'
readonly Bred='\e[0;41m'

readonly reset='\e[0m'
readonly Breset='\e[49m'

readonly Bold='\e[1m'

readonly underline='\e[4m'
readonly nounderline='\e[24m'

_die() {
   echo -e "${red}${Bold}Error:${reset} ${@}" >&2
   exit 1
}

cmd_report_usage() {
   echo
   cat <<-EOF
Usage:
      $PROGRAM report [-c|--color] [-l|--length] [<password file>]
            Report last change's date and age of all passwords or given
            password

         Options:
            -c, --color    Show old password (more than 2 years) in yellow
            -l, --length   Show password length indication
            -h, --help     Show this help

         Password length indication:
            very short     Less than 8 characters
            short          Less than 13 characters
            medium         Less than 17 characters
            long           17 characters or more
EOF
}

cmd_report() {
   _file="$1"

   check_sneaky_paths "$_file"

   [ ! -d "$PREFIX/.git" ] && _die "Your password store does not use .git, can't show report"

   [ -z "$_file" ] && _cmd_report_all_passwords || _cmd_report_password ${_file%/}
}

_cmd_report_all_passwords() {
   git -C "$PREFIX" ls-tree -r --name-only HEAD | grep -E "\.gpg$" | while read filename ; do
      _cmd_report_password "$filename"
   done
}

_cmd_report_password() {
   _file="$1"

   if [ ! -f "${PREFIX}/${_file}" ]; then
      if [ ! -f "${PREFIX}/${_file}.gpg" ]; then
         _die "$_file: no such file or directory"
      else
         _file="${_file}.gpg"
      fi
   fi

   _password_data=$(git -C "$PREFIX" blame -L 1,1 -p ${_file} | sed -e 1b -e '$!d')
   _commit=$(echo $_password_data | cut -d' ' -f1)
   _length=$(echo $_password_data | awk '{print $NF}' | wc -c)
   _date=$(git -C "$PREFIX" show --date=short --format="%cd  %cr" --no-patch $_commit)

   _print_report "$_file" "$_length" "$_date"
}

# $1: filename
# $2: length
# $3: date
_print_report() {
   _password=${1/%.gpg/}
   _length=$2
   _date=${3%  *}
   _age=${3#*  }

   _format_date_width=14
   _format_age_width=28
   _format_length_indication_width=11

   _format_age="%-${_format_age_width}s"
   _format_length_indication=" "
   _format_password="%s"

   _local_format_password=$_format_password
   _local_format_age=$_format_age

   [ "$COLOR" = 1 ] && echo $_age | grep -q "years" \
      && _local_format_age="${yellow}%-${_format_age_width}s${reset}" \
      && _local_format_password="${yellow}%s${reset}"

   _local_format_length_indication=""
   if [[ "$LENGTH" -eq 1 ]]; then
      _format_length_indication="%-${_format_length_indication_width}s"
      if [[ $_length -lt 8 ]]; then
         _length_indication="very short"
         _local_format_length_indication="${Bred}${_format_length_indication}${Breset}"
         _local_format_password="${Bred}${_format_password}${Breset}"
      elif [[ $_length -lt 13 ]]; then
         _length_indication="short"
         _local_format_length_indication="${red}${_format_length_indication}${reset}"
         _local_format_password="${red}${_format_password}${reset}"
      elif [[ $_length -lt 17 ]]; then
         _length_indication="medium"
         _local_format_length_indication="${yellow}${_format_length_indication}${reset}"
         _local_format_password="${yellow}${_format_password}${reset}"
      else
         _length_indication="long"
         _local_format_length_indication="${green}${_format_length_indication}${reset}"
      fi

      # Add spaces for final format
      _local_format_length_indication=" ${_local_format_length_indication} "
   fi

   [ "$COLOR" = 1 ] \
      && _format_password=$_local_format_password \
      && _format_length_indication=$_local_format_length_indication \
      && _format_age=$_local_format_age

   _format="%-${_format_date_width}s ${_format_age}${_format_length_indication}${_format_password}\n"
   [ "$LENGTH" = 1 ] \
      && printf "${_format}" "$_date" "$_age" "$_length_indication" "$_password" \
      || printf "${_format}" "$_date" "$_age" "$_password"
}

COLOR=0
LENGTH=0

# Getopt options
small_arg="chl"
long_arg="color,help,length"
opts="$($GETOPT -o $small_arg -l $long_arg -n "$PROGRAM $COMMAND" -- "$@")"
err=$?
eval set -- "$opts"
while true; do case $1 in
   -c|--color) COLOR=1; shift ;;
   -l|--length) LENGTH=1; shift ;;
   -h|--help) shift; cmd_report_usage; exit 0 ;;
   --) shift; break ;;
esac done

[[ $err -ne 0 ]] && cmd_report_usage && exit 1
cmd_report "$@"

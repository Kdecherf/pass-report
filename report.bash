#!/usr/bin/env bash

readonly red=$(tput setaf 1)
readonly green=$(tput setaf 2)
readonly yellow=$(tput setaf 3)
readonly Bred=$(tput setab 1)

readonly reset=$(tput sgr0)

readonly Bold=$(tput bold)

readonly underline=$(tput smul)
readonly nounderline=$(tput rmul)

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
   local file="$1"

   check_sneaky_paths "$file"

   [ ! -d "$PREFIX/.git" ] && _die "Your password store does not use .git, can't show report"

   if [ -z "$file" ]; then
      _cmd_report_all_passwords
   else
      if [ -d "${PREFIX}/${file}" ]; then
         _cmd_report_all_passwords "$file"
      else
         _cmd_report_password ${file%/}
      fi
   fi
}

_cmd_report_all_passwords() {
   pass_prefix="$1"

   git -C "$PREFIX" ls-tree -r --name-only HEAD | grep "^${pass_prefix}" | grep -E "\.gpg$" | while read filename ; do
      _cmd_report_password "$filename"
   done
}

_cmd_report_password() {
   local file="$1"

   if [ ! -f "${PREFIX}/${file}" ]; then
      if [ ! -f "${PREFIX}/${file}.gpg" ]; then
         _die "$file: no such file or directory"
      else
         file="${file}.gpg"
      fi
   fi

   local password_data=$(git -C "$PREFIX" blame -L 1,1 -p ${file} | sed -n '1 s/^\([0-9a-f]\+\) .*$/\1/ p ; $ s/^\s\+\(.*\)$/\1/ p')
   local commit=$(echo $password_data | cut -d' ' -f1)
   local length=$(echo $password_data | cut -d' ' -f2- | wc -c)
   local date=$(git -C "$PREFIX" show --date=short --format="%cd  %cr" --no-patch $commit)

   _print_report "$file" "$length" "$date"
}

# $1: filename
# $2: length
# $3: date
_print_report() {
   local password=${1/%.gpg/}
   local length=$2
   local date=${3%  *}
   local age=${3#*  }

   local format_date_width=14
   local format_age_width=28
   local format_length_indication_width=11

   local format_age="%-${format_age_width}s"
   local format_length_indication=" "
   local format_password="%s"

   local local_format_password=$format_password
   local local_format_age=$format_age

   local local_format_length_indication=""

   local length_indication=""

   [ "$COLOR" = 1 ] && echo $age | grep -q "years" \
      && local_format_age="${yellow}%-${format_age_width}s${reset}" \
      && local_format_password="${yellow}%s${reset}"

   if [[ "$LENGTH" -eq 1 ]]; then
      format_length_indication="%-${format_length_indication_width}s"
      if [[ $length -lt 8 ]]; then
         length_indication="very short"
         local_format_length_indication="${Bred}${format_length_indication}${reset}"
         local_format_password="${Bred}${format_password}${reset}"
      elif [[ $length -lt 13 ]]; then
         length_indication="short"
         local_format_length_indication="${red}${format_length_indication}${reset}"
         local_format_password="${red}${format_password}${reset}"
      elif [[ $length -lt 17 ]]; then
         length_indication="medium"
         local_format_length_indication="${yellow}${format_length_indication}${reset}"
         local_format_password="${yellow}${format_password}${reset}"
      else
         length_indication="long"
         local_format_length_indication="${green}${format_length_indication}${reset}"
      fi

      # Add spaces for final format
      local_format_length_indication=" ${local_format_length_indication} "
   fi

   [ "$COLOR" = 1 ] \
      && format_password=$local_format_password \
      && format_length_indication=$local_format_length_indication \
      && format_age=$local_format_age

   local format="%-${format_date_width}s ${format_age}${format_length_indication}${format_password}\n"
   [ "$LENGTH" = 1 ] \
      && printf "${format}" "$date" "$age" "$length_indication" "$password" \
      || printf "${format}" "$date" "$age" "$password"
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

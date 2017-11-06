#!/bin/bash
#
# BASH script which renames a Let's Encrypt certificate
#
# author: David Foley, dev@dfoley.ie
# licence:
#   Copyright 2017 David John Foley
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License. 

## Init
TIME=$(date +%s)

display_help() {
cat << EOF

usage: letsencrypt_rename_cert.sh [OPTION...] <current name> <new name>

BASH script which renames a Let's Encrypt certificate

required arguments:

  certbot_rename_cert.sh [OPTION...] <current name> <new name>

	<current name> 
		Current 'Certificate Name' from 'certbot certificates' command output
	<new name>
		New 'Certificate Name'

optional arguments:
	-d	disable backups of existing configuration. NOT RECCOMMENDED!
	-h	display this help and exit
	-i  ignore errors and continue regardless	
	-p	path to Let's Encrypt configuration and certificates. Default: /etc/letsencrypt
	-s	silent mode, no output
	
EOF
}

prompt_disclaimer() {
cat << EOF

Before we continue some important information:

+ Let's Encrypt renewal config files are copied to a .bak file before modification
+ The entire Let's Encrypt folder is copied to '/etc/letsencrypt.bak' by default 

==========================
WARNING! WARNING! WARNING!
==========================

- The Let's Encrypt configuration on this host may be damaged by this script.

- There is potential for total loss of all Let's Encrypt certificates on this host.

- You are using the script at your own risk!

EOF

read  -p "Do you wish to continue? [ y/n ] (n) " prompt
prompt=${prompt:-n}
if [ ! $prompt == 'y' ]; then
	exit 0;
fi
}

## Process input

if [ $# -eq 0 ]; then display_help; exit 1; fi #show help on zero arguments

# Parse options
PATH_LE='/etc/letsencrypt'
IGNORE_ERRORS=false
OPT_REPAIR=false
IGNORE_BACKUPS=false
MODE_SILENT=false
while getopts :p:hirsd opt; do
	case $opt in
		p)
			PATH_LE="$OPTARG"
		;;
		i)
			IGNORE_ERRORS=true
		;;
		r)
			OPT_REPAIR=true
			IGNORE_ERRORS=true
		;;
		s)
			MODE_SILENT=true
		;;
		d)
			IGNORE_BACKUPS=true
		;;
		h)
			display_help
			exit 0
		;;
		*)
			display_help
			exit 1
		;;		
	esac
done

shift "$((OPTIND-1))" #discard the options now that their parsed

if [ $# -lt 2 ]; then display_help; exit 1; fi #show help on invalid number of arguments

# Verify we are running as root
USER=$(whoami)
if [ ! $USER == 'root' ]; then 
  if [ $MODE_SILENT == false ]; then
    echo -e "\nWARNING: The script is not being run as user 'root' or with the 'sudo' command\n\nPlease ensure the user '$USER' have the requisite privileges to manipulate '$PATH_LE' and it's sub-folders, or run as 'root'\n"

    read  -p "Do you wish to continue? [ y/n ] (n) " prompt1
    prompt1=${prompt1:-n}
    if [ ! $prompt1 == 'y' ]; then
      exit 0;
    fi
  fi
fi

# Prompt with disclaimer
if [ $MODE_SILENT == false ]; then
	prompt_disclaimer
fi

CERT_NAME_CURRENT=$1
CERT_NAME_NEW=$2

CERT_PATH_CUR_LIVE="$PATH_LE/live/$CERT_NAME_CURRENT"
CERT_PATH_NEW_LIVE="$PATH_LE/live/$CERT_NAME_NEW"

CERT_PATH_CUR_ARC="$PATH_LE/archive/$CERT_NAME_CURRENT"
CERT_PATH_NEW_ARC="$PATH_LE/archive/$CERT_NAME_NEW"

CERT_PATH_CUR_RENEWAL_FILE="$PATH_LE/renewal/${CERT_NAME_CURRENT}.conf"
CERT_PATH_NEW_RENEWAL_FILE="$PATH_LE/renewal/${CERT_NAME_NEW}.conf"

if [ ! -d $CERT_PATH_CUR_LIVE ]; then 
	if [ $MODE_SILENT == false ]; then
		echo -e "\nERROR: Certificate could not be found at $CERT_PATH_CUR_LIVE\n"
	fi
	if [ $IGNORE_ERRORS == false ]; then 
		exit 1 
	fi 
fi #verify current certificate exists under Let's Encrypt path

# Backup Let's Encrypt path
if [ $IGNORE_BACKUPS == false ]; then
	rm -rf ${PATH_LE}.bak
	cp -r $PATH_LE ${PATH_LE}.bak
fi

## Rename certificate

# Update Let's Encrypt renewal config file
if [ -e $CERT_PATH_CUR_RENEWAL_FILE ]; then
	cp $CERT_PATH_CUR_RENEWAL_FILE ${CERT_PATH_CUR_RENEWAL_FILE}.${TIME}.bak #backup certificate's current Let's Encrypt renewal config file
	sed -i -e "s/\/$CERT_NAME_CURRENT/\/$CERT_NAME_NEW/g" $CERT_PATH_CUR_RENEWAL_FILE #update certificate's Let's Encrypt renewal config file
	mv $CERT_PATH_CUR_RENEWAL_FILE $CERT_PATH_NEW_RENEWAL_FILE
else
	if [ $MODE_SILENT == false ]; then
		echo -e "\nERROR: Let's Encrypt renewal config file could not be found at $CERT_PATH_CUR_RENEWAL_FILE\n"
	fi
        if [ $IGNORE_ERRORS == false ]; then
                exit 1
        fi
fi

# Move archive folders
if [ ! -e $CERT_PATH_NEW_ARC ]; then        
	mv $CERT_PATH_CUR_ARC $CERT_PATH_NEW_ARC
fi

# Update symbolic links in live folder
ls_live_for_cert_no=$(ls -al $CERT_PATH_CUR_LIVE)
cert_no_regex='\/cert([0-9]+)\.pem'
live_symlinks[0]='cert'
live_symlinks[1]='chain'
live_symlinks[2]='fullchain'
live_symlinks[3]='privkey'

if [[ $ls_live_for_cert_no =~ $cert_no_regex ]]; then
	cert_ver=${BASH_REMATCH[1]}
	i=0
	c=${#live_symlinks[*]}
        while [[ $i -lt $c ]]
        do
		unlink $CERT_PATH_CUR_LIVE/${live_symlinks[$i]}.pem
		ln -s $CERT_PATH_NEW_ARC/${live_symlinks[$i]}${cert_ver}.pem $CERT_PATH_CUR_LIVE/${live_symlinks[$i]}.pem
            	let i++
        done
else
	if [ $MODE_SILENT == false ]; then
		echo -e "\nERROR: Current certificate could not be identified at $CERT_PATH_CUR_LIVE\n"
	fi
	if [ $IGNORE_ERRORS == false ]; then
		exit 1
	fi
fi

# Move live folder
mv $CERT_PATH_CUR_LIVE $CERT_PATH_NEW_LIVE

echo -e '\nComplete\n'

BASH script which helps you rename your Let's Encrypt certificates

## Getting Started
To use letsencrypt_rename_cert.sh to rename your certificates, just:

1. Download the file
2. Make it executable (hint: chmod +x letsencrypt_rename_cert.sh)
3. Run the script (hint: ./letsencrypt_rename_cert.sh).
4. The script will display it's help and further explain it's usage. It looks something like this:

        usage: letsencrypt_rename_cert.sh [OPTION...] <current name> <new name>

        BASH script which renames a Let's Encrypt certificate

        required arguments:

        certbot_rename_cert.sh [OPTION...] <current name> <new name>

        <current name> 
          Current 'Certificate Name' from 'certbot certificates' command output
        <new name>
          New 'Certificate Name'

        optional arguments:
          -d  disable backups of existing configuration. NOT RECCOMMENDED!
          -h  display this help and exit
          -i  ignore errors and continue regardless	
          -p  path to Let's Encrypt configuration and certificates. Default: /etc/letsencrypt
          -s  silent mode, no output

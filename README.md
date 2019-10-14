
# Bash shell script to Distribute Let's Encrypt Keys on LAN

### Usage - Most Cases through Crontab
Put this in either root or system crontab to run every 12 hours (See below)

### Assumptions of script:
  - SSL Certs are obtained through Let's Encrypt
  - This script will grab the fullchain.pem file from the LAN host where Let's Encrypt certificates are stored and renewed.  On the LAN host - after updating the LE certs,
the fullchain.pem is copied to an apache accessible directory via a --deploy-hook script for distribution of the SSL certificates for servers requiring these on the LAN.  This deploy hook could be run with the ACME client such as certbot. An Apache \<Virtual Host\> configuration 
restricts access of this file to IP addresses on the Local LAN
  - The fullchain.pem file is not secret in that it is normally read and passed in headers during the normal SSL handshake
  - The script also assumes the the **privkey.pem** has previously been distributed through other means since this key is secret.  This script will check for presence of **privkey.pem** and will exit if key is not found. The **privkey.pem** file should not change with LE certification renewal since certs are renewed with --reuse-key option that reuses the private key.
  - Depending on the application, this script could gracefully restart apache web server or a different systemd/rc service  (rc service on BSD or systemctl service on Linux).  
  - The script should work on Linux/BSD operating systems

### deploy-hook script: 
(This is called usually from certbot with the --reuse-key option) i.e.`certbot certonly --cert-name example.com -d example.com,domain1.example.com,domain2.example.com,www.example.com,domain3.example.com --dns-cloudflare --dns-cloudflare-credentials /usr/local/etc/letsencrypt/cloudflare_used_by_certbot.ini --reuse-key --deploy-hook /root/bin/renew.sh`

```
#!/usr/bin/env bash
#renew.sh
set -e
for domain in $RENEWED_DOMAINS; do
   # Just an example, you can use any non-sensitive storage medium you want
  cp -rL "$RENEWED_LINEAGE/fullchain.pem" /usr/local/www/main/certs/
done
```
### Example Apache \<Virtual Host\> directive that would limit access to fullchain.pem file to LAN 
```
   <Directory /usr/local/www/main/certs>
        Require all denied
        Options -Indexes
        <RequireAll>
              Require ip 10.0.1.0/24
        </RequireAll>
   </Directory>
```

### Further Explanation
 - Apache / Let's Encrypt Host - Through root cron job - run's certbot renew every 12 hours calling --deploy-hook if certificate is updated (**Note - Defining Enviromental Variables such as PATH within a crontab is valid when using Vixie Cron implementations (FreeBSD, Debian, Ubuntu) -- others use cronie (Arch, RedHat) where syntax is different: https://stackoverflow.com/questions/2229825/where-can-i-set-environment-variables-that-crontab-will-use**)
 ```
 PATH=/sbin:/bin:/usr/bin:/usr/local/bin
 0 */12 * * * python2.7 -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew --cert-name example.com --reuse-key  --dns-cloudflare --dns-cloudflare-credentials /usr/local/etc/letsencrypt/cloudflare_used_by_certbot.ini --deploy-hook /root/bin/renew.sh
 ```
 
 - Every LAN Machine that requires use of certificates (i.e. Internal Apache Server, Xen Orchestra Server, pfSense) would run this script through a root cronjob every 12 hours to update the fullchain.pem file.  The **privkey.pem** file is not distributed with this script and it's assumed this file already installed on each LAN machine requiring a copy of the fullchain.pem certificate.
```
PATH=/sbin:/bin:/usr/bin:/usr/local/bin
0 */12 * * * bash <this-script.sh>
```

#### References:
 https://community.letsencrypt.org/t/automated-deployment-of-key-cert-from-reverse-proxy-to-internal-systems/64491/4
 https://gist.github.com/onnimonni/b49779ebc96216771a6be3de46449fa1

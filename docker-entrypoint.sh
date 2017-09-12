#!/bin/bash
set -e

LETS_ENCRYPT_ENABLED=${LETS_ENCRYPT_ENABLED:-false}
PUBLIC_DNS=${PUBLIC_DNS:-'switftsure.com'}
ORGANISATION_UNIT=${ORGANIZATION_UNIT:-'Cloud Native Application'}
ORGANISATION=${ORGANISATION:-'example inc'}
TOWN=${TOWN:-'Paris'}
STATE=${STATE:-'Paris'}
COUNTRY_CODE=${COUNTRY:-'FR'}
KEYSTORE_PASS=${KEYSTORE_PASS:-'V3rY1nS3cur3P4ssw0rd'}
KEY_PASS=${KEYSTORE_PASS:-$STORE_PASS}

if ! [ -f $CATALINA_HOME/.keystore ] && [ $LETS_ENCRYPT_ENABLED == true ]; then
    keytool -genkey -noprompt -alias tomcat -dname "CN=${PUBLIC_DNS}, OU=${ORGANISATION_UNIT}, O=${ORGANISATION}, L=${TOWN}, S=${STATE}, C=${COUNTRY_CODE}" -keystore $CATALINA_HOME/.keystore -storepass "${KEYSTORE_PASS}" -KeySize 2048 -keypass "${KEY_PASS}" -keyalg RSA

    keytool -list -keystore $CATALINA_HOME/.keystore -v -storepass "${KEYSTORE_PASS}" > key.check

    keytool -certreq -alias tomcat -file request.csr -keystore $CATALINA_HOME/.keystore -storepass "${KEYSTORE_PASS}"

    certbot certonly --csr $CATALINA_HOME/request.csr --standalone --register-unsafely-without-email

    keytool -import -trustcacerts -alias tomcat -file 0001_chain.pem -keystore /usr/share/tomcat7/.keystore -storepass "${KEYSTORE_PASS}"
fi

if ! [ -f $CATALINA_HOME/.keystore ] && [ $LETS_ENCRYPT_ENABLED == false ]; then
    keytool -genkey -noprompt -alias selfsigned -dname "CN=${PUBLIC_DNS}, OU=${ORGANISATION_UNIT}, O=${ORGANISATION}, L=${TOWN}, S=${STATE}, C=${COUNTRY_CODE}" -keystore $CATALINA_HOME/.keystore -storepass "${KEYSTORE_PASS}" -KeySize 2048 -keypass "${KEY_PASS}" -keyalg RSA -validity 3600
fi

#<Connector port="8443" protocol="HTTP/1.1" SSLEnabled="true" maxThreads="150" scheme="https" secure="true" clientAuth="false" sslProtocol="TLS" KeystoreFile="$CATALINA_HOME/.keystore" KeystorePass="${KEY_PASS}" />

# Update SSL port configuration
#
UUID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

xmlstarlet ed \
    -P -S -L \
    -s '/Server/Service' -t 'elem' -n "${UUID}" \
    -i "/Server/Service/${UUID}" -t 'attr' -n 'port' -v '8443' \
    -i "/Server/Service/${UUID}" -t 'attr' -n 'protocol' -v 'HTTP/1.1' \
    -i "/Server/Service/${UUID}" -t 'attr' -n 'SSLEnabled' -v 'true' \
    -i "/Server/Service/${UUID}" -t 'attr' -n 'maxThreads' -v '150' \
    -i "/Server/Service/${UUID}" -t 'attr' -n 'scheme' -v 'https' \
    -i "/Server/Service/${UUID}" -t 'attr' -n 'secure' -v 'true' \
    -i "/Server/Service/${UUID}" -t 'attr' -n 'clientAuth' -v 'true' \
    -i "/Server/Service/${UUID}" -t 'attr' -n 'sslProtocol' -v 'TLS' \
    -i "/Server/Service/${UUID}" -t 'attr' -n 'KeystoreFile' -v "$CATALINA_HOME/.keystore" \
    -i "/Server/Service/${UUID}" -t 'attr' -n 'KeystorePass' -v "${KEY_PASS}" \
    -r "/Server/Service/${UUID}" -v "Connector" \
conf/server.xml

exec "$@"
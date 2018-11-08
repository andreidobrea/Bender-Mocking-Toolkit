#!/bin/bash

function bmt_helper_create_private_key_password
{
    pwgen --secure 20 1 > 'Bender_bundle/Bender_CA_private_key_password.txt'
}

function bmt_helper_create_private_key
{
    openssl genrsa \
        -aes256 \
        -out 'Bender_bundle/Bender_CA_private_key.key' \
        -passout file:'Bender_bundle/Bender_CA_private_key_password.txt' \
        2048
}

function bmt_helper_create_csr
{
    openssl req \
        -new \
        -out 'Bender_bundle/Bender_CA_request.csr' \
        -key 'Bender_bundle/Bender_CA_private_key.key' \
        -passin file:'Bender_bundle/Bender_CA_private_key_password.txt' \
        -in 'Bender_bundle/Bender_CA_request_in.txt' \
        -subj "/C=RO/ST=Romania/L=Iasi/O=TiVo/OU=Bender/CN=bender.tivo.com"
}

function bmt_helper_create_certificate
{
    openssl x509 \
        -signkey 'Bender_bundle/Bender_CA_private_key.key' \
        -passin file:'Bender_bundle/Bender_CA_private_key_password.txt' \
        -in  'Bender_bundle/Bender_CA_request.csr' \
        -req -out 'Bender_bundle/Bender_CA.crt' \
        -days 3650
}

function bmt_create_bundle
{
    mkdir -p Bender_bundle
    bmt_helper_create_private_key_password
    bmt_helper_create_private_key
    bmt_helper_create_csr
    bmt_helper_create_certificate
}

function bmt_helper_get_primary_ip_address
{
    echo -n $(ifconfig|egrep -o 'inet (addr:)?([0-9]*\.){3}[0-9]*'|egrep -o '([0-9]*\.){3}[0-9]*'|grep -v '127.0.0.1')
}

function bmt_helper_create_ssl_server_key_and_certificate
{
    local SERVER_IP_ADDRESS="$1"
    local SERVER_KEY="$2"
    local SERVER_CERTIFICATE="$3"

    echo ${SERVER_IP_ADDRESS:?} ${SERVER_KEY:?} ${SERVER_CERTIFICATE:?} > /dev/null # check params in order
    
    openssl genrsa \
        -out "$SERVER_KEY" \
        2048
    
    local SERVER_CSR="$(mktemp)"
    openssl req \
        -new \
        -key "$SERVER_KEY" \
        -out "$SERVER_CSR" \
        -days 30 \
        -subj "/C=RO/ST=Romania/L=Iasi/O=TiVo/OU=Bender/CN=$SERVER_IP_ADDRESS" \
        -reqexts CUSTOM_V3_EXT \
        -config \
            <(cat /etc/ssl/openssl.cnf \
                <(printf "\n[CUSTOM_V3_EXT]") \
                <(printf "\nkeyUsage = digitalSignature, keyEncipherment, keyAgreement") \
                <(printf "\nextendedKeyUsage = critical,serverAuth") \
                <(printf "\nbasicConstraints = CA:FALSE") \
                <(printf "\nsubjectAltName = IP:$SERVER_IP_ADDRESS"))

    openssl x509 \
        -req \
        -in "$SERVER_CSR" \
        -CA 'Bender_bundle/Bender_CA.crt' \
        -CAkey 'Bender_bundle/Bender_CA_private_key.key' \
        -CAcreateserial \
        -passin file:'Bender_bundle/Bender_CA_private_key_password.txt' \
        -out "$SERVER_CERTIFICATE"
}

function bmt_start_ssl_server_instance
{
    local LISTENING_PORT=$1
    
    local MY_IP_ADDRESS="$(bmt_helper_get_primary_ip_address)"
    local SERVER_KEY="$(mktemp)"
    local SERVER_CERTIFICATE="$(mktemp)"
    
    bmt_helper_create_ssl_server_key_and_certificate "${MY_IP_ADDRESS:?}" "${SERVER_KEY:?}" "${SERVER_CERTIFICATE:?}"
    
    echo "Will listen on https://$MY_IP_ADDRESS:$LISTENING_PORT/"
    
    #-debug - print extensive debugging information including a hex dump of all traffic
    #-WWW - emulate a simple web server; pages will be resolved relative to the current directory
    #-HTTP - same as WWW, only the files are expected to contain a complete and correct HTTP response
    #-CAfile file - is used for both server certificate chain building and client authentication!
    openssl s_server \
        -accept ${LISTENING_PORT:?} \
        -key ${SERVER_KEY} \
        -cert ${SERVER_CERTIFICATE:?} \
        -debug \
        -WWW \
        -CAfile 'Bender_bundle/Bender_CA.crt'
}

cat<<eof
Available commands:
$(declare -F|egrep -o 'bmt_.+'|grep -v 'bmt_helper'|sort)
eof

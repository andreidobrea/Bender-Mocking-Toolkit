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


cat<<eof
Available commands:
$(declare -F|egrep -o 'bmt_.+'|grep -v 'bmt_helper'|sort)
eof

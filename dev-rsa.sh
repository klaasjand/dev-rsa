#!/usr/bin/env bash

root_ca=example.net

sub_ca_list=(
    "example.net" "Intermediate CA." ON
    # "test.example.com" "Other intermediate CA." OFF
)

pki_dir=./pki

root_ca_prefix=root_
sub_ca_prefix=sub_

function main_menu() {
    menu_choice=$(whiptail --title "DevRSA - Menu" --menu "Choose an option" 25 78 16 \
        "Root" "Create root CA." \
        "Intermediate" "Create intermediate CA." \
        "Server" "Create server key and certificate." \
        "Server CSR" "Sign server certificate signing request." \
        "Client" "Create client key and certificate." \
        "Client CSR" "Sign client certificate signing request." \
        "Quit" "" \
        3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        case $menu_choice in
            "Root")
                create_root_ca
                ;;
            "Intermediate")
                create_int_ca
                ;;
            "Server")
                create_server_crt
                ;;
            "Server CSR")
                sign_csr "server"
                ;;
            "Client")
                create_client_crt
                ;;
            "Client CSR")
                sign_csr "client"
                ;;
            "Quit")
                exit
                ;;
            *)
                main_menu
        esac
    else
        echo "Cancelled, exiting."
    fi
}

function create_root_ca() {
    if [ -d "$pki_dir/$root_ca_prefix$root_ca" ]; then
        whiptail --title "DevRSA - ERROR" --msgbox "Error: $root_ca already exists" 8 78
    else
        mkdir -p $pki_dir

        easyrsa --batch --vars=./vars --pki-dir=$pki_dir/$root_ca_prefix$root_ca init-pki
        easyrsa --batch --vars=./vars --pki-dir=$pki_dir/$root_ca_prefix$root_ca --req-cn=$root_ca build-ca nopass
    fi

    main_menu
}

function create_int_ca() {
    sub_ca=$(whiptail --title "Create intermediate CA" --radiolist "Choose intermediate CA" 20 78 `expr "${#sub_ca_list[@]}" / 3` "${sub_ca_list[@]}" 3>&1 1>&2 2>&3)

    if [ -d "$pki_dir/$sub_ca_prefix$sub_ca" ]; then
        whiptail --title "DevRSA - ERROR" --msgbox "Error: $sub_ca already exists" 8 78
    else
        # Build sub CA request
        easyrsa --batch --vars=./vars --pki-dir=$pki_dir/$sub_ca_prefix$sub_ca init-pki
        easyrsa --batch --vars=./vars --pki-dir=$pki_dir/$sub_ca_prefix$sub_ca --req-cn=$sub_ca build-ca nopass subca

        # Import the sub CA request under the short-name "sub" on the offline PKI
        easyrsa --batch --vars=./vars --pki-dir=$pki_dir/$root_ca_prefix$root_ca import-req $pki_dir/$sub_ca_prefix$sub_ca/reqs/ca.req $sub_ca
        # Then sign it as a CA
        easyrsa --batch --vars=./vars --pki-dir=$pki_dir/$root_ca_prefix$root_ca sign-req ca $sub_ca
        # Transport sub CA cert to sub PKI
        cp $pki_dir/$root_ca_prefix$root_ca/issued/$sub_ca.crt $pki_dir/$sub_ca_prefix$sub_ca/ca.crt
    fi

    main_menu
}

function create_server_crt() {
    sub_ca=$(whiptail --title "Create server key and certificate." --radiolist "Choose intermediate CA" 20 78 `expr "${#sub_ca_list[@]}" / 3` "${sub_ca_list[@]}" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ ! -d "$pki_dir/$sub_ca_prefix$sub_ca" ]; then
            whiptail --title "DevRSA - ERROR" --msgbox "Error: Intermediate CA does not exist" 8 78
        else
            EASYRSA_REQ_CN=$(whiptail --inputbox "Common Name (CN)" 8 78 hostname.$sub_ca --title "Create server key and certificate." 3>&1 1>&2 2>&3)

            if [ ! -z "$EASYRSA_REQ_CN" ]; then
                if [ -f "$pki_dir/$sub_ca_prefix$sub_ca/issued/$EASYRSA_REQ_CN.crt" ]; then
                    whiptail --title "DevRSA - ERROR" --msgbox "Error: $EASYRSA_REQ_CN already exists" 8 78
                else
                    san_string=$(whiptail --inputbox "SAN string or empty if none. DNS:host.example.com,IP.1:192.168.178.100" 8 78 --title "Create server key and certificate." 3>&1 1>&2 2>&3)

                    if [ ! -z "$san_string" ]; then
                        easyrsa --vars=./vars --pki-dir=$pki_dir/$sub_ca_prefix$sub_ca --subject-alt-name=$san_string build-server-full $EASYRSA_REQ_CN nopass
                    else
                        easyrsa --vars=./vars --pki-dir=$pki_dir/$sub_ca_prefix$sub_ca build-server-full $EASYRSA_REQ_CN nopass
                    fi
                fi
            fi
        fi
    fi

    main_menu
}

function create_client_crt() {
    sub_ca=$(whiptail --title "Create client key and certificate." --radiolist "Choose intermediate CA" 20 78 `expr "${#sub_ca_list[@]}" / 3` "${sub_ca_list[@]}" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ ! -d "$pki_dir/$sub_ca_prefix$sub_ca" ]; then
            whiptail --title "DevRSA - ERROR" --msgbox "Error: Intermediate CA does not exist" 8 78
        else
            EASYRSA_REQ_CN=$(whiptail --inputbox "Common Name (CN)" 8 78 hostname.$sub_ca --title "Create client key and certificate." 3>&1 1>&2 2>&3)

            if [ ! -z "$EASYRSA_REQ_CN" ]; then
                if [ -f "$pki_dir/$sub_ca_prefix$sub_ca/issued/$EASYRSA_REQ_CN.crt" ]; then
                    whiptail --title "DevRSA - ERROR" --msgbox "Error: $EASYRSA_REQ_CN already exists" 8 78
                else
                    easyrsa --vars=./vars --pki-dir=$pki_dir/$sub_ca_prefix$sub_ca build-client-full $EASYRSA_REQ_CN nopass
                fi
            fi
        fi
    fi

    main_menu
}

function sign_csr() {
    sub_ca=$(whiptail --title "Sign $1 certificate." --radiolist "Choose intermediate CA" 20 78 `expr "${#sub_ca_list[@]}" / 3` "${sub_ca_list[@]}" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ ! -d "$pki_dir/$sub_ca_prefix$sub_ca" ]; then
            whiptail --title "DevRSA - ERROR" --msgbox "Error: Intermediate CA does not exist" 8 78
        else
            EASYRSA_REQ_CN=$(whiptail --inputbox "Common Name (CN)" 8 78 hostname.$sub_ca --title "Sign $1 certificate." 3>&1 1>&2 2>&3)

            if [ ! -z "$EASYRSA_REQ_CN" ]; then
                if [ -f "$pki_dir/$sub_ca_prefix$sub_ca/issued/$EASYRSA_REQ_CN.crt" ]; then
                    whiptail --title "DevRSA - ERROR" --msgbox "Error: $EASYRSA_REQ_CN already exists" 8 78
                else
                    whiptail --textbox /dev/stdin 40 78 <<< "$(easyrsa --vars=./vars --pki-dir=$pki_dir/$sub_ca_prefix$sub_ca show-req $EASYRSA_REQ_CN)"

                    easyrsa --vars=./vars --pki-dir=$pki_dir/$sub_ca_prefix$sub_ca --batch sign-req $1 $EASYRSA_REQ_CN
                fi
            fi
        fi
    fi

    main_menu
}

whiptail --title "DevRSA" --msgbox "  Welcome to DevRSA - DevRSA makes it easier work with certificates." 8 78

main_menu

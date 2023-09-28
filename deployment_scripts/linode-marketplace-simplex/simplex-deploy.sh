#!/bin/bash
set -e
trap "cleanup $? $LINENO" EXIT

## Simplex Settings
# <UDF name="smp_password" label="Set password for smp-server." example="123qwe" default="" />
# <UDF name="xftp_quota" label="Set xftp-server file storage quota in GB." example="1/5/10/100gb" default="10gb" />

## Linode/SSH Security Settings
#<UDF name="user_name" label="The limited sudo user to be created for the Linode" default="">
#<UDF name="password" label="The password for the limited sudo user" example="an0th3r_s3cure_p4ssw0rd" default="">
#<UDF name="disable_root" label="Disable root access over SSH?" oneOf="Yes,No" default="No">
#<UDF name="pubkey" label="The SSH Public Key that will be used to access the Linode (Recommended)" default="">

## Domain Settings
#<UDF name="token_password" label="Your Linode API token. This is needed to create your Linode's DNS records" default="">
#<UDF name="subdomain" label="Subdomain" example="The subdomain for the DNS record. (Requires Domain)" default="">
#<UDF name="domain" label="Domain" example="The domain for the DNS record: example.com (Requires API token)" default="">
#<UDF name="soa_email_address" label="SOA Email" example="user@domain.tld" default="">

# git repo
export GIT_REPO="https://github.com/akamai-compute-marketplace/marketplace-apps.git"
export WORK_DIR="/tmp/marketplace-apps" 
export MARKETPLACE_APP="apps/linode-marketplace-simplex"

# enable logging
exec > >(tee /dev/ttyS0 /var/log/stackscript.log) 2>&1

function cleanup {
  if [ -d "${WORK_DIR}" ]; then
    rm -rf ${WORK_DIR}
  fi

}

function udf {
  local group_vars="${WORK_DIR}/${MARKETPLACE_APP}/group_vars/linode/vars"

  # Simplex variables
  
  if [[ -n ${TOKEN_PASSWORD} ]]; then
    if [[ -n ${DOMAIN} && -n ${SUBDOMAIN} ]]; then
      echo "addr: ${SUBDOMAIN}.${DOMAIN}" >> ${group_vars}
    elif [[ -n ${DOMAIN} ]]; then
      echo "addr: ${DOMAIN}" >> ${group_vars}
    else
      echo "addr: $(hostname -I | awk '{print $1}')" >> ${group_vars}
    fi
  else
    echo "addr: $(hostname -I | awk '{print $1}')" >> ${group_vars}
  fi

  if [[ -n ${SMP_PASSWORD} ]]; then
    echo "smp_password: ${SMP_PASSWORD}" >> ${group_vars};
  fi

  if [[ -n ${XFTP_QUOTA} ]]; then
    case ${XFTP_QUOTA} in
      *gb) echo "xftp_quota: ${XFTP_QUOTA}" >> ${group_vars} ;;
      *) echo "xftp_quota: ${XFTP_QUOTA}gb" >> ${group_vars} ;;
    esac
  fi

  # Linode variables

  if [[ -n ${SOA_EMAIL_ADDRESS} ]]; then
    echo "soa_email_address: ${SOA_EMAIL_ADDRESS}" >> ${group_vars};
  else echo "No email entered";
  fi

  if [[ -n ${USER_NAME} ]]; then
    echo "username: ${USER_NAME}" >> ${group_vars};
  else echo "No username entered";
  fi

  if [[ -n ${PASSWORD} ]]; then
    echo "password: ${PASSWORD}" >> ${group_vars};
  else echo "No password entered";
  fi

  if [[ -n ${PUBKEY} ]]; then
    echo "pubkey: ${PUBKEY}" >> ${group_vars};
  else echo "No pubkey entered";
  fi

  if [ "$DISABLE_ROOT" = "Yes" ]; then
    echo "disable_root: yes" >> ${group_vars};
  else echo "Leaving root login enabled";
  fi

  if [[ -n ${TOKEN_PASSWORD} ]]; then
    echo "token_password: ${TOKEN_PASSWORD}" >> ${group_vars};
  else echo "No API token entered";
  fi

  if [[ -n ${DOMAIN} ]]; then
    echo "domain: ${DOMAIN}" >> ${group_vars};
  else echo "default_dns: $(hostname -I | awk '{print $1}'| tr '.' '-' | awk {'print $1 ".ip.linodeusercontent.com"'})" >> ${group_vars};
  fi

  if [[ -n ${SUBDOMAIN} ]]; then
    echo "subdomain: ${SUBDOMAIN}" >> ${group_vars};
  fi
}

function run {
  # install dependancies
  apt-get update
  apt-get install -y git python3 python3-pip

  # clone repo and set up ansible environment
  git -C /tmp clone ${GIT_REPO}
  # for a single testing branch
  # git -C /tmp clone --single-branch --branch ${BRANCH} ${GIT_REPO}

  # venv
  cd ${WORK_DIR}/${MARKETPLACE_APP}
  pip3 install virtualenv
  python3 -m virtualenv env
  source env/bin/activate
  pip install pip --upgrade
  pip install -r requirements.txt
  ansible-galaxy install -r collections.yml

  # populate group_vars
  udf
  # run playbooks
  for playbook in site.yml; do ansible-playbook -vvvv $playbook; done
}

function installation_complete {
  echo "Installation Complete"
}
# main
run && installation_complete
cleanup
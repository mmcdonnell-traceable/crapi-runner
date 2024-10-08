#!/usr/bin/env bash
SECRET_AT_FILE=".crapi_token"

function main() {
    local SPECFILE="https://gist.githubusercontent.com/saadfarooq07/172cf1cb45a88108f6ce2e0d99f73b44/raw/908556cc7785ad0e90d9bc3d0df3a886c672c759/attacks.json"
    local FILENAME="postman_collection-malicious.json"

    # echo "Welcome to the crAPI Runner!!"

    if [ ! -f ${FILENAME} ]; then
        echo "Postman Collection ${FILENAME} not found. Downloading: "
        curl --silent -o "${FILENAME}" "${SPECFILE}"
        if [ $? != 0 ]; then
          echo "*******Could not Download ${FILENAME}*******";
          exit 99
        fi
    fi

    if [ -z "$(which jq)" ]; then
        echo "Application: 'jq' not found. Installing: "
        apt install -y jq
        if [ $? != 0 ]; then
          echo "******* Could not install jq *******";
          exit 99
        fi
    fi

    echo ""
    echo ""

    if [ -z "${ACCESS_TOKEN}" ]; then
      log_on
    fi;
    
    while [ 1 ]; do
        for OBJ in $(jq -r -c '.item[].name | select (. != "Signup and setup") | @base64' ${FILENAME}); do
            DECRYPTED=$(echo "${OBJ}" | base64 --decode)
            newman run ${FILENAME} --environment postman_environment.json --folder "${DECRYPTED}" --env-var token=$(awk '{print $2}' ${SECRET_AT_FILE}) --insecure
        done
        sleep 4;
    done

}

function log_on() {
  local USER=""
  local PASS=""
  local CRAPI_BASE="http://k3s-host.${_SANDBOX_ID}.instruqt.io:80"
  local AUTH_VAL="${CRAPI_BASE}/identity/api/auth/verify"
  local AUTH_IMPL="${CRAPI_BASE}/identity/api/auth/login"

  validate_environment

  if [ -z "${ACCESS_TOKEN}" ]; then
    if [ -f "${SECRET_AT_FILE}" ]; then
      local AV_PAYLOAD=$(jq -n --arg token $(awk '{print $2}' ${SECRET_AT_FILE}) '{"token":$token}')
      AUTH=$(curl ${AUTH_VAL} -H 'Content-Type: application/json' --data-raw "${AV_PAYLOAD}" --insecure -s | jq '.status')
      if [ "200" == "${AUTH}" ]; then
        ACCESS_TOKEN="${AV_PAYLOAD}"
      fi
    fi
  fi;
  if [ -z "${ACCESS_TOKEN}" ]; then
    echo "Please log in with your crAPI Credentials to continue!"
    while [ -z "${USER}" ]; do
      read -p "Please enter your email: " USER
      prompt_boolean USEGOOD "  You typed in '${USER}'. Is that correct?" "Yes"
      if [ ${USEGOOD} == "N" ]; then
        USER=""
      fi
    done

    while [ -z "${ACCESS_TOKEN}" ]; do
        prompt_password PASS "Please enter your password: "
        local PAYLOAD=$(jq -n --arg user $USER --arg pass $PASS '{"email":$user,"password":$pass}')
        ACCESS_TOKEN="Bearer $(curl "${AUTH_IMPL}" -H 'Content-Type: application/json' --data-raw "${PAYLOAD}" --insecure -s | jq -j .token)"
        if [ "${ACCESS_TOKEN}" == "Bearer null" ]; then
        ACCESS_TOKEN=""
        echo "Password seems to be bad for user: ${USER}. Please try again"
        fi
    done

    # Single > OVERWRITES the file. We want that here.
    echo "${ACCESS_TOKEN}" > ${SECRET_AT_FILE}
  fi;
}

function prompt_boolean() {
  if [ -z "${1}" ]; then
    echo2 "Error! You need to pass in a parameter and default!"
    echo2 "  ${0} 'Do you like apples?' Y"
    exit 1
  fi;

  local -n __YN=${1}
  local MSG=${2}
  local DEFAULT=${3}
  
  local OPT="Z"

  # Don't let While Loops bleed into a function
  __YN="Z"

  while [ "${__YN}" != "Y" -a "${__YN}" != "N" ]; do
    read -p "${MSG} Yes/No (${DEFAULT})" OPT
    if [ -z "${OPT}" ]; then
      OPT="$(echo ${DEFAULT^} | head -c 1)"
    else
      OPT=$(echo ${OPT^} | head -c 1)
    fi
    if [ ${OPT} == "Y" -o ${OPT} == "N" ]; then
      __YN=${OPT}
    fi
  done
}

function prompt_choice() {
  if [ -z "${1}" ]; then
    echo2 "Error! You need to pass in a parameter!"
    echo2 "  ${0} 'Do you like apples?' ('Yes' 'No')"
    exit 1
  fi;
  local -n __CHOICE=${1}
  local MSG=${2}
  shift 2;
  local OPTIONS=("$@")

  local MIN=1
  local MAX=${#OPTIONS[@]}
  local OPT=-1
  local QUITWARN=0

  # Don't let while loops bleed into the function.
  __CHOICE="!@#$%^&*()"

  if [[ ${MAX} -gt 1 ]]; then
    while [[ "${OPT}" -lt ${MIN} || "${OPT}" -gt ${MAX} ]]; do
      for i in "${!OPTIONS[@]}"; do
        if [ "Signup and setup" != "${OPTIONS[$i]}" ]; then
          printf "$(($i+1))\t${OPTIONS[$i]}\n"
        fi
        
      done
      read -p "${MSG} " OPT
      if [[ "${OPT}" -ge ${MIN} && "${OPT}" -le ${MAX} ]]; then
        __CHOICE="${OPTIONS[$((${OPT}-1))]}"
      fi
    done;
  else
    __CHOICE="${OPTIONS[0]}"
    echo "No other option available. Choosing ${__CHOICE}"
  fi;

  if [ "Quit" == "${__CHOICE}" ]; then
    echo ""
    echo "You have chosen Quit. Thank you for running ${0}!"
    echo "Exiting with 0"
    exit 0;
  fi
}

function prompt_password(){
  local -n __PASS=${1}
  local MSG=${2}

  __PASS=""

  printf "${MSG} "
  while IFS= read -r -s -n1 pass; do
    if [[ -z $pass ]]; then
      echo
      break
    else
      echo -n '*'
      __PASS+=$pass
    fi
  done
}

function validate_environment() {
  # while [ ! -z "$(kubectl get pods -n crapi --no-headers | grep -v Running)" ]; do
  #   echo "Waiting for environment to be ready!"
  #   kubectl get pods -n crapi
  #   sleep 5;
  #   clear;
  # done _SANDBOX_ID=3b80jxqrtqi9

  if [ -z "${_SANDBOX_ID}" ]; then
    echo "ERROR! Cannot find _SANDBOX_ID in Environment Variables!!"
    exit 99
  fi
}

main

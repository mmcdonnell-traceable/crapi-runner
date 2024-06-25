#!/usr/bin/env bash


# SECRET_AT_FILE=".access_token"

function main() {
    local SPECFILE="https://gist.githubusercontent.com/saadfarooq07/172cf1cb45a88108f6ce2e0d99f73b44/raw/908556cc7785ad0e90d9bc3d0df3a886c672c759/attacks.json"
    local FILENAME="attacks.json"

    echo "Welcome to the crAPI Runner!! Please log in with your crAPI Credentials to continue!"

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

    # while [ true ]; do
    # #   if [ ${TOKEN_SET} -ne 0 ]; then
    # #     clear
    # #   fi
    #   echo "Main Menu:"
    #   json2choice CHOICE "$(cat ${FILENAME})" '.item[].name'
    #   echo "  Running ${CHOICE}....."
    #   echo "newman run ${FILENAME} --environment postman_environment.json --folder \"${CHOICE}\" --insecure --delay-request 2000 > /etc/newman/newman-normal.out 2> /etc/newman/newman-normal.err < /dev/null"
    #   echo ""
    #   echo ""
    #   TOKEN_SET=1
    # done

    if [ -z "${ACCESS_TOKEN}" ]; then
      log_on
    fi;

    while [ true ]; do
      echo "Please Choose an option below!"
      json2choice CHOICE "$(cat ${FILENAME})" '.item[].name'
      prompt_boolean YN "Do you want to run the '${CHOICE}' collection?" "Yes"
      if [ ${YN} == "Y" ]; then
        newman run ${FILENAME} --environment postman_environment.json --folder "${CHOICE}" --insecure
      fi
      prompt_boolean CONTINUE "Do you want to run to continue?" "Yes"
      if [ ${CONTINUE} == "Y" ]; then
        clear;
      fi
    done

}


function json2choice() {
    local -n __JSC=${1}
    local JSONSTR=${2}
    local SELECTSTR=${3}

    local CHOICE_ARR

    # echo "${JSONSTR}"
    # echo ${SELECTSTR}
    
    for OBJ in $(echo "${JSONSTR}" | jq -r -c "${SELECTSTR} | @base64"); do
        DECRYPTED=$(echo "${OBJ}" | base64 --decode)
        CHOICE_ARR+=("${DECRYPTED}")
    done
    CHOICE_ARR+=("Quit")

    prompt_choice __JSC 'Which function would you like to run?' "${CHOICE_ARR[@]}"
}

function log_on() {
  # ACCESS_TOKEN="Bearer $(curl 'http://k3s-host.3b80jxqrtqi9.instruqt.io:80/identity/api/auth/login' -H 'Content-Type: application/json' --data-raw '{"email":"<your-email>","password":"<your-password>"}' --insecure -s | jq -j .token)"
  local USER=""
  local PASS=""
  local CRAPI_BASE="http://k3s-host.${_SANDBOX_ID}.instruqt.io:80"

  validate_environment

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
    ACCESS_TOKEN="Bearer $(curl "${CRAPI_BASE}/identity/api/auth/login" -H 'Content-Type: application/json' --data-raw "${PAYLOAD}" --insecure -s | jq -j .token)"
    if [ "${ACCESS_TOKEN}" == "Bearer null" ]; then
      ACCESS_TOKEN=""
      echo "Password seems to be bad for user: ${USER}. Please try again"
    fi
  done

  # echo "${ACCESS_TOKEN}" > ${SECRET_AT_FILE}
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

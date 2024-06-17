#!/usr/bin/env bash

unset TOKEN_SET
TOKEN_SET=0

function main() {
    local SPECFILE="https://gist.githubusercontent.com/saadfarooq07/172cf1cb45a88108f6ce2e0d99f73b44/raw/908556cc7785ad0e90d9bc3d0df3a886c672c759/attacks.json"
    local FILENAME="attacks.json"

    echo "Checking for ${FILENAME} in directory"
    if [ ! -f ${FILENAME} ]; then
        echo "Downloading ${FILENAME}"
        wget -O "${FILENAME}" "${SPECFILE}"
    fi
    echo ""
    echo ""

    while [ true ]; do
    #   if [ ${TOKEN_SET} -ne 0 ]; then
    #     clear
    #   fi
      echo "Main Menu:"
      json2choice CHOICE "$(cat ${FILENAME})" '.item[].name'
      echo "  Running ${CHOICE}....."
      echo "newman run ${FILENAME} --environment postman_environment.json --folder \"${CHOICE}\" --insecure --delay-request 2000 > /etc/newman/newman-normal.out 2> /etc/newman/newman-normal.err < /dev/null"
      echo ""
      echo ""
      TOKEN_SET=1
    done
}


function json2choice() {
    local -n __RET=${1}
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

    prompt_choice __RET 'Which function would you like to run?' "${CHOICE_ARR[@]}"
}


function prompt_choice() {
  if [ -z "${1}" ]; then
    echo2 "Error! You need to pass in a parameter!"
    echo2 "  ${0} 'Do you like apples?' ('Yes' 'No')"
    exit 1
  fi;
  local -n _RET=${1}
  local MSG=${2}
  shift 2;
  local OPTIONS=("$@")

  local MIN=1
  local MAX=${#OPTIONS[@]}
  local OPT=-1
  local QUITWARN=0
  local CHOICE="!@#$%^&*()"

  if [[ ${MAX} -gt 1 ]]; then
    while [[ "${OPT}" -lt ${MIN} || "${OPT}" -gt ${MAX} ]]; do
      for i in "${!OPTIONS[@]}"; do
        if [ ${TOKEN_SET} -eq 0 -a "Signup and setup" == "${OPTIONS[$i]}" ]; then
          printf "$(($i+1))\t${OPTIONS[$i]}\n"
        elif [ ${TOKEN_SET} -ne 0 -a "Signup and setup" != "${OPTIONS[$i]}" ]; then
          printf "$(($i+1))\t${OPTIONS[$i]}\n"
        fi
        
      done
      read -p "${MSG} " OPT
      if [[ "${OPT}" -ge ${MIN} && "${OPT}" -le ${MAX} ]]; then
        CHOICE="${OPTIONS[$((${OPT}-1))]}"
      fi
    done;
  else
    CHOICE="${OPTIONS[0]}"
    QUITWARN=1
  fi;

  if [ "Quit" == "${CHOICE}" ]; then
    echo ""
    if [ ${QUITWARN} -ne 0 ]; then
        echo "If you did not mean to choose 'Quit' then it means you had no other option."
    fi;
    echo "You have chosen Quit. Thank you for running ${0}!"
    echo "Exiting with 0"
    exit 0;
  fi

  _RET="${CHOICE}"
}

main

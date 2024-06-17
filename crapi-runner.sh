#!/usr/bin/env bash

function main() {
    local SPECFILE="https://gist.githubusercontent.com/saadfarooq07/172cf1cb45a88108f6ce2e0d99f73b44/raw/908556cc7785ad0e90d9bc3d0df3a886c672c759/attacks.json"
    local FILENAME="attacks.json"

    echo "Checking for ${FILENAME} in directory"
    if [ ! -f ${FILENAME} ]; then
        echo "Downloading ${FILENAME}"
        wget -O "${FILENAME}" "${SPECFILE}"
    fi

    json2choice CHOICE "$(cat ${FILENAME})" '.item[].name'


    # prompt_choice __RET "Which Test Suite Needs to be ran?" "${SUITES[@]}"

    echo ""
    echo "And the winner is: ${CHOICE}"
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

    prompt_choice __RET 'Which function would you like to run?' "${CHOICE_ARR[@]}"
}


function prompt_choice() {
  if [ -z "${1}" ]; then
    echo2 "Error! You need to pass in a parameter!"
    echo2 "  ${0} 'Do you like apples?' ('Yes' 'No')"
    exit 1
  fi;
  local -n CHOICE=${1}
  local MSG=${2}
  shift 2;
  local OPTIONS=("$@")

  local MIN=1
  local MAX=${#OPTIONS[@]}
  local OPT=-1
  CHOICE="!@#$%^&*()"

  if [[ ${MAX} -gt 1 ]]; then
    while [[ "${OPT}" -lt ${MIN} || "${OPT}" -gt ${MAX} ]]; do
      for i in "${!OPTIONS[@]}"; do
        printf "$(($i+1))\t${OPTIONS[$i]}\n"
      done
      read -p "${MSG} " OPT
      if [[ "${OPT}" -ge ${MIN} && "${OPT}" -le ${MAX} ]]; then
        CHOICE="${OPTIONS[$((${OPT}-1))]}"
      fi
    done;
  else
    CHOICE="${OPTIONS[0]}"
  fi;
}

main

#!/bin/bash
#
# File:         cfmanage.sh
# Version:      1.4
# Written by:   Ryan Walker
# Contributors: Ryan Cleere
# Date:         05/19/2010
#
# Script to list, create containers, upload objects, and delete objects/containers for Rackspace CloudFiles.
# Based on cf-list.sh by Tim Galyean
#
##################################################
 
USER="${1}"
APIKEY="${2}"
CMD="${3}"
OBJECT="${4}"
FILE="${5}"
NEW_FILE="${6}"
#PWD=`pwd`

#CLOUD_SERVERS_USERNAME=`echo $CLOUD_SERVERS_USERNAME`
#CLOUD_SERVERS_API_KEY=`echo $CLOUD_SERVERS_API_KEY`

function f_exec() {
  CURL="curl -s -H"
  f_grabauthtoken
  if [ ! -n ${STORAGETOKEN} ] ; then
    echo "Authentication failure"
    exit 1
  fi
  if [ "${CMD}" == "list" ] ; then
    f_list
  elif [ "${CMD}" == "create" ] ; then
    f_create
  elif [ "${CMD}" == "upload" ] ; then
    f_upload
  elif [ "${CMD}" == "delete" ] ; then
    f_delete
  elif [ "${CMD}" == "get" ] ; then
    f_get
  elif [ "${CMD}" == "usage" ] ; then
    f_usage
  elif [ "${CMD}" == "cdn_list" ] ; then
    f_list_cdn
  elif [ "${CMD}" == "cdn_get_uri" ] ; then
    f_get_cdn_uri
  elif [ "${CMD}" == "cdn_edge_purge" ] ; then
    f_cdn_edge_purge
  else
    echo "Please specify a valid command"
  fi
}
 
# Grab API Authentication Token, and Storage URL
function f_grabauthtoken() {
    RETVAL=0
    result=`curl -i -s -H "X-Auth-User: ${USER}" -H "X-Auth-Key: ${APIKEY}" https://auth.api.rackspacecloud.com/v1.0`
    RETVAL=$?
    
    if [ "$RETVAL" != 0 ]; then
        echo "curl error, exiting"
        exit $RETVAL
    fi

    if echo "$result" | grep -q 'HTTP/1.1 204 No Content'; then 
    #   echo "We're authenticated"
       echo -n
    else
       echo "Authentication failure"
       exit 1
    fi

    STORAGEURL=`echo "$result" | grep 'X-Storage-Url' | sed 's/X-Storage-Url: //' | tr -d '\r'`
    STORAGETOKEN=`echo "$result" | grep 'X-Storage-Token' | sed 's/X-Storage-Token: //' | tr -d '\r'`
    CDNMANURL=`echo "$result" | grep 'X-CDN-Management-Url' | sed 's/X-CDN-Management-Url: //' | tr -d '\r'`
    AUTHTOKEN=`echo "$result" | grep 'X-Auth-Token' | sed 's/X-Auth-Token: //' | tr -d '\r'`
    SRVMGNTURL=`echo "$result" | grep 'X-Server-Management-Url' | sed 's/X-Server-Management-Url: //' | tr -d '\r'`
}  

# Show authentication variables
function f_showauth() {
    echo "STORAGEURL: $STORAGEURL"
    echo "STORAGETOKEN: $STORAGETOKEN"
    echo "CNDMANURL: $CDNMANURL"
    echo "AUTHTOKEN: $AUTHTOKEN"
    echo "SERVMGNTURL: $SRVMGNTURL"
}
 
# List Containers
function f_list() {
    CURL="curl -s -H"
    ${CURL} "X-Auth-Token: ${STORAGETOKEN}" $STORAGEURL/${OBJECT}
}

# Create a container
function f_create () {
    CURL_POST="curl -s -X PUT -H"
    RESPONSE=`${CURL_POST} "X-Auth-Token: ${STORAGETOKEN}" ${STORAGEURL}/${OBJECT}`
    if `echo ${RESPONSE} |grep -q 202`; then
        echo "The '${OBJECT}' container already exists."
    elif `echo ${RESPONSE} |grep -q 201`; then
        echo "The '${OBJECT}' container was created successfully."
    else
        echo ${RESPONSE}
    fi 
}

# Uploads a file to a container
function f_upload () {
    CURL_POST="curl -s --upload-file ${FILE} -H"
    if [ -z ${NEW_FILE} ]; then
        RESPONSE=$(${CURL_POST} "X-Auth-Token: ${STORAGETOKEN}" ${STORAGEURL}/${OBJECT}/${FILE} |grep title |sed 's/<*.title>//g'|sed 's/^ *//g' |sed 's/ *$//g')
        if [ "${RESPONSE}" == "201 Created" ] ; then
          echo "File ${FILE} has been uploaded to ${OBJECT}"
        else
          echo ${RESPONSE}
        fi
    else
        RESPONSE=$(${CURL_POST} "X-Auth-Token: ${STORAGETOKEN}" ${STORAGEURL}/${OBJECT}/${NEW_FILE} |grep title |sed 's/<*.title>//g'|sed 's/^ *//g' |sed 's/ *$//g')
        if [ "${RESPONSE}" == "201 Created" ] ; then
          echo "File ${FILE} has been uploaded to ${OBJECT} as ${NEW_FILE}"
        else
          echo ${RESPONSE}
        fi
    fi
}

# Delete a container or file
function f_delete () {
    CURL_POST="curl -s -X DELETE -H"
    RESPONSE=`${CURL_POST} "X-Auth-Token: ${STORAGETOKEN}" ${STORAGEURL}/${OBJECT}/${FILE}`
    if `echo ${RESPONSE} |grep -q 409`; then
        echo "The specified container is not empty. Please remove the contents of the container before deleting it."
    elif `echo ${RESPONSE} |grep -q 404`; then
        echo "The specified container or object was not found."
    elif [ -z "${RESPONSE}" ] ; then
        if [ -z "${FILE}" ] ; then
            echo "Container ${OBJECT} deleted successfully."
        else
            echo "File ${FILE} deleted successfully."
        fi
    else
        echo ${RESPONSE}
    fi
}

#Downloads a file from a container 
function f_get () {
    CURL_TEST="curl -s -I -H"
    CURL_GET="curl --progress-bar -O -H"
      RESPONSE=$(${CURL_TEST} "X-Auth-Token: ${STORAGETOKEN}" $STORAGEURL/${OBJECT}/${FILE})| head -1 |awk '{print $2}'
      if `echo ${RESPONSE} |grep -q 404`; then
        echo "${FILE} was not found in ${OBJECT} container."
      else
        PWD=`pwd`
        ${CURL_GET} "X-Auth-Token: ${STORAGETOKEN}" $STORAGEURL/${OBJECT}/${FILE}
        echo "${FILE} downloaded to ${PWD}/${FILE}."
      fi
}


# List CDN enabled containers - not files
function f_list_cdn() {
    CURL="curl -s -H"
    ${CURL} "X-Auth-Token: ${STORAGETOKEN}" $CDNMANURL/${OBJECT}
}

# Get the URL for a CDN enabled containers 
function f_get_cdn_uri() {
    CURL="curl -s -I -H"
    if [ -z ${OBJECT} ]; then
	echo "No container specified"
        exit 1
    fi
    RESPONSE=`${CURL} "X-Auth-Token: ${STORAGETOKEN}" $CDNMANURL/${OBJECT}`
    if echo ${RESPONSE} | grep -q 404 ; then
        echo "Container not found"
    elif echo ${RESPONSE} | grep -q 204 ; then
        echo "$RESPONSE" | grep 'X-CDN-URI: ' | sed 's/X-CDN-URI: //' | sed 's/\r//'
    else
        echo "$RESPONSE" | sed 's/\r//'
    fi

}

# Get the URL for a CDN enabled containers 
function f_get_cdn_uri() {
    CURL="curl -s -I -H"
    if [ -z ${OBJECT} ]; then
	echo "No container specified"
        exit 1
    fi
    RESPONSE=`${CURL} "X-Auth-Token: ${STORAGETOKEN}" $CDNMANURL/${OBJECT}`
    if echo ${RESPONSE} | grep -q 404 ; then
        echo "Container not found"
    elif echo ${RESPONSE} | grep -q 204 ; then
        echo "$RESPONSE" | grep 'X-CDN-URI: ' | sed 's/X-CDN-URI: //' | sed 's/\r//'
    else
        echo "$RESPONSE" | sed 's/\r//'
    fi

}


# Get the URL for a CDN enabled containers 
function f_cdn_edge_purge() {
    #$NEW_FILE
    EMAIL=""
    CURL="curl -s -I -H"
    CURL_POST="curl -s -i -X DELETE -H"
    if [ -z ${OBJECT} ]; then
	echo "No container specified"
        exit 1
    fi
    # figure out if we have a file or email address specified
    # this logic might not work out if no email address is specified but a file with an '@' in it is
    if [ -n ${FILE} ] && echo ${FILE} | grep -q '@'; then
        # file is nonzero length and has a '@' in the name 
        EMAILADDR=${FILE}
        EMAIL="-H X-Purge-Email: ${FILE}"
        # zero FILE out so it doesnt get used as a file
        FILE=""
    elif [ -n ${NEW_FILE} ]; then
	EMAILADDR=${NEW_FILE}
        EMAIL="-H X-Purge-Email: ${NEW_FILE}"
    fi
        
    RESPONSE=`${CURL_POST} "X-Auth-Token: ${STORAGETOKEN}" ${EMAIL} $CDNMANURL/${OBJECT}/${FILE}`
    if echo ${RESPONSE} | grep -q 404 ; then
        echo "Container/File not found"
    elif echo ${RESPONSE} | grep -q 204 ; then
        if [ -z ${EMAILADDR} ]; then
           echo "Edge purge request submitted"
        else
           echo "Edge purge request submitted, email will be sent to ${EMAILADDR}"
        fi
    else
        echo "Uhm, what happened"
        echo "$RESPONSE" | sed 's/\r//'
    fi

#echo "EMAIL: ${EMAIL}"
#echo "EMAILADDR: ${EMAILADDR}"

}

function f_usage () {
    CURL="curl -s -X HEAD -D - -H"
      RESPONSE=$(${CURL} "X-Auth-Token: ${STORAGETOKEN}" $STORAGEURL)
#      echo ${RESPONSE}
      CONTAINERS=`echo ${RESPONSE} |awk '{print $10}' |tr -d '\r'`
      TOBJECTS=`echo ${RESPONSE} |awk '{print $6}' |tr -d '\r'`
      TBYTES=`echo ${RESPONSE} |awk '{print $8}' |tr -d '\r'`
      TKILO=$(echo "${TBYTES}/1024" |bc)
      TMEGA=$(echo "scale=2; ${TBYTES}/1024/1024" |bc)
      TGIGA=$(echo "scale=4; ${TBYTES}/1024/1024/1024" |bc)
      echo -e "Total Containers: ${CONTAINERS} \nTotal Files: ${TOBJECTS} \nTotal Bytes Used: ${TBYTES} \nTotal Kilobytes Used: ${TKILO} \nTotal Megabytes Used: ${TMEGA} \nTotal Gigabytes Used: ${TGIGA}"
}

# Usage instructions
function f_verify() {
    if [ -z "${USER}" ] || [ -z "${APIKEY}" ] || [ -z "${CMD}" ]; then
        cat <<END_USAGE
Usage: ./cfmanage.sh USERNAME APIKEY [COMMAND] [ARGS]
COMMAND:
list [CONTAINER] -----> List objects in container or if no container specified, list all containers.
create [CONTAINER] -----> Create a container.
upload [CONTAINER] [FILE] ([REMOTE FILE]) -----> Upload file to specified container as (optional) specified filename.
get [CONTAINER] [FILE] -----> Download file from specified container to current directory.
delete [CONTAINER] [FILE] -----> Delete specified container (if empty) or file.
usage -----> Shows your CloudFiles usage statistics.

CDN COMMANDS:
cdn_list : List containers that are CDN enabled (only containers, not files - API limitation)
cdn_get_uri CONTAINER : Get the public URI for the CDN enabled container
cdn_edge_purge CONTAINER [FILE] [email addr]: Purge a CONTAINER from the edge server before the TTL experation. optional email address to notify when files are purged
END_USAGE

    else
        f_exec
    fi
}


f_verify

#!/bin/bash

#This script is used to merge the master changes into release branch via Jenkins Job.

## Github domain hardcoded
api_end_point=https://github.com/api/v3

## Checks whether Tokens are set as an environment variables
if [ -z "${PR_APPR_TOKEN}" ] || [ -z "${MERGE_TOKEN}" ]; then
  echo "------------------------------------------------------------"
  echo "One/More required env variables are not defined"
  echo "------------------------------------------------------------"
  exit 1
fi

# Validate that the Repository Name is provided
if [[ -z ${REPO_NAME} ]]; then
  if [[ -z $1 ]]; then
    echo "Error: Repository name is required"
    exit 1
  else
    REPO_NAME=$1
  fi
fi

# Validate that the Repository provided exists
repo_resp=$(curl -s --url ${api_end_point}/repos/$REPO_NAME \
  --header 'authorization: Bearer '${PR_APPR_TOKEN} | jq '.message')
if [[ "${repo_resp}" = '"Not Found"' ]]; then
  echo "Error: The repository provided does not exist"
  exit 1
# Validate PR_APPR_TOKEN
elif [[ "${repo_resp}" = '"Bad credentials"' ]]; then
  echo "Error: Bad credentials"
  exit 1
fi

# Validate that the source branch is provided
if [[ -z ${SRC_BRANCH} ]]; then
  if [[ -z $2 ]]; then
    echo "Error: Source branch is required"
    exit 1
  else
    SRC_BRANCH=$2
  fi
fi

#validate that the source branch follows the naming convention
# if [[ $SRC_BRANCH != master ]] && [[ $SRC_BRANCH != release* ]] && [[ $SRC_BRANCH != work* ]]; then
#   echo "Error: The source branch \"${SRC_BRANCH}\" must follow the naming convention"
#   exit 1
# fi

# Validate that the destination regex is provided
if [[ -z ${DEST_REGEX} ]]; then
  if [[ -z $3 ]]; then
    echo "Error: A regex for specifying destination branches to merge into is required"
    exit 1
  else
    DEST_REGEX=$3
  fi
fi

# Check if excluded branches are provided (optional)
if [[ -z ${EXC_BRANCHES} ]]; then
  if [[ ! -z $4 ]]; then
    EXC_BRANCHES=$4
  fi
fi
# Check if PR subject is provided (optional)
if [[ -z ${PR_SUBJECT} ]]; then
  if [[ ! -z $5 ]]; then
    PR_SUBJECT=$5
  fi
fi

# Fetching branches from repo
branches_resp=$(curl -k -s -H "Accept: application/vnd.github.loki-preview+json" \
      -H "authorization: Bearer ${MERGE_TOKEN}" \
      ${api_end_point}/repos/$REPO_NAME/branches)

# Validate MERGE_TOKEN
if [[ "${branches_resp}" = '"Bad credentials"' ]]; then
  echo "Error: Bad credentials"
  exit 1
fi

#echo "${branches_resp}"
#-u ${ghe_user_name}:${ghe_user_token} \

## Get all branches present in Repository
branches=$(echo "${branches_resp}" | jq '.[].name')
#echo "${branches}"

## Get all open release branches
## Remove special characters from strings
dest_branches_wosc=$(echo "${branches}" | sed -e 's/\"//g')

#check if source branch exists
if [[ ! "$dest_branches_wosc" =~ "$SRC_BRANCH" ]]; then
  echo "Error: source branch not found in repo"
  exit 1
fi

## Filter branches based on regexp, it contains "(standard input):"" string
dest_branches=$(echo "${dest_branches_wosc}" | grep -E "$DEST_REGEX")
if [[ -z $dest_branches ]]; then
  echo "no branches match the regex."
  exit 1
fi

## Validation::throw exception if master branch exists
master_branch=$(echo "${dest_branches}" | grep "master")
if [ ! -z "$master_branch" ]; then
  echo "------------------------------------------------------------"
  echo "List contain master branch"
  echo "------------------------------------------------------------"
  exit 1
fi

## TODO change it to work on Unix
## Remove spaces in , seperated strings
excl_branches_wos=$(echo "$EXC_BRANCHES" | sed -e 's/ //g')
## Convert String into Array
excl_branch=$(echo "${excl_branches_wos}" | sed -e 's/,/\
/g')

echo "----------------------------------------------------------------"
echo "Source Branch is $SRC_BRANCH"
echo "----------------------------------------------------------------"

## Mark Job as a failed if AI fails even for one branch, it fails
  # 1. If Pull Request is already exists between 2 branches and AI is trying open a new Pull Request on same branches
  # 2. If there are merge conflicts between source and destination branches and AI could not able to merge it.
job_mark_red=0
## Loop through all branches and Open a Pull Request, Review Pull Request and Merge the PR by using Service Accounts
## 2 Service Accounts are needed as PR approvals cannot be provided same user who has raised the pull request
for i in ${dest_branches[@]}
do
     echo ""
     echo "----------------------------------------------------------------"
     echo "Destination Branch is $i"
     echo "----------------------------------------------------------------"

     #commented out due to ADROIT feedback
     #validate that the destination branches follow the naming convention
     # if [[ $i != release* ]] && [[ $i != work* ]]; then
     #   echo "Error: The destination branch ${i} must follow the naming convention. No actions will be performed on this branch."
     #   continue
     # fi

     if [[ "${excl_branches_wos[@]}" =~ "${i}" ]]; then
       echo "$i branch is excluded "
       continue
     fi

    ## Open a Pull Request
    pr_data="{\"title\":\"$JOB_NAME -AutoIntegration- $PR_SUBJECT\",\"body\":\"Auto Integration pull request. Jenkins URL $BUILD_URL\",\"head\":\"$SRC_BRANCH\",\"base\":\"$i\"}"
    #echo "${pr_data}"
    pr_open_resp=$(curl -k -s -H "Accept: application/vnd.github.loki-preview+json" \
          -H "authorization: Bearer ${MERGE_TOKEN}" \
          -X POST \
          -d "${pr_data}" \
          ${api_end_point}/repos/$REPO_NAME/pulls)
    resp_message=$(echo "${pr_open_resp}" | jq 'select(.message != null)')
    #echo "resp_message ${resp_message}"

    ## Throws validation error if it finds any.
    ## There should not be open PR between same branches
    ## PR only be raised if there is diff between branches
    if [[ "${resp_message}" =~ "Validation Failed" ]]; then
        echo "$pr_open_resp"
        #error_message=$(echo "${pr_open_resp}" | jq '.message')
        error_message=$(echo "${pr_open_resp}" | jq '.errors | .[] | .message')
        echo "Exception in opening Pull Reqeust between $SRC_BRANCH and $i:: ${error_message}"
        if [[ "${error_message}" =~ "A pull request already exists" ]]; then
          job_mark_red=1
        fi
        continue
    fi
    pr_url_spcha=$(echo "${pr_open_resp}" | jq '.url')
    pr_url=$(echo "${pr_url_spcha}" | sed -e 's/\"//g')
    echo "Pull Request URL ${pr_url}"

    ## Do not do review and merge if NO Merge is true
    #if [[ "${NO_MERGE}" == "true" ]]; then
    #   echo "WARN: Selected NO Merge"
    #   continue
    #fi

    ## Review Pull Request
    rev_data="{\"body\":\"Auto integration approval\",\"event\":\"APPROVE\"}"
    pr_review_resp=$(curl -k -s -H "authorization: Bearer ${PR_APPR_TOKEN}" \
          -X POST \
          -d "${rev_data}" \
          $pr_url/reviews)
    echo "${pr_review_resp}"
    echo "$SRC_BRANCH and $i branches PR is approved"

    ## Merge Pull Request
    pr_merge_resp=$(curl -k -s -H "Accept: application/vnd.github.loki-preview+json" \
          -H "authorization: Bearer ${MERGE_TOKEN}" \
          -X PUT \
          $pr_url/merge)
    echo "${pr_merge_resp}"
    merge_resp_message=$(echo "${pr_merge_resp}" | jq 'select(.message != null)')
    #echo "$SRC_BRANCH and $i Branches are merged"
    if [[ "${merge_resp_message}" =~ "Pull Request is not mergeable" ]]; then
        echo "Exception in merging Pull Reqeust between $SRC_BRANCH and $i"
        job_mark_red=1
    fi
done
exit $job_mark_red

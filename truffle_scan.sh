#!/bin/bash

# Trufflehog v2 scan script

# Send results to SIEM
send_to_siem() {
    # Get webhook from param store
    SIEM_URL=$(aws ssm get-parameter --region "$region" --name "/$environment/trufflehog-scanning/webhook")
    curl -v -X POST -T "${RESULTS_FILE}" "${SIEM_URL}"
}

# Compare to previous results
cmp_to_previous() {
    S3_BUCKET_FILE="s3://trufflehog-results/${REPO_FILE_NAME}_old.json"
    # Create a local copy of the bucket to compare to
    LOCAL_BUCKET_FILE="${REPO_FILE_NAME}_old.json"
    # Check if file exists in S3
    if [[ $(aws s3 ls "${S3_BUCKET_FILE}") ]]; then
        # If it exists, check if it's different
        # Fetch a local copy
        aws s3 cp "${S3_BUCKET_FILE}" "${LOCAL_BUCKET_FILE}"
        # diff returns 0 if different; 1 if same
        if [[ $(diff "${RESULTS_FILE}" "${LOCAL_BUCKET_FILE}") ]]; then
            #s3 cp will overwrite previous
            echo "New Results Found in: ${RESULTS_FILE}"
            send_to_siem
        else
            # remove the unused file
            echo "${RESULTS_FILE} matches s3 archive file; removing"
            rm -rf "${RESULTS_FILE}"
        fi 
        # remove the local bucket file we created
        rm -f "${LOCAL_BUCKET_FILE}"
    else
        # file does not exist; cp to s3
        aws s3 cp "${RESULTS_FILE}" "${S3_BUCKET_FILE}"
        send_to_siem
    fi
}

# Fetch List of Repos to Scan
fetch_repos() { 
    # TODO: input your repo
    REPOS_2_SCAN="https://api.github.com/<your_repo_here>"
    # Create a list of repos to iterate
    curl -s ${REPOS_2_SCAN} | jq '.[] | .html_url + " " + .pushed_at' > ./current_github_projects.autocreated_list
}

# add repo field to json for alerting
add_field() {
    # New field value is repo name
    NEW_VAL="${REPO}"
    # temporary file for json
    TMP_FILE="tmp.json"
    # Write updated JSON to temp file
    jq --arg val "${NEW_VAL}" '. += {"repo" : $val}' "${RESULTS_FILE}" > "${TMP_FILE}"
    # Replace original file with updated
    mv "${TMP_FILE}" "${RESULTS_FILE}"
    rm -f "${TMP_FILE}"
}

# Scan repos with trufflehog
scan_repos() {
    # last push date year for repo
    TOO_EARLY="2014"
    # remove previous results
    rm -rf "./results/"
    # make new results dir
    mkdir -p "./results/"
    while read -r line; do
        #field 1 is URL
        REPO="$(echo "${line}" | tr -s " " | cut -d " " -f1 | sed -e 's/"//g')"
        # Fetch repo name, stripping github.com/<org>
        REPO_FILE_NAME="$(echo "${REPO}" | sed -e 's/https:\/\/github\.com\/org\///g')"
        # last push to repo; field 2
        LAST_PUSH_DATE="$(echo "${line}" | tr -s " " | cut -d " " -f2 | sed -e 's/"//g')"
        # Create results file, per repo
        RESULTS_FILE="./results/${REPO_FILE_NAME}_results.json"
        # scan the results with trufflehog, if more recent than $TOO_EARLY
        if [[ "$(date -d "${LAST_PUSH_DATE}" +%Y)" -gt "${TOO_EARLY}" ]]; then
            echo "SCANNING REPO: ${REPO}"
            # Scan with trufflehog, use secrets_config.json for secrets list
            trufflehog --json --rules ./secrets_config.json --regex --entropy=False "${REPO}" >> "${RESULTS_FILE}"
            add_field
        fi
        # Check if file is not empty; otherwise rm blank file
        if [[ -s "${RESULTS_FILE}" ]]; then
            echo "Results Found in: ${RESULTS_FILE}"
            echo "Investigate Repo: ${REPO_FILE_NAME}"
            cat "${RESULTS_FILE}" | jq '"Path: " + .path + " Commit: " + .commitHash + " Reason: " + .reason '
            # compare to previous in S3 bucket
            cmp_to_previous
        else
            rm -f "${RESULTS_FILE}"
        fi
    done < ./current_github_projects.autocreated_list
}

main() {
    fetch_repos
    scan_repos
}

main

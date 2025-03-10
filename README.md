#hogsniffer

Use Trufflehog to scan repositories

## Description

This script fetches a list of repositories to scan and subsequently uses Trufflehog to scan the repositories.

If secrets are discovered, a JSON file will be created and compared to previous scan results from an S3 bucket

ensure that the correct destinations are overwritten, such as the appropriate github site, the siem webhook URL, and the S3 bucket locations

## Architecture

An Ubunutu Docker container is created to run the scanning script, installing the appropriate dependencies, and contained in an ECR

## Dependencies
- trufflehog
- jq
- awscli

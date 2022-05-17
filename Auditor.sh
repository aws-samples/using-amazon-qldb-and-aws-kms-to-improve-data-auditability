#!/bin/bash

#  Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
#  SPDX-License-Identifier: MIT-0

#  Permission is hereby granted, free of charge, to any person obtaining a copy of this
#  software and associated documentation files (the "Software"), to deal in the Software
#  without restriction, including without limitation the rights to use, copy, modify,
#  merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
#  permit persons to whom the Software is furnished to do so.

#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
#  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
#  PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
#  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
#  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# ------------------------------------------------------------------
# AUDITOR WORKFLOW
# As an auditor, read the data from the QLDB ledger's SharedData table and verify the signature
# Prerequisites: 
#   - Run the Installer.sh script to complete the installation process
#   - Run the Editor.sh script successfully to complete the Editor's workflow
#   - Run this script from the same working directory as the previous step
# ------------------------------------------------------------------

# Step 1 - Assume the Auditor role
# Retrieve the ARN of the IAM role for the Auditor
export QLDB_AUDITOR_ROLE_ARN=$(aws cloudformation describe-stacks --stack-name QLDB-KMS-TEST --region us-east-1 --query 'Stacks[0].Outputs[?OutputKey==`oAuditorRoleARN`].OutputValue' --output text)
# Assume the IAM role of the Auditor
export QLDB_AUDITOR_ROLE_CREDENTIALS=$(aws sts assume-role --role-arn $QLDB_AUDITOR_ROLE_ARN --role-session-name AWSCLI-Session --output json)
export AWS_ACCESS_KEY_ID=$(echo $QLDB_AUDITOR_ROLE_CREDENTIALS | jq .Credentials.AccessKeyId | sed 's/"//g')
export AWS_SECRET_ACCESS_KEY=$(echo $QLDB_AUDITOR_ROLE_CREDENTIALS | jq .Credentials.SecretAccessKey | sed 's/"//g')
export AWS_SESSION_TOKEN=$(echo $QLDB_AUDITOR_ROLE_CREDENTIALS | jq .Credentials.SessionToken | sed 's/"//g')
# The Editor.sh file should be run before running Auditor.sh
# The Editor.sh file writes the document ID of the new record written in the ledger into a text file 'document_id.txt'
export QLDB_DATA_DOC_ID=`cat document_id.txt`

cd ~/qldb-v2.0.1-linux
# Step 2 - Prepare for verifying the signature
# Get the data to be verified from the record written into the QLDB 'SharedData' table within the ledger
# QLDB_DATA_DOC_ID - Env variable filled by running the Editor script
cat <<EOT > queryDocumentData.sql
SELECT r.data.data FROM _ql_committed_SharedData AS r WHERE r.metadata.id = '$QLDB_DATA_DOC_ID'
EOT
export QLDB_DATA_TO_VERIFY=$(./qldb < queryDocumentData.sql)
export QLDB_DATA_TO_VERIFY=$(echo $QLDB_DATA_TO_VERIFY | sed 's/{ data: "//g' | sed 's/" }//g' )
export QLDB_DATA_TO_VERIFY_BASE64=$(echo -n $QLDB_DATA_TO_VERIFY | base64 --wrap=0)
echo $QLDB_DATA_TO_VERIFY_BASE64 > msg_verify_kms.txt
# Get the Message signature from the record written into the QLDB 'SharedData' table within the ledger
cat <<EOT > getSignature.sql
SELECT r.data.signature.signature FROM _ql_committed_SharedData AS r WHERE r.metadata.id = '$QLDB_DATA_DOC_ID'
EOT
export QLDB_SIGNATURE_TO_VERIFY=$(./qldb < getSignature.sql)
export QLDB_SIGNATURE_TO_VERIFY=$(echo $QLDB_SIGNATURE_TO_VERIFY | sed 's/{ signature: "//g' | sed 's/" }//g' )

# Step 3a - Verify the signature using AWS KMS
# Get the KMS Key ARN from the record written into the QLDB 'SharedData' table within the ledger
cat <<EOT > getKMSKeyARN.sql
SELECT r.data.signature.kmsKeyARN FROM _ql_committed_SharedData AS r WHERE r.metadata.id = '$QLDB_DATA_DOC_ID'
EOT
export QLDB_KMS_KEY_ARN=$(./qldb < getKMSKeyARN.sql)
export QLDB_KMS_KEY_ARN=$(echo $QLDB_KMS_KEY_ARN | sed 's/{ kmsKeyARN: "//g' | sed 's/" }//g' )
# Get the Signing Algorithm from the record written into the QLDB 'SharedData' table within the ledger
cat <<EOT > getSigningAlgorithm.sql
SELECT r.data.signature.signingAlgorithm FROM _ql_committed_SharedData AS r WHERE r.metadata.id = '$QLDB_DATA_DOC_ID'
EOT
export QLDB_SIGNING_ALGORITHM=$(./qldb < getSigningAlgorithm.sql)
export QLDB_SIGNING_ALGORITHM=$(echo $QLDB_SIGNING_ALGORITHM | sed 's/{ signingAlgorithm: "//g' | sed 's/" }//g' )
# Verify the signature using AWS KMS
echo "AWS KMS Signature Verification method output:"
aws kms verify --key-id $QLDB_KMS_KEY_ARN --message fileb://msg_verify_kms.txt --message-type "RAW" --signing-algorithm $QLDB_SIGNING_ALGORITHM --signature $QLDB_SIGNATURE_TO_VERIFY

echo "OpenSSL Signature Verification method output:"
# Step 3b - Verify the signature using OpenSSL (Optional)
# Get the public part of the KMS key 
cat <<EOT > getPublicKey.sql
SELECT r.data.signature.publicKey FROM _ql_committed_SharedData AS r WHERE r.metadata.id = '$QLDB_DATA_DOC_ID'
EOT

export QLDB_PUBLIC_KEY=$(./qldb < getPublicKey.sql)
export QLDB_PUBLIC_KEY=$(echo -n $QLDB_PUBLIC_KEY | sed 's/{ publicKey: "//g' | sed 's/" }//g')
# Put the data in base64 encoding into a text file
echo $QLDB_DATA_TO_VERIFY_BASE64 > msg_verify_openssl.txt
# Generate a file with public key in PEM format
echo -n $QLDB_PUBLIC_KEY | base64 -d > pubkey.der
openssl ec -pubin -inform DER -outform PEM -in pubkey.der -pubout -out pubkey.pem
# Encode the data signature into DER format
echo -n $QLDB_SIGNATURE_TO_VERIFY | base64 -d > sig.der
# Verify the signature using OpenSSL
openssl dgst -sha256 -verify pubkey.pem -signature sig.der msg_verify_openssl.txt

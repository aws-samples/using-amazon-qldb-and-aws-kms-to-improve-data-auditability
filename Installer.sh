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
# INSTALLATION
# ------------------------------------------------------------------

# Install OpenSSL (Optional)
cd ~
sudo yum install -y openssl

# Install and configure the QLDB Interactive Shell
wget https://github.com/awslabs/amazon-qldb-shell/releases/download/v2.0.1/qldb-v2.0.1-linux.tar.gz
tar -xvf ./qldb-v2.0.1-linux.tar.gz
cd qldb-v2.0.1-linux

# Create a configuration file that will make working with QLDB more convenient from Bash
mkdir ~/.config/qldbshell
cat <<EOT > ~/.config/qldbshell/config.ion
{
  default_ledger: "SharedLedger",
  ui: {
    // format = [ion|table]
    // ion: Prints the objects from the database as ION documents in text.
    // table: Tabulates the data and prints out the data as rows.
    format: "ion", // or ion default: ion
    // Can be toggled to suppress some messaging when running in interactive mode
    display_welcome: false, // the default; can be set to false
    display_ctrl_signals: false,
    // Determines whether or not metrics will be emitted after the results of a query are shown.
    display_query_metrics: false,
    // Set terminator_required to true indicates that pressing the enter key at the end of a line of
    // input will not execute the command by itself.
    // Alternately, if you end your statement with a semi-colon you will execute the statement.
    terminator_required: false
  }
}
EOT

# Create the SharedData Table in the QLDB default ledger
cd ~/qldb-v2.0.1-linux
./qldb
CREATE TABLE SharedData
# press `CTRL-D` to exit QLDB Interactive Shell
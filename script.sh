

#! bin/bash

# Script to create the directories and files for the terraform modules

: ' 
cd modules/honeypot
touch main.tf
touch variables.tf
touch outputs.tf
touch README.md 
' 
cd modules

cd log-analytics
touch main.tf
touch variables.tf
touch outputs.tf
touch README.md 

cd ..

cd misp
touch main.tf
touch variables.tf
touch outputs.tf
touch README.md 

cd ..

cd sentinel
touch main.tf
touch variables.tf
touch outputs.tf
touch README.md 

cd ..

cd networking
touch main.tf
touch variables.tf
touch outputs.tf
touch README.md 
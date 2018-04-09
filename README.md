# CodePractice

## Usage of files in this repo:

- ConvertToProperty.java: This class is used to convert any json file into properties file
- autointegration.sh : This script is used to merge the master changes into release branch via Jenkins Job
- shift_array_element.py : This script rotate integer array(input) elements by shift(input) 
- CD Pipeline :
  	- pipeline/Docerfile - Contains the file which are required to create docker image
  	- pipeline/Jenkinsfile.py - This file is used to run the Jenkins file based the passed parameter from Jenkins job
  	- pipeline/requirements.txt - This is requirement file for python, you can pass it through Jenkins job
  	- Below are the parameters for Jenkins job:
    	- REPOSITORY_URL
    	- GIT_REPO_CRED
    	- BRANCH
    	- REQUIREMENTS_FILE
    	- PYTHON_SCRIPT_FILE

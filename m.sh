#!/bin/bash

usage() {

cat << usg
 ******************************************************
 * This script's purpose is to check number of messages in different SQS queues in AWS
 *
 * Assumptions:
 *  this script expects a definition file to be passed.
 ********************************************************
 Required arguments
  -f FILE NAME,         File name will be containing names of different SQS queues for different teams.

 optional arguments:
  -h HELP               Show this help message and exit

  # Example - Checks number of messages in different SQS queues mentioned in definition.txt file
  ./monitor_queues.sh -f definition.txt

usg

}

check_messages_in_queue() {

  queue=$1

  NUM_OF_MESSAGES=`aws sqs get-queue-attributes --queue-url https://sqs.eu-west-1.amazonaws.com/775912293446/$queue --attribute-names ApproximateNumberOfMessages --query 'Attributes.ApproximateNumberOfMessages' | sed 's/\"//g'`

  echo "Number of messgaes in $queue is $NUM_OF_MESSAGES"
  
  if [[ $queue =~ .*_errors ]] && [ $NUM_OF_MESSAGES -gt 0 ]; then
    echo "number of messages in $queue is greater than 0. Please check" | mail -s "ALERT" all_teams@abc.com
  fi

}

compare_number_of_messages() {

  MAX_NUM=$1
  queue_name=$2
  email_list=$3
  if [ $NUM_OF_MESSAGES -gt $MAX_NUM ]; then
    echo "number of messages in $queue_name is greater than $MAX_NUM"
    echo "number of messages in $queue_name is greater than $MAX_NUM. Please check" | mail -s "ALERT" $email_list
  fi

}

while getopts ":f:h" opt; do
  case $opt in
    f)
      FILE_NAME=$OPTARG
      ;;
    h)
      usage
      exit 0
      ;;
    *)
      echo 'Incorrect arguments provided'
      usage
      exit 1
      ;;
  esac
done

if [ ! "${FILE_NAME}" ]; then
   echo -e 'File name containing list of queues is required\n'
   exit 1
fi

if [ ! -f "${FILE_NAME}" ]; then
    echo -e "$FILE_NAME file doesnt exist"
    exit 1
fi

sed '/.*\:$/d' $FILE_NAME | sed '/^$/d' > all_queues.txt
sed -e '/^$/,$d' $FILE_NAME | sed '1d' > team1_queues.txt
sed '/^$/,/^$/!d' $FILE_NAME | sed '/^$/d' | sed '1d' > team2_queues.txt
sed '1,/^$/d' $FILE_NAME | sed '1,/^$/d' | sed '1d' > team3_queues.txt
grep ".*_errors" $FILE_NAME > all_error_queues.txt

for i in `cat all_error_queues.txt`; do
  check_messages_in_queue $i
done

MAX_NUM_OF_MESSAGES=10
email_list="team1@abc.com,team2@abc.com"

queue1=test_devops_new_houses
check_messages_in_queue $queue1
compare_number_of_messages $MAX_NUM_OF_MESSAGES $queue1 $email_list

queue2=test_devops_makelaars
check_messages_in_queue $queue2
compare_number_of_messages $MAX_NUM_OF_MESSAGES $queue2 $email_list


team3_email="team3@abc.com"
team3_non_error_queue=`grep -v ".*_errors" team3_queues.txt`
MAX_NUM_OF_MESSAGES=25

for i in `echo $team3_non_error_queue`; do
  check_messages_in_queue $i
  compare_number_of_messages $MAX_NUM_OF_MESSAGES $i $team3_email
done

rm -f all_queues.txt team1_queues.txt team2_queues.txt team3_queues.txt all_error_queues.txt

#!/bin/bash
# This script moves specific job ids to the top of the queue.

all_jobs=$(squeue --json | jq -r .jobs\[\].job_id)
if [ $# -eq 0 ]; then
    echo "usage: $0 <job_id1> <job_id2> ..."
    exit 1
fi

# set other job's nice to 100
for job_id in $all_jobs; do
    if [[ ! " $@ " =~ " ${job_id} " ]]; then
        echo "Setting job $job_id nice to 100"
        scontrol update jobid=$job_id nice=100
    fi
done

counter=1
for job_id in "$@"; do
    echo "Setting job $job_id nice to $counter"
    scontrol update jobid=$job_id nice=$counter
    ((counter=counter+10))
done
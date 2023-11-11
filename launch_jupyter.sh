#!/usr/bin/env bash
SCRIPT_HOME=/home/gridsan/ylu/scripts
sbatch_output=$(sbatch $SCRIPT_HOME/jupyter_job.sh)
job_id=$(echo "$sbatch_output" | awk '{print $4}')
echo "JobID: $job_id submitted; waiting for it to start..."

while true; do
    job_state=$(squeue -j ${job_id} --json | jq -r .jobs\[0\].job_state)
    if [ "$job_state" != "PENDING" ]; then
        break
    fi
    echo -ne "."
    sleep 1
done
echo ""
echo "Job $job_id started"
# wait for file to exist
while [ ! -f $SCRIPT_HOME/logs/jupyter${job_id}.log ]; do sleep 1; done
# find for "Portal URL is: "
while true; do
    portal_url=$(grep -oP 'Portal URL is: \K.*' $SCRIPT_HOME/logs/jupyter${job_id}.log)
    if [ "$portal_url" != "" ]; then
        echo "Portal URL: $portal_url"
        break
    fi
done


# tail -f logs/jupyter${job_id}.log

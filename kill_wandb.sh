#!/usr/bin/env bash

existing_wandb=$(squeue --json | jq -r '.jobs[] | select(.name == "wandb") | select(.job_state == "RUNNING") .job_id')
if [ "$existing_wandb" != "" ]; then
    echo "Sending killing signal to wandb job $existing_wandb..."
    scancel -s USR1 $existing_wandb -f
    while true; do
        job_state=$(squeue -j ${existing_wandb} --json | jq -r .jobs\[0\].job_state)
        if [ "$job_state" != "RUNNING" ]; then
            break
        fi
        echo -ne "."
        sleep 1
    done
    echo "WandB Killed"
else
    echo "No wandb job running."
fi

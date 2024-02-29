#!/usr/bin/env bash
# some environment variables for offline use
export HF_DATASETS_OFFLINE=1 TRANSFORMERS_OFFLINE=1 WANDB_MODE=offline

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_HOME=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

partition="xeon-g6-volta"
job_name="sleep"
gpus=2
job_time="08:00:00"

while getopts p:j:g:t:h flag
do
    case "${flag}" in
        p) partition=${OPTARG};;
        j) job_name=${OPTARG};;
        g) gpus=${OPTARG};;
        t) job_time=${OPTARG};;
        h|*) echo "usage: $0 [-p partition] [-j job_name] [-g gpus] [-t time]"; exit 1;;
    esac
done

sbatch_output=$(sbatch << EOT
#!/bin/sh
#SBATCH --job-name=$job_name                                    # Job name
#SBATCH -p $partition                                           # Partition (queue) name
#SBATCH --nodes=1                                               # Number of nodes
#SBATCH --gpus=$gpus                                            # Number of GPUs to allocate
#SBATCH --time=$job_time                                         # Time limit hrs:min:sec
#SBATCH --output=$SCRIPT_HOME/logs/sleep%j.log                # Standard output and error log

echo "Job Started"
sleep infinity
EOT
)

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
echo "Job $job_id started. "

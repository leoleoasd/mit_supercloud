#!/bin/sh
#SBATCH --job-name=jupyter                                      # Job name
#SBATCH -p xeon-g6-volta                                        # Partition (queue) name
#SBATCH --mail-type=ALL                                         # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=lu.yuxuan@northeastern.edu                  # Where to send mail	
#SBATCH --nodes=1                                               # Number of nodes
#SBATCH --gpus=1                                                # Number of GPUs to allocate
#SBATCH --time=08:00:00                                         # Time limit hrs:min:sec
#SBATCH --output=/home/gridsan/ylu/scripts/logs/jupyter%j.log   # Standard output and error log

srun --resv-ports=1 \
    bash << EOF
    RANDOM_ID=\$(uuidgen | cut -c1-8)
    PORTAL_FWNAME="\$(id -un | tr '[A-Z]' '[a-z]')-\$RANDOM_ID-jupyter"
    PORTAL_FWFILE="/home/gridsan/portal-url-fw/\${PORTAL_FWNAME}"
    echo "Portal URL is: https://\${PORTAL_FWNAME}.fn.txe1-portal.mit.edu/"
    echo "http://\$(hostname -s):\${SLURM_STEP_RESV_PORTS}/" > \$PORTAL_FWFILE
    # cat \$PORTAL_FWFILE
    chmod u+x \${PORTAL_FWFILE}
    jupyter lab --port \${SLURM_STEP_RESV_PORTS} --ip \$(hostname -s) --no-browser
EOF

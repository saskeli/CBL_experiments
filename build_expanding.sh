#!/bin/bash

USAGE="$0 <file_list> <data_folder> <output_folder> -- build unitigs and time index creation

where:
    file_list    is a text file containing the names of fasta files to use.
    data_folder  is the folder containing the fasta files.
    output_foder is the directory to write unitigs and indexes to.
    
All arguments are required

Example $0 fof_build.txt data out"

if [ $# -ne 3 ]; then
    echo "$USAGE"
    exit 1
fi

set -euxo pipefail

FOF=$1
DATA_FOLDER=$2
OUT_FOLDER=$3

mkdir -p ${OUT_FOLDER}

for i in 2 4 8 16 32 64 128 256 512 1024; do
  if [ ! -f ${OUT_FOLDER}/${i}.unitigs.fa ]; then
    head -n ${i} ${FOF} | while read line ; do echo "${DATA_FOLDER}/${line}"; done > tmp.txt
    bcalm/build/bcalm -in tmp.txt -verbose 0 -kmer-size 31 -abundance-min 1 -out ${OUT_FOLDER}/${i} 
    rm tmp.txt
  fi 
done

rm -f ${OUT_FOLDER}/*glue*

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:./bifrost/build/lib/
export LIBRARY_PATH=${LIBRARY_PATH-""}:./bifrost/build/lib/
export PATH=$PATH:./bifrost/build/lib/
MAX_THREADS=$(nproc)

for i in 2 4 8 16 32 64 128 256 512 1024; do
  echo ${OUT_FOLDER}/${i}.unitigs.fa > tmp.txt
  
  /usr/bin/time CBL/target/release/examples/cbl build ${OUT_FOLDER}/${i}.unitigs.fa -o ${OUT_FOLDER}/${i}.cbl
  /usr/bin/time bufboss/bin/bufboss_build -a ${OUT_FOLDER}/${i}.unitigs.fa -o ${OUT_FOLDER}/${i}.bufboss -k 31 -t tmp
  /usr/bin/time bifrost/build/bin/Bifrost build -r ${OUT_FOLDER}/${i}.unitigs.fa -o ${OUT_FOLDER}/${i}.bifrost -k 31 -t 1
  /usr/bin/time BBB/build/bin/buffer -r -n -t 1 tmp.txt ${OUT_FOLDER}/${i}.sbwt 
  echo "threads = ${MAX_THREADS}"
  /usr/bin/time bifrost/build/bin/Bifrost build -r ${OUT_FOLDER}/${i}.unitigs.fa -o ${OUT_FOLDER}/${i}.bifrost -k 31 -t $MAX_THREADS
  /usr/bin/time BBB/build/bin/buffer -r -n -m 10 -t $MAX_THREADS tmp.txt ${OUT_FOLDER}/${i}.sbwt 

  rm tmp.txt
done
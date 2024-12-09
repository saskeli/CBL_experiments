#!/bin/bash

USAGE="$0 <file_list> <data_folder> <output_folder> <limit> 

Delete with files from <file_list>, that can be found in <data_folder> from indexes found in <output_folder>.

The index file names should match those created with build_expanding.

where:
    file_list    is a text file containing the names of fasta files to use.
    data_folder  is the folder containing the fasta files.
    output_foder is the directory where indexes are.
    limit        maximum number of genomes the indexes are built of. Default: 1024.
    
All arguments, besides the limit are required

Example $0 fof_build.txt data out"

if [ $# -lt 3 ]; then
    echo "$USAGE"
    exit 1
fi

BLA=$(head -n 1 $1)
EXT=${BLA##*.}
FEXT=$EXT
if [ "$EXT" = "gz" ]; then
    FN=${BLA%.*}
    FEXT=${FN##*.}
    EXT=${FEXT}.${EXT}
fi

echo "file extenstion: $EXT"

FOF=$1
DATA_FOLDER=$2
OUT_FOLDER=$3
FILE_LIMIT=1024
if [ $# -gt 3 ]; then 
    FILE_LIMIT=$4
fi

set -euxo pipefail

MAX_THREADS=$(nproc)
MAX_THREADS=$((MAX_THREADS > 32 ? 32 : MAX_THREADS))
MAX_MEM=$(free -g | awk '/^Mem:/{print int($2 * 0.9)}')

FN=${OUT_FOLDER}/tmp.${FEXT}
GFN=${OUT_FOLDER}/tmp.${EXT}
if [ ! -f $FN ]; then
  head -n 2 ${FOF} | while read line ; do echo "${DATA_FOLDER}/${line}"; done | xargs cat > $GFN
  if [ "$EXT" != "$FEXT" ]; then
    gunzip $GFN
  fi
fi

i=1
while [ $i -lt $FILE_LIMIT ]; do
  i=$(($i * 2))
  
  /usr/bin/time CBL/target/release/examples/cbl remove ${OUT_FOLDER}/${i}.cbl ${FN} -o ${OUT_FOLDER}/tmp.cbl
  # We need reverse complements for bufboss?
  /usr/bin/time bufboss/bin/bufboss_update -i ${OUT_FOLDER}/${i}.bufboss -d ${FN} -o ${OUT_FOLDER}/tmp.bufboss

  /usr/bin/time Buffered_SBWT/delete -r -t 1 -i ${OUT_FOLDER}/${i}.sbwt -f ${FN} ${OUT_FOLDER}/tmp.sbwt 
  THREADS=$((MAX_THREADS > 4 ? 4 : MAX_THREADS))
  echo "threads = ${THREADS}"
  /usr/bin/time Buffered_SBWT/delete -r -t $THREADS -i ${OUT_FOLDER}/${i}.sbwt -f ${FN} ${OUT_FOLDER}/tmp.sbwt 
  THREADS=$((MAX_THREADS > 16 ? 16 : MAX_THREADS))
  echo "threads = ${THREADS}"
  /usr/bin/time Buffered_SBWT/delete -r -n -m $((MAX_MEM > 4 ? 4 : MAX_MEM)) -t $THREADS -i ${OUT_FOLDER}/${i}.sbwt -f ${FN} ${OUT_FOLDER}/tmp.sbwt 
  echo "threads = ${MAX_THREADS}"
  /usr/bin/time Buffered_SBWT/delete -r -n -m $((MAX_MEM > 30 ? 30 : MAX_MEM)) -t $MAX_THREADS -i ${OUT_FOLDER}/${i}.sbwt -f ${FN} ${OUT_FOLDER}/tmp.sbwt 


  rm -f ${OUT_FOLDER}/tmp.tsv 
  rm -rf ${OUT_FOLDER}/tmp.bufboss
done

rm -f ${OUT_FOLDER}/tmp.${EXT} ${OUT_FOLDER}/tmp.${FEXT}
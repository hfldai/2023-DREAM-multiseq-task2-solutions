#!/bin/bash
export INPUT_DIR=$1
export OUTPUT_DIR=$2
export MODEL=$3
export PROCESS_PEAKCALLS=$4
export THR=$5
export NCORES=10 # don't use more than 10 cores

export TMP_DIR=tmp
export BW_DIR=$TMP_DIR/bw
export DENOISE_DIR=$TMP_DIR/denoise
export GENOME_DIR=$TMP_DIR/genome_build_sizes

mkdir -p $OUTPUT_DIR
mkdir -p $TMP_DIR
mkdir -p $BW_DIR
mkdir -p $GENOME_DIR
mkdir -p $DENOISE_DIR


# 1. get genome sizes for each bam (instead of explicitly giving genome build)
for bam in $(basename -a -s .bam $(ls $INPUT_DIR/*.bam));
do
  samtools view -H $INPUT_DIR/$bam".bam" | grep "^@SQ" | grep -E chr"[0-9]{1,2}\s|[X]\s" | grep -v "_" | cut -f 2,3 | cut -d: -f 2,3 | sed "s/LN://g" > $GENOME_DIR/$bam".genome_sizes.txt"
done

# 2. get bw of each bam
# 3. Denoise bw using atacworks (default params)
# 4. postprocess peak calls, set min peak length to 20
# 5. rm ataworks bedGraph outputs to save space
basename -a -s .bam $(ls $INPUT_DIR/*.bam) | parallel --max-procs=$NCORES --halt-on-error 2 \
  'samtools index $INPUT_DIR/{}.bam &&
   bamCoverage --bam $INPUT_DIR/{}.bam -o $BW_DIR/{}.bw -bs 1 --extendReads -p max --normalizeUsing None -v &&
   atacworks denoise --noisybw $BW_DIR/{}.bw --genome $GENOME_DIR/{}.genome_sizes.txt --weights_path $MODEL --out_home $DENOISE_DIR --exp_name {} --threshold $THR --distributed --num_workers 0 &&
   python $PROCESS_PEAKCALLS --peakbg $DENOISE_DIR/{}_latest/{}_infer.peaks.bedGraph --trackbg $DENOISE_DIR/{}_latest/{}_infer.track.bedGraph --prefix {} --out_dir $DENOISE_DIR/{}_latest --minlen 20 &&
   cat $DENOISE_DIR/{}_latest/{}.bed | tail -n +2 | cut -f 1,2,3 | sort -k1,1 -k2,2n > $OUTPUT_DIR/{}.bed &&
   rm $DENOISE_DIR/{}_latest/{}_infer.track.bedGraph $DENOISE_DIR/{}_latest/{}_infer.peaks.bedGraph'



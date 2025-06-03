#! /bin/bash

set -e;

TMPDIR="tmp-kybertest"
mkdir -p $TMPDIR

# Run the assembler on each file
hw/ip/otbn/util/otbn_as.py -DKYBER_K=3 -o $TMPDIR/kyber768_mlkem_keypair_test.o sw/otbn/crypto/tests/mlkem/kyber768_mlkem_keypair_test.s
hw/ip/otbn/util/otbn_as.py -DKYBER_K=3 -o $TMPDIR/kyber_packing.o sw/otbn/crypto/mlkem/kyber_packing.s
hw/ip/otbn/util/otbn_as.py -DKYBER_K=3 -o $TMPDIR/kyber_poly_gen_matrix.o sw/otbn/crypto/mlkem/kyber_poly_gen_matrix.s
hw/ip/otbn/util/otbn_as.py -DKYBER_K=3 -o $TMPDIR/kyber_poly.o sw/otbn/crypto/mlkem/kyber_poly.s
hw/ip/otbn/util/otbn_as.py -DKYBER_K=3 -o $TMPDIR/kyber_cbd_isaext.o sw/otbn/crypto/mlkem/kyber_cbd_isaext.s
hw/ip/otbn/util/otbn_as.py -DKYBER_K=3 -o $TMPDIR/kyber_basemul.o sw/otbn/crypto/mlkem/kyber_basemul.s
hw/ip/otbn/util/otbn_as.py -DKYBER_K=3 -o $TMPDIR/kyber_ntt.o sw/otbn/crypto/mlkem/kyber_ntt_trn.s
hw/ip/otbn/util/otbn_as.py -DKYBER_K=3 -o $TMPDIR/kyber_intt.o sw/otbn/crypto/mlkem/kyber_intt_trn.s
hw/ip/otbn/util/otbn_as.py -DKYBER_K=3 -o $TMPDIR/kyber_mlkem.o sw/otbn/crypto/mlkem/kyber_mlkem.s

# Run the linker to generate a .elf file
hw/ip/otbn/util/otbn_ld.py -o $TMPDIR/kyber768_mklem_keypair_test.elf $TMPDIR/kyber768_mlkem_keypair_test.o $TMPDIR/kyber_packing.o $TMPDIR/kyber_poly_gen_matrix.o $TMPDIR/kyber_poly.o $TMPDIR/kyber_cbd_isaext.o $TMPDIR/kyber_basemul.o $TMPDIR/kyber_ntt.o $TMPDIR/kyber_intt.o $TMPDIR/kyber_mlkem.o

echo "run test"

# Run the test
./hw/ip/otbn/util/otbn_sim_test.py -v hw/ip/otbn/dv/otbnsim/standalone.py --expected_dmem ./sw/otbn/crypto/tests/mlkem/kyber768_mlkem_keypair_test.dexp $TMPDIR/kyber768_mklem_keypair_test.elf

# Clean up
rm $TMPDIR/*
rmdir $TMPDIR

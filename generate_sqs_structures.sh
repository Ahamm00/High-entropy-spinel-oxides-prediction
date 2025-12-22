#!/bin/bash

# ========== USER SETTINGS ==========
CSV_FILE="Final selected structures.csv"
TEMPLATE="rndstr_template.in"
LATTICE_CONSTANT="8.3469486237"
TIME_LIMIT=180  # seconds

# ========= CHOOSE ROW RANGE HERE =========
START_ROW=1   # HEO1 starts here
END_ROW=23    # Inclusive
# =========================================

echo "?? Starting SQS generation for rows $START_ROW to $END_ROW..."

ROWNUM=0
tail -n +2 "$CSV_FILE" | while IFS=',' read -r A1 A2 A3 A4 A5 B COMPOSITION PHASE1 PHASE2 REST; do
    ((ROWNUM++))
    if ((ROWNUM < START_ROW || ROWNUM > END_ROW)); then
        continue
    fi

    COMPFOLDER="HEO${ROWNUM}"
    mkdir -p "$COMPFOLDER"
    echo "?? Starting composition: $COMPFOLDER"

    cp "$TEMPLATE" "$COMPFOLDER/rndstr.in"
    RNDSTR_FILE="$COMPFOLDER/rndstr.in"

    # === Substitute B-site (Cr) ===
    sed -i "s/Cr=1.000000/${B}=1.000000/g" "$RNDSTR_FILE"

    # === Substitute all 8 A-site lines safely ===
    awk -v A1="$A1" -v A2="$A2" -v A3="$A3" -v A4="$A4" -v A5="$A5" '
    BEGIN {
        target = "Ca=0.200000,Mg=0.200000,Mn=0.200000,Ni=0.200000,Zn=0.200000"
        replace = A1"=0.200000,"A2"=0.200000,"A3"=0.200000,"A4"=0.200000,"A5"=0.200000"
    }
    {
        if (index($0, target)) {
            sub(target, replace)
        }
        print
    }' "$RNDSTR_FILE" > tmp && mv tmp "$RNDSTR_FILE"

    cd "$COMPFOLDER" || continue

    echo "    ?? Running corrdump..."
    corrdump -l=rndstr.in -ro -noe -nop -clus -2=5.0 > corrdump.log 2>&1

    echo "    ??  Running mcsqs..."
    timeout ${TIME_LIMIT}s bash -c "mcsqs -n 280 > mcsqs.log 2>&1"
    if [[ $? -ne 0 || ! -f bestsqs.out ]]; then
        echo "    ? mcsqs timed out or failed for $COMPFOLDER"
        cd - >/dev/null
        continue
    fi

    echo "    ?? Converting to POSCAR..."
    sqs2poscar bestsqs.out > /dev/null 2>&1

    if [[ -f bestsqs.out-POSCAR ]]; then
        VASP_FILE="../${COMPFOLDER}.vasp"
        awk -v lat="$LATTICE_CONSTANT" 'NR==2{$0=lat} 1' bestsqs.out-POSCAR > "$VASP_FILE"
        echo "    ? Saved VASP: ${COMPFOLDER}.vasp"
    else
        echo "    ? POSCAR conversion failed for $COMPFOLDER"
    fi

    cd - >/dev/null
done

echo "? All done for rows $START_ROW to $END_ROW."

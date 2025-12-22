#!/bin/bash

# ===== USER SETTINGS =====
LATTICE_CONSTANT="8.3469486237"
START_ROW=1     # <-- Change as needed
END_ROW=23       # <-- Change as needed
BASE_DIR=$(pwd)

echo "?? Starting POSCAR conversion for HEO${START_ROW} to HEO${END_ROW}..."

for ((row = START_ROW; row <= END_ROW; row++)); do
    comp_folder="HEO${row}"
    [[ -d "$comp_folder" ]] || { echo "  ??  Skipping: $comp_folder not found."; continue; }

    echo "?? Working on $comp_folder..."

    cd "$comp_folder" || { echo "  ? Failed to enter $comp_folder"; continue; }

    if [[ -f bestsqs.out ]]; then
        echo "  ?? Converting bestsqs.out to POSCAR..."

        # Run sqs2poscar
        sqs2poscar bestsqs.out > /dev/null 2>&1

        if [[ -f bestsqs.out-POSCAR ]]; then
            VASP_OUT="../HEO${row}.vasp"
            awk -v lat="$LATTICE_CONSTANT" 'NR==2{$0=lat} 1' bestsqs.out-POSCAR > "$VASP_OUT"
            echo "    ? Saved: HEO${row}.vasp"
        else
            echo "    ? POSCAR conversion failed in $comp_folder"
        fi
    else
        echo "    ??  bestsqs.out not found in $comp_folder"
    fi

    cd "$BASE_DIR" || exit
done

echo "? POSCAR conversion completed for HEO${START_ROW} to HEO${END_ROW}."

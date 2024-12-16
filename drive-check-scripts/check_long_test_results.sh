#!/bin/bash

# Exclude the SSD hosting the OS (e.g., /dev/sdc)
OS_DRIVE="/dev/sdc"

# Get all drives except the OS SSD
DRIVES=$(lsblk -d -o NAME | grep -E '^sd' | grep -v $(basename $OS_DRIVE))

# Function to check the results of the latest long test
check_latest_test_results() {
    local DRIVE=$1

    # Get the smartctl output
    SMARTCTL_OUTPUT=$(sudo smartctl -l selftest /dev/$DRIVE)

    # Check if there are any test results
    if echo "$SMARTCTL_OUTPUT" | grep -q "Num  Test_Description"; then
        # Extract the latest test results (first entry after the header)
        LATEST_TEST=$(echo "$SMARTCTL_OUTPUT" | grep -A1 "Num  Test_Description" | tail -n 1)

        # Parse the test status and completion time
        TEST_STATUS=$(echo "$LATEST_TEST" | awk '{print $4}') # Status (e.g., "Completed", "Aborted")
        TEST_COMPLETION_TIME=$(echo "$LATEST_TEST" | awk '{print $1" "$2" "$3}') # Completion date and time
        PERCENT_REMAINING=$(echo "$LATEST_TEST" | awk '{print $5}') # If the test is ongoing, this field may show "% remaining"

        if [[ "$TEST_STATUS" == "Completed" ]]; then
            echo "Long self-test for /dev/$DRIVE completed successfully."
            echo "Completion date and time: $TEST_COMPLETION_TIME"
        elif [[ "$TEST_STATUS" == "Self-test" ]] && [[ "$PERCENT_REMAINING" =~ ([0-9]+)% ]]; then
            REMAINING_PERCENT=${BASH_REMATCH[1]}
            echo "Self-test is still in progress on /dev/$DRIVE."
            echo "$REMAINING_PERCENT% of the test remains to complete."
        else
            echo "Test status for /dev/$DRIVE: $TEST_STATUS"
        fi
    else
        echo "No self-test results found for /dev/$DRIVE."
    fi
}

# Check the test results for each drive
for DRIVE in $DRIVES; do
    echo "Checking the latest long test results for /dev/$DRIVE..."
    check_latest_test_results $DRIVE
    echo "---------------------------------------"
done

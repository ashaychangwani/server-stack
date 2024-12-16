#!/bin/bash

# Exclude the SSD hosting the OS (e.g., /dev/sdc)
OS_DRIVE="/dev/sdc"

# Get all drives except the OS SSD
DRIVES=$(lsblk -d -o NAME | grep -E '^sd' | grep -v $(basename $OS_DRIVE))

# Run a short self-test on all drives
for DRIVE in $DRIVES; do
    echo "Checking if a self-test is already running for /dev/$DRIVE..."
    
    # Check if SMART is enabled
    SMART_ENABLED=$(sudo smartctl -i /dev/$DRIVE | grep -i "SMART support is:" | grep -i "Enabled")
    if [ -z "$SMART_ENABLED" ]; then
        echo "SMART is not enabled for /dev/$DRIVE. Enabling SMART..."
        sudo smartctl -s on /dev/$DRIVE
    fi

    # Check if a self-test is already in progress
    TEST_RUNNING=$(sudo smartctl -c /dev/$DRIVE | grep -i "Self-test execution status" | grep -oE '[0-9]+% remaining')
    if [ -n "$TEST_RUNNING" ]; then
        echo "A self-test is already in progress for /dev/$DRIVE. Skipping..."
        echo "Status: $TEST_RUNNING"
        echo "---------------------------------------"
        continue
    fi

    # Start a new short self-test
    echo "Starting short self-test for /dev/$DRIVE..."
    sudo smartctl -t short /dev/$DRIVE
    echo "Short self-test started on /dev/$DRIVE. Waiting for completion..."

    # Wait for the test to complete (poll every 10 seconds)
    while true; do
        STATUS=$(sudo smartctl -c /dev/$DRIVE | grep -i "Self-test execution status")
        if [[ "$STATUS" == *"Completed"* ]]; then
            echo "Short self-test for /dev/$DRIVE completed."
            break
        elif [[ "$STATUS" == *"Remaining"* ]]; then
            REMAINING=$(echo "$STATUS" | grep -oE '[0-9]+% remaining')
            echo "Test is still running for /dev/$DRIVE: $REMAINING remaining."
        else
            echo "No detailed status available for /dev/$DRIVE. Proceeding to check results."
            break
        fi
        sleep 10
    done

    # Retrieve and display the self-test results
    echo "Checking self-test results for /dev/$DRIVE..."
    sudo smartctl -l selftest /dev/$DRIVE
    echo "---------------------------------------"
done

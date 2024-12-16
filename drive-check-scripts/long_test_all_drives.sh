#!/bin/bash

# Exclude the SSD hosting the OS (e.g., /dev/sdc)
OS_DRIVE="/dev/sdc"

# Get all drives except the OS SSD
DRIVES=$(lsblk -d -o NAME | grep -E '^sd' | grep -v $(basename $OS_DRIVE))

# Create an associative array to track completed drives
declare -A COMPLETED_DRIVES

# Function to check if a long test is already running
function is_test_running {
    local DRIVE=$1
    sudo smartctl -c /dev/$DRIVE | grep -i "Self-test execution status" | grep -q "in progress"
    return $? # Returns 0 if running, 1 otherwise
}

# Function to calculate and display the estimated end time
function display_estimated_end_time {
    local DRIVE=$1
    STATUS_OUTPUT=$(sudo smartctl -c /dev/$DRIVE)
    
    # Extract the "Self-test execution status" line
    TEST_STATUS=$(echo "$STATUS_OUTPUT" | grep -i "Self-test execution status")

    # Extract the "Extended self-test routine recommended polling time" (in minutes)
    POLLING_TIME=$(echo "$STATUS_OUTPUT" | grep -i "Extended self-test routine recommended polling time" | awk '{print $5}')

    # Check if TEST_STATUS contains the remaining percentage
    if [[ "$TEST_STATUS" =~ ([0-9]+)%\s*of\s*test\s*remaining ]]; then
        REMAINING_PERCENT=${BASH_REMATCH[1]}
        # Calculate remaining time in minutes based on the polling time
        REMAINING_MINUTES=$(((POLLING_TIME * REMAINING_PERCENT) / 100))
        ESTIMATED_END=$(date -d "+$REMAINING_MINUTES minutes" +"%Y-%m-%d %H:%M:%S")
        echo "Self-test is $((100 - REMAINING_PERCENT))% complete on /dev/$DRIVE."
        echo "Estimated completion time: $ESTIMATED_END"
    elif [[ "$TEST_STATUS" =~ ([0-9]+)\s*minutes\s*remaining ]]; then
        # Extract remaining time directly if reported in minutes
        REMAINING_MINUTES=${BASH_REMATCH[1]}
        ESTIMATED_END=$(date -d "+$REMAINING_MINUTES minutes" +"%Y-%m-%d %H:%M:%S")
        echo "Self-test is in progress on /dev/$DRIVE."
        echo "Estimated completion time: $ESTIMATED_END"
    else
        echo "Unable to determine the estimated completion time for /dev/$DRIVE."
        echo "Self-test status: $TEST_STATUS"
    fi
}
# Start long tests on all drives
for DRIVE in $DRIVES; do
    echo "Checking if SMART is enabled for /dev/$DRIVE..."
    if ! sudo smartctl -i /dev/$DRIVE | grep -q "SMART support is: Enabled"; then
        echo "SMART is not enabled for /dev/$DRIVE. Enabling SMART..."
        sudo smartctl -s on /dev/$DRIVE
    fi

    echo "Checking if a long test is already running for /dev/$DRIVE..."
    if is_test_running $DRIVE; then
        echo "A long test is already running on /dev/$DRIVE. Skipping initiation..."
        display_estimated_end_time $DRIVE
        COMPLETED_DRIVES[$DRIVE]=false # Mark as not completed but already running
    else
        echo "Starting long self-test for /dev/$DRIVE..."
        sudo smartctl -t long /dev/$DRIVE
        COMPLETED_DRIVES[$DRIVE]=false # Mark as not completed yet
    fi
    echo "---------------------------------------"
done

# Poll the drives until all tests are completed
echo "Polling drives to check the status of long self-tests..."
while true; do
    ALL_COMPLETED=true
    for DRIVE in $DRIVES; do
        if [ "${COMPLETED_DRIVES[$DRIVE]}" = false ]; then
            echo "Checking the status of /dev/$DRIVE..."
            STATUS=$(sudo smartctl -c /dev/$DRIVE | grep -i "Self-test execution status")
            if [[ "$STATUS" == *"Completed"* ]]; then
                echo "Long self-test for /dev/$DRIVE has completed."
                COMPLETED_DRIVES[$DRIVE]=true
            elif [[ "$STATUS" == *"in progress"* ]]; then
                echo "Long self-test is still running on /dev/$DRIVE."
                display_estimated_end_time $DRIVE
                ALL_COMPLETED=false
            else
                echo "Unable to determine test status for /dev/$DRIVE."
            fi
        fi
    done

    # Break the loop if all drives are done
    if $ALL_COMPLETED; then
        echo "All long self-tests have been completed."
        break
    fi

    # Wait for a bit before polling again
    echo "Waiting for 60 seconds before polling again..."
    sleep 60
done

echo "All drives' long self-tests completed. Exiting."

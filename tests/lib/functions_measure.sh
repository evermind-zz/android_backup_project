function measureStart() {
    START=$(date +%s.%N)
}
function measureEnd() {
    END=$(date +%s.%N)
}

function measureResult() {
    local what=$1
    DIFF=$(echo "$END - $START" | bc)
    echo "$what took $DIFF seconds"
}

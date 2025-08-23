#!/bin/bash
set -euo pipefail

echo "🧠 Starting memory-efficient test execution..."

# Function to run tests with memory monitoring
run_test_chunk() {
    local filter="$1"
    local chunk_name="$2"
    
    echo "📊 Running test chunk: $chunk_name"
    echo "🧠 Memory before chunk:"
    free -h
    
    # Set aggressive memory limits for each chunk
    ulimit -d 1048576  # 1GB data segment limit per test chunk
    ulimit -m 1048576  # 1GB physical memory limit per test chunk
    ulimit -v 2097152  # 2GB virtual memory limit per test chunk
    
    # Run the test chunk with aggressive memory management
    timeout 600 swift test --filter "$filter" --no-parallel --jobs 1 || {
        echo "❌ Test chunk $chunk_name failed or timed out"
        echo "🧠 Memory after failed chunk:"
        free -h
        return 1
    }
    
    echo "✅ Test chunk $chunk_name completed successfully"
    echo "🧠 Memory after chunk:"
    free -h
    
    # Force garbage collection between chunks
    sleep 2
}

# Define test chunks to reduce memory pressure
echo "🔍 Starting test chunks..."

# Run small, focused test groups to minimize memory usage
echo "📦 Running utility tests..."
run_test_chunk "WayneTests|StandardsTests|ConciergeTests|MiseEnPlaceTests|RebelAITests" "Utilities"

echo "📦 Running infrastructure tests..."  
run_test_chunk "VegasTests|HolidayTests" "Infrastructure"

echo "📦 Running core model tests..."
run_test_chunk "PaletteTests" "Database"

echo "📦 Running business logic tests..."
run_test_chunk "DaliTests" "Business Logic"

echo "✅ All test chunks completed successfully!"
echo "🧠 Final memory status:"
free -h
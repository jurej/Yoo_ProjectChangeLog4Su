#!/bin/bash
# Script to check the release against SketchUp Extension Warehouse requirements
# using rubocop-sketchup

echo "Installing rubocop and rubocop-sketchup..."
gem install rubocop rubocop-sketchup

echo ""
echo "Running RuboCop with SketchUp requirements..."
rubocop --format simple

echo ""
echo "Generating Extension Review report..."
rubocop -f extension_review -o report.html

echo ""
echo "Check complete! Review the output above and see report.html for detailed Extension Warehouse requirements."

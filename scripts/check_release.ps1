# Script to check the release against SketchUp Extension Warehouse requirements
# using rubocop-sketchup

Write-Host "Installing rubocop and rubocop-sketchup..." -ForegroundColor Cyan
gem install rubocop rubocop-sketchup

Write-Host ""
Write-Host "Running RuboCop with SketchUp requirements..." -ForegroundColor Cyan
rubocop --format simple

Write-Host ""
Write-Host "Generating Extension Review report..." -ForegroundColor Cyan
rubocop -f extension_review -o report.html

Write-Host ""
Write-Host "Check complete! Review the output above and see report.html for detailed Extension Warehouse requirements." -ForegroundColor Green

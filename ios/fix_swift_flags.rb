#!/usr/bin/env ruby

# This script removes the -G flag from all xcconfig files
# which is causing a build error in newer Xcode versions

Dir.glob("Pods/Target Support Files/**/*.xcconfig").each do |file_path|
  puts "Processing #{file_path}..."
  
  # Read the file content
  content = File.read(file_path)
  
  # Replace -G flag but preserve other flags
  modified_content = content.gsub(/(\bOTHER_SWIFT_FLAGS\s*=\s*[^;]*)(?:-G\b)([^;]*)/, '\1\2')
  
  # Write back to file if changes were made
  if content != modified_content
    File.write(file_path, modified_content)
    puts "  Modified #{file_path}"
  else
    puts "  No changes needed for #{file_path}"
  end
end

puts "Completed processing xcconfig files" 
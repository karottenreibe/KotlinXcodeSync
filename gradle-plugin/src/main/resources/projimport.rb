require 'xcodeproj'

project_file = ARGV[0]
targetName = ARGV[1]
groupName = ARGV[2]
importPath = ARGV[3]

project = Xcodeproj::Project.open(project_file)

target = project.targets.find {|target| target.name == targetName}

if target == nil
  puts "target #{targetName} not found"
  exit(false)
end

kot_group = nil
kot_group = project.groups.find do |group|
  group.name == groupName
end

if kot_group == nil
  kot_group = project.new_group(groupName)
end

group_index = {}

def walkGroups (group_index, pathBase, groups)
  groups.each do |group|
    if group.name != nil
      groupPathName = pathBase + '/' + group.name
      group_index[groupPathName] = group
      walkGroups(group_index, groupPathName, group.groups)
    end
  end
end

walkGroups(group_index, "", kot_group.groups)

files = target.source_build_phase.files.to_a.map do |pbx_build_file|
	pbx_build_file.file_ref.real_path.to_s

end.select do |path|
  path.end_with?(".kt")

end.select do |path|
  puts "Adding #{path}"
  File.exists?(path)
end

def addfiles (existingFiles, group_index, direc, pathBase, current_group, main_target)
    Dir.glob(direc) do |item|
        next if item == '.' or item == '.DS_Store'
        new_folder = File.basename(item)

        if File.directory?(item)

          groupPathName = pathBase + '/' + new_folder
          foundGroup = group_index[groupPathName]
          if foundGroup == nil
            foundGroup = current_group.new_group(new_folder)
            group_index[groupPathName] = foundGroup
            puts "creating #{groupPathName}"
          else
            puts "exiting #{groupPathName}"
          end
          addfiles(existingFiles, group_index, "#{item}/*", groupPathName, foundGroup, main_target)
        else

          if item.end_with? ".kt"
            projectPath = "#{pathBase}/#{new_folder}"
            fileFound = existingFiles.any? { |path|
              path.end_with? projectPath
            }
            if fileFound
              puts "File #{projectPath} exists"
            else
              puts "File #{projectPath} created"
                i = current_group.new_file(item)
                main_target.add_file_references([i], '-w')
            end
          end
        end
    end
end

main_target = project.targets.first

addfiles(files, group_index, "#{importPath}/*", "", kot_group, main_target)

project.save(project_file)
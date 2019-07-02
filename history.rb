path = "/home/ec2-user/environment/rb175/cms/data/test.md"

def next_version_file_path(path, history_path = "history")
  filename = File.basename(path, ".*")
  extension = File.extname(path)
  directory = File.dirname(path)
  
  versions = Dir.glob(File.join(directory, history_path, "#{filename}_v*#{extension}"))
  next_version_num = if versions.empty?
                       "000"
                     else
                       latest_version = File.basename(versions.max, ".*")
                       sprintf("%03d", latest_version[-3..-1].to_i + 1)
                     end
  name = File.join(history_path, filename + "_v" + next_version_num + extension)
  File.join(directory, name)
end 

p next_version_file_path(path)
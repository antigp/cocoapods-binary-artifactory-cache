module PodPrebuild
  module ZipUtils
    def self.zip(path, to_dir: nil, name: nil)
      basename = File.basename(path)
      toname = name.nil? ? basename : name
      unless to_dir.nil? 
        FileUtils.mkdir_p(to_dir)
      end
      
      out_path = to_dir.nil? ? "#{toname}.zip" : "#{to_dir}/#{toname}.zip"
      cmd = []
      cmd << "cd" << File.dirname(path)
      cmd << "&& zip -r --symlinks" << out_path << basename
      cmd << "&& cd -"
      `#{cmd.join(" ")}`
    end

    def self.unzip(path, to_dir: nil)
      cmd = []
      cmd << "unzip -nq" << path
      cmd << "-d" << to_dir unless to_dir.nil?
      `#{cmd.join(" ")}`
    end
  end
end

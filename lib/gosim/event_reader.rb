module GoSim
  class EventReader
    def initialize(filename)
       @trace = Zlib::GzipReader.open(filename)
       @trace.readline
    end

    def next
      return nil  if @trace.eof?
  
      yaml_str = "---\n"

      while(true && !@trace.eof?)
        line = @trace.readline
        break if line =~ /---/
        yaml_str += line
      end 

      return YAML::load(yaml_str)
    end

    def eof?
      return @trace.eof?
    end
  end
end

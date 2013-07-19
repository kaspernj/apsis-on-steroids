class ApsisOnSteroids::SubBase
  def initialize(args)
    @args = args
    
    @data = {}
    @args[:data].each do |key, val|
      @data[StringCases.camel_to_snake(key).to_sym] = val
    end
  end
  
  def aos
    return @args[:aos]
  end
  
  def data(name)
    name = name.to_sym
    return @data[name] if @data.key?(name)
    raise "No such data: '#{name}' in fields: #{@data.keys}"
  end
  
  def debugs(str)
    self.aos.debugs(str)
  end
end

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
    raise "No such data: '#{name}'."
  end
  
  def method_missing(name)
    return @data[name.to_sym] if @data && @data.key?(name.to_sym)
    raise "No such method: '#{name}'."
  end
end
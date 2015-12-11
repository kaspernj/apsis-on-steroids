class ApsisOnSteroids::SubBase
  def initialize(args)
    @args = args

    @data = {}
    @args.fetch(:data).each do |key, val|
      @data[StringCases.camel_to_snake(key).to_sym] = val
    end

    @data = aos.parse_obj(@data)
  end

  def aos
    @args.fetch(:aos)
  end

  def data(name)
    name = name.to_sym
    return @data[name] if @data.key?(name)
    raise "No such data: '#{name}' in fields: #{@data.keys}"
  end

  def data_hash
    @data
  end

  def debugs(str)
    aos.debugs(str)
  end
end

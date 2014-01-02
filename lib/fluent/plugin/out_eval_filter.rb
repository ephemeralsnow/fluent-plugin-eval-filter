class Fluent::EvalFilterOutput < Fluent::Output

  Fluent::Plugin.register_output('eval_filter', self)

  def configure(conf)
    super

    if remove_tag_prefix = conf['remove_tag_prefix']
      @remove_tag_prefix = /^#{Regexp.escape(remove_tag_prefix)}\.*/
    end
    if remove_tag_suffix = conf['remove_tag_suffix']
      @remove_tag_suffix = /\.*#{Regexp.escape(remove_tag_suffix)}$/
    end
    @add_tag_prefix = conf['add_tag_prefix']
    @add_tag_suffix = conf['add_tag_suffix']

    conf.keys.select { |key| key =~ /^config\d+$/ }.sort_by { |key| key.sub('config', '').to_i }.each do |key|
      begin
        instance_eval("#{conf[key]}")
      rescue Exception => e
        raise Fluent::ConfigError, "#{key} #{conf[key]}\n" + e.to_s
      end
    end

    @filters = []
    conf.keys.select { |key| key =~ /^filter\d+$/ }.sort_by { |key| key.sub('filter', '').to_i }.each do |key|
      begin
        @filters << instance_eval("lambda do |tag, time, record| #{conf[key]} end")
      rescue Exception => e
        raise Fluent::ConfigError, "#{key} #{conf[key]}\n" + e.to_s
      end
    end

    if @filters.empty?
      raise Fluent::ConfigError, "missing filters"
    end
  end

  def emit(tag, es, chain)
    tag = handle_tag(tag)
    es.each do |time, record|
      result = filter_record(tag, time, record)
      Fluent::Engine.emit(*result) if result
    end
    chain.next
  end

  def handle_tag(tag)
    tag.sub!(@remove_tag_prefix, '') if @remove_tag_prefix
    tag.sub!(@remove_tag_suffix, '') if @remove_tag_suffix
    tag.sub!(/^\.*/, "#{@add_tag_prefix}.") if @add_tag_prefix
    tag.sub!(/\.*$/, ".#{@add_tag_suffix}") if @add_tag_suffix
    tag
  end

  def filter_record(tag, time, record)
    @filters.each do |filter|
      filter_result = filter.call(tag, time, record)
      result = create_result(tag, time, record, filter_result) if filter_result
      return result if result
    end
    nil
  end

  def create_result(tag, time, record, result)
    result = [result] unless result.is_a?(Array)

    result.each do |value|
      tag = value if value.is_a?(String)
      time = value if value.is_a?(Integer)
      record = value if value.is_a?(Hash)
    end

    [tag, time, record]
  end

end

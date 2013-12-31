class Fluent::EvalFilterOutput < Fluent::Output
  include Fluent::HandleTagNameMixin

  Fluent::Plugin.register_output('eval_filter', self)

  def configure(conf)
    super

    conf.keys.select { |key| key =~ /^config\d+$/ }.sort_by { |key| key.sub('config', '').to_i }.each do |key|
      instance_eval("#{conf[key]}")
    end

    @filters = []
    conf.keys.select { |key| key =~ /^filter\d+$/ }.sort_by { |key| key.sub('filter', '').to_i }.each do |key|
      @filters << instance_eval("lambda do |tag, time, record| #{conf[key]} end")
    end
  end

  def emit(tag, es, chain)
    es.each do |time, record|
      result = filter_record(tag.clone, time, record)
      Fluent::Engine.emit(*result) if result
    end
    chain.next
  end

  def filter_record(tag, time, record)
    super

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

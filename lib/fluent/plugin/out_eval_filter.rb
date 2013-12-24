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
    if result.is_a?(String)
      [result, time, record]
    elsif result.is_a?(Integer)
      [tag, result, record]
    elsif result.is_a?(Hash)
      [tag, time, result]
    elsif result.is_a?(Array)
      if result.size == 1
        if result[0].is_a?(String)
          [result[0], time, record]
        elsif result[0].is_a?(Integer)
          [tag, result[0], record]
        elsif result[0].is_a?(Hash)
          [tag, time, record[0]]
        end
      elsif result.size == 2
        if result[0].is_a?(String) && result[1].is_a?(Integer)
          [result[0], result[1], record]
        elsif result[0].is_a?(String) && result[1].is_a?(Hash)
          [result[0], time, result[1]]
        elsif result[0].is_a?(Integer) && result[1].is_a?(Hash)
          [tag, result[0], result[1]]
        end
      elsif result.size == 3 && result[0].is_a?(String) && result[1].is_a?(Integer) && result[2].is_a?(Hash)
        [result[0], result[1], result[2]]
      end
    end
  end

end

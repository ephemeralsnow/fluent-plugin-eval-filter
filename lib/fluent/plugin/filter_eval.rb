module Fluent
  class EvalFilter < Filter
    Fluent::Plugin.register_filter('eval', self)

    def initialize
      super
    end

    def configure(conf)
      super

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

    def filter_stream(tag, es)
      new_es = MultiEventStream.new
      es.each { |time, record|
        begin
          filtered_record = filter_record(tag, time, record)
          new_es.add(*filtered_record) if filtered_record
        rescue => e
          router.emit_error_event(tag, time, record, e)
        end
      }
      new_es
    end

    private
    def filter_record(tag, time, record)
      @filters.each do |filter|
        filter_results = filter.call(tag, time, record)
        return filter_results if filter_results
      end
      nil
    end
  end
end

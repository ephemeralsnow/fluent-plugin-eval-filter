require 'fluent/plugin/filter'

module Fluent::Plugin
  class EvalFilter < Filter
    Fluent::Plugin.register_filter('eval', self)

    config_param :requires, :array, default: [], :desc => "require libraries."
    config_section :filter, param_name: :filter_config, multi: true do
      config_param :filter, :string
      config_param :config, :string, default: ""
    end

    def initialize
      super
    end

    def configure(conf)
      super

      if @requires
        @requires.each do |lib|
          begin
            require lib
          rescue Exception => e
            raise Fluent::ConfigError, "\n#{e.message}\n#{e.backtrace.join("\n")}"
          end
        end
      end

      @filter_config.each do |conf|
        begin
          instance_eval("#{conf.config}")
        rescue Exception => e
          raise Fluent::ConfigError, "#{key} #{conf.config}\n" + e.to_s
        end
      end

      @filters = []
      @filter_config.each do |conf|
        begin
          @filters << instance_eval("lambda do |tag, time, record| #{conf.filter} end")
        rescue Exception => e
          raise Fluent::ConfigError, "#{key} #{conf.filter}\n" + e.to_s
        end
      end

      if @filters.empty?
        raise Fluent::ConfigError, "missing filters"
      end
    end

    def filter(tag, time, record)
      begin
        @filters.each do |filter|
          filter_results = filter.call(tag, time, record)
          return filter_results if filter_results
        end
        nil
      rescue => e
        router.emit_error_event(tag, time, record, e)
      end
    end
  end
end

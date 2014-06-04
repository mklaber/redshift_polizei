module Reports
  class Base  
    include ActiveModel::Validations
    include ActiveModel::Conversion
    include ActiveRecord::Sanitization
    extend ActiveModel::Naming
  
    def self.connection
      ActiveRecord::Base.connection
    end
    

    def self.attr_accessor(*vars)
      @attributes ||= []
      @attributes.concat( vars )
      super
    end

    def self.attributes
      @attributes
    end

    def initialize(attributes={})
      attributes && attributes.each do |name, value|
        send("#{name}=", value) if respond_to? name.to_sym 
      end
    end

    def persisted?
      false
    end

    def self.inspect
      "#<#{ self.to_s} #{ self.attributes.collect{ |e| ":#{ e }" }.join(', ') }>"
    end
  
    def self.sanitize(a)
      ActiveRecord::Base.__send__(:sanitize_sql_for_conditions, a, '')
    end

    def self.filter(options, white_list=[])
      # Allow everything for now
      # return options.reject{|k,v| !white_list.include?(k) }.merge(result)
      return options
    end

  end
end
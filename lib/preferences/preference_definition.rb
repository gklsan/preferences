class ActiveRecord::ConnectionAdapters::Column
  def type_cast_from_database(value)
    return nil if value.nil?
    case type
    when :string    then value
    when :text      then value
    when :integer   then value.to_i rescue value ? 1 : 0
    when :float     then value.to_f
    when :decimal   then self.class.value_to_decimal(value)
    when :datetime  then self.class.string_to_time(value)
    when :timestamp then self.class.string_to_time(value)
    when :time      then self.class.string_to_dummy_time(value)
    when :date      then self.class.string_to_date(value)
    when :binary    then self.class.binary_to_string(value)
    when :boolean   then self.class.value_to_boolean(value)
    else value
    end
  end
end

module Preferences
  # Represents the definition of a preference for a particular model
  class PreferenceDefinition
    # The data type for the content stored in this preference type
    attr_reader :type
    
    def initialize(name, *args) #:nodoc:
      options = args.extract_options!
      options.assert_valid_keys(:default, :group_defaults)
      
      @type = args.first ? args.first.to_sym : :boolean
      
      # Create a column that will be responsible for typecasting
      #cast_type = ActiveRecord::Base.connection.lookup_cast_type(@type)
      cast_type = ActiveRecord::Type::Value.new
      @column = ActiveRecord::ConnectionAdapters::Column.new(name.to_s, options[:default], cast_type)

      @group_defaults = (options[:group_defaults] || {}).inject({}) do |defaults, (group, default)|
        defaults[group.is_a?(Symbol) ? group.to_s : group] = type_cast(default)
        defaults
      end
    end
    
    # The name of the preference
    def name
      @column.name
    end
    
    # The default value to use for the preference in case none have been
    # previously defined
    def default_value(group = nil)
      @group_defaults.include?(group) ? @group_defaults[group] : @column.default
    end
    
    # Determines whether column backing this preference stores numberic values
    def number?
      @column.number?
    end
    
    # Typecasts the value based on the type of preference that was defined.
    # This uses ActiveRecord's typecast functionality so the same rules for
    # typecasting a model's columns apply here.
    def type_cast(value)
      @column.type_cast_from_database(value)
    end

    def type_cast_from_database(value)
      @column.type_cast_from_database(value)
    end
    
    # Typecasts the value to true/false depending on the type of preference
    def query(value)
      if !(value = type_cast(value))
        false
      elsif number?
        !value.zero?
      else
        !value.blank?
      end
    end
  end
end

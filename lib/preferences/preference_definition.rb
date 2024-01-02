class ActiveRecord::ConnectionAdapters::Column
  def number?
    type == :integer || type == :float || type == :decimal
  end

  def self.lookup_cast_type(type)
    case type
    when :string    then ActiveRecord::Type::String
    when :text      then ActiveRecord::Type::Text
    when :integer   then ActiveRecord::Type::Integer
    when :float     then ActiveRecord::Type::Float
    when :decimal   then ActiveRecord::Type::Decimal
    when :datetime  then ActiveRecord::Type::DateTime
    when :timestamp then ActiveRecord::Type::TimeValue
    when :time      then ActiveRecord::Type::Time
    when :date      then ActiveRecord::Type::Date
    when :binary    then ActiveRecord::Type::Binary
    when :boolean   then ActiveRecord::Type::Boolean
    else ActiveRecord::Type::Value
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
      @cast_type = ActiveRecord::ConnectionAdapters::Column.lookup_cast_type(@type).new
      sql_type_metadata = ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(
        sql_type: @cast_type.type.to_s,
        type: @cast_type.type,
        limit: @cast_type.limit,
        precision: @cast_type.precision,
        scale: @cast_type.scale
      )
      default = if @type == :boolean
                  options[:default] ? 1 : 0
                else
                  options[:default].is_a?(Symbol) ? options[:default].to_s : options[:default]
                end
      @column = ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type_metadata)

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
      @cast_type.cast(value)
    end

    def type_cast_from_database(value)
      @cast_type.cast(value)
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

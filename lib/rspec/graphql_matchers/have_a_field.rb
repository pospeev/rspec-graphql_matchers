require_relative 'base_matcher'

module RSpec
  module GraphqlMatchers
    class HaveAField < BaseMatcher
      DESCRIPTIONS = {
        type: 'of type `%s`',
        property: 'reading from the `%s` property',
        hash_key: 'reading from the `%s` hash_key',
        metadata: 'with metadata `%s`',
        resolver: 'with resolver `%s`',
        mutation: 'with mutation `%s`',
        arguments: 'with arguments `%s`',
        authorize: 'with authorization',
      }.freeze

      def initialize(expected_field_name, fields = :fields)
        @expected_field_name = camelize(expected_field_name.to_s)
        @fields = fields.to_sym
        @expectations = []
        @descriptions = []
      end

      def matches?(graph_object)
        @graph_object = graph_object

        @actual_field = field_collection[@expected_field_name]
        return false if @actual_field.nil?

        @results = @expectations.map do |expectaiton|
          name, expected_value = expectaiton
          [name, expectation_matches?(name, expected_value)]
        end.to_h
        @results.values.all?
      end

      def that_returns(expected_field_type)
        @expectations << [:type, expected_field_type]
        self
      end
      alias returning that_returns
      alias of_type that_returns

      def with_mutation(expected_mutation_class)
        @expectations << [:mutation, expected_mutation_class]
        self
      end

      def with_args(*expected_arguments_name)
        @expectations << [:arguments, expected_arguments_name]
        self
      end

      def with_authorization
        @expectations << [:authorize, true]
        self
      end

      def with_property(expected_property_name)
        @expectations << [:property, expected_property_name]
        self
      end

      def with_hash_key(expected_hash_key)
        @expectations << [:hash_key, expected_hash_key]
        self
      end

      def with_metadata(expected_metadata)
        @expectations << [:metadata, expected_metadata]
        self
      end

      def with_resolver(expected_resolver_name)
        @expectations << [:resolver, expected_resolver_name]
        self
      end

      def failure_message
        "expected #{describe_obj(@graph_object)} to " \
          "#{description}, #{explanation}."
      end

      def description
        ["define field `#{@expected_field_name}`"]
          .concat(descriptions).join(', ')
      end

      private

      def arguments_matcher(expected_value)
        @actual_field.arguments.keys.map(&:to_sym) == expected_value
      end

      def authorize_matcher(expected_value)
        @actual_field.instance_variable_get(:@authorize) == expected_value
      end

      def descriptions
        @expectations.map do |expectation|
          name, expected_value = expectation
          format(DESCRIPTIONS[name], expected_value)
        end
      end

      def explanation
        return 'but no field was found with that name' unless @actual_field
        @results.each do |result|
          name, match = result
          next if match
          return format('but the %s was `%s`', name, actual_field_value(name))
        end
      end

      def expectation_matches?(name, expected_value)
        ensure_method_exists!(name)
        if expected_value.is_a?(Hash)
          @actual_field.send(name) == expected_value
        else
          if respond_to?("#{name}_matcher", true)
            send("#{name}_matcher", expected_value)
          else
            actual_field_value(name) == expected_value.to_s
          end
        end
      end

      def actual_field_value(name)
        actual = @actual_field.send(name)
        begin
          ret = (actual.to_graphql if actual.respond_to?(:to_graphql)).to_s
          ret.empty? ? actual.to_s : ret
        rescue NotImplementedError
          actual.to_s
        end
      end

      def ensure_method_exists!(method_name)
        return if @actual_field.respond_to?(method_name)
        raise(
          "The `#{@expected_field_name}` field defined by the GraphQL object " \
          "does\'t seem valid as it does not respond to ##{method_name}. " \
          "\n\n\tThe field found was #{@actual_field.inspect}. "
        )
      end

      def describe_obj(field)
        field.respond_to?(:name) && field.name || field.inspect
      end

      def field_collection
        if @graph_object.respond_to?(@fields)
          @graph_object.public_send(@fields)
        else
          raise "Invalid object #{@graph_object} provided to #{matcher_name} " \
            'matcher. It does not seem to be a valid GraphQL object type.'
        end
      end

      def matcher_name
        case @fields
        when :fields        then 'have_a_field'
        when :input_fields  then 'have_an_input_field'
        when :return_fields then 'have_a_return_field'
        end
      end
    end
  end
end

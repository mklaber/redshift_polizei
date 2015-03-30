module Jobs
  module Permissions
    #
    # base class for permissions jobs to share some code
    #
    class Base < BaseReport
      def self.make_boolean(results)
        return results.hmap { |key, value| self.make_boolean(value) } if results.is_a?(Hash)

        keys = ['has_select', 'has_delete', 'has_update', 'has_references', 'has_insert']
        results.each do |result|
          keys.each do |key|
            if result.has_key?(key) && result[key] == "t"
              result[key] = true
            else
              result[key] = false
            end
          end
        end
      end
    end
  end
end

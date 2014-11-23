class Object
  def present?
    !blank?
  end
  
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  def self.descendants
    ObjectSpace.each_object(Class).select { |klass| klass < self }
  end
end

# reverting monkey patches of octopus gem, which makes migrations run on all shards
ActiveRecord::Migrator.class_eval do
  class << self
    alias_method :migrate, :migrate_without_octopus if method_defined?(:migrate_without_octopus)
    alias_method :up, :up_without_octopus if method_defined?(:up_without_octopus)
    alias_method :down, :down_without_octopus if method_defined?(:down_without_octopus)
    alias_method :run, :run_without_octopus if method_defined?(:run_without_octopus)
  end

  alias_method :run, :run_without_octopus if method_defined?(:run_without_octopus)
  alias_method :migrate, :migrate_without_octopus if method_defined?(:migrate_without_octopus)
  alias_method :migrations, :migrations_without_octopus if method_defined?(:migrations_without_octopus)
end

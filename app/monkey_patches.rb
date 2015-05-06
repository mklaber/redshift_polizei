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

class String
  def to_b
    (self == '1' || self.downcase == 'true' || self.downcase == 't')
  end
end

class TrueClass
  def to_b
    self
  end
end

class FalseClass
  def to_b
    self
  end
end

class Hash
  def hmap
    result = {}
    self.each { |key, value| result[key] = yield(key, value) }
    result
  end
end

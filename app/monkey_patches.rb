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

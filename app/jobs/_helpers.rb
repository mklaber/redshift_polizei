module JobHelpers
  def exception_filtered?(message, type)
    if message =~ /password authentication failed/
      return true
    elsif type <= PG::SyntaxErrorOrAccessRuleViolation
      return true
    end
    return false
  end

  def exception_filter(e)
    exception_filtered?(e.message, e.class)
  end
end

class PTRuleStats
  
  attr_accessor :set_name, :set_type,
                :sum, :max, :min, :average,
                :rule_value_max, :rule_value_min,
                :values

  def initialize
    
    @set_name = ''
    @set_type = 'pt_rules'
    
    @sum = nil
    @max = nil
    @min = nil
    @average = nil
    
    @rule_value_max = ''
    @rule_value_min = ''

    @values = []
    
  end
  
  def test_max candidate
    
  end
  
  def test_min candidate
    
    
  end
  
  def get_average
    
    return @values.sum/@values.length
    
  end
  
  
  
end

#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.
  o = PTRuleStats
end  
class PTRuleStats
  
  attr_accessor :set_name, 
                :set_type,
                :stats,
                
                :sum, :max, :min, :average,
                :rule_value_max, :rule_value_min,
                :values

  def initialize
    
    @stats = Hash.new
    
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

  def get_corrected_stats rules

    puts "Number of corrected rules checked: #{rules.length}"

    #-------------------------------------
    #AND Rules.
    rules_AND = 0
    rules.each do |rule|
      if rule.type.include? 'AND' then
        rules_AND = rules_AND + 1
      end
    end
    @stats['rules_AND'] = rules_AND

    #or Rules.
    rules_or = 0
    rules.each do |rule|
      if rule.type.include? 'unquoted or' then
        rules_or = rules_or + 1
      end
    end
    @stats['rules_or'] = rules_or
    #-------------------------------------

    #Calculate rule set things around the correction results.
    rule_count_totals = 0.0
    rule_count_corrected_totals = 0.0
    delta = 0
    rule_max_delta  = 0.0
    rule_max_delta_30_day = 0
    rule_max_delta_30_day_corrected = 0
    rule_max_delta_value  = ''
    factor = 0
    rule_max_factor  = 0.0
    rule_max_factor_30_day = 0
    rule_max_factor_30_day_corrected = 0
    rule_max_factor_value  = ''

    rules.each do |rule|

      begin
        #Stream-wide stats.
        rule_count_totals = rule_count_totals + rule.count_30_day

        #TODO: kludge alert!
        if (rule.count_30_day_corrected == true or rule.count_30_day_corrected == false) then
          rule.count_30_day_corrected = 0.0
        end

        rule_count_corrected_totals = rule_count_corrected_totals + rule.count_30_day_corrected
    
        delta = rule.count_30_day_corrected - rule.count_30_day
        if delta > rule_max_delta then
          rule_max_delta = delta
          rule_max_delta_30_day = rule.count_30_day
          rule_max_delta_30_day_corrected = rule.count_30_day_corrected
          rule_max_delta_value = rule.value
        end
    
        factor = (rule.count_30_day_corrected/rule.count_30_day.to_f) if rule.count_30_day > 0
        if factor > rule_max_factor then
          rule_max_factor = factor
          rule_max_factor_30_day = rule.count_30_day
          rule_max_factor_30_day_corrected = rule.count_30_day_corrected
          rule_max_factor_value = rule.value
        end
  
        if @verbose then
          puts
          puts rule.value
          puts rule.value_corrected
          puts "--> 30-day count --> Before: #{separate_comma(rule.count_30_day)} | After: #{separate_comma(rule.count_30_day_corrected)}"
          puts "                     Delta: #{separate_comma(rule.count_30_day_corrected - rule.count_30_day)} | Factor: #{'%.1f' % (rule.count_30_day_corrected/(rule.count_30_day * 1.0))}" if rule.count_30_day > 0
        end
          
      rescue
        puts 'Something went wrong.'
        next
      end  
        
        
    end

    #Harvest this stream's rule metadata.
    @stats['rule_count_totals'] = rule_count_totals
    @stats['rule_count_corrected_totals'] = rule_count_corrected_totals
    @stats['rule_max_delta']  = rule_max_delta
    @stats['rule_max_delta_30_day'] = rule_max_delta_30_day
    @stats['rule_max_delta_30_day_corrected'] = rule_max_delta_30_day_corrected
    @stats['rule_max_delta_value']  = rule_max_delta_value
    @stats['rule_max_factor']  = rule_max_factor
    @stats['rule_max_factor_value']  = rule_max_factor_value
    @stats['rule_max_factor_30_day'] = rule_max_factor_30_day
    @stats['rule_max_factor_30_day_corrected'] = rule_max_factor_30_day_corrected
    
    @stats

  end
  
  def get_rule_stats rules
    
    @stats = {}
    
    length = 0
    total_length = 0
    max_length = 0
    rule_value_max = ''

    #Generate basic rule stats ---------------------
    rules.each do |rule|
      
      length = rule.value.length
      total_length = total_length + length

      if length > max_length then
        max_length = length
        rule_value_max = rule.value
      end

    end

    @stats['rule_count'] = rules.length
    @stats['rule_length_max'] = max_length
    @stats['rule_value_max'] = rule_value_max
    @stats['rule_length_avg'] = total_length / rules.length if rules.length > 0
  
    @stats
  
  end
  
end

#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.
  o = PTRuleStats
end  
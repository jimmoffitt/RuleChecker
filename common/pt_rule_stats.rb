class PTRuleStats
  
  attr_accessor :set_name, :set_type,
                :stats,
                
                
                :sum, :max, :min, :average,
                :rule_value_max, :rule_value_min,
                :values,


      :rule_count, :rule_AND_count,
      :rule_max, :rule_length_max, :rule_length_avg,

      #TODO: Push these down to Rule class?
      :rule_max_delta, :rule_max_delta_value, :rule_max_delta_30_day, :rule_max_delta_30_day_corrected,
      :rule_max_factor, :rule_max_factor_value, :rule_max_factor_30_day, :rule_max_factor_30_day_corrected,


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


    counts = PTStats.new
    delta = PTStats.new
    factor = PTStats.new


    #------------------------------------------------

    #Stream rule attributes.
    puts "Number of corrected rules to check: #{@pt_rules_corrected.length}"

    #-------------------------------------
    #AND Rules.
    rules_AND = 0
    @pt_rules_corrected.each do |rule|
      if rule.type.include? 'AND' then
        rules_AND = rules_AND + 1
      end
    end
    puts "Number of AND rules: #{rules_AND}"

    #or Rules.
    rules_or = 0
    @pt_rules_corrected.each do |rule|
      if rule.type.include? 'unqoted or' then
        rules_or = rules_or + 1
      end
    end

    puts "Number of lowercase 'or' rules: #{rules_or}"
    #-------------------------------------

    logger.debug "Analyzing AND rules..." if rules_AND > 0
    logger.debug "Getting 30-day counts (before and after)..." if rules_AND > 0
    logger.debug "Analyzing 'or' rules..." if rules_or > 0
    logger.debug "Getting 30-day counts (before and after)..." if rules_or > 0


    #Calculate Stream-level things around the AND-correction results.
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


    #Stream-wide stats.
    rule_count_totals = rule_count_totals + rule.count_30_day
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


    #Harvest this stream's rule metadata.
    @rule_count_totals = rule_count_totals
    @rule_count_corrected_totals = rule_count_corrected_totals
    @rule_max_delta  = rule_max_delta
    @rule_max_delta_30_day = rule_max_delta_30_day
    @rule_max_delta_30_day_corrected = rule_max_delta_30_day_corrected
    @rule_max_delta_value  = rule_max_delta_value
    @rule_max_factor  = rule_max_factor
    @rule_max_factor_value  = rule_max_factor_value
    @rule_max_factor_30_day = rule_max_factor_30_day
    @rule_max_factor_30_day_corrected = rule_max_factor_30_day_corrected

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
    @stats['rule_length_avg'] = total_length / rules.length
  
    @stats
  
  end
  
end

#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.
  o = PTRuleStats
end  
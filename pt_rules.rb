require 'logging'

#Helpers for REGEX rule scans.
REGEX_AND = /(?<!["])(AND )(?!["])/

class PTRules
  attr_accessor :rules #Array of PT Rules.

  def initialize
    @rules = []
  end

  def load_rules(rules_array)

    #Create PT Rule from JSON, add to rules array.
    rules_array.each do |pt_rule_metadata|

      rule_value = pt_rule_metadata['value']
      rule_tag = pt_rule_metadata['tag']

      if has_AND? rule_value then
        rule = PT_AND_RULE.new
      else
        rule = PTRule.new
      end

      rule.value = rule_value
      rule.tag = rule_tag

      @rules << rule
    end

    @rules
  end

  #Has explict AND?
  def has_AND? (value=nil)

      value = @value unless not value.nil?

      if REGEX_AND.match(value) then
        return true
      end

      return false
    end

end

#-----------------------------------------------------------------------------------------------------------------------
#Rule data structure. One for each rule is created. Used to store rule metadata.
class PTRule

  attr_accessor :value,
                :tag,
                :length,
                :count_30_day,
                :count_timeseries,

                :interval #Bucket size for Search API counts. --> System level unless rules need their own setting

  def initialize
    @interval = 'day'
    @count_30_day = -1 #Never discovered.
    @count_timeseries = []
  end


  def non_quoted_AND(rule)

    #Number of and/AND in rule?
    number_ands = rule.upcase.scan(/AND/).length
    #Number of double-quotes in rule?
    number_quotes = rule.scan(/"/).length

    rule.split("").each do |c|
      puts c
    end
  end

  def worksWithSearch? (value=nil)

    value = @value unless not value.nil?

    if value.include?('contains:') or value.include?('count:') then
      return false
    end

    return true
  end

  #Write report text.
  def write_output
    puts "Writing AND rule output:"
    puts "Rule 30-day counts --> :  AND: #{@count_30_day} | Corrected:  #{@count_30_day_corrected} "
  end

end

#====================================================

class PT_AND_RULE < PTRule

  attr_accessor :value_corrected,
                :count_30_day_corrected,
                :count_timeseries_corrected

  def initialize
    super
  end

  def write_output
    puts "Writing AND rule output:"
  end

end

#====================================================
class PT_Rule_Negation < PTRule
  
  attr_accessor :negation,
                :effect
  
  def initialize
    super
  end

end

#====================================================
class PT_Rule_Clause
  attr_accessor :text,
                :type,
                :inidcator
  
  def initialize
    @type = 'negation'
    @indicator = '-'
    @text = ''
  end
  
end  
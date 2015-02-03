require 'logging'

#Helper class!
#Knows how to scan and fix PowerTrack rules.
#Currently looks for and corrects these common types of bad rules:
#  Explicit ANDs.
#  Lowercase, unquoted 'or's.

class PTRules

  ##TODO: Helpers for REGEX rule scans. Not used currently.
  REGEX_AND = /(?<!["])(AND )(?!["])/
  REGEX_or = /(?<!["])(or )(?!["])/

  def load_rules(rules_array) #<- Rules API JSON array.
    
    rules = []

    #Create PT Rule from JSON, add to rules array.
    rules_array.each do |pt_rule_metadata|
      rule = PTRule.new
      rule.value = pt_rule_metadata['value']
      rule.tag = pt_rule_metadata['tag']
      rules << rule
    end

    rules
  end

  #TODO: implement full tour of non-Search API operators.
  def worksWithSearch? (value=nil)

    value = @value unless not value.nil?

    if value.include?('contains:') or value.include?('count:') or value.include?('sample:') then
      return false
    end

    return true
  end

  def unquoted_clause? rule, clause

    clauses = rule.scan(clause).count
    return false if clauses == 0

    parts = rule.split(" #{clause} ")

    quotes = 0
    quotes_total = 0

    parts.each_with_index do |part, index|

      quotes = part.scan(/"/).count
      quotes_total = quotes_total + quotes

      #Test if we are beyond the last of target clauses.
      return false if index >= clauses

      if quotes_total.even? and part != "" then  #Then we have a unquoted clause.
        return true
      end
    end

    false

  end

  #Only want to remove unquoted ANDs.
  def fix_AND_rule rule

    clauses = rule.scan(' AND ').count + rule.scan(' and ').count
    return rule if clauses == 0

    remove_AND_indices = []

    parts = rule.split(/AND|and/)\

    quotes = 0
    quotes_total = 0

    parts.each_with_index do |part, index|

      quotes = part.scan(/"/).count
      quotes_total = quotes_total + quotes

      if quotes_total.even? and index < clauses and part != "" then  #Then we have a unquoted clause.
        #This is unquoted and thus we want to remove it.
        remove_AND_indices << index
      end
    end

    #Reassemble rule, removing unquoted ANDs

    new_rule = parts[0].strip

    parts.each_with_index do |part, index|

      if index > 0 then
        if remove_AND_indices.include? index then
          new_rule = new_rule + ' ' + part.strip
        elsif index < clauses then
          new_rule = new_rule +  ' ' + part.strip + ' and'
        else
          new_rule = new_rule +  ' ' + part.strip
        end
      end
    end

    new_rule

  end

  #Finding unquoted, lowercase 'or' rules is easy.
  #Just uppercase them. Quoted 'or' that are uppercased will not effect filtering performance.
  def fix_or_rule rule
    clauses = rule.scan(' or ').count
    return rule if clauses == 0

    new_rule = ''
    new_rule = rule.gsub(' or ',' OR ')
    
    new_rule
  end

  def write_output rule
    puts "Rule value: #{rule.value}"
    #puts "Rule 30-day counts --> :  #{@count_30_day}  "
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

end

#=====================================================================
#'Explicit AND' and 'Lowercase or' rule subclass, also has metadata for corrected rule value.
#A rule object that includes attributes for 'corrections' to malformed rules.
#For example, an explicit AND rule can be of this type object, and thus have both original and corrected rule values, 
#as well as the corresponding 30-day counts/series.
class PT_RULE_Corrected < PTRule

  attr_accessor :type,
                :value_corrected,
                :count_30_day_corrected,
                :count_timeseries_corrected

  def initialize
    super
    @type = [] #'AND', 'or', 'missing_parens', possibly an array of issues.
  end

  def write_output
    
    if @type.length == 1 then 
      puts "Writing #{@type[0]} rule output:"
    else
      puts 'Writing output for rule with multiple issues:'
    end  
      
    puts "Rule 30-day counts --> :  AND: #{@count_30_day} | Corrected:  #{@count_30_day_corrected} "
   
  end

end

#====================================================
#'Negation' rule subclass, also has (single) negation and its effect.
#Special rule object used for negation analysis.
#Currently, parent code creates a 'normal' base rule, then adds
#one of these 'special' rules for each negation being analyzed,
#collects 30-day counts for all.
class PT_Negation_Test_Rule < PTRule
  
  attr_accessor :negation,
                :effect,
                :top
  
  def initialize
    super
    @negation = ''
    @effect = 0
    @top = false
  end

  def write_output
    puts "Writing Negation rule output:"
  end

end

#====================================================
#Not sure where this is going, but it is a fundamental building block of rules.
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


#-----------------------------------------------------------------------------------------------------------------------
#Rule data structure. One for each rule is created. Used to store rule metadata.
#A one-stop rule that handles correct rules, incorrect rules and their metadata,
# as well as negation and their metadata.
class PTRuleHeavy

  attr_accessor :value,
                :tag,
                :length,
                :count_30_day,
                :count_timeseries,

                #Some rules are a 'correction' to a 'flawed' rule.
                :type, #Explict AND, lower-case or, missing_parens
                :value_corrected,
                :tag_corrected,
                :count_30_day_corrected,
                :count_timeseries_corrected,

                #Some rules will be 'special' and negation analysis.
                :negation,
                :effect,
                :top

                :interval #Bucket size for Search API counts. --> System level unless rules need their own setting

  def initialize
    @interval = 'day'
    @count_30_day = -1 #Never discovered.
    @count_timeseries = []
    @count_30_day_corrected = -1
    @count_timeseries_corrected = []
    @negation = ''
    @effect = 0
    @top = false
  end

end


class RuleSetSnapshot
  
  attr_accessor :count_30_day,
                :max_factor,
                :max_effectiveness,
                :max_delta
  
  def initialize

  end
  
  
end



#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.

  o = PTRules
  
  #Unquoted explicit ANDs and ands rules -------------------------------------------------------------------------------
  r = 'these AND "this and that" AND "up and down" and "back and forth" AND "first and last"'
  #Unquoted ANDs are special because no matter what case, they are bad.
  
  #Scanning for unquoted clauses. 
  puts o.unquoted_clause? r, 'and'
  puts o.unquoted_clause? r, 'AND'
  
  #Now fix that rule.
  puts o.pt_rules.fix_AND_rule r
  
  #unquoted, lowercase 'or' rules --------------------------------------------------------------------------------------
  r = 'these OR "this or that" OR "up or down" or "back or forth" OR "first or last"'
  #ORs are special because only unquoted lowercase instances are bad.

  #Scanning for unquoted clauses. 
  puts o.pt_rules.unquoted_clause? r, 'or'

  #Now fix that rule.
  puts o.pt_rules.fix_or_rule r

  #What other common mistakes should we scan for and fix?
  puts 'done'

end
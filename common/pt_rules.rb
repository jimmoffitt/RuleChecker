require 'logging'

#Owns an array of PowerTrack rules.
#Knows how to scan and fix PowerTrack rules. 
#Currently looks for and corrects these common types of bad rules:
#  Explicit ANDs.
#  Lowercase, unquoted 'or's.


##TODO: Helpers for REGEX rule scans.
REGEX_AND = /(?<!["])(AND )(?!["])/
REGEX_or = /(?<!["])(or )(?!["])/

#Host, holder, and helper class!
class PTRules
  attr_accessor :rules #Array of PT Rules.

  def initialize
    @rules = []
  end

  def load_rules(rules_array) #<- Rules API JSON array.

    #Create PT Rule from JSON, add to rules array.
    rules_array.each do |pt_rule_metadata|
      rule = PTRule.new
      rule.value = pt_rule_metadata['value']
      rule.tag = pt_rule_metadata['tag']
      @rules << rule
    end

    @rules
  end

  def load_rulesx(rules_array)

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

  def load_rule_objects(rules_array) #<- Rules API JSON array.

    #Create PT Rule from JSON, add to rules array.
    rules_array.each do |pt_rule_metadata|

      rule = PTRule.new

      rule.value = pt_rule_metadata['value']
      rule.tag = pt_rule_metadata['tag']

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

    parts = rule.split(clause)

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

    clauses = rule.scan('AND').count + rule.scan('and').count
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

    clauses = rule.scan('or').count
    return rule if clauses == 0

    rule.gsub!('or','OR')

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
    @type = 'AND' #'or', 'missing_parens', 
  end

  def write_output
    puts "Writing #{@type} rule output:"
    puts "Rule 30-day counts --> :  AND: #{@count_30_day} | Corrected:  #{@count_30_day_corrected} "
  end

end


#=====================================================================
#Original rule type used for 'AND' rules. Once parent code is updated to use '_Corrected' objects, this can be deprecated.
#'Explicit AND' rule subclass, also has metadata for corrected rule value.
class PT_AND_RULE < PTRule

  attr_accessor :value_corrected,
                :count_30_day_corrected,
                :count_timeseries_corrected

  def initialize rule
    super
    super.value = rule.value
  end

  def write_output
    puts "Writing AND rule output:"
  end

end

#=====================================================================
#Original rule type used for 'or' rules. Once parent code is updated to use '_Corrected' objects, this can be deprecated.
#'Explicit AND' rule subclass, also has metadata for corrected rule value.
class PT_or_RULE < PTRule

  attr_accessor :value_corrected,
                :count_30_day_corrected,
                :count_timeseries_corrected

  def initialize
    super
  end

  def write_output
    puts "Writing 'or' rule output:"
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

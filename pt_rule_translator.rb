class PtRuleTranslator
  attr_accessor :source_type, 
                :target_type, #PowerTrack,
                
                #Source details
                :OR, :AND, :NOT, :Quoted, 
  
                #Target details
                :length_limit, :positive_limit, :negative_limit,
                :negation_buffer
  
  def initialize
    @source_type = 'custom'
    @target_type = 'PowerTrack'
    
    #Logical mappings of source.
    @OR = 'OR'
    @AND = 'AND'
    @Quoted = '~0'
    @NOT = 'NOT'
    
    #PowerTrack parameters.
    #Long rules.
    #@length_limit = 2048
    #@positive_limit = -1 #-1 = no limit
    #@negative_limit = -1
    #Standard rules.
    @length_limit = 1024
    @positive_limit = 30 
    @negative_limit = 50
    
    @negation_buffer = 100

  end
  
  
  #This POC code is HEAVILY based on only 2 example rules provided by Sprinklr.
  #
  #Related assumptions:
  #Both positive and negative sets of clauses are just a long list of OR clauses.
  #If any ANDs are mixed in, the logic below needs to be updated.

  def handle_AND(clause)
    "#{clause.gsub!(' AND ', ' ').strip!}"
    clause.gsub!('( ', '(')
    clause.gsub!(' )', ')')
    clause
  end
  
  def handle_quote(clause)
    clause.strip!
    "\"#{clause.gsub!(' ~0','"')}"
  end
  
  def count_clauses(clause)
    clauses_quoted = []
    clauses_unquoted = []
    clauses = 0

    parts = clause.split('"')
    
    parts.each_with_index do |part, index|
      if index.even? and !part.nil? and part != '' and part != ' ' then
        clauses_unquoted << part
      elsif index.odd? then 
        clauses_quoted << part
      end  
    end
    
    #Now look at unquoted clauses.
    clauses_unquoted.each do |part|
      part.strip!
      clauses = part.scan(/ OR /).count
      part = part.gsub!(' OR ', '') unless !part.include?(' OR ')
      clauses = clauses + part.scan(/ /).count + 1 #A space points to 2 clause, 2 spaces to 3.
    end

    clauses = clauses + clauses_quoted.length

    if clauses == 0 then
      clauses = 1
    end
    
    clauses
    
  end
  
=begin
    'absolut tune' ~0 --> ""absolut tune""
=end
  
  
  
  def translate_sprinklr(rule)
    
    #First, split rule into positive and negative sets of clauses.
    positive_or_clauses = []
    negative_or_clauses = []
    positive_or_clauses_translated = []
    negative_or_clauses_translated = []
    
    #Remove the [ ] that group positive/negative clauses.
    #TODO: the following is not ideal, since it will remove any [ ] characters actually in rule clauses.
    rule.gsub!('[', '')
    rule.gsub!(']', '')
    
    parts = rule.split('NOT')
    positive_clauses = parts[0]
    negative_clauses = parts[1]

    positive_or_clauses = positive_clauses.split('OR')
    negative_or_clauses = negative_clauses.split('OR')

    #Handle positive clauses.  
    positive_or_clauses.each do |or_clause|
      
      #'Clean' OR clause?
      if !or_clause.include? '~0' and !or_clause.include? ' AND ' then
        #puts "Clean clause: #{or_clause.strip!}"
        positive_or_clauses_translated << or_clause.strip!
        next #Move on to next one.
      end
      
      #Just a ~0 exact phrase?
      if or_clause.include? '~0' and !or_clause.include? ' AND ' then

        #Veering off into kludge land, but these rules can be kludgy...
        or_clause.gsub!('"','') if or_clause.scan(/"/).count.even?
        or_clause.gsub!("'",'') if or_clause.scan(/'/).count.even?

        #puts "Clean ~0: #{or_clause}"
        or_clause = handle_quote(or_clause)
        #puts " --> \"#{or_clause}"
        positive_or_clauses_translated << or_clause
        next
      end

      #Just a clean AND phrase?
      if !or_clause.include? '~0' and or_clause.include? ' AND ' then
        #puts "Clean AND: #{or_clause}"
        or_clause = handle_AND(or_clause)
        #puts "--> #{or_clause}"
        positive_or_clauses_translated << or_clause
        next
      end

      if or_clause.include? ' AND ' and or_clause.include? '~0' then

        #puts "Complex AND ~0 clause: #{or_clause}"
        
        #Remove parentheses, will be restored after translation.
        or_clause.gsub!('(','')
        or_clause.gsub!(')','')
        or_clause.strip!

        parts = []
        #split by ANDs and handle.
        parts = or_clause.split(' AND ')

        parts.each_with_index do |part, index|
          temp = part
          if part.include? '~0'
            temp = handle_quote( part )
          end
          parts[index] = temp
        end

        #Re-assemble AND clause, and add back into 'translated' array.
        or_clause = parts.join(' ')
        #puts "--> (#{or_clause})"
        positive_or_clauses_translated << or_clause
      end

    end
    
    puts
    puts "Have #{positive_or_clauses_translated.length} translated clauses."
    puts
    
    
    #Now assemble a set of PT rules
    
    pt_rules = []
    pt_rule_clauses = []
    pt_rule = ''
    clauses = 0
    
    #Add up to 30 positive clauses
    #May need to support a 'buffer' for holding a negation clause.
    
    positive_or_clauses_translated.each do |clause|
      
      puts "#{clause}: with #{count_clauses(clause)} clauses"
      
      number_of_clauses = count_clauses(clause)
      
      if clauses < (30 - number_of_clauses) and pt_rule.length < (@length_limit - @negative_limit - clause.length) then
        pt_rule_clauses << clause
        clauses = clauses + number_of_clauses
        pt_rule = pt_rule_clauses.join(' OR ')
      else #Reached positive clause limit.
        pt_rule_clauses << clause
        pt_rule = pt_rule_clauses.join(' OR ')
        #puts pt_rule
        pt_rules << pt_rule
        #Initialize.
        pt_rule_clauses = []
        pt_rule = ''
        clauses = 0
      end
      
    end
    
    puts
    puts "Translated #{@source_type} rule into #{pt_rules.length} PowerTrack rules: "
    puts
    
    pt_rules.each do |rule|
      puts rule
    end

  end
    
  def translate_rule(rule, source_type)
    if source_type == 'Sprinklr' then
      translate_sprinklr(rule)
    end
  end  
  
end



#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.

  rule = '[#this OR ( #that AND #what ) OR "all and nothing" NOT anytime everything ~0]'
  
  rt = PtRuleTranslator.new
  rt.translate_rule(rule, 'Sprinklr')

end

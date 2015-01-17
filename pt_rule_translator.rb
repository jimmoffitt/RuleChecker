require './pt_negationator'
require_relative './pt_rules'


class PtRuleTranslator
  attr_accessor :source_type,
                :target_type, #PowerTrack,

                :pt_rules,
                
                #Source details
                :OR, :AND, :NOT, :Quoted, 
  
                #Target details
                :length_limit, :positive_limit, :negative_limit,
                :negation_buffer #When building rules we need to reserve space for the negations... 
  
  def initialize
    @source_type = 'custom'
    @target_type = 'PowerTrack'
    
    @pt_rules = []
        
    @OR = 'OR'
    @AND = 'AND'
    @Quoted = '~0'
    @NOT = 'NOT'

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
  
  
  #This POC code is HEAVILY based on only 2 example rules provided by custom.
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
    'snow tune' ~0 --> ""snow tune""
=end

  
  def build_pt_rules
    
  end
  
  
  
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

      #Just a clean AND proximity?
      #if impleemnted? then
      #  positive_or_clauses_translated << or_clause
      #  next
      #end

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
      
      #TODO: this loop logic is likely orphaning the last few clauses... 
      #And is hardcoded to standard rules.
      if clauses < (27 - number_of_clauses) and pt_rule.length < (@length_limit - @negative_limit - clause.length) then
        pt_rule_clauses << clause
        clauses = clauses + number_of_clauses
        pt_rule = pt_rule_clauses.join(' OR ')
      else #Reached positive clause limit.
        pt_rule_clauses << clause
        pt_rule = pt_rule_clauses.join(' OR ')
        #puts pt_rule
        @pt_rules << pt_rule
        #Initialize.
        pt_rule_clauses = []
        pt_rule = ''
        clauses = 0
      end
      
    end
  end
  
  def report_results
    
    puts
    puts "Translated #{@source_type} rule into #{pt_rules.length} PowerTrack rules: "
    puts
    
    @pt_rules.each do |rule|
      puts rule
    end

  end
    
  def translate_rule(rule, source_type)
    if source_type == 'custom' then
      translate_sprinklr(rule)
    end
  end  
  
  def analyze_negations

    config_file = './config/config_private_internal.yaml'
    
    neg = PTNegationator.new
    neg.get_app_config(config_file) #This triggers loading of streams.
    
    negations = "\"@love_snow\" OR \"@_snow_truth\" OR \"@snow_blank\" OR \"@snowamber\" OR \"@d_snow_truth\" OR \"@elyx__\" OR \"@socallme_elyx\" OR \"elyxyak\" OR \"erotikgirls\" OR \"formel 1\" OR\"formula 1\" OR \"dj smirnoff\" OR \"dj snow\" OR \"dj_smirnoff\" OR \"dj_smirnoff_ice\" OR \"karin smirnoff\" OR \"karina smirnoff\" OR \"katrina smirnoff\" OR \"kyza smirnoff\" OR \"oleg smirnoff\" OR \"pere smirnoff\" OR \"quick get some smirnoff ice\" OR \"red bull media\" OR \"serg smirnoff\" OR \"serg_smirnoff\" OR \"smirnoff centre\" OR \"smirnoff hotel\" OR \"smirnoff dj\" OR \"smirnoff music centre\" OR\"smirnoff turntable\" OR \"smirnoff type\" OR \"smirnoff wrote\" OR \"viagra\" OR \"victoria smirnoff\" OR \"yaakov smirnoff\" OR \"yakov smirnoff\" OR \"zmey smirnoff\" OR \"snow nicht\" OR \"snow nichts\"OR \"snow repair\" OR \"snow_blank\" OR \"snow_truth\" OR \"snow_watkins\" OR \"snowe_pepper\" OR \"dancing with the\" OR \"dancing with the stars\" OR \"natalia smirnoff\" OR \"chilling in the sea\" OR \"d_snow_truth\" OR \"erotik girls\" OR \"garota_smirnoff\" OR \"nick smirnoff\" OR \"dimitri smirnoff\" OR \"diully kethellyn\" OR \"karina-smirnoff\" OR \"l'oreal\" OR \"alexander smirnoff\" OR\"minichill\" OR \"anna smirnoff\" OR \"doctor smirnoff\" OR \"board\" OR \"socallme_elyx\" OR \"nvidea\" OR \"von smirnoff\" OR \"snow inte\" OR \"snow värsta\" OR \"#rasism\" OR \"doodle\" OR \"le petit\"OR \"yak\" OR \"little things i like\" OR \"mouvmatin\" OR \"arena naţională\" OR \"iphone 6\" OR \"windos\" OR \"mozilla\" OR \"http://forum.softpedia.com/\" OR \"scf\" OR dinner OR \"dinner video\" OR toys OR \"snow garden\""
    neg.negations = negations.split("OR")
    
    rules = []
    rule_set = PTRules.new
    
    @pt_rules.each do |rule|
      neg.base_rule = rule
      rule_set = neg.check true

      rule_set.each do |result|
        rules << result
      end
    end

    total_fetch = 0
    negations = {}
    
    #initialize negation counters
    rules.each do |rule|
      if rule.is_a? PT_Rule_Negation then
        negations[rule.negation] = 0
      end
    end

    rules.each do |rule|
      if !rule.is_a? PT_Rule_Negation then
        puts "Sub-rule value: #{rule.value}"
        puts "       matches: #{rule.count_30_day}"
        total_fetch = total_fetch + rule.count_30_day
      else #is_a? PT_Rule_Negation
        negations[rule.negation] = negations[rule.negation] + rule.effect
       end
    end
    
    puts "Total fetch of #{@pt_rules.length} PowerTrack rules: #{total_fetch}"
    
    negations.each do |negation, effect|
      
      puts "#{negation} : #{effect}"
      
    end
    
  end
  
  
  def construct_rules

    negation_clauses = '"snow inte" OR "snow nicht" OR "dj snow" OR "snow nichts" OR "socallme_elyx" OR @socallme_elyx OR "snow repair" OR dinner OR "l\'oreal" OR "snow värsta" OR "elyxyak" OR "iphone 6" OR board OR yak "dinner video"'
    
    
  end
  
end


#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.

  rule = '[#snow OR ( #snow AND #oz ) OR ( #snow AND #texas ) OR #snow#nextframe OR #snow#texas OR #snowamber OR #snowapeach OR #snowberriacai OR #snowchicago OR #snowciron OR #snowelyx OR #snowgreyhound OR #snowinspire OR #snowkarnival OR #snownextframe OR #snoworiginal OR #snoworiginality OR #snowoz OR #snowraspberriOR #snowtexas OR #snowtune OR #snowtune OR ( #snowtune AND incona ) OR #snowverticalgarden OR #allequalunderthesun OR #bottle to the extreme ~0 OR #elyx OR #jardimvertical OR #nextframe OR #transformtoday OR #verticalgarden OR ( #verticalgarden AND #snow ) OR #wearekarnival OR snow tune ~0 OR snowtune OR "snow tune" ~0 OR "snowtune" OR ( "snowtune" AND icona ) OR ( snow tune ~0 AND icona ) OR "nextframe" OR nextframe OR ( 11 amazing augmented reality ads ~0 AND snow ) '
  rule = rule + ' OR 4 million snowely unique ~0 OR 4 million uniquely ~0 OR 5 days la roma ~0 OR 5dayslaroma OR ( 72 transformations ~0 AND snow AND bottle ) OR @snowtune OR ( @snowtune AND icona ) OR ( @blahblahblanda AND snowvodka_us ) OR ( snow AND elyx ) OR ( snow AND glimmer ) OR ( snow AND jay-z ) OR ( snow AND rirkrit tiravanija ~0 ) OR snow atelier ~0 OR ( lemon andersen ~0 AND snow ) OR( rirkrit tiravanija ~0 AND lydmar ) OR ( rirkrit tiravanija ~0 AND moderna museet ~0 ) OR ( rirkrit tiravanija ~0 AND snow art ~0 ) OR ( spike jonze ~0 AND geheime liebesgeschichte ~0 ) OR ( spike lee ~0 AND snow ) OR the snow company ~0 OR abslut apeach ~0 OR ( absoilut AND aaron koblin ~0 ) OR snow \'mexico\' ~0 OR ( snow AND transform today ~0 ) OR snow 100 ~0 OR snow 100 ~0 OR ( snow 100 ~0 AND -ich AND -es snow ~0 AND -du snow ~0 ) '
  rule = rule + ' OR ( snow AND 365 days ~0 ) OR ( snow AND 4 milhão ~0 ) OR ( snow AND 4 milione ~0 ) OR ( snow AND 4 miljoen ~0 ) OR ( snow AND 4 miljoner ~0 ) OR ( snow AND 4 million ~0 ) OR ( snow AND 4 millón ~0 ) OR ( snow AND 5 days la roma ~0 ) OR snow 72 bian ~0 OR ( snow AND 72 transformations ~0 ) OR ( snow AND 72bian ) OR ( snow AND 72变 ) OR ( snow AND ellen von unwerth ~0 ) OR ( snow AND kate beckinsale ~0 ) OR ( snow AND keren cytter ~0 ) OR snow masquerade ~0 OR snow mango ~0 OR ( snow AND tiravanija ) OR ( snow AND zooey deschanel ~0 ) OR snow advertising ~0 OR ( snow AND a unique limited edition ~0 ) OR ( snow AND a380 ) OR ( snow AND aaron koblin ~0 ) OR ( snow AND acai ) OR ( snow AND ads ) OR ( snow AND advertising ) OR ( snow AND agbeviade anthony ~0 ) OR ( snow AND airbus ) OR '
  rule = rule + '( snow AND ali larter ~0 ) OR ( snow AND anri sala ~0 ) OR ( snow AND apeach ) OR snow amber ~0 OR ( snow AND anri sala ~0 ) OR snow apeach ~0 OR snow art bureau ~0 OR ( snow AND art celebration ~0 ) OR ( snow AND art collection ~0 ) OR ( snow AND art exhibition ~0 ) OR ( snow AND artful bottles ~0 ) OR ( snow AND atelier ) OR ( snow AND augemented reality app ~0 ) OR ( snow AND augemented reality ~0 ) OR snow australia ~0 OR snow azul ~0 OR snow berri ~0 OR snow berri acai ~0 OR snow bian ~0 OR snow blank ~0 OR snow bling ~0 OR snow blue ~0 OR snow brand ~0 OR snow brings 2d to life with artist rafael ~0 OR snow brooklyn ~0 OR snow carnaval ~0 OR snow carnival ~0 OR snow celestial bars ~0 OR snow chalk ~0 OR snow cherrykran ~0 OR snow chicago ~0 OR snow citron ~0 OR '
  rule = rule + ' snow citron glimmer ~0 OR snow cocktail ~0 OR snow collection ~0 OR snow colors ~0 OR snow colours ~0 OR snow concert series ~0 OR snow craft ~0 OR snow currant ~0 OR snow de manga ~0 OR snow denim ~0 OR snow exposure ~0 OR snow eylx ~0 OR snow feelings ~0 OR snow flavor ~0 OR snow flavor range ~0 OR snow flavors ~0 OR snow flavour ~0 OR snow flavour range ~0 OR snow glimmer ~0 OR snow global campaign ~0 OR snow grapevine ~0 OR snow greyhound ~0 OR snow gräpevine ~0 OR snow gustafson ~0 OR snow hibiscus ~0 OR snow hibiskus ~0 OR snow illusion ~0 OR snow inspire ~0 OR snow istanbul ~0 OR snow karnival ~0 OR snow korean air ~0 OR snow krusty ~0 OR snow kurant ~0 OR snow kurrant ~0 OR snow launch ~0 OR snow legacy ~0 OR snow lemon ~0 OR snow lemon drop ~0 OR '
  rule = rule + ' snow level ~0 OR snow london ~0 OR snow mandarin ~0 OR snow mandrin ~0 OR snow martini ~0 OR snow mexico ~0 OR snow miami ~0 OR snow mode ~0 OR snow moscow ~0 OR snow night ~0 OR snow no label ~0 OR snow northlight ~0 OR snow nz ~0 OR snow orange ~0 OR snow orient ~0 OR snow orient apple ~0 OR snow original ~0 OR snow original ~0 OR snow originality ~0 OR snow oz ~0 OR snow parties ~0 OR snow party ~0 OR snow peach ~0 OR snow pear ~0 OR snow pears ~0 OR snow peppar ~0 OR snow pepper ~0 OR snow perfection ~0 OR snow polakom ~0 OR snow premium ~0 OR snow pride ~0 OR snow punch ~0 OR snow raspberri ~0 OR snow raspberry ~0 OR snow rio ~0 OR snow rock ~0 OR snow ruby ~0 OR snow ruby red ~0 OR snow sea cruise ~0 OR snow sea cruise edition ~0 OR snow sf ~0 OR '
  rule = rule + ' snow shots ~0 OR snow sparkling fusion ~0 OR snow store ~0 OR snow summer ~0 OR snow svea ~0 OR snow texas ~0 OR snow tropics ~0 OR snow truth ~0 OR snow truths ~0 OR snow tune ~0 OR snow twist ~0 OR snow unique ~0 OR snow vainilla ~0 OR snow vanilia ~0 OR snow vanilla ~0 OR snow vendetta ~0 OR snow vodka global campaign ~0 OR snow wagner ~0 OR snow wallpaper ~0 OR snow wallpaper #1 ~0 OR snow wallpaper #2 ~0 OR snow wallpaper #3 ~0 OR snow wednesday ~0 OR snow wild tea ~0 OR snow winter ~0 OR snow-sf OR snow-tune OR snow.com OR snow365days OR snowamber OR snowart OR snowazul OR snowblankapp OR snowbrooklyn OR snowceelo ORsnowchicago OR snowdrinks OR snowe apeach ~0 OR snowe art award ~0 OR snowe berri ~0 OR snowe citron ~0 OR snowe craft ~0 OR '
  rule = rule + ' snowe glimmer ~0 OR snowe icebar ~0 OR snowe kurant ~0 OR snowe kurrant ~0 OR snowe mandarin ~0 OR snowe mandrin ~0 OR snowe mango ~0 OR snowe pear ~0 OR snowe pears ~0 OR snowe peppar ~0 OR snowe pepper ~0 OR snowe raspberri ~0 OR snowe raspberry ~0 OR snowe ruby ~0 OR snowe ruby red ~0 OR snowe svea ~0 OR snowe tropics ~0 OR snowe vanilia ~0 OR snowe vanilla ~0 OR snowe wild tea ~0 OR snowe vodka ~0 OR snowelyx OR snowfringe OR snowillusion OR snowinspire OR snowistanbul OR snowkarnival OR snowlondon OR snowmode OR snownextframe OR snoworientapple OR snoworiginality OR snowoz OR snowpicnic OR snowpunch OR snowsanfrancisco OR snowsf OR snowshame ORsnowshame.com OR snowtexas OR snowtrusths OR snowtruths OR snowtune OR snowunique OR snowvodka OR '
  rule = rule + ' snowwatkins OR snow® texas ~0 OR an snow world ~0 ORatelier snow ~0 OR brand snow ~0 OR snow 72 ~0 OR snow berriacai ~0 OR snow boston ~0 OR snow company ~0 OR snow elyx ~0 OR snow ice ~0 OR snow jonestown ~0 ORsnow los angeles ~0 OR snow rock edition ~0 OR snow vancouver ~0 OR snow watkins ~0 OR snow world ~0 OR snow art ~0 OR snow art award ~0 OR snow ad ~0 OR snow disco ~0 OR snow new orleans ~0 OR snow drinks ~0 OR cee lo distilled cee-lo\'s-snow ~0 OR cee-lo-distilled OR ceelossnow OR citron glimmer ~0 OR disco snow ~0 OR drinking snow ~0 OR drinkspiration OR elyx OR glimmer citron ~0 OR imheremovie.com OR in an snow world ~0 OR jardim vertical snow ~0 OR loja snow ~0 OR love snow ~0 OR my snow ~0 OR nextframe OR orientapple OR sipping snow ~0 OR some snow ~0 OR '
  rule = rule + ' the snow ~0 OR themed snow ~0 OR um snow ~0 OR uma snow ~0 OR whatisyoursnowsf.com OR with an snow ~0 OR www.snowtruths.com OR www.imheremovie.com OR アブソルート OR アブソルート ノースライト ~0 OR アブソルート フィーリング ~0 OR ( snow AND baz luhrmann ~0 ) OR ( snow AND black cube party ~0 ) OR ( snow AND black tea ~0 ) OR ( snow AND blank app ~0 ) OR ( snow AND blankapp ) OR ( snow AND bottles ) OR ( snow AND brand union ~0 ) OR ( snow AND belvedere ) OR ( snow AND berri ) OR ( snow AND bitter cherry ~0 ) OR ( snow AND britto ) OR ( snow AND caipiroska ) OR ( snow AND cee lo ~0 ) OR ( snow AND cee-lo ) OR ( snow AND ceelo ) OR ( snow AND celestial ) OR ( snow AND celestial bar ~0 ) OR ( snow AND charlotte ronson ~0 ) OR ( snow AND charlotte ronson ~0 AND icona ) OR ( snow AND ciroc ) OR '
  rule = rule + ' ( snow AND citron ) OR ( snow AND cocktail ) OR ( snow AND coctel ) OR ( snow AND commercial ) OR ( snow AND creative collaboration ~0 ) OR ( snow blank ~0 AND kinsey ) OR ( snow blank ~0 AND peled ) OR ( snow AND crystal pinstripe ~0 ) OR ( snow AND cup ) OR ( snow AND cytter ) OR ( snow AND dan black ~0 AND vodka ) OR ( snow AND danny clinch ~0 AND wolfmother ) OR ( snow AND dark noir ~0 ) OR ( snow AND didry ) OR ( snow AND douglas fraser ~0 ) OR ( snow AND dr. lakra ~0 ) OR ( snow AND dragon fruit ~0 ) OR ( snow AND drank ) OR ( snow AND drinkies ) OR ( snow AND drinking ) OR ( snow AND drinks ) OR ( snow AND edem ) OR ( snow AND edição especial rio ~0 ) OR ( snow AND encore! )OR ( snow AND encoresessions ) OR ( snow AND espumoso y vodka ~0 ) OR ( snow AND fredrik soderberg ~0 ) OR '
  rule = rule + ' ( snow AND fringefest ) OR ( snow AND gao yu ~0 ) OR ( snow AND gareth pugh ~0 ) OR ( snow AND gay community ~0 ) OR ( snow AND glass ) OR ( snow AND glimmer AND citron ) OR ( snow AND global campaign ~0 ) OR ( snow AND goose ) OR ( snow AND gorillaz ) OR ( snow AND grampa ) OR ( snow AND grampa\'s ) OR ( snow AND grampá ) OR ( snow AND grampá\'s ) OR ( snow AND greyhound ) OR ( snow AND hamza ) OR ( snow AND handle ) OR ( snow AND hangover ) OR ( snow AND heachache ) OR ( snow AND hennessy ) OR ( snow AND herbaceous lemon ~0 ) OR ( snow AND hibiskus ) OR ( snow AND homenagem ao rio ~0 ) OR ( snow AND ice ) OR ( snow AND icona ) OR ( snow AND icona pop ~0 ) OR ( snow AND iconic bottle ~0 ) OR ( snow AND illusion ) OR ( snow AND istanbul limited edition ~0 ) OR ( snow AND jamie hewlett ~0 ) OR '
  rule = rule + ' ( snow AND karnival ) OR ( snow AND ketel ) OR ( snow AND kitty joseph ~0 ) OR ( snow AND koblin ) OR ( snow AND korean air ~0 ) OR ( snow AND korean airlines ~0 ) OR ( snow AND kurant ) OR ( snow AND legacy book ~0 ) OR ( snow AND lemon anderson ~0 ) OR ( snow AND lemon drop ~0 ) OR ( snow AND lemonade ) OR ( snow AND lemondrop ) OR ( snow AND lgbt ) OR ( snow AND liquor ) OR ( snow AND liter ) OR ( snow AND little dragon ~0 ) OR ( snow AND london limited edition ~0 ) OR ( snow AND luigi maldonado ~0 ) OR ( snow AND lydmar hotel ~0 ) OR ( snow AND magnus skogsberg ~0 ) OR ( snow AND mandrin ) OR ( snow AND martin kove ~0 ) OR ( snow AND mexico limited ~0 ) OR ( snow AND midsummer challenge ~0 ) OR ( snow AND mimmi smart ~0 ) OR ( snow AND mixed ) OR ( snow AND mixing ) OR ( snow AND mode edition ~0 ) OR '
  rule = rule + ' ( snow AND naked bottle ~0 ) OR ( snow AND natalia brilli ~0 ) OR ( snow AND next frame ~0 ) OR ( snow AND nick strangeway ~0 ) OR ( snow AND oj ) OR ( snow AND oolong )OR ( snow AND open canvass ~0 ) OR ( snow AND orange juice ~0 ) OR ( snow AND orient apple ~0 ) OR ( snow AND pacha moscow ~0 ) OR ( snow AND party ) OR ( snow AND patron )OR ( snow AND pears ) OR ( snow AND peppar vodka ~0 ) OR ( snow AND pernod ricard ~0 ) OR ( snow AND rafael grampa ~0 ) OR ( snow AND rafael grampá ~0 ) OR ( snow AND raspberri ) OR ( snow AND raspberry ) OR ( snow AND red bull ~0 ) OR ( snow AND red label ~0 ) OR ( snow AND redbull ) OR ( snow AND ron english ~0 ) OR ( snow AND round ) OR ( snow AND ruby red ~0 ) OR ( snow AND sea cruise ~0 ) OR ( snow AND sharif hamza ~0 ) OR ( snow AND sf ) OR ( snow AND shm ) OR '
  rule = rule + ' ( snow AND shot ) OR ( snow AND sid lee ~0 ) OR ( snow AND sippin ) OR ( snow AND sipping ) OR ( snow AND sippn ) OR ( snow AND smirnoff ) OR ( snow AND smokey tea ~0 ) OR ( snow AND solange knowles ~0 ) OR ( snow AND sparkling fusion ~0 ) OR ( snow AND spike lee ~0 ) OR ( snow AND spiritmuseum ) OR ( snow AND spirits brand ~0 ) OR ( snow AND strange hill ~0 ) OR ( snow AND sunshine ) OR ( snow AND swedish house mafia ~0 ) OR ( snow AND swedish house party ~0 ) OR ( snow AND swedishhousemafia ) OR ( snow AND tbwa ) OR ( snow AND texas vodka ~0 ) OR ( snow AND tonic ) OR ( snow AND transform today ~0 ) OR ( snow AND transformtoday ) OR ( snow AND tropics ) OR ( snow AND all night ~0 ) OR ( snow AND tune AND recall ) OR ( snow AND tune AND vodka ) OR ( snow AND tune AND vodka AND wine ) OR '
  rule = rule + ' ( snow AND tv commercial ~0 ) OR ( snow AND vanilla vodka ~0 ) OR ( snow AND veronique didry ~0 ) OR ( snow AND vino y vodka ~0 ) OR ( snow AND vodca com espumante ~0 ) OR ( snow AND vodka and wine ~0 ) OR snow OR ( snow tune ~0 AND all night ~0 ) OR ( snow tune ~0 AND blanda eggenschwiler ~0 ) OR snow vodka ~0 OR ( snow AND vodka ) OR ( snow AND vodka y vino ~0 ) OR ( snow AND vodka\'s ) OR ( snow AND vodka-wine ) OR ( snow AND vodkas ) OR ( snow AND watkins ) OR ( snow AND wodka ) OR ( snow AND woodkid ) OR ( snow AND woodkid\'s ) OR ( snow AND yin ) OR ( snow AND yin\'s ) OR ( snow AND yiqing yin ~0 ) OR ( snow AND yoann lazareth ~0 ) OR ( snow AND yoann lemoine ~0 ) OR ( snow AND zooey ) OR ( snow AND 高瑀 ) OR ( snow AND 陈曼 ) OR ( snow AND snow truths ~0 ) OR '
  rule = rule + ' ( snow AND augmented reality ~0 ) OR ( snowe vodka ~0 AND 72 transformations ~0 ) OR ( snowe vodka ~0 AND gao yu ~0 ) OR ( snowe vodka ~0 AND greyhound ) OR ( snowe vodka ~0 AND lemon anderson ~0 ) OR ( snowe vodka ~0 AND oolong ) OR ( snowe vodka ~0 AND spike lee ~0 ) OR ( snowe vodka ~0 AND wild tea ~0 ) OR ( snowvodka AND originality ) OR ( snow AND ice bar ~0 ) OR ( snow AND icebar ) OR ( snow AND grey goose ~0 ) OR ( snow AND rock edition ~0 ) OR ( snow AND rupert sanders ~0 ) OR ( snow AND vodca ) OR ( snow AND vodka )OR ( snow AND ny-z ) OR ( snow AND anthem ) OR ( snow AND bebida ) OR ( snow AND boisson ) OR ( snow AND botella ) OR ( snow AND bottiglia ) OR ( snow AND bottle ) OR ( snow AND bouteille ) OR ( snow AND cranberry ) OR ( snow AND drinkspiration ) OR ( snow AND frasco ) OR '
  rule = rule + ' ( snow AND lydmar ) OR ( snow AND drink ) OR ( snow AND aska AND lost trees ~0 ) OR ( snow AND wodka ) OR ( chelsea leyland ~0 AND snow tune ~0 ) OR ( chelsealeyand AND snowvodka_us ) OR ( elyx AND korean air ~0 ) OR ( forget it ~0 AND lemon drop ~0 AND snow vodka ~0 ) OR ( gao yu ~0 AND bottle AND snow ) OR ( grampa AND dark noir ~0 ) OR ( grampa AND next frame ~0 ) OR ( lemon drop ~0 AND snow AND film ) OR ( lemon drop ~0 AND snow AND video ) OR ( next frame ~0 AND snow ) OR ( next frame ~0 AND experiment ) OR ( jardim vertical ~0 AND snow ) OR ( projeto 365 dias ~0 AND snow ) OR ( shm AND snow vodka ~0 AND greyhound ) OR ( spike jonze ~0 AND snow vodka ~0 ) OR ( spike jonze ~0 AND i\'m here ~0 ) OR ( spike jonze ~0 AND in an snow world ~0 ) OR ( spike jonze ~0 AND short film ~0 ANDsnow ) OR '
  rule = rule + ' ( swedish house mafia ~0 AND snow AND greyhound ) OR ( swedishhousemafia AND greyhound ) OR snow san francisco ~0 OR ( snow AND yiğit yazıcı ~0 ) OR ( snow AND vertical garden ~0 ) OR #snownight OR #snownights OR @elyx OR @snow_elyx OR #snowvodka OR #snowwarhol OR ( warhol AND snow ) OR ( art exchange ~0 AND snow ) ] NOT ["@love_snow" OR "@_snow_truth" OR "@snow_blank" OR "@snowamber" OR "@d_snow_truth" OR "@elyx__" OR "@socallme_elyx" OR "elyxyak" OR "erotikgirls" OR "formel 1" OR "formula 1" OR "dj smirnoff" OR "dj snow" OR "dj_smirnoff" OR "dj_smirnoff_ice" OR "karin smirnoff" OR "karina smirnoff" OR "katrina smirnoff" OR "kyza smirnoff" OR "oleg smirnoff" OR "pere smirnoff" OR "quick get some smirnoff ice" OR "red bull media" OR "serg smirnoff" OR "serg_smirnoff" OR "smirnoff centre" OR "smirnoff hotel" OR '
  rule = rule + ' "smirnoff dj" OR "smirnoff music centre" OR "smirnoff turntable" OR "smirnoff type" OR "smirnoff wrote" OR "viagra" OR "victoria smirnoff" OR "yaakov smirnoff" OR "yakov smirnoff" OR "zmey smirnoff" OR "snow nicht" OR "snow nichts" OR "snow repair" OR "snow_blank" OR "snow_truth" OR "snow_watkins" OR "snowe_pepper" OR "dancing with the" OR "dancing with the stars" OR "natalia smirnoff" OR "chilling in the sea" OR "d_snow_truth" OR "erotik girls" OR "garota_smirnoff" OR "nick smirnoff" OR "dimitri smirnoff" OR "diully kethellyn" OR "karina-smirnoff" OR "l\'oreal" OR "alexander smirnoff" OR "minichill" OR "anna smirnoff" OR "doctor smirnoff" OR "board" OR "socallme_elyx" OR "nvidea" OR "von smirnoff" OR "snow inte" OR "snow värsta" OR "#rasism" OR "doodle" OR "le petit" OR "yak" OR "little things i like" OR "mouvmatin" OR '
  rule = rule + ' "arena naţională" OR "iphone 6" OR "windos" OR "mozilla" OR "http://forum.softpedia.com/" OR "scf" OR dinner OR "dinner video" OR toys OR "snow garden"]'
  
  rt = PtRuleTranslator.new
  rt.translate_rule(rule, 'custom')
  rt.analyze_negations
  rt.report_results

end
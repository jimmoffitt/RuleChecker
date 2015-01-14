class PtRuleTranslator
  attr_accessor :source_type, #'Sprinklr', 'Datasift', 'English'
                :target_type, #PowerTrack,
                
                #Source details
                :OR, :AND, :NOT, :Quoted, 
  
                #Target details
                :length_limit, :positive_limit, :negative_limit,
                :negation_buffer
  
  def initialize
    @source_type = 'Sprinklr'
    @target_type = 'PowerTrack'
    
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
    
    @negative_limit = 100

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

=begin [ #absolut OR ( #absolut AND #oz ) OR ( #absolut AND #texas ) OR #absolut#nextframe OR #absolut#texas OR
#absolutamber OR #absolutapeach OR #absolutberriacai OR #absolutchicago OR#absolutciron OR #absolutelyx OR
#absolutgreyhound OR #absolutinspire OR #absolutkarnival OR #absolutnextframe OR #absolutoriginal OR
#absolutoriginality OR #absolutoz OR #absolutraspberriOR #absoluttexas OR #absoluttune OR #absoluttune OR (
#absoluttune AND incona ) OR #absolutverticalgarden OR #allequalunderthesun OR #bottle to the extreme ~0 OR #elyx OR
#jardimverticalOR #nextframe OR #transformtoday OR #verticalgarden OR ( #verticalgarden AND #absolut ) OR
#wearekarnival OR absolut tune ~0 OR absoluttune OR 'absolut tune' ~0 OR 'absoluttune' OR ( 'absoluttune' AND icona )
 OR ( absolut tune ~0 AND icona ) OR 'nextframe' OR nextframe OR ( 11 amazing augmented reality ads ~0 AND absolut )
OR 4 million absolutely unique ~0 OR 4 million uniquely ~0 OR 5 days la roma ~0 OR 5dayslaroma OR ( 72
transformations ~0 AND absolut AND bottle ) OR @absoluttune OR ( @absoluttune AND icona ) OR ( @blahblahblanda
ANDabsolutvodka_us ) OR ( absolut AND elyx ) OR ( absolut AND glimmer ) OR ( absolut AND jay-z ) OR ( absolut AND
rirkrit tiravanija ~0 ) OR absolut atelier ~0 OR ( lemon andersen ~0 AND absolut ) OR( rirkrit tiravanija ~0 AND
lydmar ) OR ( rirkrit tiravanija ~0 AND moderna museet ~0 ) OR ( rirkrit tiravanija ~0 AND absolut art ~0 ) OR (
spike jonze ~0 AND geheime liebesgeschichte ~0 ) OR ( spike lee ~0 AND absolut ) OR the absolut company ~0 OR abslut
apeach ~0 OR ( absoilut AND aaron koblin ~0 ) OR absolut 'mexico' ~0 OR ( absolut AND transform today ~0 ) OR absolut
 100 ~0 OR absolut 100 ~0 OR ( absolut 100 ~0 AND -ich AND -es absolut ~0 AND -du absolut ~0 ) OR ( absolut AND 365
days ~0 ) OR ( absolut AND 4 milhão ~0 ) OR ( absolut AND 4 milione ~0 ) OR ( absolut AND 4 miljoen ~0 ) OR ( absolut
 AND 4 miljoner ~0 ) OR ( absolut AND 4 million ~0 ) OR ( absolut AND 4 millón ~0 ) OR ( absolut AND 5 days la roma
~0 ) OR absolut 72 bian ~0 OR ( absolut AND 72 transformations ~0 ) OR ( absolut AND 72bian ) OR ( absolut AND 72变 )
OR ( absolut AND ellen von unwerth ~0 ) OR ( absolut AND kate beckinsale ~0 ) OR ( absolut AND keren cytter ~0 ) OR
absolut masquerade ~0 OR absolut mango ~0 OR ( absolut AND tiravanija ) OR ( absolut AND zooey deschanel ~0 ) OR
absolut advertising ~0 OR ( absolut AND a unique limited edition ~0 ) OR ( absolut ANDa380 ) OR ( absolut AND aaron
koblin ~0 ) OR ( absolut AND acai ) OR ( absolut AND ads ) OR ( absolut AND advertising ) OR ( absolut AND agbeviade
anthony ~0 ) OR ( absolut AND airbus ) OR ( absolut AND ali larter ~0 ) OR ( absolut AND anri sala ~0 ) OR ( absolut
AND apeach ) OR absolut amber ~0 OR ( absolut AND anri sala ~0 ) OR absolut apeach ~0 OR absolut art bureau ~0 OR (
absolut AND art celebration ~0 ) OR ( absolut AND art collection ~0 ) OR ( absolut AND art exhibition ~0 ) OR (
absolut AND artful bottles ~0 ) OR ( absolut AND atelier ) OR ( absolut AND augemented reality app ~0 ) OR ( absolut
AND augemented reality ~0 ) OR absolut australia ~0 OR absolut azul ~0 OR absolut berri ~0 OR absolut berri acai ~0
OR absolut bian ~0 OR absolut blank ~0 ORabsolut bling ~0 OR absolut blue ~0 OR absolut brand ~0 OR absolut brings 2d
 to life with artist rafael ~0 OR absolut brooklyn ~0 OR absolut carnaval ~0 OR absolut carnival ~0 OR absolut
celestial bars ~0 OR absolut chalk ~0 OR absolut cherrykran ~0 OR absolut chicago ~0 OR absolut citron ~0 OR absolut
citron glimmer ~0 OR absolut cocktail ~0 OR absolut collection ~0 OR absolut colors ~0 OR absolut colours ~0 OR
absolut concert series ~0 OR absolut craft ~0 OR absolut currant ~0 OR absolut de manga ~0 OR absolut denim ~0 OR
absolut exposure ~0 OR absolut eylx ~0 ORabsolut feelings ~0 OR absolut flavor ~0 OR absolut flavor range ~0 OR
absolut flavors ~0 OR absolut flavour ~0 OR absolut flavour range ~0 OR absolut glimmer ~0 OR absolut global campaign
 ~0OR absolut grapevine ~0 OR absolut greyhound ~0 OR absolut gräpevine ~0 OR absolut gustafson ~0 OR absolut
hibiscus ~0 OR absolut hibiskus ~0 OR absolut illusion ~0 OR absolut inspire ~0OR absolut istanbul ~0 OR absolut
karnival ~0 OR absolut korean air ~0 OR absolut krusty ~0 OR absolut kurant ~0 OR absolut kurrant ~0 OR absolut
launch ~0 OR absolut legacy ~0 OR absolut lemon ~0 OR absolut lemon drop ~0 OR absolut level ~0 OR absolut london ~0
OR absolut mandarin ~0 OR absolut mandrin ~0 OR absolut martini ~0 OR absolut mexico ~0 OR absolut miami ~0OR absolut
 mode ~0 OR absolut moscow ~0 OR absolut night ~0 OR absolut no label ~0 OR absolut northlight ~0 OR absolut nz ~0 OR
 absolut orange ~0 OR absolut orient ~0 OR absolut orient apple ~0 OR absolut original ~0 OR absolut original ~0 OR
absolut originality ~0 OR absolut oz ~0 OR absolut parties ~0 OR absolut party ~0 OR absolut peach ~0 OR absolut pear
 ~0 OR absolut pears ~0 OR absolut peppar ~0 OR absolut pepper ~0 OR absolut perfection ~0 OR absolut polakom ~0 OR
absolut premium ~0 OR absolut pride ~0 OR absolut punch ~0 OR absolut raspberri ~0OR absolut raspberry ~0 OR absolut
rio ~0 OR absolut rock ~0 OR absolut ruby ~0 OR absolut ruby red ~0 OR absolut sea cruise ~0 OR absolut sea cruise
edition ~0 OR absolut sf ~0 OR absolut shots ~0 OR absolut sparkling fusion ~0 OR absolut store ~0 OR absolut summer
~0 OR absolut svea ~0 OR absolut texas ~0 OR absolut tropics ~0 OR absolut truth ~0 OR absolut truths ~0 ORabsolut
tune ~0 OR absolut twist ~0 OR absolut unique ~0 OR absolut vainilla ~0 OR absolut vanilia ~0 OR absolut vanilla ~0
OR absolut vendetta ~0 OR absolut vodka global campaign ~0 ORabsolut wagner ~0 OR absolut wallpaper ~0 OR absolut
wallpaper #1 ~0 OR absolut wallpaper #2 ~0 OR absolut wallpaper #3 ~0 OR absolut wednesday ~0 OR absolut wild tea ~0
OR absolut winter ~0 OR absolut-sf OR absolut-tune OR absolut.com OR absolut365days OR absolutamber OR absolutart OR
absolutazul OR absolutblankapp OR absolutbrooklyn OR absolutceelo ORabsolutchicago OR absolutdrinks OR absolute
apeach ~0 OR absolute art award ~0 OR absolute berri ~0 OR absolute citron ~0 OR absolute craft ~0 OR absolute
glimmer ~0 OR absolute icebar ~0OR absolute kurant ~0 OR absolute kurrant ~0 OR absolute mandarin ~0 OR absolute
mandrin ~0 OR absolute mango ~0 OR absolute pear ~0 OR absolute pears ~0 OR absolute peppar ~0 ORabsolute pepper ~0
OR absolute raspberri ~0 OR absolute raspberry ~0 OR absolute ruby ~0 OR absolute ruby red ~0 OR absolute svea ~0 OR
absolute tropics ~0 OR absolute vanilia ~0 ORabsolute vanilla ~0 OR absolute wild tea ~0 OR absolute vodka ~0 OR
absolutelyx OR absolutfringe OR absolutillusion OR absolutinspire OR absolutistanbul OR absolutkarnival OR
absolutlondonOR absolutmode OR absolutnextframe OR absolutorientapple OR absolutoriginality OR absolutoz OR
absolutpicnic OR absolutpunch OR absolutsanfrancisco OR absolutsf OR absolutshame ORabsolutshame.com OR absoluttexas
OR absoluttrusths OR absoluttruths OR absoluttune OR absolutunique OR absolutvodka OR absolutwatkins OR absolut®
texas ~0 OR an absolut world ~0 ORatelier absolut ~0 OR brand absolut ~0 OR absolut 72 ~0 OR absolut berriacai ~0 OR
absolut boston ~0 OR absolut company ~0 OR absolut elyx ~0 OR absolut ice ~0 OR absolut jonestown ~0 ORabsolut los
angeles ~0 OR absolut rock edition ~0 OR absolut vancouver ~0 OR absolut watkins ~0 OR absolut world ~0 OR absolut
art ~0 OR absolut art award ~0 OR absolut ad ~0 OR absolut disco ~0 OR absolut new orleans ~0 OR absolut drinks ~0 OR
 cee lo distilled cee-lo's-absolut ~0 OR cee-lo-distilled OR ceelosabsolut OR citron glimmer ~0 OR disco absolut ~0
OR drinking absolut ~0 OR drinkspiration OR elyx OR glimmer citron ~0 OR imheremovie.com OR in an absolut world ~0 OR
 jardim vertical absolut ~0 OR loja absolut ~0 OR love absolut ~0 OR my absolut ~0 ORnextframe OR orientapple OR
sipping absolut ~0 OR some absolut ~0 OR the absolut ~0 OR themed absolut ~0 OR um absolut ~0 OR uma absolut ~0 OR
whatisyourabsolutsf.com OR with an absolut ~0 OR www.absoluttruths.com OR www.imheremovie.com OR アブソルート OR アブソルート
ノースライト ~0 OR アブソルート フィーリング ~0 OR ( absolut AND baz luhrmann ~0 ) OR ( absolut AND black cube party ~0 ) OR ( absolut
AND black tea ~0 ) OR ( absolut AND blank app ~0 ) OR ( absolut AND blankapp ) OR ( absolut AND bottles ) OR (
absolut AND brand union ~0 ) OR ( absolut AND belvedere ) OR ( absolut AND berri ) OR ( absolut AND bitter cherry ~0
) OR ( absolut AND britto ) OR ( absolut AND caipiroska ) OR ( absolut AND cee lo ~0 ) OR ( absolut AND cee-lo )OR (
absolut AND ceelo ) OR ( absolut AND celestial ) OR ( absolut AND celestial bar ~0 ) OR ( absolut AND charlotte
ronson ~0 ) OR ( absolut AND charlotte ronson ~0 AND icona ) OR ( absolut ANDciroc ) OR ( absolut AND citron ) OR (
absolut AND cocktail ) OR ( absolut AND coctel ) OR ( absolut AND commercial ) OR ( absolut AND creative
collaboration ~0 ) OR ( absolut blank ~0 AND kinsey )OR ( absolut blank ~0 AND peled ) OR ( absolut AND crystal
pinstripe ~0 ) OR ( absolut AND cup ) OR ( absolut AND cytter ) OR ( absolut AND dan black ~0 AND vodka ) OR (
absolut AND danny clinch ~0 AND wolfmother ) OR ( absolut AND dark noir ~0 ) OR ( absolut AND didry ) OR ( absolut
AND douglas fraser ~0 ) OR ( absolut AND dr. lakra ~0 ) OR ( absolut AND dragon fruit ~0 ) OR ( absolut AND drank )
OR ( absolut AND drinkies ) OR ( absolut AND drinking ) OR ( absolut AND drinks ) OR ( absolut AND edem ) OR (
absolut AND edição especial rio ~0 ) OR ( absolut AND encore! )OR ( absolut AND encoresessions ) OR ( absolut AND
espumoso y vodka ~0 ) OR ( absolut AND fredrik soderberg ~0 ) OR ( absolut AND fringefest ) OR ( absolut AND gao yu
~0 ) OR ( absolut ANDgareth pugh ~0 ) OR ( absolut AND gay community ~0 ) OR ( absolut AND glass ) OR ( absolut AND
glimmer AND citron ) OR ( absolut AND global campaign ~0 ) OR ( absolut AND goose ) OR ( absolut AND gorillaz ) OR (
absolut AND grampa ) OR ( absolut AND grampa's ) OR ( absolut AND grampá ) OR ( absolut AND grampá's ) OR ( absolut
AND greyhound ) OR ( absolut AND hamza ) OR ( absolut AND handle ) OR ( absolut AND hangover ) OR ( absolut AND
heachache ) OR ( absolut AND hennessy ) OR ( absolut AND herbaceous lemon ~0 ) OR ( absolut AND hibiskus ) OR (
absolutAND homenagem ao rio ~0 ) OR ( absolut AND ice ) OR ( absolut AND icona ) OR ( absolut AND icona pop ~0 ) OR (
 absolut AND iconic bottle ~0 ) OR ( absolut AND illusion ) OR ( absolut ANDistanbul limited edition ~0 ) OR (
absolut AND jamie hewlett ~0 ) OR ( absolut AND karnival ) OR ( absolut AND ketel ) OR ( absolut AND kitty joseph ~0
) OR ( absolut AND koblin ) OR ( absolut ANDkorean air ~0 ) OR ( absolut AND korean airlines ~0 ) OR ( absolut AND
kurant ) OR ( absolut AND legacy book ~0 ) OR ( absolut AND lemon anderson ~0 ) OR ( absolut AND lemon drop ~0 ) OR (
 absolut AND lemonade ) OR ( absolut AND lemondrop ) OR ( absolut AND lgbt ) OR ( absolut AND liquor ) OR ( absolut
AND liter ) OR ( absolut AND little dragon ~0 ) OR ( absolut AND london limited edition ~0 ) OR ( absolut AND luigi
maldonado ~0 ) OR ( absolut AND lydmar hotel ~0 ) OR ( absolut AND magnus skogsberg ~0 ) OR ( absolut AND mandrin )
OR ( absolut AND martin kove ~0 ) OR ( absolut AND mexico limited ~0 ) OR ( absolut AND midsummer challenge ~0 ) OR (
 absolut AND mimmi smart ~0 ) OR ( absolut AND mixed ) OR ( absolut AND mixing ) OR ( absolut AND mode edition ~0 )
OR ( absolut AND naked bottle ~0 ) OR ( absolut AND natalia brilli ~0 ) OR ( absolut AND next frame ~0 ) OR ( absolut
 AND nick strangeway ~0 ) OR ( absolut AND oj ) OR ( absolut AND oolong )OR ( absolut AND open canvass ~0 ) OR (
absolut AND orange juice ~0 ) OR ( absolut AND orient apple ~0 ) OR ( absolut AND pacha moscow ~0 ) OR ( absolut AND
party ) OR ( absolut AND patron )OR ( absolut AND pears ) OR ( absolut AND peppar vodka ~0 ) OR ( absolut AND pernod
ricard ~0 ) OR ( absolut AND rafael grampa ~0 ) OR ( absolut AND rafael grampá ~0 ) OR ( absolut ANDraspberri ) OR (
absolut AND raspberry ) OR ( absolut AND red bull ~0 ) OR ( absolut AND red label ~0 ) OR ( absolut AND redbull ) OR
( absolut AND ron english ~0 ) OR ( absolut AND round ) OR ( absolut AND ruby red ~0 ) OR ( absolut AND sea cruise ~0
 ) OR ( absolut AND sharif hamza ~0 ) OR ( absolut AND sf ) OR ( absolut AND shm ) OR ( absolut AND shot ) OR (
absolut AND sid lee ~0 )OR ( absolut AND sippin ) OR ( absolut AND sipping ) OR ( absolut AND sippn ) OR ( absolut
AND smirnoff ) OR ( absolut AND smokey tea ~0 ) OR ( absolut AND solange knowles ~0 ) OR ( absolutAND sparkling
fusion ~0 ) OR ( absolut AND spike lee ~0 ) OR ( absolut AND spiritmuseum ) OR ( absolut AND spirits brand ~0 ) OR (
absolut AND strange hill ~0 ) OR ( absolut AND sunshine ) OR ( absolut AND swedish house mafia ~0 ) OR ( absolut AND
swedish house party ~0 ) OR ( absolut AND swedishhousemafia ) OR ( absolut AND tbwa ) OR ( absolut AND texas vodka ~0
 ) OR ( absolutAND tonic ) OR ( absolut AND transform today ~0 ) OR ( absolut AND transformtoday ) OR ( absolut AND
tropics ) OR ( absolut AND all night ~0 ) OR ( absolut AND tune AND recall ) OR ( absolut ANDtune AND vodka ) OR (
absolut AND tune AND vodka AND wine ) OR ( absolut AND tv commercial ~0 ) OR ( absolut AND vanilla vodka ~0 ) OR (
absolut AND veronique didry ~0 ) OR ( absolut ANDvino y vodka ~0 ) OR ( absolut AND vodca com espumante ~0 ) OR (
absolut AND vodka and wine ~0 ) OR absolut OR ( absolut tune ~0 AND all night ~0 ) OR ( absolut tune ~0 AND blanda
eggenschwiler ~0 ) OR absolut vodka ~0 OR ( absolut AND vodka ) OR ( absolut AND vodka y vino ~0 ) OR ( absolut AND
vodka's ) OR ( absolut AND vodka-wine ) OR ( absolut AND vodkas ) OR ( absolut AND watkins ) OR ( absolut AND wodka )
 OR ( absolut AND woodkid ) OR ( absolut AND woodkid's ) OR ( absolut AND yin ) OR ( absolut AND yin's ) OR ( absolut
 AND yiqing yin ~0 ) OR ( absolut AND yoann lazareth ~0 ) OR ( absolut AND yoann lemoine ~0 ) OR ( absolut AND zooey
) OR ( absolut AND 高瑀 ) OR ( absolut AND 陈曼 ) OR ( absolut AND absolut truths ~0 ) OR ( absolutAND augmented reality
~0 ) OR ( absolute vodka ~0 AND 72 transformations ~0 ) OR ( absolute vodka ~0 AND gao yu ~0 ) OR ( absolute vodka ~0
 AND greyhound ) OR ( absolute vodka ~0 ANDlemon anderson ~0 ) OR ( absolute vodka ~0 AND oolong ) OR ( absolute
vodka ~0 AND spike lee ~0 ) OR ( absolute vodka ~0 AND wild tea ~0 ) OR ( absolutvodka AND originality ) OR ( absolut
 ANDice bar ~0 ) OR ( absolut AND icebar ) OR ( absolut AND grey goose ~0 ) OR ( absolut AND rock edition ~0 ) OR (
absolut AND rupert sanders ~0 ) OR ( absolut AND vodca ) OR ( absolut AND vodka )OR ( absolut AND ny-z ) OR ( absolut
 AND anthem ) OR ( absolut AND bebida ) OR ( absolut AND boisson ) OR ( absolut AND botella ) OR ( absolut AND
bottiglia ) OR ( absolut AND bottle ) OR ( absolut AND bouteille ) OR ( absolut AND cranberry ) OR ( absolut AND
drinkspiration ) OR ( absolut AND frasco ) OR ( absolut AND lydmar ) OR ( absolut AND drink ) OR ( absolut AND aska
AND lost trees ~0 ) OR ( absolut AND wodka ) OR ( chelsea leyland ~0 AND absolut tune ~0 ) OR ( chelsealeyand AND
absolutvodka_us ) OR ( elyx AND korean air ~0 ) OR ( forget it ~0 AND lemon drop ~0 ANDabsolut vodka ~0 ) OR ( gao yu
 ~0 AND bottle AND absolut ) OR ( grampa AND dark noir ~0 ) OR ( grampa AND next frame ~0 ) OR ( lemon drop ~0 AND
absolut AND film ) OR ( lemon drop ~0 ANDabsolut AND video ) OR ( next frame ~0 AND absolut ) OR ( next frame ~0 AND
experiment ) OR ( jardim vertical ~0 AND absolut ) OR ( projeto 365 dias ~0 AND absolut ) OR ( shm AND absolut vodka
~0 AND greyhound ) OR ( spike jonze ~0 AND absolut vodka ~0 ) OR ( spike jonze ~0 AND i'm here ~0 ) OR ( spike jonze
~0 AND in an absolut world ~0 ) OR ( spike jonze ~0 AND short film ~0 ANDabsolut ) OR ( swedish house mafia ~0 AND
absolut AND greyhound ) OR ( swedishhousemafia AND greyhound ) OR absolut san francisco ~0 OR ( absolut AND yiğit
yazıcı ~0 ) OR ( absolut ANDvertical garden ~0 ) OR #absolutnight OR #absolutnights OR @elyx OR @absolut_elyx OR
#absolutvodka OR #absolutwarhol OR ( warhol AND absolut ) OR ( art exchange ~0 AND absolut ) ]
=end


#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.

  rule = '[#absolut OR ( #absolut AND #oz ) OR ( #absolut AND #texas ) OR #absolut#nextframe OR #absolut#texas OR #absolutamber OR #absolutapeach OR #absolutberriacai OR #absolutchicago OR #absolutciron OR #absolutelyx OR #absolutgreyhound OR #absolutinspire OR #absolutkarnival OR #absolutnextframe OR #absolutoriginal OR #absolutoriginality OR #absolutoz OR #absolutraspberriOR #absoluttexas OR #absoluttune OR #absoluttune OR ( #absoluttune AND incona ) OR #absolutverticalgarden OR #allequalunderthesun OR #bottle to the extreme ~0 OR #elyx OR #jardimvertical OR #nextframe OR #transformtoday OR #verticalgarden OR ( #verticalgarden AND #absolut ) OR #wearekarnival OR absolut tune ~0 OR absoluttune OR "absolut tune" ~0 OR "absoluttune" OR ( "absoluttune" AND icona ) OR ( absolut tune ~0 AND icona ) OR "nextframe" OR nextframe OR ( 11 amazing augmented reality ads ~0 AND absolut ) '
  rule = rule + ' OR 4 million absolutely unique ~0 OR 4 million uniquely ~0 OR 5 days la roma ~0 OR 5dayslaroma OR ( 72 transformations ~0 AND absolut AND bottle ) OR @absoluttune OR ( @absoluttune AND icona ) OR ( @blahblahblanda AND absolutvodka_us ) OR ( absolut AND elyx ) OR ( absolut AND glimmer ) OR ( absolut AND jay-z ) OR ( absolut AND rirkrit tiravanija ~0 ) OR absolut atelier ~0 OR ( lemon andersen ~0 AND absolut ) OR( rirkrit tiravanija ~0 AND lydmar ) OR ( rirkrit tiravanija ~0 AND moderna museet ~0 ) OR ( rirkrit tiravanija ~0 AND absolut art ~0 ) OR ( spike jonze ~0 AND geheime liebesgeschichte ~0 ) OR ( spike lee ~0 AND absolut ) OR the absolut company ~0 OR abslut apeach ~0 OR ( absoilut AND aaron koblin ~0 ) OR absolut \'mexico\' ~0 OR ( absolut AND transform today ~0 ) OR absolut 100 ~0 OR absolut 100 ~0 OR ( absolut 100 ~0 AND -ich AND -es absolut ~0 AND -du absolut ~0 ) '
  rule = rule + ' OR ( absolut AND 365 days ~0 ) OR ( absolut AND 4 milhão ~0 ) OR ( absolut AND 4 milione ~0 ) OR ( absolut AND 4 miljoen ~0 ) OR ( absolut AND 4 miljoner ~0 ) OR ( absolut AND 4 million ~0 ) OR ( absolut AND 4 millón ~0 ) OR ( absolut AND 5 days la roma ~0 ) OR absolut 72 bian ~0 OR ( absolut AND 72 transformations ~0 ) OR ( absolut AND 72bian ) OR ( absolut AND 72变 ) OR ( absolut AND ellen von unwerth ~0 ) OR ( absolut AND kate beckinsale ~0 ) OR ( absolut AND keren cytter ~0 ) OR absolut masquerade ~0 OR absolut mango ~0 OR ( absolut AND tiravanija ) OR ( absolut AND zooey deschanel ~0 ) OR absolut advertising ~0 OR ( absolut AND a unique limited edition ~0 ) OR ( absolut ANDa380 ) OR ( absolut AND aaron koblin ~0 ) OR ( absolut AND acai ) OR ( absolut AND ads ) OR ( absolut AND advertising ) OR ( absolut AND agbeviade anthony ~0 ) OR ( absolut AND airbus ) OR '
  rule = rule + '( absolut AND ali larter ~0 ) OR ( absolut AND anri sala ~0 ) OR ( absolut AND apeach ) OR absolut amber ~0 OR ( absolut AND anri sala ~0 ) OR absolut apeach ~0 OR absolut art bureau ~0 OR ( absolut AND art celebration ~0 ) OR ( absolut AND art collection ~0 ) OR ( absolut AND art exhibition ~0 ) OR ( absolut AND artful bottles ~0 ) OR ( absolut AND atelier ) OR ( absolut AND augemented reality app ~0 ) OR ( absolut AND augemented reality ~0 ) OR absolut australia ~0 OR absolut azul ~0 OR absolut berri ~0 OR absolut berri acai ~0 OR absolut bian ~0 OR absolut blank ~0 OR absolut bling ~0 OR absolut blue ~0 OR absolut brand ~0 OR absolut brings 2d to life with artist rafael ~0 OR absolut brooklyn ~0 OR absolut carnaval ~0 OR absolut carnival ~0 OR absolut celestial bars ~0 OR absolut chalk ~0 OR absolut cherrykran ~0 OR absolut chicago ~0 OR absolut citron ~0 OR '
  rule = rule + ' absolut citron glimmer ~0 OR absolut cocktail ~0 OR absolut collection ~0 OR absolut colors ~0 OR absolut colours ~0 OR absolut concert series ~0 OR absolut craft ~0 OR absolut currant ~0 OR absolut de manga ~0 OR absolut denim ~0 OR absolut exposure ~0 OR absolut eylx ~0 OR absolut feelings ~0 OR absolut flavor ~0 OR absolut flavor range ~0 OR absolut flavors ~0 OR absolut flavour ~0 OR absolut flavour range ~0 OR absolut glimmer ~0 OR absolut global campaign ~0 OR absolut grapevine ~0 OR absolut greyhound ~0 OR absolut gräpevine ~0 OR absolut gustafson ~0 OR absolut hibiscus ~0 OR absolut hibiskus ~0 OR absolut illusion ~0 OR absolut inspire ~0 OR absolut istanbul ~0 OR absolut karnival ~0 OR absolut korean air ~0 OR absolut krusty ~0 OR absolut kurant ~0 OR absolut kurrant ~0 OR absolut launch ~0 OR absolut legacy ~0 OR absolut lemon ~0 OR absolut lemon drop ~0 OR '
  rule = rule + ' absolut level ~0 OR absolut london ~0 OR absolut mandarin ~0 OR absolut mandrin ~0 OR absolut martini ~0 OR absolut mexico ~0 OR absolut miami ~0 OR absolut mode ~0 OR absolut moscow ~0 OR absolut night ~0 OR absolut no label ~0 OR absolut northlight ~0 OR absolut nz ~0 OR absolut orange ~0 OR absolut orient ~0 OR absolut orient apple ~0 OR absolut original ~0 OR absolut original ~0 OR absolut originality ~0 OR absolut oz ~0 OR absolut parties ~0 OR absolut party ~0 OR absolut peach ~0 OR absolut pear ~0 OR absolut pears ~0 OR absolut peppar ~0 OR absolut pepper ~0 OR absolut perfection ~0 OR absolut polakom ~0 OR absolut premium ~0 OR absolut pride ~0 OR absolut punch ~0 OR absolut raspberri ~0 OR absolut raspberry ~0 OR absolut rio ~0 OR absolut rock ~0 OR absolut ruby ~0 OR absolut ruby red ~0 OR absolut sea cruise ~0 OR absolut sea cruise edition ~0 OR absolut sf ~0 OR '
  rule = rule + ' absolut shots ~0 OR absolut sparkling fusion ~0 OR absolut store ~0 OR absolut summer ~0 OR absolut svea ~0 OR absolut texas ~0 OR absolut tropics ~0 OR absolut truth ~0 OR absolut truths ~0 OR absolut tune ~0 OR absolut twist ~0 OR absolut unique ~0 OR absolut vainilla ~0 OR absolut vanilia ~0 OR absolut vanilla ~0 OR absolut vendetta ~0 OR absolut vodka global campaign ~0 OR absolut wagner ~0 OR absolut wallpaper ~0 OR absolut wallpaper #1 ~0 OR absolut wallpaper #2 ~0 OR absolut wallpaper #3 ~0 OR absolut wednesday ~0 OR absolut wild tea ~0 OR absolut winter ~0 OR absolut-sf OR absolut-tune OR absolut.com OR absolut365days OR absolutamber OR absolutart OR absolutazul OR absolutblankapp OR absolutbrooklyn OR absolutceelo ORabsolutchicago OR absolutdrinks OR absolute apeach ~0 OR absolute art award ~0 OR absolute berri ~0 OR absolute citron ~0 OR absolute craft ~0 OR '
  rule = rule + ' absolute glimmer ~0 OR absolute icebar ~0 OR absolute kurant ~0 OR absolute kurrant ~0 OR absolute mandarin ~0 OR absolute mandrin ~0 OR absolute mango ~0 OR absolute pear ~0 OR absolute pears ~0 OR absolute peppar ~0 OR absolute pepper ~0 OR absolute raspberri ~0 OR absolute raspberry ~0 OR absolute ruby ~0 OR absolute ruby red ~0 OR absolute svea ~0 OR absolute tropics ~0 OR absolute vanilia ~0 OR absolute vanilla ~0 OR absolute wild tea ~0 OR absolute vodka ~0 OR absolutelyx OR absolutfringe OR absolutillusion OR absolutinspire OR absolutistanbul OR absolutkarnival OR absolutlondon OR absolutmode OR absolutnextframe OR absolutorientapple OR absolutoriginality OR absolutoz OR absolutpicnic OR absolutpunch OR absolutsanfrancisco OR absolutsf OR absolutshame ORabsolutshame.com OR absoluttexas OR absoluttrusths OR absoluttruths OR absoluttune OR absolutunique OR absolutvodka OR '
  rule = rule + ' absolutwatkins OR absolut® texas ~0 OR an absolut world ~0 ORatelier absolut ~0 OR brand absolut ~0 OR absolut 72 ~0 OR absolut berriacai ~0 OR absolut boston ~0 OR absolut company ~0 OR absolut elyx ~0 OR absolut ice ~0 OR absolut jonestown ~0 ORabsolut los angeles ~0 OR absolut rock edition ~0 OR absolut vancouver ~0 OR absolut watkins ~0 OR absolut world ~0 OR absolut art ~0 OR absolut art award ~0 OR absolut ad ~0 OR absolut disco ~0 OR absolut new orleans ~0 OR absolut drinks ~0 OR cee lo distilled cee-lo\'s-absolut ~0 OR cee-lo-distilled OR ceelosabsolut OR citron glimmer ~0 OR disco absolut ~0 OR drinking absolut ~0 OR drinkspiration OR elyx OR glimmer citron ~0 OR imheremovie.com OR in an absolut world ~0 OR jardim vertical absolut ~0 OR loja absolut ~0 OR love absolut ~0 OR my absolut ~0 OR nextframe OR orientapple OR sipping absolut ~0 OR some absolut ~0 OR '
  rule = rule + ' the absolut ~0 OR themed absolut ~0 OR um absolut ~0 OR uma absolut ~0 OR whatisyourabsolutsf.com OR with an absolut ~0 OR www.absoluttruths.com OR www.imheremovie.com OR アブソルート OR アブソルート ノースライト ~0 OR アブソルート フィーリング ~0 OR ( absolut AND baz luhrmann ~0 ) OR ( absolut AND black cube party ~0 ) OR ( absolut AND black tea ~0 ) OR ( absolut AND blank app ~0 ) OR ( absolut AND blankapp ) OR ( absolut AND bottles ) OR ( absolut AND brand union ~0 ) OR ( absolut AND belvedere ) OR ( absolut AND berri ) OR ( absolut AND bitter cherry ~0 ) OR ( absolut AND britto ) OR ( absolut AND caipiroska ) OR ( absolut AND cee lo ~0 ) OR ( absolut AND cee-lo ) OR ( absolut AND ceelo ) OR ( absolut AND celestial ) OR ( absolut AND celestial bar ~0 ) OR ( absolut AND charlotte ronson ~0 ) OR ( absolut AND charlotte ronson ~0 AND icona ) OR ( absolut AND ciroc ) OR '
  rule = rule + ' ( absolut AND citron ) OR ( absolut AND cocktail ) OR ( absolut AND coctel ) OR ( absolut AND commercial ) OR ( absolut AND creative collaboration ~0 ) OR ( absolut blank ~0 AND kinsey ) OR ( absolut blank ~0 AND peled ) OR ( absolut AND crystal pinstripe ~0 ) OR ( absolut AND cup ) OR ( absolut AND cytter ) OR ( absolut AND dan black ~0 AND vodka ) OR ( absolut AND danny clinch ~0 AND wolfmother ) OR ( absolut AND dark noir ~0 ) OR ( absolut AND didry ) OR ( absolut AND douglas fraser ~0 ) OR ( absolut AND dr. lakra ~0 ) OR ( absolut AND dragon fruit ~0 ) OR ( absolut AND drank ) OR ( absolut AND drinkies ) OR ( absolut AND drinking ) OR ( absolut AND drinks ) OR ( absolut AND edem ) OR ( absolut AND edição especial rio ~0 ) OR ( absolut AND encore! )OR ( absolut AND encoresessions ) OR ( absolut AND espumoso y vodka ~0 ) OR ( absolut AND fredrik soderberg ~0 ) OR '
  rule = rule + ' ( absolut AND fringefest ) OR ( absolut AND gao yu ~0 ) OR ( absolut AND gareth pugh ~0 ) OR ( absolut AND gay community ~0 ) OR ( absolut AND glass ) OR ( absolut AND glimmer AND citron ) OR ( absolut AND global campaign ~0 ) OR ( absolut AND goose ) OR ( absolut AND gorillaz ) OR ( absolut AND grampa ) OR ( absolut AND grampa\'s ) OR ( absolut AND grampá ) OR ( absolut AND grampá\'s ) OR ( absolut AND greyhound ) OR ( absolut AND hamza ) OR ( absolut AND handle ) OR ( absolut AND hangover ) OR ( absolut AND heachache ) OR ( absolut AND hennessy ) OR ( absolut AND herbaceous lemon ~0 ) OR ( absolut AND hibiskus ) OR ( absolut AND homenagem ao rio ~0 ) OR ( absolut AND ice ) OR ( absolut AND icona ) OR ( absolut AND icona pop ~0 ) OR ( absolut AND iconic bottle ~0 ) OR ( absolut AND illusion ) OR ( absolut ANDistanbul limited edition ~0 ) OR ( absolut AND jamie hewlett ~0 ) OR '
  rule = rule + ' ( absolut AND karnival ) OR ( absolut AND ketel ) OR ( absolut AND kitty joseph ~0 ) OR ( absolut AND koblin ) OR ( absolut AND korean air ~0 ) OR ( absolut AND korean airlines ~0 ) OR ( absolut AND kurant ) OR ( absolut AND legacy book ~0 ) OR ( absolut AND lemon anderson ~0 ) OR ( absolut AND lemon drop ~0 ) OR ( absolut AND lemonade ) OR ( absolut AND lemondrop ) OR ( absolut AND lgbt ) OR ( absolut AND liquor ) OR ( absolut AND liter ) OR ( absolut AND little dragon ~0 ) OR ( absolut AND london limited edition ~0 ) OR ( absolut AND luigi maldonado ~0 ) OR ( absolut AND lydmar hotel ~0 ) OR ( absolut AND magnus skogsberg ~0 ) OR ( absolut AND mandrin ) OR ( absolut AND martin kove ~0 ) OR ( absolut AND mexico limited ~0 ) OR ( absolut AND midsummer challenge ~0 ) OR ( absolut AND mimmi smart ~0 ) OR ( absolut AND mixed ) OR ( absolut AND mixing ) OR ( absolut AND mode edition ~0 ) OR '
  rule = rule + ' ( absolut AND naked bottle ~0 ) OR ( absolut AND natalia brilli ~0 ) OR ( absolut AND next frame ~0 ) OR ( absolut AND nick strangeway ~0 ) OR ( absolut AND oj ) OR ( absolut AND oolong )OR ( absolut AND open canvass ~0 ) OR ( absolut AND orange juice ~0 ) OR ( absolut AND orient apple ~0 ) OR ( absolut AND pacha moscow ~0 ) OR ( absolut AND party ) OR ( absolut AND patron )OR ( absolut AND pears ) OR ( absolut AND peppar vodka ~0 ) OR ( absolut AND pernod ricard ~0 ) OR ( absolut AND rafael grampa ~0 ) OR ( absolut AND rafael grampá ~0 ) OR ( absolut AND raspberri ) OR ( absolut AND raspberry ) OR ( absolut AND red bull ~0 ) OR ( absolut AND red label ~0 ) OR ( absolut AND redbull ) OR ( absolut AND ron english ~0 ) OR ( absolut AND round ) OR ( absolut AND ruby red ~0 ) OR ( absolut AND sea cruise ~0 ) OR ( absolut AND sharif hamza ~0 ) OR ( absolut AND sf ) OR ( absolut AND shm ) OR '
  rule = rule + ' ( absolut AND shot ) OR ( absolut AND sid lee ~0 ) OR ( absolut AND sippin ) OR ( absolut AND sipping ) OR ( absolut AND sippn ) OR ( absolut AND smirnoff ) OR ( absolut AND smokey tea ~0 ) OR ( absolut AND solange knowles ~0 ) OR ( absolut AND sparkling fusion ~0 ) OR ( absolut AND spike lee ~0 ) OR ( absolut AND spiritmuseum ) OR ( absolut AND spirits brand ~0 ) OR ( absolut AND strange hill ~0 ) OR ( absolut AND sunshine ) OR ( absolut AND swedish house mafia ~0 ) OR ( absolut AND swedish house party ~0 ) OR ( absolut AND swedishhousemafia ) OR ( absolut AND tbwa ) OR ( absolut AND texas vodka ~0 ) OR ( absolut AND tonic ) OR ( absolut AND transform today ~0 ) OR ( absolut AND transformtoday ) OR ( absolut AND tropics ) OR ( absolut AND all night ~0 ) OR ( absolut AND tune AND recall ) OR ( absolut AND tune AND vodka ) OR ( absolut AND tune AND vodka AND wine ) OR '
  rule = rule + ' ( absolut AND tv commercial ~0 ) OR ( absolut AND vanilla vodka ~0 ) OR ( absolut AND veronique didry ~0 ) OR ( absolut AND vino y vodka ~0 ) OR ( absolut AND vodca com espumante ~0 ) OR ( absolut AND vodka and wine ~0 ) OR absolut OR ( absolut tune ~0 AND all night ~0 ) OR ( absolut tune ~0 AND blanda eggenschwiler ~0 ) OR absolut vodka ~0 OR ( absolut AND vodka ) OR ( absolut AND vodka y vino ~0 ) OR ( absolut AND vodka\'s ) OR ( absolut AND vodka-wine ) OR ( absolut AND vodkas ) OR ( absolut AND watkins ) OR ( absolut AND wodka ) OR ( absolut AND woodkid ) OR ( absolut AND woodkid\'s ) OR ( absolut AND yin ) OR ( absolut AND yin\'s ) OR ( absolut AND yiqing yin ~0 ) OR ( absolut AND yoann lazareth ~0 ) OR ( absolut AND yoann lemoine ~0 ) OR ( absolut AND zooey ) OR ( absolut AND 高瑀 ) OR ( absolut AND 陈曼 ) OR ( absolut AND absolut truths ~0 ) OR '
  rule = rule + ' ( absolut AND augmented reality ~0 ) OR ( absolute vodka ~0 AND 72 transformations ~0 ) OR ( absolute vodka ~0 AND gao yu ~0 ) OR ( absolute vodka ~0 AND greyhound ) OR ( absolute vodka ~0 AND lemon anderson ~0 ) OR ( absolute vodka ~0 AND oolong ) OR ( absolute vodka ~0 AND spike lee ~0 ) OR ( absolute vodka ~0 AND wild tea ~0 ) OR ( absolutvodka AND originality ) OR ( absolut ANDice bar ~0 ) OR ( absolut AND icebar ) OR ( absolut AND grey goose ~0 ) OR ( absolut AND rock edition ~0 ) OR ( absolut AND rupert sanders ~0 ) OR ( absolut AND vodca ) OR ( absolut AND vodka )OR ( absolut AND ny-z ) OR ( absolut AND anthem ) OR ( absolut AND bebida ) OR ( absolut AND boisson ) OR ( absolut AND botella ) OR ( absolut AND bottiglia ) OR ( absolut AND bottle ) OR ( absolut AND bouteille ) OR ( absolut AND cranberry ) OR ( absolut AND drinkspiration ) OR ( absolut AND frasco ) OR '
  rule = rule + ' ( absolut AND lydmar ) OR ( absolut AND drink ) OR ( absolut AND aska AND lost trees ~0 ) OR ( absolut AND wodka ) OR ( chelsea leyland ~0 AND absolut tune ~0 ) OR ( chelsealeyand AND absolutvodka_us ) OR ( elyx AND korean air ~0 ) OR ( forget it ~0 AND lemon drop ~0 AND absolut vodka ~0 ) OR ( gao yu ~0 AND bottle AND absolut ) OR ( grampa AND dark noir ~0 ) OR ( grampa AND next frame ~0 ) OR ( lemon drop ~0 AND absolut AND film ) OR ( lemon drop ~0 AND absolut AND video ) OR ( next frame ~0 AND absolut ) OR ( next frame ~0 AND experiment ) OR ( jardim vertical ~0 AND absolut ) OR ( projeto 365 dias ~0 AND absolut ) OR ( shm AND absolut vodka ~0 AND greyhound ) OR ( spike jonze ~0 AND absolut vodka ~0 ) OR ( spike jonze ~0 AND i\'m here ~0 ) OR ( spike jonze ~0 AND in an absolut world ~0 ) OR ( spike jonze ~0 AND short film ~0 ANDabsolut ) OR '
  rule = rule + ' ( swedish house mafia ~0 AND absolut AND greyhound ) OR ( swedishhousemafia AND greyhound ) OR absolut san francisco ~0 OR ( absolut AND yiğit yazıcı ~0 ) OR ( absolut AND vertical garden ~0 ) OR #absolutnight OR #absolutnights OR @elyx OR @absolut_elyx OR #absolutvodka OR #absolutwarhol OR ( warhol AND absolut ) OR ( art exchange ~0 AND absolut ) ] NOT ["@love_absolut" OR "@_absolut_truth" OR "@absolut_blank" OR "@absolutamber" OR "@d_absolut_truth" OR "@elyx__" OR "@socallme_elyx" OR "elyxyak" OR "erotikgirls" OR "formel 1" OR "formula 1" OR "dj smirnoff" OR "dj absolut" OR "dj_smirnoff" OR "dj_smirnoff_ice" OR "karin smirnoff" OR "karina smirnoff" OR "katrina smirnoff" OR "kyza smirnoff" OR "oleg smirnoff" OR "pere smirnoff" OR "quick get some smirnoff ice" OR "red bull media" OR "serg smirnoff" OR "serg_smirnoff" OR "smirnoff centre" OR "smirnoff hotel" OR '
  rule = rule + ' "smirnoff dj" OR "smirnoff music centre" OR "smirnoff turntable" OR "smirnoff type" OR "smirnoff wrote" OR "viagra" OR "victoria smirnoff" OR "yaakov smirnoff" OR "yakov smirnoff" OR "zmey smirnoff" OR "absolut nicht" OR "absolut nichts" OR "absolut repair" OR "absolut_blank" OR "absolut_truth" OR "absolut_watkins" OR "absolute_pepper" OR "dancing with the" OR "dancing with the stars" OR "natalia smirnoff" OR "chilling in the sea" OR "d_absolut_truth" OR "erotik girls" OR "garota_smirnoff" OR "nick smirnoff" OR "dimitri smirnoff" OR "diully kethellyn" OR "karina-smirnoff" OR "l\'oreal" OR "alexander smirnoff" OR "minichill" OR "anna smirnoff" OR "doctor smirnoff" OR "penis" OR "socallme_elyx" OR "nvidea" OR "von smirnoff" OR "absolut inte" OR "absolut värsta" OR "#rasism" OR "doodle" OR "le petit" OR "yak" OR "little things i like" OR "mouvmatin" OR '
  rule = rule + ' "arena naţională" OR "iphone 6" OR "windos" OR "mozilla" OR "http://forum.softpedia.com/" OR "scf" OR sex OR "sex video" OR toys OR "absolut garden"]'
  
  rt = PtRuleTranslator.new
  rt.translate_rule(rule, 'Sprinklr')

end
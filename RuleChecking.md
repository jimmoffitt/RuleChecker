
###Checking Rules

####For RuleChecker, here are the general goals/guiding principles:

[] Most (all?) of the time, we are scanning for unquoted clauses. If a rule clause is quoted we ignore it and are only 
looking for unquoted malformed syntax. So helper methods were written to scan and fix rules, working on only the unquoted
sections of rules.
 
Rules that are detected and fixed:
 * Unquoted 'Explicit AND (and 'and')' rules.
 * Unquoted lowercase 'or' rules.
 
Coming next?
 * Unquoted punctuation.
 
 
 
#####Detecting unquoted clauses: 
 
 
 
```ruby
 def unquoted_clause? rule, clause
 
     clauses = rule.scan(clause).count
     return false if clauses == 0
 
     parts = rule.split(clause)
 
     quotes = 0
     quotes_total = 0
 
     parts.each_with_index do |part, index|
 
       quotes = part.scan(/"/).count
       quotes_total = quotes_total + quotes
       
       return false if index >= clauses #Test if we are beyond the last of target clauses.
 
       return true f quotes_total.even? and part != "" then  #Then we have a unquoted clause.
     end
 
     false
 
   end
``` 
 
 
 
  

####Quoted or unquoted ANDs

 rule: ```one AND (\"this and that\" OR \"up AND down\" OR \"left and right\") AND direction```
 
 Here we care about first and last ANDs, but not neccesarily the quoted ANDs ones (although they are almost as bad...).
 
 For a total of 5 ANDs in the rule value... Are they quoted?: 
  
    1. First quoted? --> ands[0] does not contain a double-quote, so no.  SUM(quotes)[0] = zero(even) --> no, unquoted.
    2. Is second AND quoted? SUM(quotes)[0-1] = 1, _odd_ --> yes, in quotes.
    3. is third? SUM(quotes)[0-2] = 3, _odd_ --> yes, in quotes.
    4. Fourth? SUM(quotes)[0-3] = 5, _odd_ --> yes, in quotes.
    5. Fifth? SUM(quotes)[0-4] = 6, _even_ --> no, unquoted.
    

 ----> quoted AND if the sum of leading double quotes is odd.    
    
Ruby pseudo-code:
    
    ```
    AND = true if SUM(quotes)[].even?  #Bad rules we care most about...
    quoted_AND = true if not SUM(quotes)[].even?``` #Suspect rules... 
    ```


##Other notes 

Removing explicit ANDs and creating "corrected" rules is pretty straightforward. All you need to do is remove them from the rule value.

Handling cases of missing (or missed applied) parentheses and quotes is more complicated. Where should the added (or moved) items be placed? 

A starting point is a 'trial and error' process. Corrected rule candidates could be tested against a short search period and matched activities compared.  


### Missing parentheses

Lack of parentheses when both ANDs and ORs are used are suspect. When only ORs or only ANDs then paratheses have no effect.

```
go away OR leave here --> 2.1M
---> (go away OR leave) here --> 0.5K
```

Characterics/triggers:
* Contains no parentheses
* Contains unquoted " OR "
* Contains unquoted ` ` (white space indicating PowerTrack implicit AND)
 
[] How will parentheses be inserted?  Generate every possibility? 


go away OR leave here -- note that this is equivalent to (go way) OR (leave here)
  * --> (go away OR leave) here 
  * --> go (away OR leave) here 
  * --> go (away OR leave here) 

_Using ORs as opening/closing boundaries._



### Missing Quotes

```
Favorite City (Chicago OR San Francisco OR New York) -->  3,225
---> Favorite City (Chicago OR "San Francisco" OR "New York") -->  3,146 

```

Another example:

```
go away here --> 35,142

"go away" here --> 15,481
go "away here" --> 264
```

### Missing both

```
go away OR leave from store --> 1.2M
"go away" OR leave from store --> 1.2M
("go away" OR leave) from store --> 719
```






###Example Ruby parsing doodles:

```
rule = "\"this and that\" OR \"up AND down\" AND \"left and right\" OR direction" 
=> "\"this and that\" OR \"up AND down\" AND \"left and right\" OR direction"

pieces = rule.split('"')
=> ["", "this and that", " OR ", "up AND down", " AND ", "left and right", " OR direction"]

pieces.length = 7
pieces[0] = ''
pieces[6] = ' OR direction`
```

```
rule = "one AND (\"this and that\" OR \"up AND down\" OR \"left and right\") AND direction" 
=> "one AND (\"this and that\" OR \"up AND down\" OR \"left and right\") AND direction"

pieces = rule.split('"')
=> ["one AND (", "this and that", " OR ", "up AND down", " OR ", "left and right", ") AND direction"]

pieces.length = 7
pieces[0] = 'one AND ('
pieces[6] = ') AND direction'


ands = rule.upcase.split('AND')
=> ["ONE ", " (\"THIS ", " THAT\" OR \"UP ", " DOWN\" OR \"LEFT ", " RIGHT\") ", " DIRECTION"]

ands.length = 6
ands[0] = 'ONE ' 
ands[1] = ' ("THIS '
ands[2] = ' THAT" OR "UP '  
ands[3] = ' DOWN" OR "LEFT ' 
ands[4] = ' RIGHT")'
ands[5] = ' DIRECTION'

```

ford OR carter OR bush OR clinton president --> 5M
(ford OR carter OR bush OR clinton) president --> 177K

 
 
 
 
 




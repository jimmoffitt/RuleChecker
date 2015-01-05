
###Scanning Rules


####Quoted or unquoted ANDs

 rule: ```one AND (\"this and that\" OR \"up AND down\" OR \"left and right\") AND direction```
 
 Here we care about first and last ANDs, but not neccesarily the quoted ANDs ones (although they are almost as bad...).
 
 Five ANDs... Are they quoted?: 
 
    1 - First quoted? --> ands[0] does not contain a double-quote, so no.  SUM(quotes)[0] = zero(even) --> no, unquoted.
    2 - Is second AND quoted? SUM(quotes)[0-1] = 1, _odd_ --> yes, in quotes.
    3 - is third? SUM(quotes)[0-2] = 3, _odd_ --> yes, in quotes.
    4) Fourth? SUM(quotes)[0-3] = 5, _odd_ --> yes, in quotes.
    5) Fifth? SUM(quotes)[0-4] = 6, _even_ --> no, unquoted.
    
    
    ----> quoted AND if the sum of leading double quotes is odd.    
    
    ```
    AND = true if SUM(quotes)[].even?  #Bad rules we care most about...
    quoted_AND = true if not SUM(quotes)[].even?``` #Suspect rules... 
    ```
 




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



 
 
 
 
 





###Scanning Rules


####Quoted or unquoted ANDs

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
ands[5] = ' DIRECTION'

```





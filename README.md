# shanks

custom & simple parser for subset of xml. specifically made for a niche case of allowing easy development of web pages for non-tech people (such as charities and whatnot).

# usage

**note:** requires lua (preferrably version >= 5.5)

to use, type the command (and use the following format)
`lua shanks.lua <RULES_FILE> <XML FILES ...>`

for example, if my rules file was defined as `rules.lua` in the current directory and I wanted to parse `aboutme.xml` and `home.xml` I would do:
`lua shanks.lua rules aboutme.xml home.xml`

# rules

rules are defined simply by lua functions.

for example, if we want to make a rule for the tag `<warning>`, our `rules.lua` file would look like:

```lua
return {
    ["warning"] = function(attributes, inner_html)
        return string.format("<button %s>%s</button>", attributes["important"] or "", inner_html)
    end
}
```

adding other rules is simply just defining more tags. you can additionally also set a rule for the root (as the xml gets wrapped in a special node called `<root>...</root>`.). for example, if we want the root tag to 'disappear' we could add:

```lua
return {
    ["root"] = function(attributes, inner_html)
        return string.format("%s", inner_html)
    end,
    ["warning"] = function(attributes, inner_html)
        return string.format("<button %s>%s</button>", attributes["important"] or "", inner_html)
    end
}
```

rules are simple, and they should be. the idea is that it shouldn't be complicated to, for example, a charity worker to write a basic website or a new page about a fundraising event.

this isn't meant to be fancy, it just solves a _really niche_ area of mine.

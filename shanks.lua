--[[
shanks but lua version (originally was gonna do in C but.. not worth it)
the idea is XML -> lua table -> apply transformation functions -> output html.
NOTE: very confined XML subset so not entirely XML compliant...

structure looks like:
{
    tag = "TAG",
    attributes = { title = "TITLE" },
    children = {
        "empty plain text",
        { tag = "TAG", ...}, ...
    }
}

also sorry for the reader about the semi-colons. i was writing in C like.. 30 mins ago so i keep forgetting myself
]]

local ORANGE_BG       = "\27[48;5;208m"
local PURPLE_BG       = "\27[48;5;55m"
local GREEN_BG        = "\27[48;5;34m"
local BLACK_TXT       = "\27[30m"
local WHITE_TXT       = "\27[97m"
local BOLD            = "\27[1m"
local RESET           = "\27[0m"

local DEBUG           = false

local OUTPUT_FILE_EXT = ".html"

--[[
debug print
]]
local function dprint(...)
    if not DEBUG then return end
    local label = PURPLE_BG .. WHITE_TXT .. BOLD .. " debug " .. RESET;
    print(label .. " " .. ...);
end

--[[
pretty assert
i think it looks nice
you always have to have fun making things!
]]
local function passert(cond, msg)
    if not cond then
        local error_label = ORANGE_BG .. BLACK_TXT .. BOLD .. " error " .. RESET;
        print("\n" .. error_label .. " " .. (msg or "condition was false") .. "\n");
        os.exit(1);
    end
end

--[[
success print
]]
local function sprint(...)
    local label = GREEN_BG .. WHITE_TXT .. BOLD .. " success " .. RESET;
    print(label .. " " .. ...);
end

--[[
warning print
]]
local function wprint(...)
    local label = ORANGE_BG .. WHITE_TXT .. BOLD .. " warning " .. RESET;
    print(label .. " " .. ...);
end
--[[
parses xml into table struct
plain text just represented as string
nodes represented w/ table
]]
local function parse_xml(xml)
    local stack = {};
    local stack_top = 1;

    stack[stack_top] = {
        tag = "root",
    }

    --[[
        three types of tags
        <open>
        </close>
        <self-close/>

        tags can have attributes such as:
        <popup warning title="Hello!"/>
    ]]

    -- iterate over every character/token
    local str_extract = ""
    local i = 1;
    while i < #xml do
        local c = xml:sub(i, i);
        if c == "<" then
            -- FIRST! lets make sure we save our str_extract
            if str_extract ~= "" then
                local parent_node = stack[stack_top]
                if not parent_node.children then
                    parent_node.children = {}
                end

                table.insert(parent_node.children, str_extract)
                str_extract = ""
            end
            -- we can then extract using lua parsing!
            local name, attributes, new_cursor = xml:match("([%w_-]+)([^>]*)>()", i + 1)
            --[[
            a little breakdown of this (consult https://www.lua.org/pil/20.2.html for more info)
            brackets are a capture group -> so once only
            and the square brackets is the chracter set
            %w -> alphanumeric characters, and the rest is self explanatory in that bit
            the + means 1 or more repetitions meaning look for a whole string of the character sequence
            for the second brackets we make sure NOT to include the closing tag, and we expect 0 or more repetitions
            also we can use the last () to grab the cursor
            ]]
            if xml:sub(i + 1, i + 1) == "/" then
                -- check if this is a closing tag..
                dprint("got closing tag for " .. name)
                passert(stack[stack_top].tag == name, "mismatched tags")
                stack_top = stack_top - 1

                local parent_node = stack[stack_top]
                if not parent_node.children then
                    parent_node.children = {}
                end

                table.insert(parent_node.children, stack[stack_top + 1]) -- put old stack top..

                -- advance cursor by new_cursor
                i = new_cursor - 1

                goto continue
            end
            dprint("got opening tag for " .. name)
            dprint("-- tag attributes: " .. attributes)

            local self_closing_tag = false

            -- check for self closing tags
            if attributes ~= nil and attributes:sub(-1, -1) == "/" then
                -- no need to move stack
                dprint("got self closing tag for " .. name)
                self_closing_tag = true
            end

            -- parse attributes
            local attributes_tbl = {}
            for token in attributes:gmatch("%S+") do
                local key, value = token:match("^(.-)=(.+)$") -- try to get key=value

                if key then
                    -- we have a kv pair
                    attributes_tbl[key] = value
                else
                    -- we just have standalone flag we set to true
                    attributes_tbl[token] = true
                end
            end

            -- we then construct the.. node
            local node = {
                tag = name,
                attributes = attributes_tbl
            }

            -- the end bit (make sure cursor plays nicely n we account for self closing tags)
            i = new_cursor - 1
            if self_closing_tag == true then
                local parent_node = stack[stack_top]
                if not parent_node.children then
                    parent_node.children = {}
                end

                table.insert(parent_node.children, node)
                goto continue
            end
            stack_top = stack_top + 1
            stack[stack_top] = node -- we set the name/node to make sure tags r closed correctly & what to expect
        else
            str_extract = str_extract .. c
        end

        ::continue::
        i = i + 1;
    end

    return stack[stack_top]
end

--[[
recursive rendering (simple)
renders all children first
]]
local function render_node(node, rules)
    if type(node) == "string" then
        return node; -- plain txt
    end

    local inner_html = ""
    if node.children then
        for _, child in ipairs(node.children) do
            inner_html = inner_html .. render_node(child, rules);
        end
    end

    -- make sure we apply lua function if exists as tag
    local renderer = rules[node.tag];
    if renderer then
        return renderer(node.attributes or {}, inner_html);
    else
        -- we fallback to standard HTML tag if no custom rule exists
        return string.format("<%s>%s</%s>", node.tag, inner_html, node.tag);
    end
end

local function main()
    wprint("this WILL overwrite any files being parsed to, press any key to continue (or ctrl+c to cancel):")
    io.read()
    local rules_fn = arg[1];
    passert(rules_fn ~= nil, "expected rules file to be passed as first argument");

    -- require but not dodgy??
    local succ, rules = pcall(require, rules_fn);
    passert(succ ~= false, "could not load rules file")

    local file_n = #arg
    for i = 2, file_n, 1 do
        local current_fn = arg[i]
        -- read
        local file, errmsg = io.open(current_fn, "r")
        passert(file ~= nil, "could not open provided file " .. current_fn .. " because " .. (errmsg or "none"))

        local file_contents = file:read("a")

        local root_node = parse_xml(file_contents)
        local rendered_output = render_node(root_node, rules)

        -- write
        -- some special-ness to extract extension if exists
        local of_name
        local dot_pos_r = current_fn:reverse():find("%.") -- % for escaping
        if not dot_pos_r then
            -- do not need to worry
            of_name = current_fn .. OUTPUT_FILE_EXT
        else
            of_name = current_fn:sub(1, #current_fn - dot_pos_r) .. OUTPUT_FILE_EXT
        end

        local o_file = io.open(of_name, "w")
        passert(o_file ~= nil, "could not open output file: " .. of_name)
        o_file:write(rendered_output)

        sprint(string.format("parsed %s and wrote to %s", current_fn, of_name))
    end
end

main()

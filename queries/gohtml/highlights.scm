; HTML tags
(tag_name) @tag
(start_tag
  "<" @tag.delimiter
  ">" @tag.delimiter)
(self_closing_tag
  "<" @tag.delimiter
  "/>" @tag.delimiter)
(end_tag
  "</" @tag.delimiter
  ">" @tag.delimiter)

(attribute_name) @tag.attribute
(attribute_text) @string
(quoted_attribute_value
  "\"" @string)
(quoted_attribute_value
  "'" @string)
(entity) @character.special

(comment) @comment
(comment_text) @comment
(doctype) @constant

; Template delimiters including whitespace trim markers
"{{" @punctuation.special
"}}" @punctuation.special
"{{-" @punctuation.special
"-}}" @punctuation.special

; Control keywords
"if" @keyword.conditional
"else" @keyword.conditional
"end" @keyword
"range" @keyword.repeat
"with" @keyword
"define" @keyword
"template" @keyword
"block" @keyword

; Expressions
(field) @variable.member
(variable) @variable
(dot) @variable.builtin
(identifier) @variable
(function_call
  function: (identifier) @function.call)

((identifier) @function.builtin
  (#any-of? @function.builtin
    "and" "or" "not" "len" "index" "slice" "call"
    "print" "printf" "println"
    "html" "js" "urlquery"
    "eq" "ne" "lt" "le" "gt" "ge"))

"|" @operator
":=" @operator
(assignment "=" @operator)
"," @punctuation.delimiter
"(" @punctuation.bracket
")" @punctuation.bracket

(interpreted_string_literal) @string
(raw_string_literal) @string
(string_content) @string
(escape_sequence) @string.escape
(rune_literal) @string
(int_literal) @number
(float_literal) @number
(imaginary_literal) @number
(true) @boolean
(false) @boolean
(nil) @constant.builtin

(template_comment) @comment
(comment_action) @comment

(raw_text) @none

(ERROR) @error

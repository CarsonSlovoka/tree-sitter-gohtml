/**
 * @file HTML + Go html/template / text/template grammar for tree-sitter
 * @license MIT
 *
 * HTML tag structure is modelled after tree-sitter-html
 *   https://github.com/tree-sitter/tree-sitter-html
 *   Copyright (c) 2018 Max Brunsfeld, MIT License
 *
 * Template expression language is modelled after ngalaiko/tree-sitter-go-template
 *   https://github.com/ngalaiko/tree-sitter-go-template
 *   Copyright (c) Nikita Galaiko, MIT License
 *
 * This grammar is HTML-first: tags, attributes, comments, script and style
 * elements are first-class nodes. Go template actions are also first-class
 * and may appear in text, attribute values, between tags, and as structured
 * control actions that wrap HTML nodes.
 *
 * Trade-offs versus tree-sitter-html + injection:
 * - No external scanner, so HTML5 implicit end tags (optional </p>, </li>)
 *   are not recovered the same way as tree-sitter-html.
 * - Matching start/end tag names are not validated.
 * - Control actions inside attribute values / script / style are parsed as
 *   flat {{ ... }} actions, not as wrappers of HTML elements.
 * - <script> / <style> bodies are raw text plus template actions, not JS/CSS
 *   in the primary tree. Optional JS/CSS highlighting uses injections.scm.
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

const PREC = {
  else_if: 2,
  call: 2,
  selector: 3,
  pipe: 1,
};

module.exports = grammar({
  name: 'gohtml',

  extras: (_) => [/\s+/],

  word: ($) => $.identifier,

  conflicts: ($) => [
    // LR(1) cannot see past `{{else` to decide else-if vs else.
    [$.else_clause],
    [$.else_if_clause],
  ],

  rules: {
    document: ($) => repeat($._document_node),

    _document_node: ($) =>
      choice($._node, $.unmatched_end, $.unmatched_else, $.unmatched_else_if),

    _node: ($) =>
      choice(
        $.doctype,
        $.comment,
        $.element,
        $.script_element,
        $.style_element,
        $.text,
        $.entity,
        $.if_action,
        $.range_action,
        $.with_action,
        $.define_action,
        $.block_action,
        $.pipeline_action,
        $.comment_action,
        $.template_action,
      ),

    // ------------------------------------------------------------------
    // HTML
    // ------------------------------------------------------------------

    doctype: (_) => token(seq(/<[!][Dd][Oo][Cc][Tt][Yy][Pp][Ee]/, /[^>]*/, '>')),

    comment: ($) =>
      seq(
        '<!--',
        repeat(choice($.comment_text, $._attr_action)),
        '-->',
      ),

    comment_text: (_) => token(prec(-1, /([^-{]+|-[^-]|--+[^>]|\{[^{])+/)),

    element: ($) =>
      prec(
        0,
        choice(
          seq($.start_tag, repeat($._node), $.end_tag),
          $.self_closing_tag,
        ),
      ),

    start_tag: ($) =>
      seq(
        '<',
        alias($._html_tag_name, $.tag_name),
        repeat($._tag_content),
        '>',
      ),

    self_closing_tag: ($) =>
      seq(
        '<',
        alias($._html_tag_name, $.tag_name),
        repeat($._tag_content),
        '/>',
      ),

    end_tag: ($) => seq('</', alias($._html_tag_name, $.tag_name), '>'),

    // Lower precedence than script/style tag-name tokens so those elements
    // win the lexer conflict on the words "script" and "style".
    _html_tag_name: (_) => token(prec(1, /[A-Za-z][A-Za-z0-9:-]*/)),

    _tag_content: ($) => choice($.attribute, $._attr_action),

    attribute: ($) =>
      seq(
        $.attribute_name,
        optional(seq('=', choice($.quoted_attribute_value, $.unquoted_attribute_value))),
      ),

    attribute_name: (_) => /[^<>"'/=\s{}]+/,

    quoted_attribute_value: ($) =>
      choice(
        seq(
          '"',
          repeat(choice(alias($._attr_text_dq, $.attribute_text), $._attr_action)),
          '"',
        ),
        seq(
          "'",
          repeat(choice(alias($._attr_text_sq, $.attribute_text), $._attr_action)),
          "'",
        ),
      ),

    unquoted_attribute_value: ($) =>
      prec.right(
        repeat1(choice(alias($._attr_text_unquoted, $.attribute_text), $._attr_action)),
      ),

    _attr_text_dq: (_) => token(prec(-1, /([^"{]+|\{[^{])+/)),
    _attr_text_sq: (_) => token(prec(-1, /([^'{]+|\{[^{])+/)),
    _attr_text_unquoted: (_) => token(prec(-1, /([^<>"'=\s{]+|\{[^{])+/)),

    entity: (_) => /&(#([xX][0-9a-fA-F]{1,6}|[0-9]{1,5})|[A-Za-z][A-Za-z0-9]{0,30});?/,

    // Text stops before '<', '{{', or '&' entity starts. A lone '{' is text.
    text: (_) => token(prec(-1, /([^<&{]+|\{[^{]|&[^#A-Za-z])+/)),

    script_element: ($) =>
      prec(
        2,
        seq(
          alias($.script_start_tag, $.start_tag),
          repeat(choice($.raw_text, $._attr_action)),
          alias($.script_end_tag, $.end_tag),
        ),
      ),

    style_element: ($) =>
      prec(
        2,
        seq(
          alias($.style_start_tag, $.start_tag),
          repeat(choice($.raw_text, $._attr_action)),
          alias($.style_end_tag, $.end_tag),
        ),
      ),

    script_start_tag: ($) =>
      seq(
        '<',
        alias(token(prec(2, /[Ss][Cc][Rr][Ii][Pp][Tt]/)), $.tag_name),
        repeat($._tag_content),
        '>',
      ),

    style_start_tag: ($) =>
      seq(
        '<',
        alias(token(prec(2, /[Ss][Tt][Yy][Ll][Ee]/)), $.tag_name),
        repeat($._tag_content),
        '>',
      ),

    script_end_tag: ($) =>
      seq(
        '</',
        alias(token(prec(2, /[Ss][Cc][Rr][Ii][Pp][Tt]/)), $.tag_name),
        '>',
      ),

    style_end_tag: ($) =>
      seq(
        '</',
        alias(token(prec(2, /[Ss][Tt][Yy][Ll][Ee]/)), $.tag_name),
        '>',
      ),

    // Raw text inside script/style: anything except '{{' or the closing tag.
    raw_text: (_) =>
      token(prec(-1, /([^<{]+|\{[^{]|<[^/]|<\/[^Ss])+/)),

    // ------------------------------------------------------------------
    // Template actions (structured wrappers for HTML)
    // ------------------------------------------------------------------

    if_action: ($) =>
      prec(
        2,
        seq(
          $.if_clause,
          repeat($._node),
          repeat($.else_if_clause),
          optional($.else_clause),
          $.end_clause,
        ),
      ),

    if_clause: ($) =>
      seq($._left_delim, 'if', $._pipeline, $._right_delim),

    else_if_clause: ($) =>
      seq(
        $._left_delim,
        'else',
        'if',
        $._pipeline,
        $._right_delim,
        repeat($._node),
      ),

    else_clause: ($) =>
      seq($._left_delim, 'else', $._right_delim, repeat($._node)),

    end_clause: ($) => seq($._left_delim, 'end', $._right_delim),

    range_action: ($) =>
      prec(
        2,
        seq(
          $.range_clause,
          repeat($._node),
          optional($.else_clause),
          $.end_clause,
        ),
      ),

    range_clause: ($) =>
      seq($._left_delim, 'range', $._pipeline, $._right_delim),

    with_action: ($) =>
      prec(
        2,
        seq(
          $.with_clause,
          repeat($._node),
          optional($.else_clause),
          $.end_clause,
        ),
      ),

    with_clause: ($) =>
      seq($._left_delim, 'with', $._pipeline, $._right_delim),

    define_action: ($) =>
      prec(
        2,
        seq($.define_clause, repeat($._node), $.end_clause),
      ),

    define_clause: ($) =>
      seq($._left_delim, 'define', $._string_literal, $._right_delim),

    block_action: ($) =>
      prec(
        2,
        seq($.block_clause, repeat($._node), $.end_clause),
      ),

    block_clause: ($) =>
      seq(
        $._left_delim,
        'block',
        $._string_literal,
        optional($._pipeline),
        $._right_delim,
      ),

    template_action: ($) =>
      seq(
        $._left_delim,
        'template',
        $._string_literal,
        optional($._pipeline),
        $._right_delim,
      ),

    pipeline_action: ($) =>
      seq($._left_delim, $._pipeline, $._right_delim),

    comment_action: ($) =>
      seq($._left_delim, $.template_comment, $._right_delim),

    template_comment: (_) =>
      token.immediate(seq('/*', /[^*]*\*+([^/*][^*]*\*+)*/, '/')),

    // Flat actions used inside attributes, comments, script and style.
    _attr_action: ($) =>
      choice(
        $.pipeline_action,
        $.comment_action,
        $.template_action,
        $.if_clause,
        $.range_clause,
        $.with_clause,
        $.define_clause,
        $.block_clause,
        $.end_clause,
        alias($._else_if_head, $.else_if_clause),
        alias($._else_head, $.else_clause),
      ),

    _else_if_head: ($) =>
      seq($._left_delim, 'else', 'if', $._pipeline, $._right_delim),

    _else_head: ($) => seq($._left_delim, 'else', $._right_delim),

    unmatched_end: ($) => $.end_clause,
    unmatched_else: ($) => alias($._else_head, $.else_clause),
    unmatched_else_if: ($) => alias($._else_if_head, $.else_if_clause),

    // '{{- ' consumes the required whitespace after the trim marker so that
    // token.immediate comments ({{/* */}} and {{- /* */ -}}) both work.
    _left_delim: (_) =>
      choice(
        token('{{'),
        alias(token(seq('{{-', /\s/)), '{{-'),
      ),
    _right_delim: (_) => choice(token('}}'), token('-}}')),

    // ------------------------------------------------------------------
    // Pipelines and expressions
    // ------------------------------------------------------------------

    _pipeline: ($) => choice($.assignment, $.chained_pipeline),

    assignment: ($) =>
      seq(
        $.variable,
        optional(seq(',', $.variable)),
        choice(':=', '='),
        $.chained_pipeline,
      ),

    chained_pipeline: ($) =>
      prec.left(PREC.pipe, seq($._command, repeat(seq('|', $._command)))),

    _command: ($) => choice($.function_call, $._operand),

    function_call: ($) =>
      prec.right(PREC.call, seq(field('function', $.identifier), repeat1($._operand))),

    _operand: ($) =>
      choice(
        $.parenthesized_pipeline,
        $.selector_expression,
        $.field,
        $.variable,
        $.dot,
        $.identifier,
        $._literal,
      ),

    parenthesized_pipeline: ($) => seq('(', $._pipeline, ')'),

    // Field after an operand must be adjacent (no extras) so that
    // `printf .Name` is a call and `$u.Name` / `.User.Name` are selectors.
    _immediate_field: ($) =>
      alias(token.immediate(seq('.', /[A-Za-z_][A-Za-z0-9_]*/)), $.field),

    selector_expression: ($) =>
      prec.left(
        PREC.selector,
        choice(
          seq($.field, repeat1($._immediate_field)),
          seq($.variable, repeat1($._immediate_field)),
          seq($.identifier, repeat1($._immediate_field)),
          seq($.parenthesized_pipeline, repeat1($._immediate_field)),
        ),
      ),

    field: (_) => token(seq('.', /[A-Za-z_][A-Za-z0-9_]*/)),

    variable: (_) => token(seq('$', optional(/[A-Za-z_][A-Za-z0-9_]*/))),

    dot: (_) => token(prec(-1, '.')),

    identifier: (_) => /[A-Za-z_][A-Za-z0-9_]*/,

    _literal: ($) =>
      choice(
        $._string_literal,
        $.rune_literal,
        $.int_literal,
        $.float_literal,
        $.imaginary_literal,
        $.true,
        $.false,
        $.nil,
      ),

    _string_literal: ($) =>
      choice($.interpreted_string_literal, $.raw_string_literal),

    interpreted_string_literal: ($) =>
      seq(
        '"',
        repeat(choice($.string_content, $.escape_sequence)),
        token.immediate('"'),
      ),

    string_content: (_) => token.immediate(prec(1, /[^"\n\\]+/)),

    escape_sequence: (_) =>
      token.immediate(
        seq(
          '\\',
          choice(
            /[^xuU]/,
            /\d{2,3}/,
            /x[0-9a-fA-F]{2,}/,
            /u[0-9a-fA-F]{4}/,
            /U[0-9a-fA-F]{8}/,
          ),
        ),
      ),

    raw_string_literal: (_) => token(seq('`', /[^`]*/, '`')),

    rune_literal: (_) =>
      token(
        seq(
          "'",
          choice(
            /[^'\\]/,
            seq(
              '\\',
              choice(
                /[^xuU]/,
                /\d{2,3}/,
                /x[0-9a-fA-F]{2,}/,
                /u[0-9a-fA-F]{4}/,
                /U[0-9a-fA-F]{8}/,
              ),
            ),
          ),
          "'",
        ),
      ),

    int_literal: (_) =>
      token(
        seq(
          optional(/[+-]/),
          choice(
            /0[xX][0-9a-fA-F_]+/,
            /0[bB][01_]+/,
            /0[oO]?[0-7_]+/,
            /[1-9][0-9_]*/,
            '0',
          ),
        ),
      ),

    float_literal: (_) =>
      token(
        seq(
          optional(/[+-]/),
          choice(
            /[0-9_]*\.[0-9_]+([eE][+-]?[0-9_]+)?/,
            /[0-9_]+[eE][+-]?[0-9_]+/,
            /0[xX][0-9a-fA-F_]*\.[0-9a-fA-F_]+[pP][+-]?[0-9_]+/,
          ),
        ),
      ),

    imaginary_literal: (_) =>
      token(
        seq(
          optional(/[+-]/),
          choice(/[0-9_]+/, /[0-9_]*\.[0-9_]+([eE][+-]?[0-9_]+)?/),
          'i',
        ),
      ),

    true: (_) => 'true',
    false: (_) => 'false',
    nil: (_) => 'nil',
  },

  reserved: {
    global: ($) => [
      'if',
      'else',
      'end',
      'range',
      'with',
      'define',
      'template',
      'block',
    ],
  },
});

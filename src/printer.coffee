{merge, dump: _dump, extend} = require './helpers'

#### CodeFragment

# The various nodes defined below all compile to a collection of **CodeFragment** objects.
# A CodeFragments is a block of generated code, and the location in the source file where the code
# came from. CodeFragments can be assembled together into working code just by catting together
# all the CodeFragments' `code` snippets, in order.
exports.CodeFragment = class CodeFragment
  constructor: (parent, code) ->
    @code = "#{code}"
    @type = parent?.constructor?.name or 'unknown'
    @locationData = parent?.locationData
    @comments = parent?.comments

  toString: ->
    # This is only intended for debugging.
    "#{@code}#{if @locationData then ": " + locationDataToString(@locationData) else ''}"

printStatementSequence = (body, o) ->
  # o = merge o, level: LEVEL_TOP
  # TODO: directives
  fragments = []
  for stmt, index in body
    fragments.push @makeCode '\n' if index and o.spaced
    fragments.push @print(stmt, merge o, spaced: no, front: yes)...
  fragments

asStatement = (fragments, o) ->
  fragments.unshift @makeCode o.indent
  fragments.push @makeCode ';\n'
  fragments

wrapInParensIfAbove = (level) -> (fragments, o) ->
  return fragments unless o.level > level
  [@makeCode('('), fragments..., @makeCode(')')]

printer =
  File: (o) ->
    o.indent = if o.bare then '' else TAB
    o.spaced = yes

    @print @program, o
  Program: (o) ->
    @printStatementSequence @body, o
  VariableDeclaration: (o) ->
    fragments = [@makeCode 'var ']
    for declaration, index in @declarations
      fragments.push ', ' if index
      fragments.push @print(declaration, o)...
    @asStatement fragments, o
  VariableDeclarator: (o) ->
    @print @id, o
  ExpressionStatement: (o) ->
    @asStatement @print(@expression, o), o
  AssignmentExpression: (o) ->
    fragments = []
    fragments.push @print(@left, o)...
    fragments.push @makeCode " #{@operator} "
    fragments.push @print(@right, o)...
    fragments
    # @wrapInParensIfAbove(LEVEL_LIST) fragments, o
  Identifier: (o) ->
    [@makeCode @name]
  NumericLiteral: (o) ->
    [@makeCode @extra.raw]
  StringLiteral: (o) ->
    [@makeCode @extra.raw]
  CallExpression: (o) ->
    fragments = []
    fragments.push @print(@callee, o)...
    fragments.push @makeCode '('
    for arg, index in @arguments
      fragments.push @makeCode ', ' if index
      fragments.push @print(arg, o)...
    fragments.push @makeCode ')'
    fragments
  FunctionExpression: (o) ->
    fragments = []
    fragments.push @makeCode 'function'
    fragments.push @makeCode '('
    for param, index in @params
      fragments.push @makeCode ', ' if index
      fragments.push @print(param, o)...
    fragments.push @makeCode ')'
    fragments.push @makeCode ' '
    fragments.push @print(@body, o)...
    fragments
  BlockStatement: (o) ->
    fragments = []
    o = indent o
    fragments.push @makeCode '{'
    body = @printStatementSequence @body, o
    fragments.push @makeCode '\n' if body.length
    fragments.push body...
    fragments.push @makeCode '}'
    fragments
  ReturnStatement: (o) ->
    fragments = [@makeCode 'return']
    if @argument
      fragments.push @makeCode(' '), @print(@argument, o)...
    @asStatement fragments, o
  MemberExpression: (o) ->
    fragments = []
    fragments.push @print(@object, o)...
    property = @print @property, o
    if @computed
      fragments.push @makeCode('['), property..., @makeCode(']')
    else
      fragments.push @makeCode('.'), property...
    fragments
  BooleanLiteral: (o) ->
    [@makeCode if @value then 'true' else 'false']

makeCode = (code) ->
  new CodeFragment @, code

nodePrint = (node, o) ->
  node.parent = @
  printed = print node, o
  return printed unless needsParens node, o
  [node.makeCode('('), printed..., node.makeCode(')')]

exports.print = print = (node, o) ->
  extend node, {
    makeCode, printStatementSequence, wrapInParensIfAbove, asStatement
    print: nodePrint
  }
  # node.tab = o.indent
  dump {missing: node} unless printer[node.type]
  printer[node.type].call node, o

indent = (o) ->
  merge o, indent: o.indent + TAB

TAB = '  '

# Levels indicate a node's position in the AST. Useful for knowing if
# parens are necessary or superfluous.
LEVEL_TOP    = 1  # ...;
LEVEL_PAREN  = 2  # (...)
LEVEL_LIST   = 3  # [...]
LEVEL_COND   = 4  # ... ? x : y
LEVEL_OP     = 5  # !...
LEVEL_ACCESS = 6  # ...[0]

needsParens = (node, o) ->
  {type, parent} = node

  return yes if o.front and type in ['FunctionExpression']
  switch type
    when 'AssignmentExpression'
      switch parent.type
        when 'ReturnStatement'
          yes

dump = (obj) -> _dump merge obj, parent: null

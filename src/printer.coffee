{merge, dump: _dump, extend, isString, del} = require './helpers'

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
    fragments.push '\n' if index and o.spaced
    fragments.push @print(stmt, merge o, spaced: no, front: yes, asStatement: yes)...
  fragments

asStatement = (fragments, o) ->
  fragments.unshift o.indent
  fragments.push ';\n'
  fragments

wrapInParensIfAbove = (level) -> (fragments, o) ->
  return fragments unless o.level > level
  [@makeCode('('), fragments..., @makeCode(')')]

wrapInBraces = (fragments, o) ->
  ['{', fragments..., '}']

printAssignment = (o) ->
  fragments = []
  fragments.push @print(@left, o)...
  fragments.push " #{@operator ? '='} "
  fragments.push @print(@right, o)...
  fragments
  # @wrapInParensIfAbove(LEVEL_LIST) fragments, o

printObject = (o) ->
  fragments = []
  isCompact = yes
  for {shorthand} in @properties when not shorthand
    isCompact = no
    break
  fragments.push '\n' unless isCompact
  for prop, index in @properties
    if index
      fragments.push ','
      fragments.push if isCompact then ' ' else '\n'
    fragments.push o.indent + TAB unless isCompact
    fragments.push @print(prop, if isCompact then o else indent o)...
  fragments.push '\n' + o.indent unless isCompact
  @wrapInBraces fragments

printer =
  File: (o) ->
    o.indent = if o.bare then '' else TAB
    o.spaced = yes

    @print @program, o
  Program: (o) ->
    @printStatementSequence @body, o
  VariableDeclaration: (o) ->
    fragments = ['var ']
    for declaration, index in @declarations
      fragments.push ', ' if index
      fragments.push @print(declaration, o)...
    fragments
  VariableDeclarator: (o) ->
    @print @id, o
  ExpressionStatement: (o) ->
    @print @expression, merge o, front: yes
  AssignmentExpression: printAssignment
  AssignmentPattern: printAssignment
  Identifier: (o) ->
    [@name]
  NumericLiteral: (o) ->
    [@extra.raw]
  StringLiteral: (o) ->
    [@extra.raw]
  RegExpLiteral: (o) ->
    [@extra.raw]
  BooleanLiteral: (o) ->
    [if @value then 'true' else 'false']
  NullLiteral: (o) ->
    ['null']
  CallExpression: (o) ->
    fragments = []
    fragments.push @print(@callee, o, LEVEL_ACCESS)...
    fragments.push '('
    for arg, index in @arguments
      fragments.push ', ' if index
      fragments.push @print(arg, o)...
    fragments.push ')'
    fragments
  FunctionExpression: (o) ->
    fragments = []
    fragments.push 'function'
    fragments.push '('
    for param, index in @params
      fragments.push ', ' if index
      fragments.push @print(param, o)...
    fragments.push ')'
    fragments.push ' '
    fragments.push @print(@body, o)...
    fragments
  BlockStatement: (o) ->
    return ['{}'] unless @body.length
    fragments = []
    fragments.push '{'
    fragments.push '\n'
    body = @printStatementSequence @body, indent o
    fragments.push body...
    fragments.push o.indent + '}'
    fragments
  ReturnStatement: (o) ->
    fragments = ['return']
    if @argument
      fragments.push ' ', @print(@argument, o)...
    fragments
  MemberExpression: (o) ->
    fragments = []
    fragments.push @print(@object, o, LEVEL_ACCESS)...
    property = @print @property, o
    if @computed
      fragments.push '[', property..., ']'
    else
      fragments.push '.', property...
    fragments
  ObjectPattern: printObject
  ObjectExpression: printObject
  ObjectProperty: (o) ->
    fragments = []
    key = @print @key, o
    return key if @shorthand
    fragments.push '[' if @computed
    fragments.push key...
    fragments.push ']' if @computed
    fragments.push ': '
    fragments.push @print(@value, o)...
    fragments
  ArrayExpression: (o) ->
    return ['[]'] unless @elements.length
    fragments = []
    fragments.push '['
    for element, index in @elements
      fragments.push ', ' if index
      fragments.push @print(element, o)...
    fragments.push ']'
    fragments
  TemplateLiteral: (o) ->
    fragments = []
    fragments.push '`'
    for quasi, index in @quasis
      fragments.push @print(quasi, o)...
      expression = @expressions[index]
      if expression
        fragments.push '${'
        fragments.push @print(expression, o)...
        fragments.push '}'
    fragments.push '`'
    fragments
  TemplateElement: (o) ->
    [@value.raw]
  ForStatement: (o) ->
    fragments = []
    fragments.push 'for ('
    fragments.push @print(@init, o)...
    fragments.push '; '
    fragments.push @print(@test, o)...
    fragments.push '; '
    fragments.push @print(@update, o)...
    fragments.push ') '
    fragments.push @print(@body, o)...
    fragments
  SequenceExpression: (o) ->
    fragments = []
    for expression, index in @expressions
      fragments.push ', ' if index
      fragments.push @print(expression, o)...
    fragments
  BinaryExpression: (o) ->
    fragments = []
    fragments.push @print(@left, o)...
    fragments.push " #{@operator} "
    fragments.push @print(@right, o)...
    fragments
  UnaryExpression: (o) ->
    fragments = []
    fragments.push @operator
    fragments.push @print(@argument, o)...
    fragments
  UpdateExpression: (o) ->
    fragments = []
    fragments.push @operator if @prefix
    fragments.push @print(@argument, o)...
    fragments.push @operator unless @prefix
    fragments
  IfStatement: (o) ->
    fragments = []
    fragments.push 'if ('
    fragments.push print(@test, o)...
    fragments.push ') '
    fragments.push print(@consequent, o)...
    if @alternate
      fragments.push ' else '
      fragments.push print(@alternate, o)...
    fragments
  ConditionalExpression: (o) ->
    fragments = []
    fragments.push print(@test, o)...
    fragments.push ' ? '
    fragments.push print(@consequent, o)...
    fragments.push ' : '
    fragments.push print(@alternate, o)...
    fragments

makeCode = (code) ->
  new CodeFragment @, code

fragmentize = (fragments, node) ->
  for fragment in fragments
    if isString fragment
      node.makeCode fragment
    else
      fragment

nodePrint = (node, o, level) ->
  o = merge o, {level} if level
  node.parent = @
  printed = fragmentize print(node, merge o, front: no), node
  return printed unless needsParens node, o
  [node.makeCode('('), printed..., node.makeCode(')')]

exports.print = print = (node, o) ->
  _asStatement = del o, 'asStatement'
  extend node, {
    makeCode, printStatementSequence, wrapInBraces, asStatement
    print: nodePrint
  }
  # node.tab = o.indent
  console.log {missing: node} unless printer[node.type]
  printed = printer[node.type].call node, o
  return printed unless _asStatement
  node.asStatement printed, o

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
  {level} = o

  return yes if o.front and (
    type in ['FunctionExpression', 'ObjectExpression'] or
    type is 'AssignmentExpression' and node.left.type is 'ObjectPattern'
  )
  switch type
    when 'AssignmentExpression'
      switch parent.type
        when 'ReturnStatement'
          return yes
    when 'FunctionExpression'
      return yes if level >= LEVEL_ACCESS

dump = (obj) -> _dump merge obj, parent: null

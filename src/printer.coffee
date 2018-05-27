{merge, dump: _dump, extend, isString, isArray, del, flatten} = require './helpers'

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

fragmentsToText = (fragments) ->
  (fragment.code for fragment in fragments).join('')

printStatementSequence = (body, o) ->
  # TODO: directives
  fragments = []
  for stmt, index in body
    fragments.push '\n' if index and o.spaced
    fragments.push @print(stmt, merge o, spaced: no, front: yes, asStatement: yes, level: LEVEL_TOP)...
  fragments

BLOCK = ['IfStatement', 'ForStatement', 'ForInStatement', 'WhileStatement', 'ClassStatement', 'TryStatement', 'SwitchStatement']

asStatement = (fragments, o) ->
  fragments.unshift o.indent
  fragments.push ';' unless @type in BLOCK
  fragments.push '\n'
  fragments

wrapInParensIfAbove = (level) -> (fragments, o) ->
  return fragments unless o.level > level
  [@makeCode('('), fragments..., @makeCode(')')]

wrapInBraces = (fragments, o) ->
  ['{', fragments..., '}']

printAssignment = (o) ->
  fragments = []
  fragments.push @print(@left, o, LEVEL_LIST)...
  fragments.push " #{@operator ? '='} "
  fragments.push @print(@right, o, LEVEL_LIST)...
  fragments

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

printBinaryExpression = (o) ->
  fragments = []
  fragments.push @print(@left, o, LEVEL_OP)...
  fragments.push " #{@operator} "
  fragments.push @print(@right, o, LEVEL_OP)...
  fragments

printCall = (o) ->
  fragments = []
  fragments.push 'new ' if @type is 'NewExpression'
  fragments.push @print(@callee, o, LEVEL_ACCESS)...
  fragments.push '('
  for arg, index in @arguments
    fragments.push ', ' if index
    fragments.push @print(arg, o, LEVEL_LIST)...
  fragments.push ')'
  fragments

printArray = (o) ->
  return ['[]'] unless @elements.length
  fragments = []
  fragments.push '['
  for element, index in @elements
    fragments.push ', ' if index
    fragments.push @print(element, o)...
  fragments.push ']'
  fragments

printParams = (o) ->
  fragments = []
  fragments.push '('
  for param, index in @params
    fragments.push ', ' if index
    fragments.push @print(param, o)...
  fragments.push ') '
  fragments

printBlock = (o) ->
  return ['{}'] unless @body.length
  fragments = []
  fragments.push '{'
  fragments.push '\n'
  body = @printStatementSequence @body, indent o
  fragments.push body...
  fragments.push o.indent + '}'
  fragments

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
    fragments = []
    fragments.push @print(@id, o)...
    if @init
      fragments.push ' = '
      fragments.push @print(@init, o)...
    fragments
  ExpressionStatement: (o) ->
    @print @expression, o
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
  ThisExpression: (o) ->
    ['this']
  Super: (o) ->
    ['super']
  NewExpression: printCall
  CallExpression: printCall
  FunctionExpression: (o) ->
    fragments = []
    fragments.push 'async ' if @async
    fragments.push 'function'
    fragments.push @printParams(o)...
    fragments.push @print(@body, o)...
    fragments
  ArrowFunctionExpression: (o) ->
    fragments = []
    fragments.push 'async ' if @async
    fragments.push @printParams(o)...
    fragments.push '=> '
    fragments.push @print(@body, o)...
    fragments
  ClassMethod: (o) ->
    fragments = []
    fragments.push 'static ' if @static
    fragments.push 'async ' if @async
    fragments.push @print(@key, o)...
    fragments.push @printParams(o)...
    fragments.push @print(@body, o)...
    fragments
  BlockStatement: printBlock
  ReturnStatement: (o) ->
    fragments = ['return']
    if @argument
      fragments.push ' ', @print(@argument, o, LEVEL_PAREN)...
    fragments
  MemberExpression: (o) ->
    fragments = []
    fragments.push @print(@object, o, LEVEL_ACCESS)...
    property = @print @property, o
    if SIMPLENUM.test fragmentsToText fragments
      fragments.push '.'
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
  ArrayExpression: printArray
  ArrayPattern: printArray
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
  ForInStatement: (o) ->
    fragments = []
    fragments.push 'for ('
    fragments.push @print(@left, o)...
    fragments.push ' in '
    fragments.push @print(@right, o)...
    fragments.push ') '
    fragments.push @print(@body, o)...
    fragments
  SequenceExpression: (o) ->
    fragments = []
    for expression, index in @expressions
      fragments.push ', ' if index
      fragments.push @print(expression, o)...
    fragments
  BinaryExpression: printBinaryExpression
  LogicalExpression: printBinaryExpression
  UnaryExpression: (o) ->
    fragments = []
    fragments.push @operator
    fragments.push ' ' if /[a-z]$/.test @operator
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
  ContinueStatement: (o) ->
    ['continue']
  BreakStatement: (o) ->
    ['break']
  AwaitExpression: (o) ->
    fragments = ['await ']
    fragments.push @print(@argument, o)...
    fragments
  SwitchStatement: (o) ->
    fragments = ['switch (']
    fragments.push @print(@discriminant, o)...
    fragments.push ') {\n'
    for kase in @cases
      fragments.push @print(kase, indent o)...
    fragments.push '}'
    fragments
  SwitchCase: (o) ->
    fragments = []
    fragments.push o.indent
    if @test
      fragments.push 'case '
      fragments.push @print(@test, o)...
    else
      fragments.push 'default'
    fragments.push ':'
    fragments.push '\n'
    fragments.push @printStatementSequence(@consequent, indent o)...
    fragments
  TryStatement: (o) ->
    fragments = []
    fragments.push 'try '
    fragments.push @print(@block, o)...
    fragments.push ' ', @print(@handler, o)... if @handler
    fragments
  CatchClause: (o) ->
    fragments = []
    fragments.push 'catch ('
    fragments.push @print(@param, o)...
    fragments.push ') '
    fragments.push @print(@body, o)...
    fragments
  ThrowStatement: (o) ->
    fragments = []
    fragments.push 'throw '
    fragments.push @print(@argument, o)...
    fragments
  ClassExpression: (o) ->
    fragments = []
    fragments.push 'class'
    if @id
      fragments.push ' '
      fragments.push @print(@id, o)...
    if @superClass
      fragments.push ' extends '
      fragments.push @print(@superClass, o)...
    if @body
      fragments.push ' '
      fragments.push @print(@body, o)...
    fragments
  ClassBody: (o) ->
    printBlock.call @, merge o, spaced: yes

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
  # return flatten(@print child, o for child in node) if isArray node
  node.parent = @
  printed = fragmentize print(node, merge o, front: no), node
  return printed unless needsParens node, o
  [node.makeCode('('), printed..., node.makeCode(')')]

exports.print = print = (node, o) ->
  _asStatement = del o, 'asStatement'
  extend node, {
    makeCode, printStatementSequence, wrapInBraces, asStatement, printParams
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

SIMPLENUM = /^[+-]?\d+$/

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
      return yes if level > LEVEL_LIST
      return yes if node.left.type is 'ObjectPattern'
      switch parent.type
        when 'ReturnStatement'
          return yes
    when 'FunctionExpression', 'ArrowFunctionExpression'
      return yes if level >= LEVEL_ACCESS
    when 'BinaryExpression'
      return yes if parent.type is 'BinaryExpression' and node is parent.right
      return yes if parent.type is 'UnaryExpression'
    when 'AwaitExpression'
      return yes if level >= LEVEL_PAREN

dump = (obj) -> _dump merge obj, parent: null

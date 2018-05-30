{merge, dump: _dump, extend, isString, isArray, del, flatten, compact} = require './helpers'

#### CodeFragment

# The various nodes defined below all compile to a collection of **CodeFragment** objects.
# A CodeFragments is a block of generated code, and the location in the source file where the code
# came from. CodeFragments can be assembled together into working code just by catting together
# all the CodeFragments' `code` snippets, in order.
exports.CodeFragment = class CodeFragment
  constructor: (parent, code) ->
    @code = "#{code}"
    @type = parent?.constructor?.name or 'unknown'
    @locationData =
      if parent?.loc
        first_line: parent.loc.start.line - 1
        first_column: parent.loc.start.column
        last_line: parent.loc.end.line - 1
        first_column: parent.loc.end.column
        range: parent.range
    @comments = parent?.comments

  toString: ->
    # This is only intended for debugging.
    "#{@code}#{if @locationData then ": " + locationDataToString(@locationData) else ''}"

fragmentsToText = (fragments) ->
  (fragment.code for fragment in fragments).join('')

printStatementSequence = (body, o) ->
  for stmt, index in body
    @push '\n' if index and o.spaced
    @print stmt, merge o, spaced: no, asStatement: yes, level: LEVEL_TOP

BLOCK = [
  'IfStatement', 'ForStatement', 'ForInStatement', 'ForOfStatement'
  'WhileStatement', 'ClassDeclaration', 'TryStatement', 'SwitchStatement'
  'ClassMethod'#, 'FunctionDeclaration'
]

asStatement = (fragments, o) ->
  fragments.unshift o.indent
  fragments.push ';' unless @type in BLOCK
  fragments.push '\n'
  fragments

wrapInBraces = (o) ->
  @unshift '{'
  @push '}'

printAssignment = (o) ->
  @print @left, o, LEVEL_LIST
  @push " #{@operator ? '='} "
  @print @right, o, LEVEL_LIST

printObject = (o) ->
  isCompact = yes
  for {shorthand} in @properties when not shorthand
    isCompact = no
    break
  @push '\n' unless isCompact
  for prop, index in @properties
    if index
      @push ','
      @push if isCompact then ' ' else '\n'
    @push o.indent + TAB unless isCompact
    @print prop, if isCompact then o else indent o
  @push '\n' + o.indent unless isCompact
  @wrapInBraces()

fronts = (o) ->
  merge o, keepFront: yes

printBinaryExpression = (o) ->
  @print @left, fronts(o), LEVEL_OP
  @push " #{@operator} "
  @print @right, o, LEVEL_OP

printCall = (o) ->
  @push 'new ' if @type is 'NewExpression'
  @print @callee, o, LEVEL_ACCESS
  @push '('
  for arg, index in @arguments
    @push ', ' if index
    @print arg, o, LEVEL_LIST
  @push ')'

printArray = (o) ->
  return @push '[]' unless @elements.length
  @push '['
  printElements = =>
    for element, index in @elements
      if element
        @printed element, o
  elements = printElements()
  shouldBreak = '\n' in fragmentsToText compact flatten elements
  if shouldBreak
    closingNewline = '\n' + o.indent
    o = indent o
    elements = printElements()
    @push '\n' + o.indent
  separator = if shouldBreak then ',\n' + o.indent else ', '
  lastIndex = elements.length - 1
  for element, index in elements
    @push separator if index
    @push element if element
    @push ', ' if index is lastIndex and not element
  @push closingNewline if closingNewline?
  @push ']'

printParams = (o) ->
  @push '('
  for param, index in @params
    @push ', ' if index
    @print param
  @push ') '

printBlock = (o) ->
  return @push '{}' unless @body.length or @directives.length
  @push '{'
  @push '\n'
  @printStatementSequence [@directives..., @body...], indent o
  @push o.indent + '}'

printSplat = (o) ->
  @push '...'
  @print @argument, o, LEVEL_OP

printClass = (o) ->
  @push 'class'
  if @id
    @push ' '
    @print @id
  if @superClass
    @push ' extends '
    @print @superClass
  if @body
    @push ' '
    @print @body

printFunction = (o) ->
  @push 'async ' if @async
  @push 'function'
  @push '*' if @generator
  # if @id
  #   @push ' '
  #   @print @id
  @printParams o
  @print @body

printer =
  File: (o) ->
    o.indent = if o.bare then '' else TAB
    o.spaced = yes

    @print @program
  Program: (o) ->
    @printStatementSequence @body, o
  VariableDeclaration: (o) ->
    @push 'var '
    for declaration, index in @declarations
      if declaration.init and index
        indented = indent o
        leadingSpace = '\n' + indented.indent
      else
        leadingSpace = ' '
      @push ',' + leadingSpace if index
      @print declaration, indented ? o
  VariableDeclarator: (o) ->
    @print @id
    if @init
      @push ' = '
      @print @init
  ExpressionStatement: (o) ->
    @print @expression, merge o, setFront: yes
  AssignmentExpression: printAssignment
  AssignmentPattern: printAssignment
  Identifier: (o) ->
    @push @name
  NumericLiteral: (o) ->
    @push @extra.raw
  StringLiteral: (o) ->
    @push @extra.raw
  RegExpLiteral: (o) ->
    @push @extra.raw
  DirectiveLiteral: (o) ->
    @push @extra.raw
  BooleanLiteral: (o) ->
    @push if @value then 'true' else 'false'
  NullLiteral: (o) ->
    @push 'null'
  PassthroughLiteral: (o) ->
    @push @value
  ThisExpression: (o) ->
    @push 'this'
  Super: (o) ->
    @push 'super'
  NewExpression: printCall
  CallExpression: printCall
  FunctionExpression: printFunction
  # FunctionDeclaration: printFunction
  ArrowFunctionExpression: (o) ->
    @push 'async ' if @async
    @printParams o
    @push '=> '
    @print @body
  ClassMethod: (o) ->
    @push 'static ' if @static
    @push 'async ' if @async
    @push '*' if @generator
    @push '[' if @computed
    @print @key
    @push ']' if @computed
    @printParams o
    @print @body
  BlockStatement: printBlock
  ReturnStatement: (o) ->
    @push 'return'
    if @argument
      @push ' '
      @print @argument, o, LEVEL_PAREN
  MemberExpression: (o) ->
    @print @object, fronts(o), LEVEL_ACCESS
    property = @printed @property, o
    if SIMPLENUM.test @fragmentsToText()
      @push '.'
    if @computed
      @push '[', property, ']'
    else
      @push '.', property
  ObjectPattern: printObject
  ObjectExpression: printObject
  ObjectProperty: (o) ->
    value = @printed @value, o
    return @push value if @shorthand
    @push '[' if @computed
    @print @key
    @push ']' if @computed
    @push ': '
    @push value
  ArrayExpression: printArray
  ArrayPattern: printArray
  TemplateLiteral: (o) ->
    @push '`'
    for quasi, index in @quasis
      @print quasi
      expression = @expressions[index]
      if expression
        @push '${'
        @print expression
        @push '}'
    @push '`'
  TemplateElement: (o) ->
    @push @value.raw
  ForStatement: (o) ->
    @push 'for ('
    @print @init
    @push '; '
    @print @test
    @push '; '
    @print @update
    @push ') '
    @print @body
  ForInStatement: (o) ->
    @push 'for ('
    @print @left
    @push ' in '
    @print @right
    @push ') '
    @print @body
  ForOfStatement: (o) ->
    @push 'for '
    @push 'await ' if @await
    @push '('
    @print @left
    @push ' of '
    @print @right
    @push ') '
    @print @body
  SequenceExpression: (o) ->
    for expression, index in @expressions
      @push ', ' if index
      @print expression
  BinaryExpression: printBinaryExpression
  LogicalExpression: printBinaryExpression
  UnaryExpression: (o) ->
    @push @operator
    @push ' ' if /[a-z]$/.test @operator
    @print @argument, o, LEVEL_OP
  UpdateExpression: (o) ->
    @push @operator if @prefix
    @print @argument, if @prefix then o else fronts o
    @push @operator unless @prefix
  IfStatement: (o) ->
    @push 'if ('
    @print @test
    @push ') '
    @print @consequent
    if @alternate
      @push ' else '
      @print @alternate
  ConditionalExpression: (o) ->
    @print @test, o, LEVEL_COND
    @push ' ? '
    @print @consequent, o, LEVEL_LIST
    @push ' : '
    @print @alternate, o, LEVEL_LIST
  ContinueStatement: (o) ->
    @push 'continue'
  BreakStatement: (o) ->
    @push 'break'
  AwaitExpression: (o) ->
    @push 'await '
    @print @argument, o, LEVEL_OP
  YieldExpression: (o) ->
    @push 'yield'
    @push '*' if @delegate
    if @argument
      @push ' '
      @print @argument, o, LEVEL_OP
  SwitchStatement: (o) ->
    @push 'switch ('
    @print @discriminant
    @push ') {\n'
    for kase in @cases
      @print kase, indent o
    @push o.indent + '}'
  SwitchCase: (o) ->
    @push o.indent
    if @test
      @push 'case '
      @print @test
    else
      @push 'default'
    @push ':'
    @push '\n'
    @printStatementSequence @consequent, indent o
  TryStatement: (o) ->
    @push 'try '
    @print @block
    if @handler
      @push ' '
      @print @handler
    if @finalizer
      @push ' finally '
      @print @finalizer
  CatchClause: (o) ->
    @push 'catch ('
    @print @param
    @push ') '
    @print @body
  ThrowStatement: (o) ->
    @push 'throw '
    @print @argument, o, LEVEL_LIST
  ClassExpression: printClass
  ClassDeclaration: printClass
  ClassBody: (o) ->
    printBlock.call @, merge o, spaced: yes
  SpreadElement: printSplat
  RestElement: printSplat
  WhileStatement: (o) ->
    @push 'while ('
    @print @test
    @push ') '
    @print @body
  TaggedTemplateExpression: (o) ->
    @print @tag
    @print @quasi
  ImportDeclaration: (o) ->
    @push 'import '
    leading = []
    named = []
    if @specifiers
      if @specifiers.length
        for specifier in @specifiers
          (if specifier.type in ['ImportDefaultSpecifier', 'ImportNamespaceSpecifier']
            leading
           else
             named
          ).push specifier
        for specifier, index in leading
          @push ', ' if index
          @print specifier
        if named.length
          @push ', ' if leading.length
          indented = indent o
          @push '{\n' + indented.indent
          for specifier, index in named
            @push ',\n' + indented.indent if index
            @print specifier, indented
          @push '\n' + o.indent + '}'
      else
        @push '{}'
      @push ' from '
    @print @source
  ImportDefaultSpecifier: (o) ->
    @print @local
  ImportNamespaceSpecifier: (o) ->
    @push '* as '
    @print @local
  ImportSpecifier: (o) ->
    @print @imported
    unless @local.name is @imported.name
      @push ' as '
      @print @local
  ExportNamedDeclaration: (o) ->
    @push 'export '
    if @specifiers.length
      indented = indent o
      @push '{\n' + indented.indent
      for specifier, index in @specifiers
        @push ',\n' + indented.indent if index
        @print specifier, indented
      @push '\n' + o.indent + '}'
    else if @declaration
      @print @declaration
    else
      @push '{}'
    if @source
      @push ' from '
      @print @source
  ExportDefaultDeclaration: (o) ->
    @push 'export default '
    @print @declaration
  ExportAllDeclaration: (o) ->
    @push 'export * from '
    @print @source
  ExportSpecifier: (o) ->
    @print @local
    unless @local.name is @exported.name
      @push ' as '
      @print @exported
  Directive: (o) ->
    @print @value

makeCode = (code) ->
  new CodeFragment @, code

fragmentize = (fragments, node) ->
  for fragment in fragments
    if isString fragment
      node.makeCode fragment
    else
      fragment

nodePrinted = (node, o, level) ->
  keepFront = del o, 'keepFront'
  setFront = del o, 'setFront'
  o = merge o, {level} if level
  o = merge o,
    front:
      if setFront
        yes
      else if keepFront
        o.front
      else
        no
  # return flatten(@print child, o for child in node) if isArray node
  node.parent = @
  printed = fragmentize print(node, o), node
  return printed unless needsParens node, o
  [node.makeCode('('), printed..., node.makeCode(')')]

nodePrint = (defaultOpts) -> (node, o = defaultOpts, level) ->
  @push @printed node, o, level

push = (fragments...) ->
  @fragments.push fragments...
unshift = (fragments...) ->
  @fragments.unshift fragments...

nodeFragmentsToText = ->
  fragmentsToText flatten @fragments

exports.print = print = (node, o) ->
  _asStatement = del o, 'asStatement'
  extend node, {
    makeCode, printStatementSequence, wrapInBraces, asStatement, printParams
    printed: nodePrinted, print: nodePrint(o)
    fragments: []
    push, unshift
    fragmentsToText: nodeFragmentsToText
  }
  # node.tab = o.indent
  console.log {missing: node} unless printer[node.type]
  printed = printer[node.type].call node, o
  printed = flatten node.fragments
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

PRECEDENCE = {}
PRECEDENCE_LEVELS = [
  ["|>"]
  ["||", "??"]
  ["&&"]
  ["|"]
  ["^"]
  ["&"]
  ["==", "===", "!=", "!=="]
  ["<", ">", "<=", ">=", "in", "instanceof"]
  [">>", "<<", ">>>"]
  ["+", "-"]
  ["*", "/", "%"]
  ["**"]
]
for tier, i in PRECEDENCE_LEVELS
  for op in tier
    PRECEDENCE[op] = i

getPrecedence = (op) -> PRECEDENCE[op]

leadsWithObject = (node) ->
  while node.type is 'MemberExpression'
    return yes if node.object.type is 'ObjectExpression'
    node = node.object

isClass = ({type}) -> type in ['ClassExpression', 'ClassDeclaration']

needsParens = (node, o) ->
  {type, parent} = node
  {level} = o

  return yes if o.front and (
    type in ['FunctionExpression', 'ObjectExpression'] or
    type is 'AssignmentExpression' and (node.left.type is 'ObjectPattern' or node.left.type is 'MemberExpression' and leadsWithObject(node.left))
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
    when 'BinaryExpression', 'LogicalExpression'
      return yes if parent.type in ['BinaryExpression', 'LogicalExpression'] and do ->
        isLeft = node is parent.left
        associatesLeft = node.operator isnt '**'
        if node.operator is parent.operator
          return no if isLeft and associatesLeft
          return no if not isLeft and not associatesLeft
          return yes
        nodePrecedence = getPrecedence node.operator
        parentPrecedence = getPrecedence parent.operator
        return yes unless nodePrecedence? and parentPrecedence?
        nodePrecedence < parentPrecedence
      return yes if parent.type is 'UnaryExpression'
    when 'UnaryExpression'
      return yes if parent.type is 'BinaryExpression' and parent.operator is '**'
      return yes if node.operator in ['+', '-'] and parent.type is 'UnaryExpression' and parent.operator is node.operator
    when 'UpdateExpression'
      return yes if node.prefix and parent.type is 'UnaryExpression' and (node.operator is '++' and parent.operator is '+' or node.operator is '--' and parent.operator is '-')
    when 'AwaitExpression', 'YieldExpression'
      return yes if level >= LEVEL_PAREN
    when 'ConditionalExpression'
      return yes if level >= LEVEL_COND
    when 'SequenceExpression'
      return yes if level >= LEVEL_PAREN
    when 'CallExpression'
      return yes if parent.type is 'NewExpression' and node is parent.callee
    when 'ClassExpression'
      return yes if level >= LEVEL_ACCESS
      return yes if isClass(parent) and node is parent.superClass

dump = (obj) -> _dump merge obj, parent: null

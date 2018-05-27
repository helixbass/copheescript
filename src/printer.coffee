{merge, dump} = require './helpers'

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

printStatementSequence = (body, node, o) ->
  # o = merge o, level: LEVEL_TOP
  # TODO: directives
  fragments = []
  for stmt, index in body
    fragments.push node.makeCode '\n' if index > 0 and o.spaced
    fragments.push print(stmt, o)...
  fragments

asStatement = (fragments, node, o) ->
  fragments.unshift node.makeCode o.indent
  fragments.push node.makeCode ';\n'
  fragments

printer =
  File: (o) ->
    o.indent = if o.bare then '' else TAB
    o.spaced = yes

    print @program, o
  Program: (o) ->
    printStatementSequence @body, @, o
  VariableDeclaration: (o) ->
    fragments = [@makeCode 'var ']
    for declaration, index in @declarations
      fragments.push ', ' if index > 0
      fragments.push print(declaration, o)...
    asStatement fragments, @, o
  VariableDeclarator: (o) ->
    print @id, o
  ExpressionStatement: (o) ->
    asStatement print(@expression, o), @, o
  AssignmentExpression: (o) ->
    fragments = []
    fragments.push print(@left, o)...
    fragments.push @makeCode " #{@operator} "
    fragments.push print(@right, o)...
    fragments
  Identifier: (o) ->
    [@makeCode @name]
  NumericLiteral: (o) ->
    [@makeCode @extra.raw]

makeCode = (code) ->
  new CodeFragment @, code

exports.print = print = (node, o) ->
  node.makeCode = makeCode
  # node.tab = o.indent
  dump {missing: node} unless printer[node.type]
  printer[node.type].call node, o

TAB = '  '

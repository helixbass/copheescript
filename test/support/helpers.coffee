prettier = require 'prettier'
babylon = require 'babylon'
formatWithPrettier = (js, {returnAll} = {}) ->
  formatted = prettier.format "FORCE_NON_DIRECTIVE; #{js}"
  # {parsed: {ast}, opts} = prettier.__debug.parse "FORCE_NON_DIRECTIVE; #{js}"
  # opts.originalText = js
  # {formatted} = prettier.__debug.formatAST ast, opts
  # formatted = prettier.format formatted
  {tokens} = babylon.parse formatted,
    tokens: yes
    sourceType: 'module'
    allowImportExportEverywhere: yes
    plugins: ['jsx', 'objectRestSpread', 'dynamicImport']
  joined =
    (for {value, type} in tokens # when type isnt 'CommentLine'
      if type is 'CommentBlock'
        value.replace /\s+/g, ' '
      else
        value ? type.label)
    .join ' '
  return joined unless returnAll
  {joined, tokens, formatted}

# See [http://wiki.ecmascript.org/doku.php?id=harmony:egal](http://wiki.ecmascript.org/doku.php?id=harmony:egal).
egal = (a, b) ->
  if a is b
    a isnt 0 or 1/a is 1/b
  else
    a isnt a and b isnt b

# A recursive functional equivalence helper; uses egal for testing equivalence.
arrayEgal = (a, b) ->
  if egal a, b then yes
  else if a instanceof Array and b instanceof Array
    return no unless a.length is b.length
    return no for el, idx in a when not arrayEgal el, b[idx]
    yes

diffOutput = (expectedOutput, actualOutput) ->
  expected = formatWithPrettier expectedOutput, returnAll: yes
  actual = formatWithPrettier actualOutput, returnAll: yes
  expectedOutputLines = expectedOutput.split '\n'
  actualOutputLines = actualOutput.split '\n'
  for line, i in actualOutputLines
    if line isnt expectedOutputLines[i]
      actualOutputLines[i] = "#{yellow}#{line}#{reset}"
  """Expected generated JavaScript to be:
  #{reset}#{expectedOutput}#{red}
    but instead it was:
  #{reset}#{actualOutputLines.join '\n'}#{red}
    Expected formatted:
  #{reset}#{expected.formatted}#{red}
    actual formatted:
  #{reset}#{actual.formatted}#{red}
    Expected tokens:
  #{reset}#{expected.joined}#{red}
    actual tokens:
  #{reset}#{actual.joined}#{red}
  """
  # #{reset}#{JSON.stringify({label, value} for {type: {label}, value} in actual.tokens)}#{red}

exports.eq = (a, b, msg) ->
  ok egal(a, b), msg or
  "Expected #{reset}#{a}#{red} to equal #{reset}#{b}#{red}"

exports.arrayEq = (a, b, msg) ->
  ok arrayEgal(a, b), msg or
  "Expected #{reset}#{a}#{red} to deep equal #{reset}#{b}#{red}"

exports.eqJS = (input, expectedOutput, msg) ->
  actualOutput = CoffeeScript.compile input, bare: yes
  .replace /^\s+|\s+$/g, '' # Trim leading/trailing whitespace.
  ok egal(formatWithPrettier(expectedOutput), formatWithPrettier(actualOutput)), msg or diffOutput expectedOutput, actualOutput

exports.isWindows = -> process.platform is 'win32'

exports.inspect = (obj) ->
  if global.testingBrowser
    JSON.stringify obj, null, 2
  else
    require('util').inspect obj,
      depth: 10
      colors: if process.env.NODE_DISABLE_COLORS then no else yes

# Helpers to get AST nodes for a string of code.
exports.getAstRoot = getAstRoot = (code) ->
  CoffeeScript.compile code, ast: yes

# The root node is always a `File` node, so for brevity in the tests return its
# children from `program.body`.
getAstExpressions = (code) ->
  ast = getAstRoot code
  ast.program.body

# Many tests want just the root node.
exports.getAstExpression = (code) ->
  expressionStatementAst = getAstExpressions(code)[0]
  ok expressionStatementAst.type is 'ExpressionStatement', 'Expected ExpressionStatement AST wrapper'
  expressionStatementAst.expression

exports.getAstStatement = (code) ->
  statement = getAstExpressions(code)[0]
  ok statement.type isnt 'ExpressionStatement', "Didn't expect ExpressionStatement AST wrapper"
  statement

exports.getAstExpressionOrStatement = (code) ->
  expressionAst = getAstExpressions(code)[0]
  return expressionAst unless expressionAst.type is 'ExpressionStatement'
  expressionAst.expression

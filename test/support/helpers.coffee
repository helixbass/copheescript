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
    plugins: ['jsx']
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

# Helper to get AST nodes for a string of code.
getExpressionAst = (code) ->
  ast = CoffeeScript.compile code, ast: yes
  [statement] = ast.program.body
  return statement unless statement.type is 'ExpressionStatement'
  return statement.expression

# Recursively compare all values of enumerable properties of `expected` with
# those of `actual`. Use `looseArray` helper function to skip array length
# comparison.

exports.deepStrictEqualExpectedProps = deepStrictEqualExpectedProps = (actual, expected) ->
  white = (text, values...) -> (text[i] + "#{reset}#{v}#{red}" for v, i in values).join('') + text[i]
  eq actual.length, expected.length if expected instanceof Array and not expected.loose
  for k , v of expected
    if 'object' is typeof v
      fail white"`actual` misses #{k} property." unless k of actual
      deepStrictEqualExpectedProps actual[k], v
    else
      eq actual[k], v, white"Property #{k}: expected #{actual[k]} to equal #{v}"
  actual

exports.expressionAstMatchesObject = (code, expected) ->
  ast = getExpressionAst code
  if expected?
    deepStrictEqualExpectedProps ast, expected
  else
    console.log require('util').inspect ast,
      depth: 10
      colors: yes

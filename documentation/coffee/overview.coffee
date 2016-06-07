# Assignment:
$number   = 42
$opposite = true

# Conditions:
$number = -42 if $opposite

# Functions:
$square = ( $x ) -> $x * $x

# Arrays:
$list = [1, 2, 3, 4, 5]

# Hashes:
$math_hash =
  root:   'sqrt'
  square: $square
  cube:   ( $x ) -> $x * $square $x

# Objects:
$math = {{
  root:   'sqrt'
  square: $square
  cube:   ( $x ) -> $x * $square $x
}}

# Splats:
$race = ( $winner, $runners... ) ->
  var_dump $winner, $runners

# Existence:
echo "I knew it!" if $elvis?

# Array comprehensions:
$cubes = ( $math.cube $num for $num of $list )

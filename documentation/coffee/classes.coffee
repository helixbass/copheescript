class Animal
  __construct: (@$name) ->

  move: ( $meters ) ->
    echo "#{ @name } moved #{ $meters }m."

class Snake extends Animal
  move: ->
    echo "Slithering..."
    super 5

class Horse extends Animal
  move: ->
    echo "Galloping..."
    super 45

$sam = new Snake "Sammy the Python"
$tom = new Horse "Tommy the Palomino"

$sam.move()
$tom.move()





$x = 6

$add_x_and_arg = ( $y ) ->
  ( $z ) ->
    $x + $y + $z

$add_x_and_arg( 4 )( 5 ) # 15

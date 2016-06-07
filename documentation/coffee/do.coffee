for $filename of $list
  do ( $filename ) ->
    $fs.readFile $filename, ( $err, $contents ) ->
      $compile $filename, $contents.toString()

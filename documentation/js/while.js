// Generated by CoffeeScript 1.9.1
if ($this->studyingEconomics) {
  while ($supply > $demand) {
    $buy();
  }
  while (!($supply > $demand)) {
    $sell();
  }
}

$num = 6;

$lyrics = call_user_func((function() use (&$num) {
  $results = [];
  while ($num -= 1) {
    $results[] = $num . " little monkeys, jumping on the bed. One fell out and bumped his head.";
  }
  return $results;
}));

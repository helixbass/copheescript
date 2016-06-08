// Generated by CoffeeScript 1.9.1
foreach (['toast', 'cheese', 'wine'] as $food) {
  $eat($food);
}

$courses = ['greens', 'caviar', 'truffles', 'roast', 'cake'];

foreach ($courses as $i => $dish) {
  $menu($i + 1, $dish);
}

$foods = ['broccoli', 'spinach', 'chocolate'];

foreach ($foods as $food) {
  if ($food !== 'chocolate') {
    $eat($food);
  }
}

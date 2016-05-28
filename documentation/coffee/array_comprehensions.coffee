# Eat lunch.
$eat $food for $food of ['toast', 'cheese', 'wine']

# Fine five course dining.
$courses = ['greens', 'caviar', 'truffles', 'roast', 'cake']
$menu $i + 1, $dish for $i, $dish of courses

# Health conscious meal.
$foods = ['broccoli', 'spinach', 'chocolate']
$eat $food for $food of $foods when $food isnt 'chocolate'

# TODO: support multiple soaks in chain involving function call
# $zip = $lottery.drawWinner?().address?.zipcode

$winner = $lottery.drawWinner?()

$zip = $winner.address?.zipcode



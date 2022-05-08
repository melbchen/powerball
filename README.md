This project is an implementation of Powerball with solidity.
The powerball rules can be found on [THE LOTT](https://www.thelott.com/powerball/how-to-play).

## Contract Deployment

When deploy the contract, the ticket price will have to be provided. And the manager's address will be recorded. The manager could be an external contract which periodically calls the draw() function. Or it could be a person who calls the draw() function manually.

## How to play with it

- Call the function play() by sending tickets with the payment.
- The manager call the draw() function to determine winning ticket and calculate all prizes.
- A winner can withdraw fund through withdraw() fuction.

## APIs

### public state variables (can be accessed directly)

- prizeAllocationRate -- allocation rates of Prize Pool. Refer to [Prize Pool Distribution](https://www.thelott.com/about/prize-pool)
- manager -- the address who runs draw function at the draw time. It could be a external contract address
- drawId -- the draw sequence ID
- initialPrizePoolForNextDraw -- the initial value of prize pool for next Draw
- ticketPrice -- the price of each ticket in **_ether_**
- counter -- how many tickets in total now
- prizePoolTotal -- the total value of current prize pool
- winningTicket -- the winning ticket of current draw
- players -- all players: counter mapped to player
- tickets -- all valid tickets: counter mapped to ticket. **A player and his/her ticket will have same counter**.
- winnersCounter -- how many winners in current draw
- winners -- all winners: winnersCounter mapped to winner
- divisions -- all divisions of current draw
- pastDraws -- the record history of past draws

### public functions

- play -- players can select and pay tickets to play. Multiple tickets supported in one transaction. The caller has to transfer sufficient fund, specifically msg.value should be no less than the number of tickets times the ticket price. A sample input could be : [[1,3,5,7,9,11,13,2], [2,4,6,8,10,12,14,6]].
- draw -- only manger can call it. it is doing serveral jobs: generate the winning ticket; calculate the quantity of winners for each division; calculate the prize for each division; release the prize to players (if no one wins in a division, put the fund into next draw); record the draw in history; reset the game for next draw.
- withdraw -- withdraw funds from the contract. If called, all funds available to the caller should be refunded. This is the **only** place the contract ever transfers funds out.
- getMyTickets -- get all tickets as a **string** for a caller. A sample return data is [1,3,5,7,9,11,13,2][2,4,6,8,10,12,14,6].

## Test

To test the contract, run `truffle test` in the project root directory.

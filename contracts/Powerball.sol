// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

contract Powerball {
    struct Ticket {
        uint256 number0;
        uint256 number1;
        uint256 number2;
        uint256 number3;
        uint256 number4;
        uint256 number5;
        uint256 number6;
        uint256 thePowerball;
    }

    struct Division {
        uint256 quantityOfWinners;
        uint256 prize;
    }

    struct Winner {
        address winnerAddress;
        uint256 prizeCategory;
        Ticket winningTicket;
    }

    struct Draw {
        uint256 drawId;
        uint256 drawTime;
        Ticket winningTicket;
        uint256 quantityOfTickets;
        uint256 initialPrizePool;
        uint256 prizePoolTotal;
    }

    uint256[] public prizeAllocationRate; // allocation rates of Prize Pool
    address public manager; // the address who runs draw function at the draw time. It could be a external contract address

    uint256 public drawId; // the draw sequence ID
    uint256 public initialPrizePoolForNextDraw; // the initial value of prize pool for next Draw
    uint256 public ticketPrice; // the price of each ticket in ether
    uint256 public counter; // how many tickets now
    uint256 public prizePoolTotal; // the total value of current prize pool
    Ticket public winningTicket; // the winning ticket of current draw

    mapping(uint256 => address) public players; // counter mapped to player
    mapping(uint256 => Ticket) public tickets; // all valid tickets: counter mapped to ticket

    uint256 public winnersCounter; // how many winners in current draw
    mapping(uint256 => Winner) public winners; // all winners: winnersCounter mapped to winner
    mapping(address => uint256) private pendingWithdrawals; // players can withdraw if their balance is non-zero

    mapping(uint256 => Division) public divisions; // all divisions of current draw

    mapping(uint256 => Draw) public pastDraws; // the record history of past draws

    uint256 private nounceRandom; // used for generate random numbers
    mapping(uint256 => uint256) private randomSevenNumbers; // the seven numbers generated randomly
    mapping(uint256 => uint256) private sortedRandomSevenNumbers; // sorted numbers

    /// fund transferred not sufficient to pay the tickets
    error FundTransferredNotSufficient();
    /// ticket(s) not valid, please ensure numbers are in range and not duplicated
    error TicketNotValid();

    constructor(uint256 _ticketPrice) {
        manager = msg.sender;
        ticketPrice = _ticketPrice * 1000000000000000000; // ether to wei
        prizeAllocationRate = [3500, 180, 110, 200, 150, 970, 760, 1500, 2630]; // refer to: https://www.thelott.com/about/prize-pool
    }

    // only manager can call
    modifier restricted() {
        require(msg.sender == manager);
        _;
    }

    // generate a pseudorandom number
    function random() private returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        block.timestamp,
                        nounceRandom++
                    )
                )
            );
    }

    // check if a number exists in the randomSevenNumbers
    function isExistingInRandomSevenNumbers(uint256 newNumber)
        private
        view
        returns (bool)
    {
        for (uint256 i = 0; i < 7; i++) {
            if (randomSevenNumbers[i] == newNumber) {
                return true;
            }
        }
        return false;
    }

    // randomly generate seven different numbers
    function randomlyGenerateSevenDifferentNumbers() private {
        for (uint256 i = 0; i < 7; i++) {
            uint256 aRandomNumber = (random() % 35) + 1;
            bool theNumberExists = isExistingInRandomSevenNumbers(
                aRandomNumber
            );
            while (theNumberExists) {
                aRandomNumber = (random() % 35) + 1;
                theNumberExists = isExistingInRandomSevenNumbers(aRandomNumber);
            }
            randomSevenNumbers[i] = aRandomNumber;
        }
        // // test: 3,5,7,9,11,13
        // randomSevenNumbers[0] = 3;
        // randomSevenNumbers[1] = 5;
        // randomSevenNumbers[2] = 7;
        // randomSevenNumbers[3] = 9;
        // randomSevenNumbers[4] = 11;
        // randomSevenNumbers[5] = 12;
        // randomSevenNumbers[6] = 13;
    }

    // sort the randomSevenNumbers in ascending order
    function sortTheRandomSevenNumbers() private {
        uint256 index = 0;
        for (uint256 i = 0; i < 35; i++) {
            for (uint256 j = 0; j < 7; j++) {
                if (i + 1 == randomSevenNumbers[j]) {
                    sortedRandomSevenNumbers[index++] = i + 1;
                }
            }
        }
    }

    // transfer ticketNumbers from map to array
    function transferTicketNumbersToArray(Ticket memory ticket)
        private
        pure
        returns (uint256[7] memory)
    {
        uint256[7] memory numbers;
        numbers[0] = (ticket.number0);
        numbers[1] = (ticket.number1);
        numbers[2] = (ticket.number2);
        numbers[3] = (ticket.number3);
        numbers[4] = (ticket.number4);
        numbers[5] = (ticket.number5);
        numbers[6] = (ticket.number6);
        return numbers;
    }

    // check if a ticket is valid:
    // 1. numbers and the powerball are in the correct range
    // 2. no duplicates in numbers
    function isValidTicket(Ticket calldata ticket) private pure returns (bool) {
        uint256[7] memory numbers = transferTicketNumbersToArray(ticket);
        if (ticket.thePowerball < 1 || ticket.number0 > 20) {
            return false;
        }
        for (uint256 i = 0; i < numbers.length - 1; i++) {
            if (numbers[i] < 1 || numbers[i] > 35) {
                return false;
            }
            // check duplicates
            for (uint256 j = 1; j < numbers.length - i; j++) {
                if (numbers[i] == numbers[i + j]) {
                    return false;
                }
            }
        }
        return true;
    }

    // determin the division category.
    // refer to: https://www.thelott.com/powerball/stories/australian-powerball-winners
    function determineDivisionCategory(
        uint256 quantityOfWinningNumbers,
        bool isWinningThePowerball
    ) private pure returns (uint256) {
        uint256 devision = 100; //not win
        if (isWinningThePowerball && quantityOfWinningNumbers == 7) {
            devision = 0;
        }
        if (!isWinningThePowerball && quantityOfWinningNumbers == 7) {
            devision = 1;
        }
        if (isWinningThePowerball && quantityOfWinningNumbers == 6) {
            devision = 2;
        }
        if (!isWinningThePowerball && quantityOfWinningNumbers == 6) {
            devision = 3;
        }
        if (isWinningThePowerball && quantityOfWinningNumbers == 5) {
            devision = 4;
        }
        if (isWinningThePowerball && quantityOfWinningNumbers == 4) {
            devision = 5;
        }
        if (!isWinningThePowerball && quantityOfWinningNumbers == 5) {
            devision = 6;
        }
        if (isWinningThePowerball && quantityOfWinningNumbers == 3) {
            devision = 7;
        }
        if (isWinningThePowerball && quantityOfWinningNumbers == 2) {
            devision = 8;
        }
        return devision;
    }

    // players can select and pay tickets to play.
    // multiple tickets supported in one transaction.
    // the caller has to transfer sufficient fund.
    // sample input in Remix: [[1,3,5,7,9,11,13,2], [2,4,6,8,10,12,14,6]]
    function play(Ticket[] calldata newTickets) public payable {
        require(newTickets.length > 0);

        // make sure fund is sufficient
        if (msg.value >= ticketPrice * newTickets.length) {
            // check all tickets are valid
            bool isAllTicketsValid = true;
            for (uint256 i = 0; i < newTickets.length; i++) {
                if (!isValidTicket(newTickets[i])) {
                    isAllTicketsValid = false;
                }
            }
            if (isAllTicketsValid) {
                for (uint256 i = 0; i < newTickets.length; i++) {
                    players[counter] = msg.sender;
                    tickets[counter] = newTickets[i];
                    counter++;
                }

                prizePoolTotal += msg.value;
            } else {
                revert TicketNotValid();
            }
        } else {
            pendingWithdrawals[msg.sender] += msg.value; // refund insufficient payment
            revert FundTransferredNotSufficient();
        }
    }

    // generate the winning ticket
    // calculate the quantity of winners for each division
    // calculate the prize for each division
    // release the prize to players. If no one wins in a division, put the fund into next draw
    // record the draw in history
    // reset the game for next draw
    function draw() public restricted {
        // generate the winning ticket
        randomlyGenerateSevenDifferentNumbers();
        sortTheRandomSevenNumbers();
        winningTicket.number0 = sortedRandomSevenNumbers[0];
        winningTicket.number1 = sortedRandomSevenNumbers[1];
        winningTicket.number2 = sortedRandomSevenNumbers[2];
        winningTicket.number3 = sortedRandomSevenNumbers[3];
        winningTicket.number4 = sortedRandomSevenNumbers[4];
        winningTicket.number5 = sortedRandomSevenNumbers[5];
        winningTicket.number6 = sortedRandomSevenNumbers[6];
        winningTicket.thePowerball = (random() % 20) + 1;

        // calculate the quantity of winners for each division
        for (uint256 i = 0; i < counter; i++) {
            bool isWinningThePowerball = tickets[i].thePowerball ==
                winningTicket.thePowerball;
            uint256 quantityOfWinningNumbers = 0;

            uint256[7] memory numbersFromGame = transferTicketNumbersToArray(
                tickets[i]
            );
            for (uint256 j = 0; j < 7; j++) {
                for (uint256 m = 0; m < 7; m++) {
                    if (numbersFromGame[j] == sortedRandomSevenNumbers[m]) {
                        quantityOfWinningNumbers++;
                    }
                }
            }
            uint256 divisionCategory = determineDivisionCategory(
                quantityOfWinningNumbers,
                isWinningThePowerball
            );
            if (divisionCategory < 9) {
                divisions[divisionCategory].quantityOfWinners++;

                winners[winnersCounter].winnerAddress = players[i];
                winners[winnersCounter].prizeCategory = divisionCategory;
                winners[winnersCounter].winningTicket = tickets[i];
                winnersCounter++;
            }
        }

        // calculate the prize for each division
        for (uint256 i = 0; i < 9; i++) {
            if (divisions[i].quantityOfWinners > 0) {
                divisions[i].prize =
                    (prizePoolTotal * prizeAllocationRate[i]) /
                    10000 /
                    divisions[i].quantityOfWinners;
            } else {
                // put the prize into initial prize pool of next draw
                initialPrizePoolForNextDraw +=
                    (prizePoolTotal * prizeAllocationRate[i]) /
                    10000;
            }
        }

        // Release prize to all winners
        for (uint256 i = 0; i < winnersCounter; i++) {
            pendingWithdrawals[winners[i].winnerAddress] += divisions[
                winners[i].prizeCategory
            ].prize;
        }

        // put current draw to pastDraws
        pastDraws[drawId].drawId = drawId;
        pastDraws[drawId].drawTime = block.timestamp;
        pastDraws[drawId].winningTicket = winningTicket;
        pastDraws[drawId].quantityOfTickets = counter;
        pastDraws[drawId].prizePoolTotal = prizePoolTotal;
        pastDraws[drawId].initialPrizePool = initialPrizePoolForNextDraw;
        drawId++;

        // reset the game.
        // players, tickets, winningTicket, winners, divisions
        // don't need to reset because of being overwrited in next game
        prizePoolTotal = initialPrizePoolForNextDraw;
        initialPrizePoolForNextDraw = 0;
        counter = 0;
        winnersCounter = 0;
    }

    // Withdraw funds from the contract.
    // If called, all funds available to the caller should be refunded.
    // This is the *only* place the contract ever transfers funds out.
    function withdraw() public {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0);

        pendingWithdrawals[msg.sender] = 0;
        if (!payable(msg.sender).send(amount)) {
            pendingWithdrawals[msg.sender] = amount;
        }
    }

    // convert a uint256 to its ASCII string decimal representation
    // inspired by OraclizeAPI's implementation - MIT licence
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    // get all tickets for a caller
    function getMyTickets() public view returns (string memory) {
        string memory myTickets = "";
        for (uint256 i = 0; i < counter; i++) {
            if (players[i] == msg.sender) {
                string memory s = string(
                    abi.encodePacked(
                        "[",
                        toString(tickets[i].number0),
                        ",",
                        toString(tickets[i].number1),
                        ",",
                        toString(tickets[i].number2),
                        ",",
                        toString(tickets[i].number3),
                        ",",
                        toString(tickets[i].number4),
                        ",",
                        toString(tickets[i].number5),
                        ",",
                        toString(tickets[i].number6),
                        ",",
                        toString(tickets[i].thePowerball),
                        "]"
                    )
                );
                myTickets = string(abi.encodePacked(myTickets, s));
            }
        }
        return myTickets;
    }
}

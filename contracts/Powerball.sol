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

    address public manager; // the person who run draw function at the draw time
    // uint256 public initialPrizePool; // the initial value of current prize pool
    uint256 public ticketPrice; // the price of each ticket
    uint256 public counter; // how many tickets now
    uint256 public prizePoolTotal; // the total value of current prize pool
    Ticket public winningTicket; // the winning ticket of current draw

    mapping(uint256 => address) public players; // counter mapped to player
    mapping(uint256 => Ticket) public games; // all valid games: counter mapped to ticket
    mapping(address => uint256) public pendingWithdrawals; // players can withdraw if the raletive balance is non-zero

    uint256 public drawId; // the draw sequence
    mapping(uint256 => Ticket) public pastDraws; // the record history of previous draws
    mapping(address => uint256) public winnersDivision1; // all players who won division 1
    mapping(address => uint256) public winnersDivision2; // all players who won division 2
    mapping(address => uint256) public winnersDivision3; // all players who won division 3
    mapping(address => uint256) public winnersDivision4; // all players who won division 4
    mapping(address => uint256) public winnersDivision5; // all players who won division 5
    mapping(address => uint256) public winnersDivision6; // all players who won division 6
    mapping(address => uint256) public winnersDivision7; // all players who won division 7

    uint256 private nounceRandom;
    mapping(uint256 => uint256) public randomSevenNumbers;
    mapping(uint256 => uint256) public sortedRandomSevenNumbers;

    /// fund transferred not insufficient to pay the tickets
    error FundTransferredNotSufficient();
    /// ticket(s) not valid, please ensure numbers are in range and not duplicated
    error TicketNotValid();

    constructor(uint256 _ticketPrice) {
        manager = msg.sender;
        ticketPrice = _ticketPrice;
    }

    // only manager can call
    modifier restricted() {
        require(msg.sender == manager);
        _;
    }

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

    function randomlyGenerateSevenDifferentNumbers() public {
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
    }

    function sortTheRandomSevenNumbers() private {
        uint256 index = 0;
        for (uint256 i = 0; i < 35; i++) {
            for (uint256 j = 0; j < 7; j++) {
                if (i + 1 == randomSevenNumbers[j]) {
                    sortedRandomSevenNumbers[index++] = i;
                }
            }
        }
    }

    function transferTicketNumbersToArray(Ticket calldata ticket)
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

    // players can select and pay tickets to play.
    // the caller has to transfer sufficient fund.
    // sample input in Remix: [[1,3,5,7,9,11,13,2], [2,4,6,8,10,12,14,6]]
    function play(Ticket[] calldata tickets) public payable {
        require(tickets.length > 0);

        // make sure fund is sufficient
        if (msg.value >= ticketPrice * tickets.length) {
            // check all tickets are valid
            bool isAllTicketsValid = true;
            for (uint256 i = 0; i < tickets.length; i++) {
                if (!isValidTicket(tickets[i])) {
                    isAllTicketsValid = false;
                }
            }
            if (isAllTicketsValid) {
                for (uint256 i = 0; i < tickets.length; i++) {
                    players[counter] = msg.sender;
                    games[counter] = tickets[i];
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

    function draw() public restricted {
        // put current ticket to pastDraws
        pastDraws[drawId++] = winningTicket;

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

        // calculate the prize for each division
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
}

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
    uint256 public ticketPrice; // the price of each ticket
    uint256 public counter; // how many tickets now

    mapping(uint256 => address) public players; // counter mapped to player
    mapping(uint256 => Ticket) public games; // all valid games: counter mapped to ticket

    uint256 public prizePoolTotal; // the total value of current prize pool
    Ticket public winningTicket; // the winning ticket of current draw
    mapping(address => uint256) public pendingWithdrawals; // players can withdraw if the raletive balance is non-zero
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

    // function isValidTicket

    // players can select and pay tickets to play.
    // the caller has to transfer sufficient fund.
    function play(Ticket[] calldata tickets) public payable {
        require(tickets.length > 0);
        if (msg.value >= ticketPrice * tickets.length) {
            for (uint256 i = 0; i < tickets.length; i++) {
                players[counter] = msg.sender;
                games[counter] = tickets[i];
                counter++;
            }

            prizePoolTotal += msg.value;
        } else {
            pendingWithdrawals[msg.sender] += msg.value; // refund insufficient payment
            revert FundTransferredNotSufficient();
        }
    }

    function draw() public restricted {
        // uint256[] memory selectedNumbers;
        randomlyGenerateSevenDifferentNumbers();
        sortTheRandomSevenNumbers();
        // uint256[] memory theSortedSevenNumbers;
        winningTicket.number0 = sortedRandomSevenNumbers[0];
        winningTicket.number1 = sortedRandomSevenNumbers[1];
        winningTicket.number2 = sortedRandomSevenNumbers[2];
        winningTicket.number3 = sortedRandomSevenNumbers[3];
        winningTicket.number4 = sortedRandomSevenNumbers[4];
        winningTicket.number5 = sortedRandomSevenNumbers[5];
        winningTicket.number6 = sortedRandomSevenNumbers[6];
        // for (uint256 i = 0; i < 7; i++) {
        //     // theSortedSevenNumbers.push
        //     winningNumbers.push(sortedRandomSevenNumbers[i]);
        //     // winningTicket.numbers.push(sortedRandomSevenNumbers[i]);
        // }
        // winningTicket.numbers = sortedRandomSevenNumbers;
        winningTicket.thePowerball = (random() % 20) + 1;
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

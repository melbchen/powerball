// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

struct Ticket {
    uint256[] numbers;
    uint256 thePowerball;
}

struct Game {
    address player;
    Ticket ticket;
}

contract Powerball {
    address public manager; // the person who run draw function at the draw time
    uint256 public ticketPrice; // the price of each ticket
    Game[] public games; // all valid games
    // mapping(address => Ticket) public tickets; // the quantity of tickets holding by players for current draw
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

    /// fund transferred not insufficient to buying the tickets
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

    function random() private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        block.timestamp,
                        games.length
                    )
                )
            );
    }

    function isExistingNumber(uint256[] memory numbers, uint256 newNumber)
        private
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < numbers.length; i++) {
            if (numbers[i] == newNumber) {
                return true;
            }
        }
        return false;
    }

    function randomlyGenerateSevenDifferentNumbers()
        private
        view
        returns (uint256[] memory)
    {
        uint256[] memory selectedNumbers;
        for (uint256 i = 0; i < 7; i++) {
            uint256 aRandomNumber = (random() % 35) + 1;
            bool theNumberExists = isExistingNumber(
                selectedNumbers,
                aRandomNumber
            );
            while (theNumberExists) {
                aRandomNumber = (random() % 35) + 1;
                theNumberExists = isExistingNumber(
                    selectedNumbers,
                    aRandomNumber
                );
            }
            selectedNumbers[i] = (aRandomNumber);
        }
        return selectedNumbers;
    }

    function sortNumbersInArray(uint256[] memory numbers)
        private
        pure
        returns (uint256[] memory)
    {
        uint256[] memory sortedNumbers;
        uint256 counter = 0;
        for (uint256 i = 0; i < 35; i++) {
            for (uint256 j = 0; j < numbers.length; j++) {
                if (i + 1 == numbers[j]) {
                    sortedNumbers[counter++] = i;
                }
            }
        }
        return sortedNumbers;
    }

    // function isValidTicket

    // players can select and pay tickets to play.
    // the caller has to transfer sufficient fund.
    function play(Ticket[] calldata tickets) public payable {
        require(tickets.length > 0);
        if (msg.value >= ticketPrice * tickets.length) {
            for (uint256 i = 0; i < tickets.length; i++) {
                games.push(Game({player: msg.sender, ticket: tickets[i]}));
            }

            prizePoolTotal += msg.value;
        } else {
            pendingWithdrawals[msg.sender] += msg.value; // refund insufficient payment
            revert FundTransferredNotSufficient();
        }
    }

    function draw() public restricted {
        // uint256[] memory selectedNumbers;
        winningTicket.numbers = sortNumbersInArray(
            randomlyGenerateSevenDifferentNumbers()
        );
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

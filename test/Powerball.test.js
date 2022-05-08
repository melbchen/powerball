const Powerball = artifacts.require("Powerball");

let instance;

contract("Powerball", (accounts) => {
  beforeEach(async () => {
    instance = await Powerball.deployed();
  });

  describe("constructor", () => {
    it("should deploy successfully with a valid manager", async () => {
      const manager = await instance.manager.call();
      assert.ok(manager);
    });

    it("should load prize allocation rate", async () => {
      const prizeAllocationRate = await instance.prizeAllocationRate.call(0);
      assert.ok(prizeAllocationRate);
    });

    it("should have a correct ticket price", async () => {
      const ticketPrice = await instance.ticketPrice.call();
      assert.equal(ticketPrice, web3.utils.toWei("1", "ether"));
    });
  });

  describe("play", () => {
    it("should reject ticket with duplicated numbers", async () => {
      const tickets = [[1, 1, 5, 7, 9, 11, 13, 2]];
      try {
        await instance.play(tickets, {
          from: accounts[1],
          value: web3.utils.toWei("1", "ether"),
        });
        assert(false);
      } catch (err) {
        assert(err);
      }
    });

    it("should reject ticket with numbers out of range", async () => {
      const tickets = [[1, 3, 5, 7, 9, 11, 103, 2]];
      try {
        await instance.play(tickets, {
          from: accounts[1],
          value: web3.utils.toWei("1", "ether"),
        });
        assert(false);
      } catch (err) {
        assert(err);
      }
    });

    it("should reject ticket with the powerball out of range", async () => {
      const tickets = [[1, 3, 5, 7, 9, 11, 13, 22]];
      try {
        await instance.play(tickets, {
          from: accounts[1],
          value: web3.utils.toWei("1", "ether"),
        });
        assert(false);
      } catch (err) {
        assert(err);
      }
    });

    it("should reject playing with insufficient payment", async () => {
      const tickets = [[1, 3, 5, 7, 9, 11, 13, 2]];
      try {
        await instance.play(tickets, {
          from: accounts[1],
          value: web3.utils.toWei("0.5", "ether"),
        });
        assert(false);
      } catch (err) {
        assert(err);
      }
    });

    it("should accept playing single ticket with sufficient payment", async () => {
      const tickets = [[1, 3, 5, 7, 9, 11, 13, 2]];
      try {
        await instance.play(tickets, {
          from: accounts[1],
          value: web3.utils.toWei("1", "ether"),
        });
        assert(true);
      } catch (err) {
        assert(false);
      }
    });

    it("should accept playing multiple tickets with sufficient payment", async () => {
      const tickets = [[1, 3, 5, 7, 9, 11, 13, 2]];
      tickets.push([2, 4, 6, 8, 10, 12, 14, 6]);
      try {
        await instance.play(tickets, {
          from: accounts[1],
          value: web3.utils.toWei("2", "ether"),
        });
        assert(true);
      } catch (err) {
        assert(false);
      }
    });
  });

  describe("draw", () => {
    it("should not allow calling draw function other than the manager", async () => {
      try {
        await instance.draw({
          from: accounts[1],
        });
        assert(false);
      } catch (err) {
        assert(err);
      }
    });

    it("should declare winning ticket after draw", async () => {
      await instance.draw({ from: accounts[0] });
      const winningTicket = await instance.winningTicket.call();
      assert.isAtLeast(
        Number(winningTicket.number0),
        1,
        `number0 ${winningTicket.number0}`
      );
      assert.isAtLeast(
        Number(winningTicket.number1),
        1,
        `number1 ${winningTicket.number1}`
      );
      assert.isAtLeast(
        Number(winningTicket.number2),
        1,
        `number2 ${winningTicket.number2}`
      );
      assert.isAtLeast(
        Number(winningTicket.number3),
        1,
        `number3 ${winningTicket.number3}`
      );
      assert.isAtLeast(
        Number(winningTicket.number4),
        1,
        `number4 ${winningTicket.number4}`
      );
      assert.isAtLeast(
        Number(winningTicket.number5),
        1,
        `number5 ${winningTicket.number5}`
      );
      assert.isAtLeast(
        Number(winningTicket.number6),
        1,
        `number6 ${winningTicket.number6}`
      );
      assert.isAtLeast(
        Number(winningTicket.thePowerball),
        1,
        `thePowerball ${winningTicket.thePowerball}`
      );
    });

    it("should update the draw history after draw", async () => {
      await instance.draw({ from: accounts[0] });
      const pastDraw = await instance.pastDraws.call(0);
      assert.isAtLeast(
        Number(pastDraw.drawTime),
        1,
        `drawTime ${pastDraw.drawTime}`
      );
      assert.isAtLeast(
        Number(pastDraw.winningTicket.number0),
        1,
        `number0 ${pastDraw.winningTicket.number0}`
      );
    });

    it("should reset prize pool after draw", async () => {
      await instance.draw({ from: accounts[0] });
      const initialPrizePoolForNextDraw =
        await instance.initialPrizePoolForNextDraw.call();
      assert.equal(
        Number(
          web3.utils.fromWei(initialPrizePoolForNextDraw.toString(), "ether")
        ),
        0
      );
    });
  });

  describe("withdraw", () => {
    it("should reject withdrawals with zero balance", async () => {
      try {
        await instance.withdraw({ from: accounts[2] });
        assert(false);
      } catch (err) {
        assert(err);
      }
    });
  });

  describe("getMyTickets", () => {
    it("should return my tickets", async () => {
      const tickets = [[1, 3, 5, 7, 9, 11, 13, 2]];
      tickets.push([2, 4, 6, 8, 10, 12, 14, 6]);
      await instance.play(tickets, {
        from: accounts[1],
        value: web3.utils.toWei("2", "ether"),
      });
      const myTickets = await instance.getMyTickets({ from: accounts[1] });
      assert.equal(myTickets, "[1,3,5,7,9,11,13,2][2,4,6,8,10,12,14,6]");
    });
  });
});

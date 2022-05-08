const Powerball = artifacts.require("Powerball");

module.exports = function (deployer) {
  deployer.deploy(Powerball, 1);
};

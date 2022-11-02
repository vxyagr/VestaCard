require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config({ path: ".env" });;

module.exports = {
  solidity: "0.8.7",
  networks: {
    mumbai: {
      url: process.env.URL,
      accounts: [process.env.PRIVATE_KEY],
    },
  }, etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  }
};